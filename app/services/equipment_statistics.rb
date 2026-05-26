class EquipmentStatistics
  RECENT_DAYS = 14
  RECENT_LIMIT = 5

  def initialize(equipment:)
    @equipment = equipment
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
    attr_reader :equipment

    def brews
      @brews ||= brews_scope.includes(:bean).order(occurred_at: :desc, created_at: :desc).to_a
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
      equipment.grinder? ? equipment.grinder_brews : equipment.machine_brews
    end

    def last_service_event
      @last_service_event ||= events.find { |event| (event.event_type_names & service_event_types).any? }
    end

    def service_event_types
      if equipment.grinder?
        %w[grinder_cleaning grinder_deep_cleaning burr_change]
      else
        %w[machine_descaling machine_backflush]
      end
    end

    def brews_since_service
      @brews_since_service ||= if last_service_event
        brews.select { |brew| brew.occurred_at >= last_service_event.occurred_at }
      else
        brews
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
      @recent_dates ||= ((RECENT_DAYS - 1).days.ago.to_date..Date.current).to_a
    end

    def brews_by_date
      @brews_by_date ||= brews.select { |brew| recent_dates.include?(brew.occurred_at.to_date) }.group_by { |brew| brew.occurred_at.to_date }
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
