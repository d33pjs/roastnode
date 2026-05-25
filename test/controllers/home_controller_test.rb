require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "shows the public home page" do
    get root_path

    assert_response :success
    assert_select "h1", I18n.t("home.index.title")
    assert_select "a[href=?]", new_session_path, text: I18n.t("home.index.sign_in")
  end

  test "shows signed-in state after authentication" do
    user = users(:one)
    sign_in_as(user)

    get root_path

    assert_response :success
    assert_select "p", text: I18n.t("home.index.signed_in_as", email: user.email_address)
    assert_select "a[href=?]", new_session_path, count: 0
  end
end
