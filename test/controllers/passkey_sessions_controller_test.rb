require "test_helper"

class PasskeySessionsControllerTest < ActionDispatch::IntegrationTest
  test "login options use browser account picker" do
    fake = fake_options(payload: { "challenge" => "login-challenge" })

    stub_webauthn_credential(:options_for_get, fake) do
      post options_passkey_session_path, as: :json
    end

    assert_response :success
    assert_equal [], response.parsed_body.fetch("allowCredentials")
    assert_equal "required", response.parsed_body.fetch("userVerification")
  end

  test "verified passkey starts a session" do
    credential = passkey_credentials(:one_touch_id)
    fake_options = fake_options(payload: { "challenge" => "login-challenge" })
    fake_assertion = FakeAssertedCredential.new(id: credential.external_id, sign_count: 3)

    stub_webauthn_credential(:options_for_get, fake_options) do
      post options_passkey_session_path, as: :json
    end

    assert_difference -> { credential.user.sessions.count }, 1 do
      stub_webauthn_credential(:from_get, fake_assertion) do
        post passkey_session_path, params: { credential: { id: credential.external_id } }, as: :json
      end
    end

    assert_response :success
    assert cookies[:session_id].present?
    assert_equal root_path, response.parsed_body.fetch("redirect_url")
    assert_equal 3, credential.reload.sign_count
    assert credential.last_used_at.present?
  end

  test "unknown credential fails generically" do
    fake_options = fake_options(payload: { "challenge" => "login-challenge" })
    fake_assertion = FakeAssertedCredential.new(id: "unknown-credential", sign_count: 3)

    stub_webauthn_credential(:options_for_get, fake_options) do
      post options_passkey_session_path, as: :json
    end

    stub_webauthn_credential(:from_get, fake_assertion) do
      post passkey_session_path, params: { credential: { id: "unknown-credential" } }, as: :json
    end

    assert_response :unprocessable_entity
    assert_nil cookies[:session_id]
    assert_equal "Passkey sign-in failed.", response.parsed_body.fetch("error")
  end
end
