module PasskeyTestHelper
  FakeOptions = Struct.new(:challenge, :payload, keyword_init: true) do
    def to_json(*)
      payload.merge("challenge" => challenge).to_json
    end
  end

  FakeCreatedCredential = Struct.new(:id, :public_key, :sign_count, keyword_init: true) do
    def verify(challenge, user_verification: nil)
      raise WebAuthn::Error, "missing challenge" if challenge.blank?
      raise WebAuthn::Error, "user verification required" unless user_verification == true

      true
    end
  end

  FakeAssertedCredential = Struct.new(:id, :sign_count, keyword_init: true) do
    def verify(challenge, public_key:, sign_count:, user_verification: nil)
      raise WebAuthn::Error, "missing challenge" if challenge.blank?
      raise WebAuthn::Error, "user verification required" unless user_verification == true
      raise WebAuthn::SignCountVerificationError, "stale sign count" if self.sign_count < sign_count

      true
    end
  end

  def fake_options(challenge: nil, payload: {})
    challenge ||= payload["challenge"] || "test-challenge"
    FakeOptions.new(challenge:, payload:)
  end

  def passkey_assertion_params(id: "credential-one")
    {
      "id" => id,
      "rawId" => id,
      "type" => "public-key",
      "response" => {
        "clientDataJSON" => "client-data-json",
        "authenticatorData" => "authenticator-data",
        "signature" => "signature",
        "userHandle" => nil
      }
    }
  end

  def stub_webauthn_credential(method_name, replacement)
    original = WebAuthn::Credential.method(method_name)

    WebAuthn::Credential.define_singleton_method(method_name) do |*args, **kwargs, &block|
      if replacement.respond_to?(:call)
        replacement.call(*args, **kwargs, &block)
      else
        replacement
      end
    end

    yield
  ensure
    WebAuthn::Credential.define_singleton_method(method_name, original) if original
  end
end
