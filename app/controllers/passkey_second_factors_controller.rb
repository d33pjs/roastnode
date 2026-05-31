class PasskeySecondFactorsController < ApplicationController
  include PasskeyChallenges

  allow_unauthenticated_access only: %i[show options create]
  rate_limit to: 10, within: 3.minutes, only: %i[options create], with: -> { render json: { error: t("passkey_second_factors.rate_limited") }, status: :too_many_requests }

  def show
    redirect_to new_session_path, alert: t(".expired") unless pending_passkey_user
  end

  def options
    user = pending_passkey_user
    return render json: { error: t(".expired") }, status: :unauthorized unless user

    challenge, options = Passkeys::Options.authentication_for(credentials: user.passkey_credentials)
    store_passkey_challenge(:second_factor, challenge, user_id: user.id)
    render json: options
  end

  def create
    user = pending_passkey_user
    return render json: { error: t(".expired") }, status: :unauthorized unless user

    challenge = consume_passkey_challenge(:second_factor, user_id: user.id)
    return render json: { error: t(".failed") }, status: :unprocessable_entity unless challenge

    Passkeys::Assertion.new(
      challenge:,
      credential_params: webauthn_credential_params,
      user:
    ).verify!

    clear_pending_passkey_user
    start_new_session_for(user)
    redirect_url = after_authentication_url
    redirect_url = root_path if redirect_url == root_url
    render json: { redirect_url: }
  rescue ActiveRecord::RecordNotFound, ActionController::ParameterMissing, WebAuthn::Error
    clear_pending_passkey_user
    render json: { error: t(".failed") }, status: :unprocessable_entity
  end
end
