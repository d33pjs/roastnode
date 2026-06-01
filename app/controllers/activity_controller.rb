class ActivityController < ApplicationController
  def index
    @activity = HistoryPaginator.new(WorkspaceActivityFeed.new(current_workspace).records, page: params[:page])
  end
end
