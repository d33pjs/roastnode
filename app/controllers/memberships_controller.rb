class MembershipsController < ApplicationController
  def index
    if invalid_active_workspace?
      Current.user.update!(active_workspace: nil)
      return redirect_to root_path, alert: t("authorization.denied")
    end

    unless current_workspace_policy.read?
      Current.user.ensure_active_workspace!
      return redirect_to root_path, alert: t("authorization.denied")
    end

    @memberships = current_workspace.memberships.includes(:user).order(:role, "users.email_address")
  end

  private
    def invalid_active_workspace?
      Current.user.active_workspace.present? &&
        !Current.user.memberships.exists?(workspace: Current.user.active_workspace)
    end
end
