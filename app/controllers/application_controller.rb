class ApplicationController < ActionController::Base
  include Authentication
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  around_action :use_current_user_time_zone

  helper_method :current_workspace, :current_membership, :current_workspace_policy, :first_user_setup_available?

  private
    def use_current_user_time_zone(&block)
      resume_session
      zone = Time.find_zone(Current.user&.time_zone)

      if zone
        Time.use_zone(zone, &block)
      else
        yield
      end
    end

    def normalize_decimal_attributes(attributes, *keys)
      keys.each do |key|
        next unless attributes.key?(key)

        attributes[key] = LocalizedNumberParser.normalize_decimal(attributes[key])
      end

      attributes
    end

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

    def first_user_setup_available?
      !User.exists?
    end

    def with_workspace_activity(action:, subject:, occurred_at: nil, details: {}, visibility: nil)
      result = false
      ActiveRecord::Base.transaction do
        result = yield
        raise ActiveRecord::Rollback unless result

        Activity::Emitter.record!(
          action: resolve_activity_value(action),
          workspace: current_workspace,
          actor: Current.user,
          subject: resolve_activity_value(subject),
          occurred_at: resolve_activity_value(occurred_at) || Time.current,
          visibility:,
          details: resolve_activity_value(details)
        )
      end
      result || false
    end

    def with_account_activity(action:, user:, subject: user, details: {})
      result = false
      ActiveRecord::Base.transaction do
        result = yield
        raise ActiveRecord::Rollback unless result

        workspace = user.active_workspace
        Activity::Emitter.record!(
          action:,
          workspace:,
          actor: user,
          subject:,
          visibility: workspace ? "workspace_admin" : "instance_admin",
          details:
        )
      end
      result
    end

    def resolve_activity_value(value)
      value.respond_to?(:call) ? value.call : value
    end

    def record_used_up_transition!(bean, previous_status:)
      bean.reload
      return unless previous_status != "used_up" && bean.used_up?

      Activity::Emitter.record!(
        action: "bean.used_up", workspace: current_workspace, actor: Current.user, subject: bean
      )
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

    def authorize_workspace_owner!
      return if current_workspace_policy.owner?

      redirect_to root_path, alert: t("authorization.denied")
    end

    def authorize_instance_admin!
      return if Current.user&.instance_admin?

      redirect_to root_path, alert: t("authorization.denied")
    end
end
