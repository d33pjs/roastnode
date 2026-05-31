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
        validate_credential_params!
        WebAuthn::Credential.from_get(@credential_params)
      end

      def validate_credential_params!
        raise_malformed_credential unless @credential_params.is_a?(Hash)

        required_assertion_keys = %w[id rawId type]
        raise_malformed_credential unless required_assertion_keys.all? { |key| credential_param_present?(@credential_params, key) }

        response = credential_param(@credential_params, "response")
        raise_malformed_credential unless response.is_a?(Hash)

        required_response_keys = %w[clientDataJSON authenticatorData signature]
        raise_malformed_credential unless required_response_keys.all? { |key| credential_param_present?(response, key) }
      end

      def credential_param(params, key)
        params[key] || params[key.to_sym]
      end

      def credential_param_present?(params, key)
        credential_param(params, key).present?
      end

      def raise_malformed_credential
        raise WebAuthn::Error, "Malformed passkey assertion."
      end

      def find_credential!(external_id)
        scope = @user ? @user.passkey_credentials : PasskeyCredential.all
        scope.find_by!(external_id:)
      end
  end
end
