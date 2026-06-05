class SessionsController < ApplicationController
  include PasskeyChallenges

  AUTH_NOTICE_MESSAGES = [
    "Password reset instructions sent (if user with that email address exists).",
    "Password has been reset."
  ].freeze

  allow_unauthenticated_access only: %i[ new create destroy ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_path, alert: "Try again later." }

  def new
    discard_unrelated_notice
  end

  def create
    if user = User.authenticate_by(params.permit(:email_address, :password))
      if user.passkey_second_factor_enabled?
        store_pending_passkey_user(user)
        redirect_to passkey_second_factor_path
      else
        start_new_session_for user
        redirect_to after_authentication_url
      end
    else
      redirect_to new_session_path, alert: "Try another email address or password."
    end
  end

  def destroy
    resume_session
    terminate_session if Current.session
    clear_pending_passkey_user
    redirect_to new_session_path, status: :see_other
  end

  private
    def discard_unrelated_notice
      return if flash[:notice].blank?
      return if AUTH_NOTICE_MESSAGES.include?(flash[:notice])

      flash.delete(:notice)
    end
end
