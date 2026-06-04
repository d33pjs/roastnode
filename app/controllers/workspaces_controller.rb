class WorkspacesController < ApplicationController
  before_action :set_workspace, only: :switch
  before_action :authorize_workspace_admin!, only: %i[edit update]
  before_action :authorize_workspace_owner!, only: %i[transfer_ownership destroy]

  def edit
    @workspace = current_workspace
    load_public_brew_shares
  end

  def update
    @workspace = current_workspace

    if @workspace.update(workspace_params)
      PublicBrewShareRefresher.refresh_for(@workspace)
      redirect_to dashboard_path, notice: t(".updated")
    else
      load_public_brew_shares
      render :edit, status: :unprocessable_entity
    end
  end

  def transfer_ownership
    membership = current_workspace.memberships.find(params[:membership_id])
    result = WorkspaceMembershipManager.new(
      workspace: current_workspace,
      actor_membership: current_membership
    ).transfer_ownership(membership)

    if result.success?
      redirect_to memberships_path, notice: t(".transferred")
    else
      redirect_to memberships_path, alert: t("workspace_membership_manager.errors.#{result.error}")
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to memberships_path, alert: t("authorization.denied")
  end

  def destroy
    @workspace = current_workspace

    unless params[:confirmation] == @workspace.name
      return redirect_to edit_workspace_path, alert: t(".confirmation_mismatch")
    end

    @workspace.destroy_with_history!

    redirect_to root_path, notice: t(".destroyed")
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
      params.require(:workspace).permit(:name, :default_currency, :buy_me_a_coffee_url, :logo, :banner)
    end

    def load_public_brew_shares
      @public_brew_shares = current_workspace
        .public_brew_shares
        .includes(:public_brew_share_views, brew: [ :bean, :user ])
        .order(updated_at: :desc, created_at: :desc)
    end
end
