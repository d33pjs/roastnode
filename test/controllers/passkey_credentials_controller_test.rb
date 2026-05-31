require "test_helper"

class PasskeyCredentialsControllerTest < ActionDispatch::IntegrationTest
  test "registration options require current password" do
    sign_in_as(users(:one))

    post options_passkey_credentials_path, params: { current_password: "wrong" }, as: :json

    assert_response :unauthorized
  end

  test "registration options store a challenge after current password confirmation" do
    sign_in_as(users(:one))
    fake = fake_options(payload: { "challenge" => "registration-challenge" })

    stub_webauthn_credential(:options_for_create, fake) do
      post options_passkey_credentials_path, params: { current_password: "password" }, as: :json
    end

    assert_response :success
    assert_equal "registration-challenge", response.parsed_body.fetch("challenge")
  end

  test "creates passkey credential after verified registration" do
    user = users(:one)
    sign_in_as(user)
    fake_options = fake_options(payload: { "challenge" => "registration-challenge" })
    fake_credential = FakeCreatedCredential.new(
      id: "new-passkey-id",
      public_key: "new-public-key",
      sign_count: 4
    )

    stub_webauthn_credential(:options_for_create, fake_options) do
      post options_passkey_credentials_path, params: { current_password: "password" }, as: :json
    end

    assert_difference -> { user.passkey_credentials.count }, 1 do
      stub_webauthn_credential(:from_create, fake_credential) do
        post passkey_credentials_path, params: {
          nickname: "Phone",
          credential: { id: "new-passkey-id" }
        }, as: :json
      end
    end

    assert_response :created
    credential = user.passkey_credentials.order(:created_at).last
    assert_equal "new-passkey-id", credential.external_id
    assert_equal "new-public-key", credential.public_key
    assert_equal 4, credential.sign_count
    assert_equal "Phone", credential.nickname
  end

  test "renames own passkey" do
    sign_in_as(users(:one))
    credential = passkey_credentials(:one_touch_id)

    patch passkey_credential_path(credential), params: { passkey_credential: { nickname: "YubiKey" } }

    assert_redirected_to edit_profile_path
    assert_equal "YubiKey", credential.reload.nickname
  end

  test "does not rename another user's passkey" do
    sign_in_as(users(:two))
    credential = passkey_credentials(:one_touch_id)

    patch passkey_credential_path(credential), params: { passkey_credential: { nickname: "Stolen" } }

    assert_redirected_to edit_profile_path
    assert_equal "MacBook Touch ID", credential.reload.nickname
  end

  test "enabling second factor requires a passkey and current password" do
    user = users(:two)
    sign_in_as(user)

    patch second_factor_passkey_credentials_path, params: {
      user: {
        passkey_second_factor_enabled: "1",
        current_password: "password"
      }
    }

    assert_response :unprocessable_entity
    assert_not user.reload.passkey_second_factor_enabled?
  end

  test "enabling and disabling second factor requires current password" do
    user = users(:one)
    sign_in_as(user)

    patch second_factor_passkey_credentials_path, params: {
      user: {
        passkey_second_factor_enabled: "1",
        current_password: "password"
      }
    }

    assert_redirected_to edit_profile_path
    assert user.reload.passkey_second_factor_enabled?

    patch second_factor_passkey_credentials_path, params: {
      user: {
        passkey_second_factor_enabled: "0",
        current_password: "password"
      }
    }

    assert_redirected_to edit_profile_path
    assert_not user.reload.passkey_second_factor_enabled?
  end

  test "deleting last passkey disables second factor with current password" do
    user = users(:one)
    user.update!(passkey_second_factor_enabled: true)
    sign_in_as(user)
    credential = passkey_credentials(:one_touch_id)

    assert_difference -> { user.passkey_credentials.count }, -1 do
      delete passkey_credential_path(credential), params: { current_password: "password" }
    end

    assert_redirected_to edit_profile_path
    assert_not user.reload.passkey_second_factor_enabled?
  end
end
