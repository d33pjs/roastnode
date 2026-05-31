class MembershipsController < ApplicationController
  before_action :set_membership, only: %i[update destroy]

  def index
    if invalid_active_workspace?
      Current.user.update!(active_workspace: nil)
      return redirect_to root_path, alert: t("authorization.denied")
    end

    unless current_workspace_policy.read?
      Current.user.ensure_active_workspace!
      return redirect_to root_path, alert: t("authorization.denied")
    end

    load_memberships
  end

  def update
    result = membership_manager.update_role(@membership, membership_role)
    redirect_to memberships_path, flash_for(result, success_key: ".updated")
  end

  def destroy
    result = membership_manager.remove(@membership)
    redirect_to memberships_path, flash_for(result, success_key: ".removed")
  end

  private
    def invalid_active_workspace?
      Current.user.active_workspace.present? &&
        !Current.user.memberships.exists?(workspace: Current.user.active_workspace)
    end

    def load_memberships
      @memberships = current_workspace.memberships.includes(:user).order(:role, "users.email_address")
      @transfer_memberships = @memberships.reject { |membership| membership.id == current_membership.id }
    end

    def set_membership
      @membership = current_workspace.memberships.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      redirect_to memberships_path, alert: t("authorization.denied")
    end

    def membership_manager
      @membership_manager ||= WorkspaceMembershipManager.new(
        workspace: current_workspace,
        actor_membership: current_membership
      )
    end

    def membership_role
      params.require(:membership)[:role]
    end

    def flash_for(result, success_key:)
      if result.success?
        { notice: t(success_key) }
      else
        { alert: t("workspace_membership_manager.errors.#{result.error}") }
      end
    end
end
