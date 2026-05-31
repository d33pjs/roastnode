require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = User.take }

  test "new" do
    get new_session_path
    assert_response :success
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
