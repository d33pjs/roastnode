class WorkspacesController < ApplicationController
  before_action :set_workspace, only: :switch
  before_action :authorize_workspace_admin!, only: %i[edit update]

  def edit
    @workspace = current_workspace
  end

  def update
    @workspace = current_workspace

    if @workspace.update(workspace_params)
      redirect_to dashboard_path, notice: t(".updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

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

    def workspace_params
      params.require(:workspace).permit(:name, :default_currency)
    end
end
