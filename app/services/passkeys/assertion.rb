module Passkeys
  class Assertion
    def initialize(challenge:, credential_params:, user: nil)
      @challenge = challenge
      @credential_params = credential_params
      @user = user
    end

    def verify!
      webauthn_credential = webauthn_credential_from_params
      credential = find_credential!(webauthn_credential.id)
      webauthn_credential.verify(
        @challenge,
        public_key: credential.public_key,
        sign_count: credential.sign_count,
        user_verification: true
      )
      credential.update!(
        sign_count: webauthn_credential.sign_count,
        last_used_at: Time.current
      )
      credential
    end

    private
      def webauthn_credential_from_params
        WebAuthn::Credential.from_get(@credential_params)
      rescue NoMethodError => error
        raise WebAuthn::Error, error.message
      end

      def find_credential!(external_id)
        scope = @user ? @user.passkey_credentials : PasskeyCredential.all
        scope.find_by!(external_id:)
      end
  end
end
