require "test_helper"

class PasskeyCredentialsControllerTest < ActionDispatch::IntegrationTest
  test "registration options require current password" do
    sign_in_as(users(:one))

    post options_passkey_credentials_path, params: { current_password: "wrong" }, as: :json

    assert_response :unauthorized
  end

  test "registration options current-password checks are rate limited by user and remote ip" do
    ActionController::Base.cache_store.clear
    sign_in_as(users(:one))

    10.times do
      post options_passkey_credentials_path,
        params: { current_password: "wrong" },
        headers: { "REMOTE_ADDR" => "203.0.113.13" },
        as: :json
      assert_response :unauthorized
    end

    post options_passkey_credentials_path,
      params: { current_password: "wrong" },
      headers: { "REMOTE_ADDR" => "203.0.113.13" },
      as: :json

    assert_response :too_many_requests
    assert_equal I18n.t("passkey_credentials.rate_limited"), response.parsed_body.fetch("error")
  ensure
    ActionController::Base.cache_store.clear
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

    event = nil
    assert_difference -> { user.passkey_credentials.count }, 1 do
      stub_webauthn_credential(:from_create, fake_credential) do
        event = assert_activity_event(action: "passkey.created", workspace: user.active_workspace, actor: user) do
          post passkey_credentials_path, params: {
            nickname: "Phone",
            credential: { id: "new-passkey-id" }
          }, as: :json
        end
      end
    end

    assert_response :created
    credential = user.passkey_credentials.order(:created_at).last
    assert_equal "new-passkey-id", credential.external_id
    assert_equal "new-public-key", credential.public_key
    assert_equal 4, credential.sign_count
    assert_equal "Phone", credential.nickname
    assert_equal credential, event.subject
    assert_no_match(/new-passkey-id|new-public-key|challenge/i, event.metadata.to_json)
  end

  test "create without a registration challenge does not create a passkey credential" do
    user = users(:one)
    sign_in_as(user)
    fake_credential = FakeCreatedCredential.new(
      id: "new-passkey-id",
      public_key: "new-public-key",
      sign_count: 4
    )

    assert_no_difference -> { user.passkey_credentials.count } do
      stub_webauthn_credential(:from_create, fake_credential) do
        post passkey_credentials_path, params: {
          nickname: "Phone",
          credential: { id: "new-passkey-id" }
        }, as: :json
      end
    end

    assert_response :unprocessable_entity
  end

  test "create with another user's registration challenge does not create a passkey credential" do
    user = users(:two)
    sign_in_as(users(:one))
    fake_options = fake_options(payload: { "challenge" => "registration-challenge" })
    fake_credential = FakeCreatedCredential.new(
      id: "new-passkey-id",
      public_key: "new-public-key",
      sign_count: 4
    )

    stub_webauthn_credential(:options_for_create, fake_options) do
      post options_passkey_credentials_path, params: { current_password: "password" }, as: :json
    end

    sign_in_as(user)

    assert_no_difference -> { user.passkey_credentials.count } do
      stub_webauthn_credential(:from_create, fake_credential) do
        post passkey_credentials_path, params: {
          nickname: "Phone",
          credential: { id: "new-passkey-id" }
        }, as: :json
      end
    end

    assert_response :unprocessable_entity
  end

  test "create with an expired registration challenge does not create a passkey credential" do
    user = users(:one)
    sign_in_as(user)
    fake_options = fake_options(payload: { "challenge" => "registration-challenge" })
    fake_credential = FakeCreatedCredential.new(
      id: "new-passkey-id",
      public_key: "new-public-key",
      sign_count: 4
    )

    travel_to 11.minutes.ago do
      stub_webauthn_credential(:options_for_create, fake_options) do
        post options_passkey_credentials_path, params: { current_password: "password" }, as: :json
      end
    end

    assert_no_difference -> { user.passkey_credentials.count } do
      stub_webauthn_credential(:from_create, fake_credential) do
        post passkey_credentials_path, params: {
          nickname: "Phone",
          credential: { id: "new-passkey-id" }
        }, as: :json
      end
    end

    assert_response :unprocessable_entity
  end

  test "failed WebAuthn registration consumes the challenge and cannot be retried" do
    user = users(:one)
    sign_in_as(user)
    fake_options = fake_options(payload: { "challenge" => "registration-challenge" })
    failing_credential = FakeCreatedCredential.new(
      id: "new-passkey-id",
      public_key: "new-public-key",
      sign_count: 4
    )
    verified_credential = FakeCreatedCredential.new(
      id: "new-passkey-id",
      public_key: "new-public-key",
      sign_count: 4
    )

    failing_credential.define_singleton_method(:verify) do |*, **|
      raise WebAuthn::Error, "verification failed"
    end

    stub_webauthn_credential(:options_for_create, fake_options) do
      post options_passkey_credentials_path, params: { current_password: "password" }, as: :json
    end

    assert_no_difference -> { user.passkey_credentials.count } do
      stub_webauthn_credential(:from_create, failing_credential) do
        post passkey_credentials_path, params: {
          nickname: "Phone",
          credential: { id: "new-passkey-id" }
        }, as: :json
      end
    end
    assert_response :unprocessable_entity

    assert_no_difference -> { user.passkey_credentials.count } do
      stub_webauthn_credential(:from_create, verified_credential) do
        post passkey_credentials_path, params: {
          nickname: "Phone",
          credential: { id: "new-passkey-id" }
        }, as: :json
      end
    end
    assert_response :unprocessable_entity
  end

  test "renames own passkey" do
    sign_in_as(users(:one))
    credential = passkey_credentials(:one_touch_id)

    assert_activity_event(action: "passkey.renamed", workspace: users(:one).active_workspace, actor: users(:one), subject: credential) do
      patch passkey_credential_path(credential), params: { passkey_credential: { nickname: "YubiKey" } }
    end

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

  test "does not delete another user's passkey" do
    sign_in_as(users(:two))
    credential = passkey_credentials(:one_touch_id)

    assert_no_difference -> { PasskeyCredential.count } do
      delete passkey_credential_path(credential), params: { current_password: "password" }
    end

    assert_redirected_to edit_profile_path
    assert PasskeyCredential.exists?(credential.id)
  end

  test "enabling second factor requires a passkey and current password" do
    user = users(:two)
    sign_in_as(user)

    assert_no_difference -> { ActivityEvent.count } do
      patch second_factor_passkey_credentials_path, params: {
        user: {
          passkey_second_factor_enabled: "1",
          current_password: "password"
        }
      }
    end

    assert_response :unprocessable_entity
    assert_not user.reload.passkey_second_factor_enabled?
  end

  test "enabling and disabling second factor requires current password" do
    user = users(:one)
    sign_in_as(user)

    assert_activity_event(
      action: "passkey.second_factor_enabled", workspace: user.active_workspace, actor: user, subject: user
    ) do
      patch second_factor_passkey_credentials_path, params: {
        user: {
          passkey_second_factor_enabled: "1",
          current_password: "password"
        }
      }
    end

    assert_redirected_to edit_profile_path
    assert user.reload.passkey_second_factor_enabled?

    assert_activity_event(
      action: "passkey.second_factor_disabled", workspace: user.active_workspace, actor: user, subject: user
    ) do
      patch second_factor_passkey_credentials_path, params: {
        user: {
          passkey_second_factor_enabled: "0",
          current_password: "password"
        }
      }
    end

    assert_redirected_to edit_profile_path
    assert_not user.reload.passkey_second_factor_enabled?
  end

  test "second factor with wrong current password does not change the flag" do
    user = users(:one)
    user.update!(passkey_second_factor_enabled: true)
    sign_in_as(user)

    patch second_factor_passkey_credentials_path, params: {
      user: {
        passkey_second_factor_enabled: "0",
        current_password: "wrong"
      }
    }

    assert_response :unprocessable_entity
    assert user.reload.passkey_second_factor_enabled?
  end

  test "deleting last passkey disables second factor with current password" do
    user = users(:one)
    user.update!(passkey_second_factor_enabled: true)
    sign_in_as(user)
    credential = passkey_credentials(:one_touch_id)

    assert_difference -> { user.passkey_credentials.count }, -1 do
      event = assert_activity_event(action: "passkey.deleted", workspace: user.active_workspace, actor: user) do
        delete passkey_credential_path(credential), params: { current_password: "password" }
      end
      assert_equal credential.id, event.subject_id
      assert_nil event.subject
    end

    assert_redirected_to edit_profile_path
    assert_not user.reload.passkey_second_factor_enabled?
  end

  test "deleting last passkey with wrong current password does not delete or disable second factor" do
    user = users(:one)
    user.update!(passkey_second_factor_enabled: true)
    sign_in_as(user)
    credential = passkey_credentials(:one_touch_id)

    assert_no_difference -> { user.passkey_credentials.count } do
      delete passkey_credential_path(credential), params: { current_password: "wrong" }
    end

    assert_redirected_to edit_profile_path
    assert user.reload.passkey_second_factor_enabled?
    assert PasskeyCredential.exists?(credential.id)
  end

  test "deleting last passkey with missing current password does not delete or disable second factor" do
    user = users(:one)
    user.update!(passkey_second_factor_enabled: true)
    sign_in_as(user)
    credential = passkey_credentials(:one_touch_id)

    assert_no_difference -> { user.passkey_credentials.count } do
      delete passkey_credential_path(credential)
    end

    assert_redirected_to edit_profile_path
    assert user.reload.passkey_second_factor_enabled?
    assert PasskeyCredential.exists?(credential.id)
  end
end
