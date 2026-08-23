class BrewGrinderReminder
  Reference = Data.define(:brew) do
    delegate :bean, :grinder, :grind_setting, to: :brew

    def usable?
      grinder.present? || grind_setting.present?
    end

    def comparison_key
      return unless usable?

      [ grinder&.id&.to_s, grind_setting.to_s.strip.downcase.presence ].to_json
    end

    def display_parts
      [ bean.display_name, grinder&.name, grind_setting.to_s.strip.presence ].compact
    end
  end

  Result = Data.define(:last_bean, :last_bean_id, :previous, :best_by_bean_id) do
    def best_for(bean)
      best_by_bean_id[bean.id]
    end
  end

  def initialize(workspace:, user:, method:, beans:)
    @workspace = workspace
    @user = user
    @method = method
    @beans = beans
  end

  def call
    last_brew = previous_brew
    previous = reference_for(last_brew)
    previous = nil unless previous&.usable?

    Result.new(
      last_bean: last_brew&.bean,
      last_bean_id: last_brew&.bean_id,
      previous:,
      best_by_bean_id: best_references
    )
  end

  private
    attr_reader :workspace, :user, :method, :beans

    def previous_brew
      ordered(workspace.brews.where(user:, method:)).first ||
        ordered(workspace.brews.where(method:)).first
    end

    def best_references
      workspace.brews
        .where(method:, bean_id: beans.map(&:id))
        .where.not(rating: nil)
        .where("brews.grinder_id IS NOT NULL OR NULLIF(BTRIM(brews.grind_setting), '') IS NOT NULL")
        .select("DISTINCT ON (brews.bean_id) brews.*")
        .order(Arel.sql(<<~SQL.squish))
          brews.bean_id,
          brews.rating DESC,
          brews.occurred_at DESC NULLS LAST,
          brews.created_at DESC NULLS LAST
        SQL
        .preload(:bean, :grinder)
        .index_by(&:bean_id)
        .transform_values { |brew| reference_for(brew) }
    end

    def ordered(scope)
      scope.includes(:bean, :grinder).order(occurred_at: :desc, created_at: :desc)
    end

    def reference_for(brew)
      Reference.new(brew:) if brew
    end
end
