require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "shows the public home page" do
    get root_path

    assert_response :success
    assert_select "img[data-testid=brand-wordmark][alt=?]", "Roastnode"
    assert_select "img[data-testid=brand-wordmark][src*=?]", "logo_wordmark_transparent"
    assert_select "h1", I18n.t("home.index.title")
    assert_select "a[href=?]", new_session_path, text: I18n.t("home.index.sign_in")
  end

  test "shows signed-in state after authentication" do
    user = users(:one)
    user.update!(display_name: "Jens")
    sign_in_as(user)

    get root_path

    assert_response :success
    assert_select "img[data-testid=brand-wordmark][alt=?]", "Roastnode"
    assert_select "img[data-testid=brand-wordmark][src*=?]", "logo_wordmark_transparent"
    assert_select "[data-testid=workspace-mobile-menu].sm\\:hidden"
    assert_select "[data-testid=workspace-desktop-menu].hidden.sm\\:flex"
    assert_select "p", text: I18n.t("workspaces.show.signed_in_as", user: user.display_label)
    assert_no_match user.email_address, response.body
    assert_select "a[href=?]", edit_profile_path, text: I18n.t("workspaces.show.profile")
    assert_select "a[href=?]", edit_workspace_path, text: I18n.t("workspaces.show.settings")
    assert_select "a[href=?]", new_session_path, count: 0
  end

  test "dashboard falls back to unknown username without exposing email" do
    user = users(:one)
    user.update!(display_name: nil)
    sign_in_as(user)

    get root_path

    assert_response :success
    assert_select "p", text: I18n.t("workspaces.show.signed_in_as", user: user.display_label)
    assert_no_match user.email_address, response.body
  end

  test "workspace owner sees invite management link" do
    sign_in_as(users(:one))

    get root_path

    assert_response :success
    assert_select "a[href=?]", workspace_invites_path, text: I18n.t("workspaces.show.invites")
    assert_select "a[href=?]", workspace_export_path, text: I18n.t("workspaces.show.export")
    assert_select "a[href=?]", workspace_export_beans_path, text: I18n.t("workspaces.show.export_beans")
    assert_select "a[href=?]", workspace_export_brews_path, text: I18n.t("workspaces.show.export_brews")
    assert_select "a[href=?]", new_beanconqueror_import_path, text: I18n.t("workspaces.show.import")
  end

  test "instance admin sees instance admin link" do
    user = users(:one)
    user.update!(instance_admin: true)
    sign_in_as(user)

    get root_path

    assert_response :success
    assert_select "a[href='/instance_admin']", text: I18n.t("workspaces.show.instance_admin"), count: 2
  end

  test "workspace member does not see export link" do
    user = users(:two)
    user.update!(active_workspace: workspaces(:household))
    sign_in_as(user)

    get root_path

    assert_response :success
    assert_select "a[href=?]", workspace_export_path, count: 0
    assert_select "a[href=?]", workspace_export_beans_path, count: 0
    assert_select "a[href=?]", workspace_export_brews_path, count: 0
    assert_select "a[href=?]", edit_workspace_path, count: 0
    assert_select "a[href='/instance_admin']", count: 0
  end

  test "workspace dashboard shows coffee actions and recent activity" do
    sign_in_as(users(:one))

    get root_path

    assert_response :success
    assert_select "[data-testid=dashboard-primary-actions]"
    assert_select "[data-testid=dashboard-secondary-actions].hidden.sm\\:flex"
    assert_select "[data-testid=dashboard-mobile-more-actions].sm\\:hidden"
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

  test "root honors log espresso landing preference while dashboard remains accessible" do
    user = users(:one)
    user.update!(default_landing_screen: "log_espresso")
    sign_in_as(user)

    get root_path

    assert_redirected_to new_brew_path

    get dashboard_path

    assert_response :success
    assert_select "[data-testid=dashboard-primary-actions]"
  end

  test "workspace dashboard shows latest and latest best hero cards" do
    workspace = workspaces(:household)
    user = users(:one)
    latest = brews(:morning_espresso)
    latest.update!(
      occurred_at: Time.zone.local(2026, 5, 26, 12, 0, 0),
      rating: 3,
      notes: "Latest but not best."
    )
    best = workspace.brews.create!(
      user:,
      bean: beans(:second_open_household),
      grinder: equipment(:household_grinder),
      machine: equipment(:household_machine),
      occurred_at: Time.zone.local(2026, 5, 25, 12, 0, 0),
      bean_weight_grams: 18,
      ground_weight_grams: 18,
      dose_grams: 18,
      beverage_grams: 45,
      total_time_seconds: 31,
      rating: 5
    )
    sign_in_as(user)

    get root_path

    assert_response :success
    assert_select "h2", I18n.t("workspaces.show.hero.latest")
    assert_select "h2", I18n.t("workspaces.show.hero.best")
    assert_select "[data-testid=dashboard-latest-brew-card] a[href=?]", brew_path(latest)
    assert_select "[data-testid=dashboard-latest-best-brew-card] a[href=?]", brew_path(best)
    assert_select "[data-testid=dashboard-latest-brew-card] [data-testid=brew-timestamp]", "26.05.2026 12:00:00"
    assert_select "[data-testid=dashboard-latest-best-brew-card] [data-testid=brew-rating][aria-label=?]", "Rating 5 of 5 beans"
  end

  test "shows onboarding for signed-in user without workspace" do
    user = User.create!(email_address: "workspace-needed@example.com", password: "password")
    sign_in_as(user)

    get root_path

    assert_response :success
    assert_select "h1", I18n.t("workspace_onboardings.new.title")
  end
end
