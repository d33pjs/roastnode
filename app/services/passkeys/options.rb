module Passkeys
  class Options
    def self.registration_for(user)
      user.ensure_webauthn_user_id!
      options = WebAuthn::Credential.options_for_create(
        user: {
          id: user.webauthn_user_id,
          name: user.email_address
        },
        exclude: user.passkey_credentials.pluck(:external_id)
      )
      json = JSON.parse(options.to_json)
      json["authenticatorSelection"] = {
        "residentKey" => "required",
        "requireResidentKey" => true,
        "userVerification" => "required"
      }
      json["attestation"] = "none"

      [ options.challenge, json ]
    end

    def self.authentication_for(credentials: [])
      allow = credentials.map { |credential| credential.external_id }
      options = WebAuthn::Credential.options_for_get(allow:)
      json = JSON.parse(options.to_json)
      json["allowCredentials"] = [] if allow.empty?
      json["userVerification"] = "required"

      [ options.challenge, json ]
    end
  end
end
