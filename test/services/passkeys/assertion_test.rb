require "test_helper"

class Passkeys::AssertionTest < ActiveSupport::TestCase
  test "updates sign count and last used timestamp after verified assertion" do
    credential = passkey_credentials(:one_touch_id)
    asserted = FakeAssertedCredential.new(id: credential.external_id, sign_count: 5)

    travel_to Time.zone.local(2026, 5, 31, 12, 0, 0) do
      stub_webauthn_credential(:from_get, asserted) do
        verified = Passkeys::Assertion.new(
          challenge: "assertion-challenge",
          credential_params: passkey_assertion_params(id: credential.external_id),
          user: users(:one)
        ).verify!

        assert_equal credential, verified
        assert_equal 5, credential.reload.sign_count
        assert_equal Time.current, credential.last_used_at
      end
    end
  end

  test "raises when scoped user does not own credential" do
    credential = passkey_credentials(:one_touch_id)
    asserted = FakeAssertedCredential.new(id: credential.external_id, sign_count: 5)

    stub_webauthn_credential(:from_get, asserted) do
      assert_raises(ActiveRecord::RecordNotFound) do
        Passkeys::Assertion.new(
          challenge: "assertion-challenge",
          credential_params: passkey_assertion_params(id: credential.external_id),
          user: users(:two)
        ).verify!
      end
    end
  end

  test "raises on stale sign count" do
    credential = passkey_credentials(:one_touch_id)
    credential.update!(sign_count: 10)
    asserted = FakeAssertedCredential.new(id: credential.external_id, sign_count: 5)

    stub_webauthn_credential(:from_get, asserted) do
      assert_raises(WebAuthn::SignCountVerificationError) do
        Passkeys::Assertion.new(
          challenge: "assertion-challenge",
          credential_params: passkey_assertion_params(id: credential.external_id),
          user: users(:one)
        ).verify!
      end
    end
  end

  test "raises webauthn error before from_get for malformed payload" do
    error = assert_raises(WebAuthn::Error) do
      Passkeys::Assertion.new(
        challenge: "assertion-challenge",
        credential_params: { "id" => passkey_credentials(:one_touch_id).external_id },
        user: users(:one)
      ).verify!
    end

    assert_equal "Malformed passkey assertion.", error.message
  end

  test "does not swallow internal no method errors from from_get" do
    credential = passkey_credentials(:one_touch_id)

    stub_webauthn_credential(:from_get, ->(*) { raise NoMethodError, "internal failure" }) do
      assert_raises(NoMethodError) do
        Passkeys::Assertion.new(
          challenge: "assertion-challenge",
          credential_params: passkey_assertion_params(id: credential.external_id),
          user: users(:one)
        ).verify!
      end
    end
  end
end
