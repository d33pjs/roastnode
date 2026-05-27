class StatisticsController < ApplicationController
  def index
    @statistics_start_date, @statistics_end_date = statistics_date_range
    @statistics = WorkspaceStatistics.new(
      workspace: current_workspace,
      start_date: @statistics_start_date,
      end_date: @statistics_end_date
    ).call
  end

  private
    def statistics_date_range
      start_date = parse_statistics_date(params[:start_date]) || WorkspaceStatistics.default_start_date
      end_date = parse_statistics_date(params[:end_date]) || WorkspaceStatistics.default_end_date

      start_date > end_date ? [ end_date, start_date ] : [ start_date, end_date ]
    end

    def parse_statistics_date(value)
      return nil if value.blank?

      Date.iso8601(value)
    rescue ArgumentError
      nil
    end
end
