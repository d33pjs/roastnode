class WorkspaceWasteStatistics
  LIMIT = 5

  def initialize(beans:, brews:)
    @beans = beans
    @espresso_brews = brews.select(&:espresso?)
  end

  def call
    { leftovers:, grounds:, channeling: }
  end

  private
    def leftovers
      @beans.select { |bean| bean.opened_on.present? && (bean.finished? || bean.archived?) && bean.remaining_grams.positive? }
        .map { |bean| { bean:, grams: bean.remaining_grams } }
        .sort_by { |row| [ -row[:grams], row[:bean].display_name, row[:bean].id ] }.first(LIMIT)
    end

    def grounds
      @espresso_brews.select { |brew| brew.ground_weight_grams.present? && brew.dose_grams.present? }
        .group_by(&:bean).filter_map do |bean, brews|
          grams = brews.sum { |brew| [ brew.ground_weight_grams - brew.dose_grams, 0.to_d ].max }
          { bean:, grams:, sample_count: brews.size } if grams.positive?
        end.sort_by { |row| [ -row[:grams], -row[:sample_count], row[:bean].display_name, row[:bean].id ] }.first(LIMIT)
    end

    def channeling
      @espresso_brews.reject { |brew| brew.channeling.nil? }.group_by(&:bean).filter_map do |bean, brews|
        count = brews.count(&:channeling?)
        { bean:, count:, sample_count: brews.size, percent: (count.to_d * 100 / brews.size).round } if count.positive?
      end.sort_by { |row| [ -row[:count], -row[:percent], -row[:sample_count], row[:bean].display_name, row[:bean].id ] }.first(LIMIT)
    end
end
