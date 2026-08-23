require "base64"

module Activity
  class Query
    ActorOption = Data.define(:value, :label)
    ACTOR_KIND_SQL = "(metadata ->> 'actor_kind')".freeze
    ACTOR_LABEL_SQL = "(metadata ->> 'actor_label')".freeze
    ACTOR_WHITESPACE_SQL_PATTERN = "[[:space:]\u00A0\u1680\u2000-\u200A\u2028\u2029\u202F\u205F\u3000]+".freeze
    ACTOR_NORMALIZED_LABEL_SQL = "BTRIM(REGEXP_REPLACE(#{ACTOR_LABEL_SQL}, ?, ' ', 'g'))".freeze
    ACTOR_CONTROL_SQL_PATTERN = "[[:cntrl:]\u0080-\u009F]".freeze
    ACTOR_SENSITIVE_SQL_PATTERN = Metadata::SENSITIVE.source.freeze
    ACTOR_ABSOLUTE_PATH_SQL_PATTERN = Metadata::ABSOLUTE_PATH.source.sub("\\A", "^").freeze
    ACTOR_OPTION_KEY_SQL = <<~SQL.squish.freeze
      CASE
        WHEN #{ACTOR_KIND_SQL} = 'system' THEN 'system'
        WHEN #{ACTOR_KIND_SQL} = 'user' AND actor_id IS NOT NULL THEN 'user:' || actor_id::text
        WHEN #{ACTOR_KIND_SQL} = 'user' THEN 'former:' || #{ACTOR_LABEL_SQL}
      END
    SQL
    ACTOR_OPTION_SELECT_SQL = <<~SQL.squish.freeze
      DISTINCT ON (#{ACTOR_OPTION_KEY_SQL})
      actor_id,
      #{ACTOR_KIND_SQL} AS actor_kind_snapshot,
      #{ACTOR_LABEL_SQL} AS actor_label_snapshot
    SQL
    KNOWN_SUBJECT_TYPES = EventContract.actions.filter_map do |action|
      EventContract.fetch(action).fetch(:subject_type)
    end.uniq.freeze
    NESTED_SUBJECT_PRELOADS = {
      "InventoryAdjustment" => :bean,
      "PublicBrewShare" => :brew,
      "PublicBeanShare" => :bean,
      "PublicRecipeShare" => :recipe
    }.freeze

    def initialize(workspace:, membership:, user:, category: nil, actor: nil, start_date: nil, end_date: nil)
      @workspace = workspace
      @membership = membership
      @user = user
      @category = category.to_s.presence
      @actor_filter = actor.to_s.presence
      @start_date = parse_date(start_date)
      @end_date = parse_date(end_date)
    end

    def events
      @events ||= apply_filters(authorized_scope).recent
    end

    def paginated_events(page:)
      HistoryPaginator.new(events, page:).tap do |paginator|
        preload_subjects(paginator.records)
      end
    end

    def recent_events(limit:)
      preload_subjects(events.limit(limit).to_a)
    end

    def actor_options
      seen = {}
      actor_option_rows.each do |row|
        actor_id = row[:actor_id]
        kind = row[:actor_kind_snapshot]
        label = validated_actor_label(row[:actor_label_snapshot])
        next unless label

        value = if kind == "system"
          "system"
        elsif actor_id
          "user:#{actor_id}"
        else
          "former:#{Base64.urlsafe_encode64(label, padding: false)}"
        end
        seen[value] ||= label
      end
      seen.map { |value, label| ActorOption.new(value:, label:) }.sort_by { |option| option.label.downcase }
    end

    private
      attr_reader :workspace, :membership, :user, :category, :actor_filter, :start_date, :end_date

      def authorized_scope
        return ActivityEvent.none unless valid_active_workspace_membership?

        visibilities = membership&.can_manage_workspace? ? %w[workspace workspace_admin] : %w[workspace]
        workspace_rows = ActivityEvent.where(workspace:, visibility: visibilities)
        return workspace_rows unless user&.instance_admin?

        workspace_rows.or(ActivityEvent.where(workspace_id: nil, visibility: "instance_admin"))
      end

      def valid_active_workspace_membership?
        membership && workspace && user &&
          membership.workspace_id == workspace.id && membership.user_id == user.id
      end

      def actor_option_rows
        authorized_scope
          .where("jsonb_typeof(metadata) = 'object'")
          .where("jsonb_typeof(metadata -> 'actor_kind') = 'string'")
          .where("jsonb_typeof(metadata -> 'actor_label') = 'string'")
          .where("#{ACTOR_KIND_SQL} IN (?)", %w[user system])
          .where("#{ACTOR_NORMALIZED_LABEL_SQL} <> ''", ACTOR_WHITESPACE_SQL_PATTERN)
          .where("CHAR_LENGTH(#{ACTOR_LABEL_SQL}) <= ?", Metadata::MAX_TEXT)
          .where("NOT (#{ACTOR_LABEL_SQL} ~ ?)", ACTOR_CONTROL_SQL_PATTERN)
          .where(
            "NOT (#{ACTOR_NORMALIZED_LABEL_SQL} ~* ?)",
            ACTOR_WHITESPACE_SQL_PATTERN,
            ACTOR_SENSITIVE_SQL_PATTERN
          )
          .where(
            "NOT (#{ACTOR_NORMALIZED_LABEL_SQL} ~* ?)",
            ACTOR_WHITESPACE_SQL_PATTERN,
            ACTOR_ABSOLUTE_PATH_SQL_PATTERN
          )
          .select(Arel.sql(ACTOR_OPTION_SELECT_SQL))
          .reorder(Arel.sql("#{ACTOR_OPTION_KEY_SQL}, occurred_at DESC, id DESC"))
      end

      def preload_subjects(records)
        preload_event_workspaces(records)
        records.group_by { |event| event[:subject_type] }.each do |subject_type, typed_records|
          next unless KNOWN_SUBJECT_TYPES.include?(subject_type)

          preloadable_records = typed_records.reject { |event| EventContract::ACCOUNT_ACTIONS.include?(event.action) }
          next if preloadable_records.empty?

          nested = NESTED_SUBJECT_PRELOADS[subject_type]
          associations = nested ? { subject: nested } : :subject
          ActiveRecord::Associations::Preloader.new(records: preloadable_records, associations:).call
        end
        records
      end

      def preload_event_workspaces(records)
        records.each do |event|
          association = event.association(:workspace)
          association.target = event.workspace_id == workspace.id ? workspace : nil
          association.loaded!
        end
      end

      def apply_filters(scope)
        if category
          return scope.none unless ActivityEvent::CATEGORIES.include?(category)
          scope = scope.where(category:)
        end
        scope = filter_actor(scope)
        scope = scope.where("occurred_at >= ?", start_date.beginning_of_day) if start_date
        scope = scope.where("occurred_at <= ?", end_date.end_of_day) if end_date
        scope
      end

      def filter_actor(scope)
        return scope unless actor_filter
        return scope.where("metadata ->> 'actor_kind' = ?", "system") if actor_filter == "system"

        kind, id = actor_filter.split(":", 2)
        integer_id = Integer(id, exception: false)
        return scope.where(actor_id: integer_id) if kind == "user" && integer_id
        if kind == "former"
          label = validated_actor_label(Base64.urlsafe_decode64(id.to_s).force_encoding(Encoding::UTF_8))
          return scope.none unless label

          return scope.where(actor_id: nil)
            .where("metadata ->> 'actor_kind' = ?", "user")
            .where("metadata ->> 'actor_label' = ?", label)
        end

        scope.none
      rescue ArgumentError
        scope.none
      end

      def validated_actor_label(value)
        return unless value.is_a?(String)

        label = value.dup.force_encoding(Encoding::UTF_8)
        return unless label.valid_encoding? && label.present?
        return if label.length > Metadata::MAX_TEXT
        return if Metadata.unsafe_text?(label)

        label
      end

      def parse_date(value)
        Date.iso8601(value.to_s) if value.present?
      rescue Date::Error
        nil
      end
  end
end
