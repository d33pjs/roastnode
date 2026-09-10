class WorkspaceStatistics
  RECENT_DAYS = 7

  def self.default_start_date
    (RECENT_DAYS - 1).days.ago.to_date
  end

  def self.default_end_date
    Date.current
  end

  def initialize(
    workspace:,
    start_date: nil,
    end_date: nil,
    logger_id: nil,
    recipient_filter: nil
  )
    @workspace = workspace
    @start_date = (start_date || self.class.default_start_date).to_date
    @end_date = (end_date || self.class.default_end_date).to_date
    @start_date, @end_date = @end_date, @start_date if @start_date > @end_date
    @logger_id = logger_id
    @recipient_filter = recipient_filter
  end

  def call
    {
      totals:,
      leaders:,
      series:,
      distributions:,
      rates:,
      breakdowns:,
      personas: WorkspacePersonaStatistics.new(brews:).call
    }
  end

  private
    attr_reader :workspace, :start_date, :end_date, :logger_id, :recipient_filter

    def brews
      @brews ||= filtered_brew_scope
        .includes(:bean, :grinder, :machine, :brewer, :user, :recipient_user)
        .to_a
    end

    def filtered_brew_scope
      scope = workspace.brews.where(
        occurred_at: start_date.beginning_of_day..end_date.end_of_day
      )
      scope = scope.where(user_id: logger_id) if logger_id.present?
      apply_recipient_filter(scope)
    end

    def apply_recipient_filter(scope)
      case recipient_filter
      when nil
        scope
      when "self"
        scope.where(recipient_kind: "self")
      when "guests"
        scope.where(recipient_kind: "guest")
      when /\Auser:(\d+)\z/
        recipient_user_id = Regexp.last_match(1).to_i
        scope.where(
          <<~SQL.squish,
            (brews.recipient_kind = :self_kind AND brews.user_id = :user_id)
            OR
            (brews.recipient_kind = :household_member_kind AND brews.recipient_user_id = :user_id)
          SQL
          self_kind: "self",
          household_member_kind: "household_member",
          user_id: recipient_user_id
        )
      else
        raise ArgumentError, "unsupported recipient filter"
      end
    end

    def espresso_brews
      @espresso_brews ||= brews.select(&:espresso?)
    end

    def beans
      @beans ||= workspace.beans.to_a
    end

    def totals
      priced_costs = known_brew_costs
      known_spends = known_bean_spend_cents
      {
        total_brews: brews.size,
        total_bean_weight_grams: brews.sum(&:bean_weight_grams),
        open_beans: beans.count(&:open?),
        known_spend_cents: known_spends.sum,
        known_spend_bean_count: known_spends.size,
        average_known_brew_cost_cents: average_cost_cents(priced_costs),
        priced_brew_count: priced_costs.size
      }
    end

    def leaders
      {
        grinder: equipment_leader(:grinder),
        machine: equipment_leader(:machine)
      }
    end

    def series
      {
        brews_by_day: recent_dates.map do |date|
          { date:, count: brews_by_date.fetch(date, []).size }
        end,
        consumption_by_day: recent_dates.map do |date|
          { date:, grams: brews_by_date.fetch(date, []).sum(&:bean_weight_grams) }
        end
      }
    end

    def distributions
      {
        taste_balance: count_by_present_value(brews, :taste_balance),
        retention_marker: count_by_present_value(espresso_brews, :retention_marker),
        method: count_by_present_value(brews, :method)
      }
    end

    def rates
      {
        channeling_brew_count: espresso_brews.size,
        channeling_percent: percentage(espresso_brews.count(&:channeling?), espresso_brews.size)
      }
    end

    def breakdowns
      {
        roasters: bean_breakdown(:roaster_name),
        origins: bean_breakdown(:origin),
        processes: bean_breakdown(:process)
      }
    end

    def known_brew_costs
      brews.filter_map do |brew|
        bean = brew.bean
        next if bean.purchase_price_cents.blank? || bean.bag_size_grams.blank? || bean.bag_size_grams <= 0

        brew.bean_weight_grams * bean.purchase_price_cents / bean.bag_size_grams
      end
    end

    def known_bean_spend_cents
      beans.filter_map(&:purchase_price_cents)
    end

    def average_cost_cents(costs)
      return nil if costs.empty?

      (costs.sum / costs.size).round
    end

    def equipment_leader(kind)
      equipment = brews.filter_map(&kind).tally.max_by { |item, count| [ count, item.name ] }
      return nil unless equipment

      item, count = equipment
      { name: item.name, count: }
    end

    def recent_dates
      @recent_dates ||= (start_date..end_date).to_a
    end

    def brews_by_date
      @brews_by_date ||= brews.select { |brew| recent_dates.include?(brew.occurred_at.to_date) }.group_by { |brew| brew.occurred_at.to_date }
    end

    def count_by_present_value(records, method_name)
      records
        .map { |record| record.public_send(method_name) }
        .compact_blank
        .tally
        .sort_by { |label, count| [ -count, label ] }
        .to_h
    end

    def percentage(part, whole)
      return 0 if whole.zero?

      ((part.to_d / whole) * 100).round
    end

    def bean_breakdown(attribute)
      beans
        .map { |bean| bean.public_send(attribute) }
        .compact_blank
        .tally
        .sort_by { |label, count| [ -count, label ] }
        .map { |label, count| { label:, count: } }
    end
end
