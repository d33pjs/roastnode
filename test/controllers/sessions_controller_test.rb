require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = User.take }

  test "new" do
    get new_session_path

    assert_response :success
    assert_select "main[data-testid=session-new]"
    assert_select "[data-testid=session-form-panel]"
    assert_select "img[data-testid=brand-wordmark][alt=?]", "Roastnode"
    assert_select "form[action=?][method=post]", session_path
    assert_select "button[data-action=?]", "passkey#authenticate"
    assert_select "a[data-testid=site-footer-github][href=?]", Roastnode::AppVersion.github_url
    assert_select "[data-testid=site-footer-github-logo]"
    assert_select "[data-testid=site-footer-version]", count: 0
  end

  test "new does not show unrelated app notices" do
    sign_in_as(users(:one))

    patch workspace_path, params: {
      workspace: {
        name: "Jens Coffee Lab",
        default_currency: "EUR"
      }
    }

    assert_redirected_to dashboard_path

    get new_session_path

    assert_response :success
    assert_select "#notice", count: 0
    assert_no_match I18n.t("workspaces.update.updated"), response.body
  end

  test "new keeps password reset notices" do
    post passwords_path, params: { email_address: @user.email_address }

    assert_redirected_to new_session_path

    follow_redirect!

    assert_response :success
    assert_select "#notice", text: "Password reset instructions sent (if user with that email address exists)."
  end

  test "create with valid credentials" do
    post session_path, params: { email_address: @user.email_address, password: "password" }

    assert_redirected_to root_path
    assert cookies[:session_id]
  end

  test "create with valid credentials and passkey second factor redirects without creating session" do
    user = users(:one)
    user.update!(passkey_second_factor_enabled: true)

    assert_no_difference -> { user.sessions.count } do
      post session_path, params: { email_address: user.email_address, password: "password" }
    end

    assert_redirected_to passkey_second_factor_path
    assert_nil cookies[:session_id]
  end

  test "create with invalid credentials" do
    post session_path, params: { email_address: @user.email_address, password: "wrong" }

    assert_redirected_to new_session_path
    assert_nil cookies[:session_id]
  end

  test "destroy" do
    sign_in_as(User.take)

    delete session_path

    assert_redirected_to new_session_path
    assert_empty cookies[:session_id]
  end

  test "destroy clears pending passkey login without authenticated session" do
    user = users(:one)
    user.update!(passkey_second_factor_enabled: true)

    post session_path, params: { email_address: user.email_address, password: "password" }

    assert_redirected_to passkey_second_factor_path
    assert_nil cookies[:session_id]

    assert_no_difference -> { user.sessions.count } do
      delete session_path
    end

    assert_redirected_to new_session_path
    assert_nil cookies[:session_id]

    get passkey_second_factor_path

    assert_redirected_to new_session_path
  end
end
