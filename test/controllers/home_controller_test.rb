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
    assert_select "p", text: I18n.t("workspaces.show.signed_in_as", email: user.email_address)
    assert_select "a[href=?]", new_session_path, count: 0
  end

  test "workspace owner sees invite management link" do
    sign_in_as(users(:one))

    get root_path

    assert_response :success
    assert_select "a[href=?]", workspace_invites_path, text: I18n.t("workspaces.show.invites")
  end

  test "shows onboarding for signed-in user without workspace" do
    user = User.create!(email_address: "workspace-needed@example.com", password: "password")
    sign_in_as(user)

    get root_path

    assert_response :success
    assert_select "h1", I18n.t("workspace_onboardings.new.title")
  end
end
