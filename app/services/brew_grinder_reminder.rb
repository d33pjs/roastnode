class BrewGrinderReminder
  Reference = Data.define(:brew) do
    delegate :bean, :grinder, :grind_setting, to: :brew

    def comparison_key
      [ grinder&.id&.to_s, grind_setting.to_s.strip.downcase.presence ].to_json
    end

    def display_parts
      [ bean.display_name, grinder&.name, grind_setting.to_s.strip.presence ].compact
    end
  end

  History = Data.define(:reference, :settings, :recent_settings, :best_settings, :brew_count, :bag_count, :inherited)
  Result = Data.define(:last_bean, :last_bean_id, :previous, :histories_by_bean_id, :last_uses_by_grinder_id) do
    def histories_for(bean)
      histories_by_bean_id.fetch(bean.id, {})
    end
  end

  RECENCY = "brews.occurred_at DESC NULLS LAST, brews.created_at DESC NULLS LAST, brews.id DESC".freeze
  GROUP_COLUMNS = "beans.coffee_history_id, beans.grind_state, brews.grinder_id".freeze

  def initialize(workspace:, user:, method:, beans:)
    @workspace = workspace
    @user = user
    @method = method
    @beans = beans.select { |bean| bean.persisted? && bean.workspace_id == workspace.id }
  end

  def call
    last_brew = previous_brew
    Result.new(
      last_bean: last_brew&.bean,
      last_bean_id: last_brew&.bean_id,
      previous: last_brew && Reference.new(brew: last_brew),
      histories_by_bean_id: histories,
      last_uses_by_grinder_id: last_grinder_uses
    )
  end

  private
    attr_reader :workspace, :user, :method, :beans

    def previous_brew
      ordered(workspace.brews.where(user:, method:)).first ||
        ordered(workspace.brews.where(method:)).first
    end

    def ordered(scope)
      scope.preload(:bean, :grinder).order(Arel.sql(RECENCY))
    end

    def last_grinder_uses
      scope = workspace.brews.joins(:bean)
        .where(beans: { workspace_id: workspace.id, grind_state: "whole_bean" })
        .where(grinder_id: workspace.equipment.grinder.select(:id))
      latest_brews("brews.grinder_id", scope).to_h do |brew|
        [ brew.grinder_id.to_s, Reference.new(brew:) ]
      end
    end

    def eligible_brews
      workspace.brews.where(method:).joins(:bean)
        .where(beans: { workspace_id: workspace.id, coffee_history_id: beans.map(&:coffee_history_id).uniq })
        .where(grinder_id: workspace.equipment.grinder.select(:id))
        .where("brews.grind_setting ~ '[^[:space:]]'")
    end

    def histories
      return {} if beans.empty?

      own = latest_brews("brews.bean_id, brews.grinder_id", eligible_brews.where(bean_id: beans.map(&:id)))
        .index_by { |brew| [ brew.bean_id, brew.grinder_id ] }
      shared = latest_brews(GROUP_COLUMNS, eligible_brews)
        .group_by { |brew| [ brew.bean.coffee_history_id, brew.bean.grind_state ] }
      summaries = setting_summaries

      beans.to_h do |bean|
        entries = shared.fetch([ bean.coffee_history_id, bean.grind_state ], []).to_h do |family_brew|
          reference_brew = own.fetch([ bean.id, family_brew.grinder_id ], family_brew)
          summary = summaries.fetch([ bean.coffee_history_id, bean.grind_state, family_brew.grinder_id ])
          [ family_brew.grinder_id.to_s, History.new(
            reference: Reference.new(brew: reference_brew),
            settings: summary[:settings], recent_settings: summary[:recent_settings], best_settings: summary[:best_settings],
            brew_count: summary[:brew_count], bag_count: summary[:bag_count],
            inherited: reference_brew.bean_id != bean.id
          ) ]
        end
        [ bean.id, entries ]
      end
    end

    def latest_brews(columns, scope)
      scope.select("DISTINCT ON (#{columns}) brews.*")
        .order(Arel.sql("#{columns}, #{RECENCY}"))
        .preload(:bean, :grinder).to_a
    end

    # Return at most three settings per sort mode/history/grind state/grinder.
    # Counts stay in PostgreSQL; no historical Brew collection is instantiated.
    def setting_summaries
      source = eligible_brews.select(
        "brews.id, brews.bean_id, beans.coffee_history_id, beans.grind_state, brews.grinder_id, " \
        "brews.grind_setting, brews.rating, brews.occurred_at, brews.created_at, " \
        "LOWER(REGEXP_REPLACE(brews.grind_setting, '^[[:space:]]+|[[:space:]]+$', '', 'g')) AS normalized_setting"
      ).to_sql
      rows = Brew.connection.select_all(<<~SQL)
        WITH eligible AS (#{source}),
        totals AS (
          SELECT coffee_history_id, grind_state, grinder_id, COUNT(*) AS brew_count,
            COUNT(DISTINCT bean_id) AS bag_count
          FROM eligible GROUP BY coffee_history_id, grind_state, grinder_id
        ),
        settings AS (
          SELECT *, COUNT(*) OVER setting_group AS setting_count,
            AVG(rating) OVER setting_group AS average_rating,
            COUNT(rating) OVER setting_group AS rating_count,
            ROW_NUMBER() OVER (setting_group ORDER BY occurred_at DESC NULLS LAST, created_at DESC NULLS LAST, id DESC) AS latest
          FROM eligible
          WINDOW setting_group AS (PARTITION BY coffee_history_id, grind_state, grinder_id, normalized_setting)
        ),
        ranked AS (
          SELECT *, ROW_NUMBER() OVER (
            PARTITION BY coffee_history_id, grind_state, grinder_id
            ORDER BY setting_count DESC, occurred_at DESC NULLS LAST, created_at DESC NULLS LAST, id DESC
          ) AS position,
          ROW_NUMBER() OVER (
            PARTITION BY coffee_history_id, grind_state, grinder_id
            ORDER BY occurred_at DESC NULLS LAST, created_at DESC NULLS LAST, id DESC
          ) AS recent_position,
          ROW_NUMBER() OVER (
            PARTITION BY coffee_history_id, grind_state, grinder_id
            ORDER BY average_rating DESC NULLS LAST, rating_count DESC,
              occurred_at DESC NULLS LAST, created_at DESC NULLS LAST, id DESC
          ) AS best_position
          FROM settings WHERE latest = 1
        )
        SELECT ranked.*, totals.brew_count, totals.bag_count
        FROM ranked JOIN totals USING (coffee_history_id, grind_state, grinder_id)
        WHERE position <= 3 OR recent_position <= 3 OR (rating_count > 0 AND best_position <= 3)
        ORDER BY coffee_history_id, grind_state, grinder_id, position
      SQL
      rows.group_by { |row| [ row["coffee_history_id"], row["grind_state"], row["grinder_id"] ] }
        .transform_values do |group|
          { brew_count: group.first["brew_count"], bag_count: group.first["bag_count"],
            settings: ranked_settings(group, "position"),
            recent_settings: ranked_settings(group, "recent_position"),
            best_settings: ranked_settings(group.select { |row| row["rating_count"] > 0 }, "best_position") }
        end
    end

    def ranked_settings(rows, position)
      rows.select { |row| row[position] <= 3 }.sort_by { |row| row[position] }.map do |row|
        { setting: row["grind_setting"].strip, count: row["setting_count"],
          average_rating: row["average_rating"]&.to_f, rating_count: row["rating_count"], occurred_at: row["occurred_at"] }
      end
    end
end
