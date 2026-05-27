class StatisticsController < ApplicationController
  TIMEFRAMES = %w[
    last_7_days
    last_30_days
    last_90_days
    this_year
    all_time
  ].freeze

  def index
    @statistics_timeframe = params[:timeframe].presence_in(TIMEFRAMES)
    @statistics_timeframe_options = TIMEFRAMES
    @statistics_start_date, @statistics_end_date = statistics_date_range
    @statistics = WorkspaceStatistics.new(
      workspace: current_workspace,
      start_date: @statistics_start_date,
      end_date: @statistics_end_date
    ).call
  end

  private
    def statistics_date_range
      return timeframe_date_range(@statistics_timeframe) if @statistics_timeframe.present?

      start_date = parse_statistics_date(params[:start_date]) || WorkspaceStatistics.default_start_date
      end_date = parse_statistics_date(params[:end_date]) || WorkspaceStatistics.default_end_date

      start_date > end_date ? [ end_date, start_date ] : [ start_date, end_date ]
    end

    def timeframe_date_range(timeframe)
      case timeframe
      when "last_7_days" then trailing_days_range(7)
      when "last_30_days" then trailing_days_range(30)
      when "last_90_days" then trailing_days_range(90)
      when "this_year" then [ Date.current.beginning_of_year, Date.current ]
      when "all_time" then all_time_date_range
      end
    end

    def trailing_days_range(days)
      [ Date.current - (days - 1), Date.current ]
    end

    def all_time_date_range
      first_brew_date = current_workspace.brews.minimum(:occurred_at)&.to_date
      last_brew_date = current_workspace.brews.maximum(:occurred_at)&.to_date
      return [ Date.current, Date.current ] if first_brew_date.blank?

      [ first_brew_date, [ last_brew_date, Date.current ].compact.max ]
    end

    def parse_statistics_date(value)
      return nil if value.blank?

      Date.iso8601(value)
    rescue ArgumentError
      nil
    end
end
