class StatisticsController < ApplicationController
  def index
    @statistics = WorkspaceStatistics.new(workspace: current_workspace).call
  end
end
