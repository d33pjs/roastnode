require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "shows the public home page" do
    get root_path

    assert_response :success
    assert_select "img[data-testid=brand-wordmark][alt=?]", "Roastnode"
    assert_select "img[data-testid=brand-wordmark][src*=?]", "logo_wordmark_transparent"
    assert_select "h1", I18n.t("home.index.title")
    assert_select "a[href=?]", new_session_path, text: I18n.t("home.index.sign_in")
    assert_select "[data-testid=app-mobile-navigation]", count: 0
    assert_select "a[data-testid=site-footer-github][href=?]", Roastnode::AppVersion.github_url
    assert_select "[data-testid=site-footer-github-logo]"
    assert_select "[data-testid=site-footer-version]", count: 0
  end

  test "signed-in app renders themed shell navigation" do
    user = users(:one)
    user.update!(theme: "dark", display_name: "Jens")
    sign_in_as(user)

    get dashboard_path

    assert_response :success
    assert_select "html.theme-dark"
    assert_select "[data-testid=app-navigation][data-controller=?]", "app-nav"
    assert_select "[data-testid=app-navigation] img[data-testid=brand-wordmark][alt=?][src*=?]",
      "Roastnode",
      "logo_wordmark_transparent"
    assert_select "[data-testid=app-navigation] img[data-testid=brand-mark]", count: 0
    assert_select "[data-testid=app-mobile-actions].md\\:hidden" do
      assert_select "a[data-testid=app-nav-log][href=?]", new_brew_path
      assert_select "[data-testid=app-mobile-menu]"
    end
    assert_select "[data-testid=app-desktop-navigation]"
    assert_select "[data-testid=app-mobile-navigation]", count: 0
    assert_select "[data-testid=app-nav-more]", count: 0
    assert_select "a[data-testid=app-nav-log][href=?]", new_brew_path
    assert_select "a[data-testid=app-nav-dashboard][href=?]", dashboard_path
    assert_select "a[data-testid=app-nav-beans][href=?]", beans_path
    assert_select "a[data-testid=app-nav-statistics][href=?]", statistics_path
    assert_select "a[data-testid=app-nav-gear][href=?]", gear_path
    assert_select "details[data-testid=app-nav-account][data-app-nav-target=?][data-action*=?]",
      "menu",
      "toggle->app-nav#closeOtherMenus"
    assert_select "details[data-testid=app-nav-settings][data-app-nav-target=?][data-action*=?]",
      "menu",
      "toggle->app-nav#closeOtherMenus"
    assert_select "a[href=?]", equipment_index_path, text: I18n.t("shared.app_navigation.equipment"), count: 0
    assert_select "a[href=?]", preparation_tools_path, text: I18n.t("shared.app_navigation.preparation_tools"), count: 0
    assert_select "a[href=?]", edit_profile_path, text: I18n.t("shared.app_navigation.profile")
    assert_select "a[href=?]", memberships_path, text: I18n.t("shared.app_navigation.members")
    assert_select "a[href=?]", workspace_export_path, text: I18n.t("shared.app_navigation.export")
    assert_select "a[href=?]", new_beanconqueror_import_path, text: I18n.t("shared.app_navigation.import")
    assert_select "form[action=?][method=post]", session_path
    assert_select "form[action=?][method=post]", session_path, text: /#{Regexp.escape(user.display_label)}/
    assert_select "[data-testid=site-footer-version]", text: I18n.t("shared.site_footer.version", version: Roastnode::AppVersion.current)
    assert_select "a[data-testid=site-footer-github][href=?]", Roastnode::AppVersion.github_url
    assert_select "[data-testid=site-footer-github-logo]"
    assert_no_match(/fixed inset-x-3 bottom-3/, response.body)
    assert_no_match user.email_address, response.body
  end

  test "shows signed-in state after authentication" do
    user = users(:one)
    user.update!(display_name: "Jens")
    sign_in_as(user)

    get root_path

    assert_response :success
    assert_select "img[data-testid=brand-wordmark][alt=?]", "Roastnode"
    assert_select "img[data-testid=brand-wordmark][src*=?]", "logo_wordmark_transparent"
    assert_select "[data-testid=app-navigation]"
    assert_select "[data-testid=app-mobile-navigation]", count: 0
    assert_select "[data-testid=app-desktop-navigation]"
    assert_select "[data-testid=dashboard-shell] img[data-testid=brand-wordmark]", count: 0
    assert_select "p", text: I18n.t("workspaces.show.signed_in_as", user: user.display_label), count: 0
    assert_select "p", text: I18n.t("workspaces.show.role", role: memberships(:owner).role.humanize), count: 0
    assert_no_match user.email_address, response.body
    assert_select "a[href=?]", edit_profile_path, text: I18n.t("shared.app_navigation.profile")
    assert_select "a[href=?]", edit_workspace_path, text: I18n.t("shared.app_navigation.workspace_settings")
    assert_select "a[href=?]", new_session_path, count: 0
  end

  test "dashboard falls back to unknown username without exposing email" do
    user = users(:one)
    user.update!(display_name: nil)
    sign_in_as(user)

    get root_path

    assert_response :success
    assert_select "p", text: I18n.t("workspaces.show.signed_in_as", user: user.display_label), count: 0
    assert_no_match user.email_address, response.body
  end

  test "workspace owner sees invite management link" do
    sign_in_as(users(:one))

    get root_path

    assert_response :success
    assert_select "a[href=?]", workspace_invites_path, text: I18n.t("shared.app_navigation.invites")
    assert_select "a[href=?]", workspace_export_path, text: I18n.t("shared.app_navigation.export")
    assert_select "a[href=?]", workspace_export_beans_path, text: I18n.t("shared.app_navigation.export_beans")
    assert_select "a[href=?]", workspace_export_brews_path, text: I18n.t("shared.app_navigation.export_brews")
    assert_select "a[href=?]", workspace_export_media_path, text: I18n.t("shared.app_navigation.export_media")
    assert_select "a[href=?]", new_beanconqueror_import_path, text: I18n.t("shared.app_navigation.import")
  end

  test "instance admin sees instance admin link" do
    user = users(:one)
    user.update!(instance_admin: true)
    sign_in_as(user)

    get root_path

    assert_response :success
    assert_select "a[href='/instance_admin']", { minimum: 1, text: I18n.t("shared.app_navigation.instance_admin") }
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
    assert_select "a[href=?]", workspace_export_media_path, count: 0
    assert_select "a[href=?]", edit_workspace_path, count: 0
    assert_select "a[href='/instance_admin']", count: 0
    assert_select "[data-testid=app-nav-settings]", count: 0
  end

  test "workspace dashboard shows overview and recent activity without duplicate command strips" do
    sign_in_as(users(:one))

    get root_path

    assert_response :success
    assert_select "[data-testid=dashboard-primary-actions]", count: 0
    assert_select "[data-testid=dashboard-secondary-actions]", count: 0
    assert_select "main a[href=?]", new_brew_path, count: 0
    assert_select "main a[href=?]", new_bean_path, count: 0
    assert_select "main a[href=?]", new_equipment_path, count: 0
    assert_select "main a[href=?]", new_equipment_event_path, count: 0
    assert_select "h2", I18n.t("workspaces.show.open_beans")
    assert_select "a[href=?]", bean_path(beans(:open_household)), text: /#{beans(:open_household).name}/
    assert_select "a[href=?]", bean_path(beans(:other_workspace_open)), count: 0
    assert_select "a[href=?]", brew_path(brews(:morning_espresso)), text: /#{beans(:open_household).name}/
    assert_select "a[href=?]", equipment_event_path(equipment_events(:grinder_cleaning)), text: /Grinder cleaning/
    assert_select "[data-testid=dashboard-recent-activity-heading] a[href=?]", activity_path, text: I18n.t("workspaces.show.view_all")
    assert_select "p", text: I18n.t("workspaces.show.activity.adjustment", amount: "-18", bean: beans(:open_household).name), count: 0
    assert_select "p", text: I18n.t("workspaces.show.status.brews_this_week")
  end

  test "workspace dashboard renders open bean primary photos and refreshed sections" do
    bean = beans(:open_household)
    photo = attach_photo(bean)
    bean.set_primary_photo!(photo)
    sign_in_as(users(:one))

    get dashboard_path

    assert_response :success
    assert_select "[data-testid=dashboard-shell]"
    assert_select "[data-testid=dashboard-open-beans] img[data-testid=dashboard-open-bean-photo][src=?]",
      media_attachment_path(photo, variant: :thumbnail)
    assert_select "[data-testid=dashboard-primary-actions]", count: 0
    assert_select "[data-testid=dashboard-secondary-actions]", count: 0
    assert_select "[data-testid=dashboard-recent-activity]"
    assert_select "[data-testid=workspace-mobile-menu]", count: 0
    assert_select "[data-testid=workspace-desktop-menu]", count: 0
  end

  test "workspace dashboard renders open bean cockpit facts" do
    travel_to Time.zone.local(2026, 6, 7, 12, 0, 0) do
      workspace = workspaces(:household)
      bean = beans(:open_household)
      bean.update!(
        opened_on: Date.new(2026, 5, 10),
        roast_date: Date.new(2026, 5, 1),
        remaining_grams: 150
      )
      latest = brews(:morning_espresso)
      latest.update!(
        bean:,
        occurred_at: Time.zone.local(2026, 6, 6, 8, 15, 0),
        grind_setting: "12.5",
        dose_grams: 18,
        beverage_grams: 45,
        total_time_seconds: 29,
        rating: 3
      )
      best = workspace.brews.create!(
        user: users(:one),
        bean:,
        grinder: equipment(:household_grinder),
        machine: equipment(:household_machine),
        occurred_at: Time.zone.local(2026, 5, 24, 8, 15, 0),
        bean_weight_grams: 18,
        ground_weight_grams: 18,
        dose_grams: 18,
        beverage_grams: 42,
        total_time_seconds: 27,
        grind_setting: "13",
        rating: 5
      )
      sign_in_as(users(:one))

      get dashboard_path

      assert_response :success
      assert_select "[data-testid=dashboard-open-bean-cockpit]"
      assert_select "[data-testid=?]", "dashboard-open-bean-card-#{bean.id}" do
        assert_select "a[href=?]", bean_path(bean), text: /#{bean.name}/
        assert_select "[data-testid=?]", "dashboard-open-bean-remaining-#{bean.id}", text: /132g of 250g/
        assert_select "[data-testid=?]", "dashboard-open-bean-open-age-#{bean.id}", text: "Open 28 days"
        assert_select "[data-testid=?]", "dashboard-open-bean-roast-age-#{bean.id}", text: "Roast age 37 days"
        assert_select "a[href=?]", brew_path(latest), text: /Last coffee/
        assert_select "[data-testid=?]", "dashboard-open-bean-last-setup-#{bean.id}", text: /Grind 12.5/
        assert_select "[data-testid=?]", "dashboard-open-bean-last-setup-#{bean.id}", text: /1:2,5 in 29s/
        assert_select "a[href=?]", brew_path(best), text: /Best brew/
        assert_select "[data-testid=?]", "dashboard-open-bean-best-#{bean.id}", text: /Rating 5/
        assert_select "a[href=?]", new_brew_path(repeat_brew_id: best.id), text: I18n.t("workspaces.show.cockpit.repeat")
      end
      assert_select "body", text: beans(:other_workspace_open).name, count: 0
    end
  end

  test "workspace dashboard constrains open beans and recent activity on narrow screens" do
    sign_in_as(users(:one))

    get dashboard_path

    assert_response :success
    assert_select "[data-testid=dashboard-open-beans].min-w-0"
    assert_select "[data-testid=dashboard-recent-activity].min-w-0"
    assert_select "[data-testid=dashboard-recent-activity] a.min-w-0"
    assert_select "[data-testid=dashboard-recent-activity] p.break-words"
    assert_select "[data-testid=dashboard-latest-coffee-card].min-w-0"
    assert_select "[data-testid=dashboard-latest-coffee-card] > a.min-w-0"
  end

  test "workspace dashboard header uses household logo without repeated app identity" do
    workspace = workspaces(:household)
    logo = attach_named_photo(workspace, :logo, filename: "household-logo.jpg")
    user = users(:one)
    user.update!(display_name: "Jens")
    sign_in_as(user)

    get dashboard_path

    assert_response :success
    assert_select "[data-testid=dashboard-shell] img[data-testid=brand-wordmark]", count: 0
    assert_select "[data-testid=dashboard-workspace-heading] img[data-testid=dashboard-workspace-logo][src=?]",
      media_attachment_path(logo, variant: :thumbnail)
    assert_select "[data-testid=dashboard-workspace-heading] h1", workspace.name
    assert_select "p", text: I18n.t("workspaces.show.signed_in_as", user: user.display_label), count: 0
    assert_select "p", text: I18n.t("workspaces.show.role", role: memberships(:owner).role.humanize), count: 0
  end

  test "workspace dashboard shows manual inventory adjustments in recent activity" do
    bean = beans(:open_household)
    bean.inventory_adjustments.create!(
      workspace: bean.workspace,
      user: users(:one),
      delta_grams: 12.5,
      reason: "manual",
      note: "Found extra beans.",
      occurred_at: Time.zone.local(2026, 5, 27, 10, 15, 0)
    )
    sign_in_as(users(:one))

    get root_path

    assert_response :success
    assert_select "p", text: I18n.t("workspaces.show.activity.adjustment", amount: "12,5", bean: bean.name)
  end

  test "root honors log espresso landing preference while dashboard remains accessible" do
    user = users(:one)
    user.update!(default_landing_screen: "log_espresso")
    sign_in_as(user)

    get root_path

    assert_redirected_to new_brew_path

    get dashboard_path

    assert_response :success
    assert_select "[data-testid=dashboard-shell]"
    assert_select "[data-testid=dashboard-primary-actions]", count: 0
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
    assert_select "[data-testid=dashboard-latest-coffee-heading] a[href=?]", coffees_path, text: I18n.t("workspaces.show.view_all")
    assert_select "[data-testid=dashboard-latest-coffee-card] a[href=?]", brew_path(latest)
    assert_select "[data-testid=dashboard-latest-best-brew-card] a[href=?]", brew_path(best)
    assert_select "[data-testid=dashboard-latest-coffee-card] > a", count: 1
    assert_select "[data-testid=dashboard-latest-best-brew-card] > a", count: 1
    assert_select "[data-testid=dashboard-latest-coffee-card] a[href=?]", bean_path(latest.bean), count: 0
    assert_select "[data-testid=dashboard-latest-coffee-card] a[href=?]", equipment_path(latest.grinder), count: 0
    assert_select "[data-testid=dashboard-latest-coffee-card] [data-testid=brew-timestamp]", "26.05.2026 12:00:00"
    assert_select "[data-testid=dashboard-latest-best-brew-card] [data-testid=brew-rating][aria-label=?]", "Rating 5 of 5 beans"
  end

  test "workspace dashboard renders compact header timer and ordered metric trends" do
    travel_to Time.zone.local(2026, 6, 10, 12, 0, 0) do
      workspace = workspaces(:household)
      brew = brews(:morning_espresso)
      brew.update!(
        occurred_at: Time.zone.local(2026, 6, 10, 10, 0, 0),
        rating: 4
      )
      workspace.external_coffees.create!(
        user: users(:one),
        drink_type: "Flat White",
        occurred_at: Time.zone.local(2026, 6, 10, 11, 0, 0),
        price_cents: 450,
        currency: workspace.default_currency
      )
      beans(:open_household).update!(opened_on: Date.new(2026, 5, 10), remaining_grams: 150)
      beans(:second_open_household).update!(opened_on: Date.new(2026, 5, 12), remaining_grams: 220)
      workspace.beans.create!(
        name: "Closed Today",
        roaster_name: "Done Roaster",
        bag_size_grams: 250,
        remaining_grams: 0,
        opened_on: Date.new(2026, 5, 1),
        finished_at: Time.zone.local(2026, 6, 10, 8, 0, 0)
      )
      sign_in_as(users(:one))

      get dashboard_path

      assert_response :success
      assert_select "[data-testid=dashboard-workspace-header] [data-testid=dashboard-last-coffee-timer][data-controller=?]", "dashboard-timer"
      assert_select "[data-testid=dashboard-last-coffee-timer].lg\\:text-right", text: /1h 0m 0s/
      assert_select "[data-testid=dashboard-last-coffee-timer]", text: /Updates every second/, count: 0
      assert_appears_before 'data-testid="dashboard-last-coffee-timer"', 'data-testid="dashboard-latest-coffee-card"'
      assert_select "[data-testid=dashboard-latest-coffee-card] > a", count: 1
      assert_select "[data-testid=dashboard-latest-best-brew-card] > a", count: 1
      assert_select "section[data-testid=dashboard-metrics-grid].xl\\:grid-cols-4"
      assert_select "[data-testid=dashboard-metrics-grid] > article[data-testid=dashboard-metric-coffees-today]"
      assert_select "[data-testid=dashboard-metrics-grid] > article[data-testid=dashboard-metric-spent-this-week]"
      assert_select "[data-testid=dashboard-metrics-grid] > article.h-48", count: 12
      assert_select "[data-testid=dashboard-metric-coffees-today]", text: /#{I18n.t("workspaces.show.status.coffees_today")}/
      assert_select "[data-testid=dashboard-metric-coffees-today] [data-testid=dashboard-metric-chart].absolute svg[data-testid=dashboard-line-chart]"
      assert_select "[data-testid=dashboard-metric-coffees-today] line[data-testid=dashboard-line-chart-average]"
      assert_select "[data-testid=dashboard-metric-coffees-today] circle[data-testid=dashboard-line-chart-current]"
      assert_select "[data-testid=dashboard-metric-coffees-today] [data-testid=dashboard-metric-trend-label].absolute", text: /last 4 weeks/
      assert_card_contains_in_order(
        "dashboard-metric-coffees-today",
        'data-testid="dashboard-metric-chart"',
        'data-testid="dashboard-metric-trend-label"'
      )
      assert_select "[data-testid=dashboard-metric-spent-this-week]", text: /last 4 weeks/
      assert_select "[data-testid=dashboard-metric-open-beans]", text: /#{I18n.t("workspaces.show.status.open_beans")}/
      assert_select "[data-testid=dashboard-metric-stock-bags]", text: /#{I18n.t("workspaces.show.status.stock_bags")}/
      assert_select "[data-testid=dashboard-metric-open-grams]", text: /#{I18n.t("workspaces.show.status.open_grams_remaining")}/
      assert_select "[data-testid=dashboard-metric-closed-bags-today]", text: /#{I18n.t("workspaces.show.status.closed_bags_today")}/
      assert_select "[data-testid=dashboard-metric-closed-bags-this-week]", text: /#{I18n.t("workspaces.show.status.closed_bags_this_week")}/
      assert_appears_before 'data-testid="dashboard-metric-coffees-today"', 'data-testid="dashboard-metric-brews-today"'
      assert_appears_before 'data-testid="dashboard-metric-brews-today"', 'data-testid="dashboard-metric-coffees-this-week"'
      assert_appears_before 'data-testid="dashboard-metric-coffees-this-week"', 'data-testid="dashboard-metric-brews-this-week"'
      assert_appears_before 'data-testid="dashboard-metric-open-beans"', 'data-testid="dashboard-metric-stock-bags"'
      assert_appears_before 'data-testid="dashboard-metric-stock-bags"', 'data-testid="dashboard-metric-open-grams"'
      assert_appears_before 'data-testid="dashboard-metric-open-grams"', 'data-testid="dashboard-metric-stock-grams"'
      assert_appears_before 'data-testid="dashboard-metric-closed-bags-today"', 'data-testid="dashboard-metric-closed-bags-this-week"'
      assert_appears_before 'data-testid="dashboard-metric-closed-bags-this-week"', 'data-testid="dashboard-metric-spent-today"'
      assert_appears_before 'data-testid="dashboard-metric-spent-today"', 'data-testid="dashboard-metric-spent-this-week"'
    end
  end

  test "workspace dashboard latest coffee can be an external coffee" do
    workspace = workspaces(:household)
    latest_brew = brews(:morning_espresso)
    latest_brew.update!(occurred_at: Time.zone.local(2026, 6, 1, 8, 0, 0), rating: 5)
    external = workspace.external_coffees.create!(
      user: users(:one),
      drink_type: "Iced Latte",
      place_name: "Station Coffee",
      occurred_at: Time.zone.local(2026, 6, 1, 9, 0, 0),
      acidity_balance: "balanced",
      intensity: "weak",
      rating: 3
    )
    sign_in_as(users(:one))

    get dashboard_path

    assert_response :success
    assert_select "h2", I18n.t("workspaces.show.hero.latest")
    assert_select "[data-testid=dashboard-latest-coffee-card] a[href=?]", external_coffee_path(external)
    assert_select "[data-testid=dashboard-latest-coffee-card] [data-testid=external-coffee-hero-card]", text: /Iced Latte/
    assert_select "[data-testid=dashboard-latest-best-brew-card] a[href=?]", brew_path(latest_brew)
  end

  test "workspace dashboard renders latest quick drip hero card" do
    workspace = workspaces(:household)
    user = users(:one)
    brew = workspace.brews.create!(
      user:,
      method: "quick_drip",
      bean: beans(:second_open_household),
      brewer: equipment(:household_brewer),
      occurred_at: Time.current + 1.day,
      machine_cups: 6,
      coffee_spoons: 6,
      grams_per_coffee_spoon: 5,
      total_time_seconds: 320,
      taste_balance: "neutral",
      rating: 4
    )
    sign_in_as(user)

    get dashboard_path

    assert_response :success
    assert_select "[data-testid=dashboard-latest-coffee-card] a[href=?]", brew_path(brew)
    assert_select "[data-testid=dashboard-latest-coffee-card] [data-testid=brew-hero-card][data-method=quick_drip]"
    assert_select "[data-testid=dashboard-latest-coffee-card] [data-testid=quick-drip-machine-cups]", "6"
    assert_select "[data-testid=dashboard-latest-coffee-card] [data-testid=brew-chart-grid]", count: 0
  end

  test "shows onboarding for signed-in user without workspace" do
    user = User.create!(email_address: "workspace-needed@example.com", password: "password")
    sign_in_as(user)

    get root_path

    assert_response :success
    assert_select "h1", I18n.t("workspace_onboardings.new.title")
  end

  private
    def assert_appears_before(first, second)
      first_index = response.body.index(first)
      second_index = response.body.index(second)

      assert first_index, "Expected #{first.inspect} to appear in response body"
      assert second_index, "Expected #{second.inspect} to appear in response body"
      assert_operator first_index, :<, second_index
    end

    def assert_card_contains_in_order(testid, first, second)
      card_start = response.body.index(%(data-testid="#{testid}"))
      assert card_start, "Expected #{testid.inspect} to appear in response body"

      card_end = response.body.index("</article>", card_start)
      assert card_end, "Expected #{testid.inspect} card to close"

      card_body = response.body[card_start...card_end]
      first_index = card_body.index(first)
      second_index = card_body.index(second)
      assert first_index, "Expected #{first.inspect} to appear in #{testid.inspect}"
      assert second_index, "Expected #{second.inspect} to appear in #{testid.inspect}"
      assert_operator first_index, :<, second_index
    end
end
