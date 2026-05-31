require "test_helper"

class PasskeySecondFactorsControllerTest < ActionDispatch::IntegrationTest
  test "show redirects without pending password login" do
    get passkey_second_factor_path

    assert_redirected_to new_session_path
  end

  test "options are scoped to pending user's credentials" do
    user = users(:one)
    user.update!(passkey_second_factor_enabled: true)
    fake = fake_options(payload: { "challenge" => "second-factor-challenge" })
    seen_allow = nil

    post session_path, params: { email_address: user.email_address, password: "password" }

    stub_webauthn_credential(:options_for_get, ->(allow:, **) {
      seen_allow = allow
      fake
    }) do
      post options_passkey_second_factor_path, as: :json
    end

    assert_response :success
    assert_equal user.passkey_credentials.pluck(:external_id), seen_allow
    assert_equal "required", response.parsed_body.fetch("userVerification")
  end

  test "verified second factor starts session and clears pending state" do
    credential = passkey_credentials(:one_touch_id)
    user = credential.user
    user.update!(passkey_second_factor_enabled: true)
    fake_options = fake_options(payload: { "challenge" => "second-factor-challenge" })
    fake_assertion = FakeAssertedCredential.new(id: credential.external_id, sign_count: 8)

    post session_path, params: { email_address: user.email_address, password: "password" }

    stub_webauthn_credential(:options_for_get, fake_options) do
      post options_passkey_second_factor_path, as: :json
    end

    assert_difference -> { user.sessions.count }, 1 do
      stub_webauthn_credential(:from_get, fake_assertion) do
        post passkey_second_factor_path, params: { credential: { id: credential.external_id } }, as: :json
      end
    end

    assert_response :success
    assert cookies[:session_id].present?
    assert_equal root_path, response.parsed_body.fetch("redirect_url")

    get passkey_second_factor_path

    assert_redirected_to new_session_path
  end

  test "pending second factor expires after ten minutes" do
    user = users(:one)
    user.update!(passkey_second_factor_enabled: true)

    post session_path, params: { email_address: user.email_address, password: "password" }

    travel 11.minutes do
      post options_passkey_second_factor_path, as: :json
    end

    assert_response :unauthorized
    assert_nil cookies[:session_id]
  end

  test "credential for a different user fails second factor" do
    pending_user = users(:two)
    pending_user.passkey_credentials.create!(
      external_id: "credential-two",
      public_key: "public-key-two",
      sign_count: 0
    )
    pending_user.update!(passkey_second_factor_enabled: true)
    other_credential = passkey_credentials(:one_touch_id)
    fake_options = fake_options(payload: { "challenge" => "second-factor-challenge" })
    fake_assertion = FakeAssertedCredential.new(id: other_credential.external_id, sign_count: 8)

    post session_path, params: { email_address: pending_user.email_address, password: "password" }

    stub_webauthn_credential(:options_for_get, fake_options) do
      post options_passkey_second_factor_path, as: :json
    end

    stub_webauthn_credential(:from_get, fake_assertion) do
      post passkey_second_factor_path, params: { credential: { id: other_credential.external_id } }, as: :json
    end

    assert_response :unprocessable_entity
    assert_nil cookies[:session_id]
  end

  test "missing credential params fail generically" do
    credential = passkey_credentials(:one_touch_id)
    user = credential.user
    user.update!(passkey_second_factor_enabled: true)
    fake_options = fake_options(payload: { "challenge" => "second-factor-challenge" })

    post session_path, params: { email_address: user.email_address, password: "password" }

    stub_webauthn_credential(:options_for_get, fake_options) do
      post options_passkey_second_factor_path, as: :json
    end

    assert_no_difference -> { user.sessions.count } do
      post passkey_second_factor_path, params: {}, as: :json
    end

    assert_response :unprocessable_entity
    assert_nil cookies[:session_id]
    assert_equal "Passkey verification failed.", response.parsed_body.fetch("error")
  end

  test "malformed credential params fail generically" do
    credential = passkey_credentials(:one_touch_id)
    user = credential.user
    user.update!(passkey_second_factor_enabled: true)
    fake_options = fake_options(payload: { "challenge" => "second-factor-challenge" })

    post session_path, params: { email_address: user.email_address, password: "password" }

    stub_webauthn_credential(:options_for_get, fake_options) do
      post options_passkey_second_factor_path, as: :json
    end

    assert_no_difference -> { user.sessions.count } do
      post passkey_second_factor_path, params: { credential: "bad" }, as: :json
    end

    assert_response :unprocessable_entity
    assert_nil cookies[:session_id]
    assert_equal "Passkey verification failed.", response.parsed_body.fetch("error")
  end
end
