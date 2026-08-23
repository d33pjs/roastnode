require "base64"

module Activity
  class Query
    ActorOption = Data.define(:value, :label)

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

    def actor_options
      seen = {}
      authorized_scope.reorder(occurred_at: :desc, id: :desc).pluck(:id, :actor_id, :metadata).each do |_id, actor_id, metadata|
        next unless metadata.is_a?(Hash)

        kind = metadata["actor_kind"]
        label = validated_actor_label(metadata["actor_label"])
        next unless %w[user system].include?(kind) && label

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
