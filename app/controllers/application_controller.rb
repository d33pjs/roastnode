class ApplicationController < ActionController::Base
  include Authentication
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  helper_method :current_workspace, :current_membership, :current_workspace_policy

  private
    def current_workspace
      return unless Current.user

      @current_workspace ||= Current.user.ensure_active_workspace!
    end

    def current_membership
      return unless current_workspace

      @current_membership ||= Current.user.membership_for(current_workspace)
    end

    def current_workspace_policy
      @current_workspace_policy ||= WorkspacePolicy.new(current_membership)
    end

    def authorize_workspace_admin!
      return if current_workspace_policy.manage?

      redirect_to root_path, alert: t("authorization.denied")
    end

    def authorize_workspace_write!
      return if current_workspace_policy.write?

      redirect_to root_path, alert: t("authorization.denied")
    end

    def authorize_workspace_export!
      return if current_workspace_policy.export?

      redirect_to root_path, alert: t("authorization.denied")
    end

    def authorize_instance_admin!
      return if Current.user&.instance_admin?

      redirect_to root_path, alert: t("authorization.denied")
    end
end
