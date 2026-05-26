class PreparationToolStatistics
  RECENT_BREW_LIMIT = 5
  BEST_BREW_LIMIT = 3

  def initialize(preparation_tool:)
    @preparation_tool = preparation_tool
  end

  def call
    {
      totals:,
      averages:,
      rates:,
      distributions:,
      best_brews:,
      recent_brews:
    }
  end

  private
    attr_reader :preparation_tool

    def brews
      @brews ||= preparation_tool.brews.includes(:bean, :grinder, :machine).order(occurred_at: :desc, created_at: :desc).to_a
    end

    def totals
      {
        brew_count: brews.size,
        total_bean_weight_grams: brews.sum(&:bean_weight_grams)
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
      channeling_count = brews.count(&:channeling?)

      {
        channeling_count:,
        channeling_percent: percentage(channeling_count, brews.size)
      }
    end

    def distributions
      {
        taste_balance: count_by_present_value(:taste_balance),
        retention_marker: count_by_present_value(:retention_marker)
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

    def rounded_average(values, precision:)
      return nil if values.empty?

      average = values.sum(&:to_d) / values.size
      average.round(precision)
    end

    def percentage(part, whole)
      return 0 if whole.blank? || whole.to_d.zero?

      ((part.to_d / whole.to_d) * 100).round
    end

    def count_by_present_value(method_name)
      brews
        .map { |brew| brew.public_send(method_name) }
        .compact_blank
        .tally
        .sort_by { |label, count| [ -count, label ] }
        .to_h
    end
end
