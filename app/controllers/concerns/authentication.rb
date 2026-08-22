module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :require_authentication
    helper_method :authenticated?
  end

  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
    end
  end

  private
    def authenticated?
      resume_session
    end

    def require_authentication
      resume_session || request_authentication
    end

    def resume_session
      Current.session ||= find_session_by_cookie
    end

    def find_session_by_cookie
      Session.find_by(id: cookies.signed[:session_id]) if cookies.signed[:session_id]
    end

    def request_authentication
      session[:return_to_after_authenticating] = request.url
      redirect_to new_session_path
    end

    def after_authentication_url
      session.delete(:return_to_after_authenticating) || root_url
    end

    def start_new_session_for(user, authentication_method: "password")
      session_record = nil
      ActivityEvent.transaction do
        session_record = user.sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip)
        workspace = user.active_workspace
        Activity::Emitter.record!(
          action: "session.signed_in", workspace:, actor: user, subject: user,
          visibility: workspace ? "workspace_admin" : "instance_admin",
          details: { authentication_method: }
        )
      end
      ActiveRecord.after_all_transactions_commit do
        Current.session = session_record
        cookies.signed.permanent[:session_id] = {
          value: session_record.id, httponly: true, same_site: :lax
        }
      end
    end

    def terminate_session
      session_record = Current.session
      user = session_record.user
      ActivityEvent.transaction do
        session_record.destroy!
        workspace = user.active_workspace
        Activity::Emitter.record!(
          action: "session.signed_out", workspace:, actor: user, subject: user,
          visibility: workspace ? "workspace_admin" : "instance_admin"
        )
      end
      cookies.delete(:session_id)
    end
end
