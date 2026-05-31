class PasskeyCredentialsController < ApplicationController
  include PasskeyChallenges

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

    credential = Passkeys::Registration.new(
      user: Current.user,
      challenge:,
      credential_params: webauthn_credential_params,
      nickname: params[:nickname]
    ).save!
    render json: { redirect_url: edit_profile_path, id: credential.id }, status: :created
  rescue WebAuthn::Error, ActiveRecord::RecordInvalid
    render json: { error: t(".failed") }, status: :unprocessable_entity
  end

  def update
    credential = Current.user.passkey_credentials.find_by(id: params[:id])
    return redirect_to edit_profile_path, alert: t(".not_found") unless credential

    credential.update!(passkey_credential_params)
    redirect_to edit_profile_path, notice: t(".renamed")
  end

  def destroy
    credential = Current.user.passkey_credentials.find_by(id: params[:id])
    return redirect_to edit_profile_path, alert: t(".not_found") unless credential

    if Current.user.passkey_credentials.one?
      unless Current.user.authenticate(params[:current_password].to_s)
        return redirect_to edit_profile_path, alert: t(".current_password_invalid")
      end

      Current.user.update!(passkey_second_factor_enabled: false)
    end

    credential.destroy!
    redirect_to edit_profile_path, notice: t(".deleted")
  end

  def second_factor
    unless Current.user.authenticate(second_factor_params[:current_password].to_s)
      Current.user.errors.add(:base, t(".current_password_invalid"))
      @user = Current.user
      return render "profiles/edit", status: :unprocessable_entity
    end

    Current.user.update!(passkey_second_factor_enabled: second_factor_params[:passkey_second_factor_enabled] == "1")
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
end
