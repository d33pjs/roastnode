class DashboardMetrics
  COMPARISON_WEEKS = 4

  def initialize(workspace:, now: Time.current)
    @workspace = workspace
    @now = now
  end

  def call
    {
      counts:,
      inventory:,
      spend:,
      last_coffee_at:,
      comparisons:
    }
  end

  private
    attr_reader :workspace, :now

    def counts
      {
        coffees_today: brews_today.count + external_coffees_today.count,
        coffees_this_week: brews_this_week.count + external_coffees_this_week.count,
        brews_today: brews_today.count,
        brews_this_week: brews_this_week.count
      }
    end

    def inventory
      {
        open_bean_count: open_beans.count,
        stock_bag_count: stock_beans.count,
        stock_grams: stock_beans.sum(:remaining_grams),
        open_grams: open_beans.sum(:remaining_grams),
        closed_bags_today: closed_bags.where(finished_at: today_range).count,
        closed_bags_this_week: closed_bags.where(finished_at: week_range).count
      }
    end

    def spend
      {
        today_cents: spend_cents_for(today_range),
        week_cents: spend_cents_for(week_range)
      }
    end

    def last_coffee_at
      [ latest_brew_at, latest_external_coffee_at ].compact.max
    end

    def comparisons
      {
        coffees_today: comparison_for(current: counts[:coffees_today], baseline: daily_baseline_values { |range| coffee_count_for(range) }),
        coffees_this_week: comparison_for(current: counts[:coffees_this_week], baseline: weekly_baseline_values { |range| coffee_count_for(range) }),
        brews_today: comparison_for(current: counts[:brews_today], baseline: daily_baseline_values { |range| brew_count_for(range) }),
        brews_this_week: comparison_for(current: counts[:brews_this_week], baseline: weekly_baseline_values { |range| brew_count_for(range) }),
        spent_today: comparison_for(current: spend[:today_cents], baseline: daily_baseline_values { |range| spend_cents_for(range) }),
        spent_this_week: comparison_for(current: spend[:week_cents], baseline: weekly_baseline_values { |range| spend_cents_for(range) })
      }
    end

    def brews_today
      @brews_today ||= workspace.brews.where(occurred_at: today_range)
    end

    def brews_this_week
      @brews_this_week ||= workspace.brews.where(occurred_at: week_range)
    end

    def external_coffees_today
      @external_coffees_today ||= workspace.external_coffees.where(occurred_at: today_range)
    end

    def external_coffees_this_week
      @external_coffees_this_week ||= workspace.external_coffees.where(occurred_at: week_range)
    end

    def stock_beans
      @stock_beans ||= workspace.beans.where(archived_at: nil, finished_at: nil, opened_on: nil).where("remaining_grams > 0")
    end

    def open_beans
      @open_beans ||= workspace.beans.open
    end

    def closed_bags
      @closed_bags ||= workspace.beans.where(archived_at: nil).where.not(finished_at: nil)
    end

    def today
      @today ||= now.to_date
    end

    def today_range
      @today_range ||= today.all_day
    end

    def week_range
      @week_range ||= today.all_week
    end

    def latest_brew_at
      workspace.brews.where.not(recipient_kind: :guest).maximum(:occurred_at)
    end

    def latest_external_coffee_at
      workspace.external_coffees.maximum(:occurred_at)
    end

    def coffee_count_for(range)
      brew_count_for(range) + workspace.external_coffees.where(occurred_at: range).count
    end

    def brew_count_for(range)
      workspace.brews.where(occurred_at: range).count
    end

    def spend_cents_for(range)
      brew_spend_cents_for(range) + workspace.external_coffees.where(occurred_at: range).sum(:price_cents).to_i
    end

    def brew_spend_cents_for(range)
      workspace
        .brews
        .includes(:bean)
        .where(occurred_at: range)
        .sum do |brew|
          bean = brew.bean
          next 0 if bean.purchase_price_cents.blank? || bean.bag_size_grams.blank? || bean.bag_size_grams <= 0

          (brew.bean_weight_grams * bean.purchase_price_cents / bean.bag_size_grams).round
        end
    end

    def daily_baseline_values
      (COMPARISON_WEEKS).downto(1).map do |weeks_ago|
        date = today - weeks_ago.weeks
        yield date.all_day
      end
    end

    def weekly_baseline_values
      current_week_start = today.beginning_of_week
      (COMPARISON_WEEKS).downto(1).map do |weeks_ago|
        week_start = current_week_start - weeks_ago.weeks
        yield week_start.all_week
      end
    end

    def comparison_for(current:, baseline:)
      average = average_value(baseline)
      direction = comparison_direction(current, average)
      values = baseline + [ current ]
      decimal_values = values.map(&:to_d)

      {
        current:,
        baseline_average: average,
        percent: comparison_percent(current, average),
        direction:,
        label: comparison_label(current, average, direction),
        values:,
        scale_min: [ 0.to_d, *decimal_values ].min,
        scale_max: decimal_values.max || 0.to_d
      }
    end

    def average_value(values)
      return 0.to_d if values.empty?

      values.sum.to_d / values.size
    end

    def comparison_direction(current, average)
      current = current.to_d
      average = average.to_d
      return "same" if average.zero? && current.zero?
      return "new" if average.zero?
      return "same" if comparison_percent(current, average).zero?

      current > average ? "up" : "down"
    end

    def comparison_percent(current, average)
      current = current.to_d
      average = average.to_d
      return nil if average.zero?

      (((current - average) / average) * 100).round
    end

    def comparison_label(current, average, direction)
      return "same as last 4 weeks" if direction == "same"
      return "new over last 4 weeks" if direction == "new"

      percent = comparison_percent(current, average)
      prefix = percent.positive? ? "+" : ""
      "#{prefix}#{percent}% over last 4 weeks"
    end
end
