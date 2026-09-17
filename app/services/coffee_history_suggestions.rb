class CoffeeHistorySuggestions
  def initialize(workspace:, name:, roaster_name:, bean: nil)
    @workspace = workspace
    @name = name.to_s.squish.downcase
    @roaster_name = roaster_name.to_s.squish.downcase
    @bean = bean
  end

  def call
    return [] if @name.blank? || @roaster_name.blank?

    scope = @workspace.beans.where(<<~SQL.squish, @name, @roaster_name)
      LOWER(TRIM(REGEXP_REPLACE(name, '[[:space:]]+', ' ', 'g'))) = ? AND
      LOWER(TRIM(REGEXP_REPLACE(roaster_name, '[[:space:]]+', ' ', 'g'))) = ?
    SQL
    scope = scope.where.not(coffee_history_id: @bean.coffee_history_id) if @bean
    representatives = scope.select("DISTINCT ON (coffee_history_id) beans.*")
      .order(:coffee_history_id, created_at: :desc, id: :desc).limit(20).to_a
    counts = @workspace.beans.where(coffee_history_id: representatives.map(&:coffee_history_id)).group(:coffee_history_id).count
    representatives.map { |bean| { bean:, bag_count: counts.fetch(bean.coffee_history_id) } }
  end
end
