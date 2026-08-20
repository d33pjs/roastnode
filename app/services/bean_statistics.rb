class BeanStatistics
  RECENT_BREW_LIMIT = 5
  BEST_BREW_LIMIT = 3

  def initialize(bean:, start_date: nil, end_date: nil)
    @bean = bean
    @start_date = start_date&.to_date
    @end_date = end_date&.to_date
    if @start_date.present? && @end_date.present? && @start_date > @end_date
      @start_date, @end_date = @end_date, @start_date
    end
  end

  def call
    {
      totals:,
      averages:,
      rates:,
      comparisons:,
      distributions:,
      best_brews:,
      recent_brews:
    }
  end

  private
    attr_reader :bean, :start_date, :end_date

    def brews
      @brews ||= begin
        scope = bean.brews.includes(:grinder, :machine, :brewer)
        scope = scope.where(occurred_at: start_date.beginning_of_day..) if start_date.present?
        scope = scope.where(occurred_at: ..end_date.end_of_day) if end_date.present?
        scope.order(occurred_at: :desc).to_a
      end
    end

    def espresso_brews
      @espresso_brews ||= brews.select(&:espresso?)
    end

    def totals
      {
        brew_count: brews.size,
        total_bean_weight_grams: brews.sum(&:bean_weight_grams),
        remaining_percent: remaining_percent,
        open_age_days: open_age_days,
        finished_used_grams: bean.finished_used_grams,
        finished_open_days: bean.finished_open_days,
        finished_grams_per_day: bean.finished_grams_per_day
      }
    end

    def averages
      {
        rating: rounded_average(brews.filter_map(&:rating), precision: 1),
        beverage_grams: rounded_average(brews.filter_map(&:beverage_grams), precision: 1),
        total_time_seconds: rounded_average(brews.filter_map(&:total_time_seconds), precision: 0)
      }
    end

    def rates
      channeling_count = espresso_brews.count(&:channeling?)

      {
        channeling_count:,
        channeling_brew_count: espresso_brews.size,
        channeling_percent: percentage(channeling_count, espresso_brews.size)
      }
    end

    def comparisons
      @comparisons ||= BeanComparisonRanker.new(bean:).call
    end

    def distributions
      {
        taste_balance: count_by_present_value(:taste_balance),
        retention_marker: count_by_present_value(:retention_marker, records: espresso_brews),
        grind_setting: count_by_present_value(:grind_setting),
        method: count_by_present_value(:method)
      }
    end

    def best_brews
      brews
        .select { |brew| brew.rating.present? }
        .sort_by { |brew| [ -brew.rating, -brew.occurred_at.to_i ] }
        .first(BEST_BREW_LIMIT)
    end

    def recent_brews
      brews.first(RECENT_BREW_LIMIT)
    end

    def remaining_percent
      return nil if bean.bag_size_grams.blank? || bean.bag_size_grams.to_d <= 0

      percentage(bean.remaining_grams, bean.bag_size_grams)
    end

    def open_age_days
      BeanOpenDuration.new(
        bean:,
        latest_brew_at: bean.brews.maximum(:occurred_at)
      ).call
    end

    def rounded_average(values, precision:)
      return nil if values.empty?

      average = values.sum(&:to_d) / values.size
      average.round(precision)
    end

    def percentage(part, whole)
      return 0 if whole.blank? || whole.to_d.zero?

      ((part.to_d / whole.to_d) * 100).round
    end

    def count_by_present_value(method_name, records: brews)
      records
        .map { |brew| brew.public_send(method_name) }
        .compact_blank
        .tally
        .sort_by { |label, count| [ -count, label ] }
        .to_h
    end
end
