class WorkspacesController < ApplicationController
  before_action :set_workspace, only: :switch

  def switch
    if Current.user.memberships.exists?(workspace: @workspace)
      Current.user.update!(active_workspace: @workspace)
      redirect_to root_path, notice: t(".switched", name: @workspace.name)
    else
      Current.user.ensure_active_workspace!
      redirect_to root_path, alert: t("authorization.denied")
    end
  end

  private
    def set_workspace
      @workspace = Workspace.find(params[:id])
    end
end
