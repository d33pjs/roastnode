class EquipmentStatistics
  RECENT_DAYS = 14
  RECENT_LIMIT = 5

  def initialize(equipment:, start_date: nil, end_date: nil)
    @equipment = equipment
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
      service:,
      distributions:,
      series:,
      recent_events:,
      recent_brews:
    }
  end

  private
    attr_reader :equipment, :start_date, :end_date

    def brews
      @brews ||= apply_date_range(brews_scope).includes(:bean).order(occurred_at: :desc, created_at: :desc).to_a
    end

    def all_brews
      @all_brews ||= brews_scope.includes(:bean).order(occurred_at: :desc, created_at: :desc).to_a
    end

    def events
      @events ||= equipment.equipment_events.includes(:user).recent.to_a
    end

    def totals
      {
        brew_count: brews.size,
        total_bean_weight_grams: brews.sum(&:bean_weight_grams)
      }
    end

    def averages
      {
        rating: rounded_average(brews.filter_map(&:rating), precision: 1)
      }
    end

    def rates
      {
        channeling_percent: percentage(brews.count(&:channeling?), brews.size)
      }
    end

    def service
      {
        last_event: last_service_event,
        brews_since_service: brews_since_service.size,
        grams_since_service: brews_since_service.sum(&:bean_weight_grams)
      }
    end

    def distributions
      {
        event_types: event_type_distribution
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

    def recent_events
      events.first(RECENT_LIMIT)
    end

    def recent_brews
      brews.first(RECENT_LIMIT)
    end

    def brews_scope
      case equipment.kind
      when "grinder"
        equipment.grinder_brews
      when "machine"
        equipment.machine_brews
      when "brewer"
        equipment.brewer_brews
      else
        Brew.none
      end
    end

    def last_service_event
      @last_service_event ||= events.find { |event| (event.event_type_names & service_event_types).any? }
    end

    def service_event_types
      case equipment.kind
      when "grinder"
        %w[grinder_cleaning grinder_deep_cleaning burr_change]
      when "machine"
        %w[machine_descaling machine_backflush]
      else
        []
      end
    end

    def brews_since_service
      @brews_since_service ||= if last_service_event
        all_brews.select { |brew| brew.occurred_at >= last_service_event.occurred_at }
      else
        all_brews
      end
    end

    def event_type_distribution
      events
        .flat_map(&:event_type_names)
        .compact_blank
        .tally
        .sort_by { |label, count| [ -count, label ] }
        .to_h
    end

    def recent_dates
      @recent_dates ||= begin
        range_end = end_date || Date.current
        range_start = start_date || (range_end - (RECENT_DAYS - 1))
        (range_start..range_end).to_a
      end
    end

    def brews_by_date
      @brews_by_date ||= brews.select { |brew| recent_dates.include?(brew.occurred_at.to_date) }.group_by { |brew| brew.occurred_at.to_date }
    end

    def apply_date_range(scope)
      scope = scope.where(occurred_at: start_date.beginning_of_day..) if start_date.present?
      scope = scope.where(occurred_at: ..end_date.end_of_day) if end_date.present?
      scope
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
end
