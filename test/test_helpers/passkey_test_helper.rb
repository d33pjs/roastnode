module WebAuthn
  module Credential
    unless respond_to?(:stub)
      def self.stub(method_name, replacement)
        original = method(method_name)

        define_singleton_method(method_name) do |*args, **kwargs, &block|
          if replacement.respond_to?(:call)
            replacement.call(*args, **kwargs, &block)
          else
            replacement
          end
        end

        yield
      ensure
        define_singleton_method(method_name, original) if original
      end
    end
  end
end

module PasskeyTestHelper
  FakeOptions = Struct.new(:challenge, :payload, keyword_init: true) do
    def to_json(*)
      payload.merge("challenge" => challenge).to_json
    end
  end

  FakeCreatedCredential = Struct.new(:id, :public_key, :sign_count, keyword_init: true) do
    def verify(challenge)
      raise WebAuthn::Error, "missing challenge" if challenge.blank?

      true
    end
  end

  FakeAssertedCredential = Struct.new(:id, :sign_count, keyword_init: true) do
    def verify(challenge, public_key:, sign_count:)
      raise WebAuthn::Error, "missing challenge" if challenge.blank?
      raise WebAuthn::SignCountVerificationError, "stale sign count" if self.sign_count < sign_count

      true
    end
  end

  def fake_options(challenge: nil, payload: {})
    challenge ||= payload["challenge"] || "test-challenge"
    FakeOptions.new(challenge:, payload:)
  end
end
