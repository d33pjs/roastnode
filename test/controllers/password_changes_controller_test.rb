require "test_helper"

class PasswordChangesControllerTest < ActionDispatch::IntegrationTest
  test "signed-in user can open password change form" do
    sign_in_as(users(:one))

    get edit_password_change_path

    assert_response :success
    assert_select "h1", I18n.t("password_changes.edit.title")
    assert_select "form[action=?]", password_change_path
    assert_select "input[name=?]", "user[current_password]"
    assert_select "input[name=?]", "user[password]"
    assert_select "input[name=?]", "user[password_confirmation]"
  end

  test "password change requires current password" do
    user = users(:one)
    sign_in_as(user)

    assert_no_changes -> { user.reload.password_digest } do
      patch password_change_path, params: {
        user: {
          current_password: "wrong",
          password: "new-password",
          password_confirmation: "new-password"
        }
      }
    end

    assert_response :unprocessable_entity
    assert_select "div", /#{I18n.t("password_changes.update.current_password_invalid")}/
  end

  test "password change current-password checks are rate limited by user and remote ip" do
    ActionController::Base.cache_store.clear
    user = users(:one)
    sign_in_as(user)

    10.times do
      patch password_change_path,
        params: {
          user: {
            current_password: "wrong",
            password: "new-password",
            password_confirmation: "new-password"
          }
        },
        headers: { "REMOTE_ADDR" => "203.0.113.12" }
      assert_response :unprocessable_entity
    end

    patch password_change_path,
      params: {
        user: {
          current_password: "wrong",
          password: "new-password",
          password_confirmation: "new-password"
        }
      },
      headers: { "REMOTE_ADDR" => "203.0.113.12" }

    assert_response :too_many_requests
    assert_select "body", text: /#{I18n.t("password_changes.update.rate_limited")}/
  ensure
    ActionController::Base.cache_store.clear
  end

  test "password change rejects mismatched confirmation" do
    user = users(:one)
    sign_in_as(user)

    assert_no_changes -> { user.reload.password_digest } do
      patch password_change_path, params: {
        user: {
          current_password: "password",
          password: "new-password",
          password_confirmation: "different"
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "password change updates digest rotates sessions and keeps current browser signed in" do
    user = users(:one)
    other_session = user.sessions.create!
    sign_in_as(user)
    old_current_session_id = Current.session.id

    assert_changes -> { user.reload.password_digest } do
      patch password_change_path, params: {
        user: {
          current_password: "password",
          password: "new-password",
          password_confirmation: "new-password"
        }
      }
    end

    assert_redirected_to edit_profile_path
    assert_not Session.exists?(other_session.id)
    assert_not Session.exists?(old_current_session_id)
    assert_equal 1, user.sessions.count
    assert cookies[:session_id].present?

    get dashboard_path
    assert_response :success

    delete session_path
    post session_path, params: { email_address: user.email_address, password: "new-password" }
    assert_redirected_to root_path
  end
end
