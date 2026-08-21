class ActivityController < ApplicationController
  def index
    @activity_query = Activity::Query.new(
      workspace: current_workspace, membership: current_membership, user: Current.user,
      category: params[:category], actor: params[:actor],
      start_date: params[:start_date], end_date: params[:end_date]
    )
    @actor_options = @activity_query.actor_options
    @activity = HistoryPaginator.new(@activity_query.events, page: params[:page])
    @activity_filters_active = params.values_at(:category, :actor, :start_date, :end_date).any?(&:present?)
  end
end
