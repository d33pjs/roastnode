class PasskeyCredentialsController < ApplicationController
  include PasskeyChallenges

  rate_limit to: 10,
    within: 3.minutes,
    only: :options,
    by: :authenticated_password_check_rate_limit_key,
    with: -> { render json: { error: t("passkey_credentials.rate_limited") }, status: :too_many_requests }
  rate_limit to: 10,
    within: 3.minutes,
    only: :destroy,
    by: :authenticated_password_check_rate_limit_key,
    with: -> { redirect_to edit_profile_path, alert: t("passkey_credentials.rate_limited") }
  rate_limit to: 10,
    within: 3.minutes,
    only: :second_factor,
    by: :authenticated_password_check_rate_limit_key,
    with: -> {
      Current.user.errors.add(:base, t("passkey_credentials.rate_limited"))
      @user = Current.user
      render "profiles/edit", status: :too_many_requests
    }

  def options
    unless Current.user.authenticate(params[:current_password].to_s)
      return render json: { error: t(".current_password_invalid") }, status: :unauthorized
    end

    challenge, options = Passkeys::Options.registration_for(Current.user)
    store_passkey_challenge(:registration, challenge, user_id: Current.user.id)
    render json: options
  end

  def create
    challenge = consume_passkey_challenge(:registration, user_id: Current.user.id)
    return render json: { error: t(".failed") }, status: :unprocessable_entity unless challenge

    credential = PasskeyCredential.transaction do
      created_credential = Passkeys::Registration.new(
        user: Current.user,
        challenge:,
        credential_params: webauthn_credential_params,
        nickname: params[:nickname]
      ).save!
      record_account_activity!(action: "passkey.created", subject: created_credential)
      created_credential
    end
    render json: { redirect_url: edit_profile_path, id: credential.id }, status: :created
  rescue WebAuthn::Error, ActiveRecord::RecordInvalid
    render json: { error: t(".failed") }, status: :unprocessable_entity
  end

  def update
    credential = Current.user.passkey_credentials.find_by(id: params[:id])
    return redirect_to edit_profile_path, alert: t(".not_found") unless credential

    with_account_activity(action: "passkey.renamed", user: Current.user, subject: credential) do
      credential.update!(passkey_credential_params)
    end
    redirect_to edit_profile_path, notice: t(".renamed")
  end

  def destroy
    credential = Current.user.passkey_credentials.find_by(id: params[:id])
    return redirect_to edit_profile_path, alert: t(".not_found") unless credential

    last_credential = Current.user.passkey_credentials.one?
    if last_credential && !Current.user.authenticate(params[:current_password].to_s)
      return redirect_to edit_profile_path, alert: t(".current_password_invalid")
    end

    with_account_activity(action: "passkey.deleted", user: Current.user, subject: credential) do
      Current.user.update!(passkey_second_factor_enabled: false) if last_credential
      credential.destroy!
    end
    redirect_to edit_profile_path, notice: t(".deleted")
  end

  def second_factor
    unless Current.user.authenticate(second_factor_params[:current_password].to_s)
      Current.user.errors.add(:base, t(".current_password_invalid"))
      @user = Current.user
      return render "profiles/edit", status: :unprocessable_entity
    end

    PasskeyCredential.transaction do
      Current.user.update!(passkey_second_factor_enabled: second_factor_params[:passkey_second_factor_enabled] == "1")
      action = if Current.user.passkey_second_factor_enabled?
        "passkey.second_factor_enabled"
      else
        "passkey.second_factor_disabled"
      end
      record_account_activity!(action:, subject: Current.user)
    end
    redirect_to edit_profile_path, notice: t(".updated")
  rescue ActiveRecord::RecordInvalid
    @user = Current.user
    render "profiles/edit", status: :unprocessable_entity
  end

  private
    def passkey_credential_params
      params.require(:passkey_credential).permit(:nickname)
    end

    def second_factor_params
      params.require(:user).permit(:passkey_second_factor_enabled, :current_password)
    end

    def authenticated_password_check_rate_limit_key
      "#{Current.user.id}:#{request.remote_ip}"
    end

    def record_account_activity!(action:, subject:)
      workspace = Current.user.active_workspace
      Activity::Emitter.record!(
        action:, workspace:, actor: Current.user, subject:,
        visibility: workspace ? "workspace_admin" : "instance_admin"
      )
    end
end
