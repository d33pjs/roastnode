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

  test "workspace dashboard shows coffee actions and recent activity" do
    sign_in_as(users(:one))

    get root_path

    assert_response :success
    assert_select "a[href=?]", new_brew_path, text: I18n.t("workspaces.show.actions.log_brew")
    assert_select "a[href=?]", new_bean_path, text: I18n.t("workspaces.show.actions.add_bean")
    assert_select "a[href=?]", new_equipment_path, text: I18n.t("workspaces.show.actions.add_equipment")
    assert_select "a[href=?]", new_equipment_event_path, text: I18n.t("workspaces.show.actions.add_equipment_event")
    assert_select "h2", I18n.t("workspaces.show.open_beans")
    assert_select "a[href=?]", bean_path(beans(:open_household)), text: /#{beans(:open_household).name}/
    assert_select "a[href=?]", bean_path(beans(:other_workspace_open)), count: 0
    assert_select "a[href=?]", brew_path(brews(:morning_espresso)), text: /#{beans(:open_household).name}/
    assert_select "a[href=?]", equipment_event_path(equipment_events(:grinder_cleaning)), text: /Grinder cleaning/
    assert_select "p", text: I18n.t("workspaces.show.activity.adjustment", amount: "-18", bean: beans(:open_household).name), count: 0
    assert_select "p", text: I18n.t("workspaces.show.status.brews_this_week")
  end

  test "shows onboarding for signed-in user without workspace" do
    user = User.create!(email_address: "workspace-needed@example.com", password: "password")
    sign_in_as(user)

    get root_path

    assert_response :success
    assert_select "h1", I18n.t("workspace_onboardings.new.title")
  end
end
