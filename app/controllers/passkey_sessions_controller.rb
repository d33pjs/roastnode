class PasskeySessionsController < ApplicationController
  include PasskeyChallenges

  allow_unauthenticated_access only: %i[options create]
  rate_limit to: 10, within: 3.minutes, only: %i[options create], with: -> { render json: { error: t("passkey_sessions.rate_limited") }, status: :too_many_requests }

  def options
    challenge, options = Passkeys::Options.authentication_for
    store_passkey_challenge(:login, challenge)
    render json: options
  end

  def create
    challenge = consume_passkey_challenge(:login)
    return render json: { error: t(".failed") }, status: :unprocessable_entity unless challenge

    credential = Passkeys::Assertion.new(
      challenge:,
      credential_params: webauthn_credential_params
    ).verify!

    start_new_session_for(credential.user)
    redirect_url = after_authentication_url
    redirect_url = root_path if redirect_url == root_url
    render json: { redirect_url: }
  rescue ActiveRecord::RecordNotFound, ActionController::ParameterMissing, WebAuthn::Error
    render json: { error: t(".failed") }, status: :unprocessable_entity
  end
end
