require "test_helper"

class Passkeys::OptionsTest < ActiveSupport::TestCase
  test "registration options require discoverable credentials and user verification" do
    user = users(:one)
    fake = fake_options(
      payload: {
        "challenge" => "test-challenge",
        "user" => { "id" => "user-id", "name" => user.email_address }
      }
    )

    captured_options = nil
    stub_webauthn_credential(:options_for_create, ->(**options) {
      captured_options = options
      fake
    }) do
      challenge, options = Passkeys::Options.registration_for(user)

      assert_equal "test-challenge", challenge
      assert_equal [ "credential-one" ], captured_options.fetch(:exclude)
      assert_equal "required", options.fetch("authenticatorSelection").fetch("residentKey")
      assert_equal true, options.fetch("authenticatorSelection").fetch("requireResidentKey")
      assert_equal "required", options.fetch("authenticatorSelection").fetch("userVerification")
      assert_equal "none", options.fetch("attestation")
    end
  end

  test "authentication options can force browser account picker" do
    fake = fake_options(payload: { "challenge" => "test-challenge" })

    stub_webauthn_credential(:options_for_get, fake) do
      challenge, options = Passkeys::Options.authentication_for

      assert_equal "test-challenge", challenge
      assert_equal [], options.fetch("allowCredentials")
      assert_equal "required", options.fetch("userVerification")
    end
  end

  test "authentication options scope allowed credentials when provided" do
    fake = fake_options(
      payload: {
        "challenge" => "test-challenge",
        "allowCredentials" => [ { "type" => "public-key", "id" => "credential-one" } ]
      }
    )
    captured_options = nil

    stub_webauthn_credential(:options_for_get, ->(**options) {
      captured_options = options
      fake
    }) do
      credential = passkey_credentials(:one_touch_id)
      challenge, options = Passkeys::Options.authentication_for(credentials: [ credential ])

      assert_equal "test-challenge", challenge
      assert_equal [ "credential-one" ], captured_options.fetch(:allow)
      assert_equal [ { "type" => "public-key", "id" => "credential-one" } ], options.fetch("allowCredentials")
      assert_equal "required", options.fetch("userVerification")
    end
  end
end
