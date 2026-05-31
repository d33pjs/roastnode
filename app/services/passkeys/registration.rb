module Passkeys
  class Registration
    def initialize(user:, challenge:, credential_params:, nickname:)
      @user = user
      @challenge = challenge
      @credential_params = credential_params
      @nickname = nickname
    end

    def save!
      webauthn_credential = WebAuthn::Credential.from_create(@credential_params)
      webauthn_credential.verify(@challenge)

      @user.passkey_credentials.create!(
        external_id: webauthn_credential.id,
        public_key: webauthn_credential.public_key,
        sign_count: webauthn_credential.sign_count,
        nickname: @nickname.presence
      )
    end
  end
end
