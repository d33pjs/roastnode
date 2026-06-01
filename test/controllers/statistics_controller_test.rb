require "test_helper"

class StatisticsControllerTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  test "workspace member sees scoped statistics" do
    sign_in_as(users(:one))

    get statistics_path

    assert_response :success
    assert_select "h1", I18n.t("statistics.index.title")
    assert_select "a[data-testid=statistics-all-brews-button][href=?]", brews_path, text: I18n.t("statistics.index.all_brews")
    assert_select "[data-testid=statistics-total-brews-card] a[href=?]", brews_path, text: I18n.t("statistics.index.view_all")
    assert_select "[data-testid=total-brews]", "1"
    assert_select "[data-testid=total-ground]", "18g"
    assert_select "[data-testid=open-beans]", "2"
    assert_select "h2", I18n.t("statistics.index.equipment")
    assert_select "p", text: /Niche Zero/
    assert_select "p", text: /Other Grinder/, count: 0
  end

  test "workspace member sees last seven days as the default statistics range" do
    travel_to Time.zone.local(2026, 5, 27, 12, 0, 0) do
      brews(:morning_espresso).update!(occurred_at: Time.zone.local(2026, 5, 26, 8, 0, 0))
      workspaces(:household).brews.create!(
        user: users(:one),
        bean: beans(:second_open_household),
        grinder: equipment(:household_grinder),
        machine: equipment(:household_machine),
        occurred_at: Time.zone.local(2026, 5, 18, 9, 30, 0),
        bean_weight_grams: 20,
        ground_weight_grams: 20,
        dose_grams: 20,
        beverage_grams: 50,
        total_time_seconds: 32,
        rating: 3
      )

      sign_in_as(users(:one))
      get statistics_path

      assert_response :success
      assert_select "input[data-testid=statistics-start-date][value='2026-05-21']"
      assert_select "input[data-testid=statistics-end-date][value='2026-05-27']"
      assert_select "[data-testid=total-brews]", "1"
      assert_select "[data-testid=total-ground]", "18g"
      assert_select "a[data-testid=statistics-timeframe-last_7_days][aria-current=page]", text: I18n.t("statistics.index.timeframes.last_7_days")
    end
  end

  test "workspace member filters statistics by date range" do
    brews(:morning_espresso).update!(occurred_at: Time.zone.local(2026, 5, 26, 8, 0, 0))
    workspaces(:household).brews.create!(
      user: users(:one),
      bean: beans(:second_open_household),
      grinder: equipment(:household_grinder),
      machine: equipment(:household_machine),
      occurred_at: Time.zone.local(2026, 5, 20, 9, 30, 0),
      bean_weight_grams: 20,
      ground_weight_grams: 20.4,
      dose_grams: 20,
      beverage_grams: 50,
      total_time_seconds: 32,
      channeling: true,
      taste_balance: "bitter",
      rating: 3
    )

    sign_in_as(users(:one))
    get statistics_path, params: { start_date: "2026-05-26", end_date: "2026-05-26" }

    assert_response :success
    assert_select "input[data-testid=statistics-start-date][value='2026-05-26']"
    assert_select "input[data-testid=statistics-end-date][value='2026-05-26']"
    assert_select "[data-testid=total-brews]", "1"
    assert_select "[data-testid=total-ground]", "18g"
  end

  test "workspace member uses relative timeframe shortcuts" do
    travel_to Time.zone.local(2026, 5, 27, 12, 0, 0) do
      brews(:morning_espresso).update!(occurred_at: Time.zone.local(2026, 5, 26, 8, 0, 0))
      workspaces(:household).brews.create!(
        user: users(:one),
        bean: beans(:second_open_household),
        grinder: equipment(:household_grinder),
        machine: equipment(:household_machine),
        occurred_at: Time.zone.local(2026, 5, 1, 9, 30, 0),
        bean_weight_grams: 20,
        ground_weight_grams: 20,
        dose_grams: 20,
        beverage_grams: 50,
        total_time_seconds: 32,
        rating: 3
      )

      sign_in_as(users(:one))
      get statistics_path, params: { timeframe: "last_7_days" }

      assert_response :success
      assert_select "input[data-testid=statistics-start-date][value='2026-05-21']"
      assert_select "input[data-testid=statistics-end-date][value='2026-05-27']"
      assert_select "[data-testid=total-brews]", "1"
      assert_select "[data-testid=total-ground]", "18g"
      assert_select "a[href=?]", statistics_path(timeframe: "last_30_days"), text: I18n.t("statistics.index.timeframes.last_30_days")
      assert_select "a[href=?]", statistics_path, text: I18n.t("statistics.index.reset_timerange")
    end
  end

  test "workspace member uses all time statistics timeframe" do
    travel_to Time.zone.local(2026, 5, 27, 12, 0, 0) do
      brews(:morning_espresso).update!(occurred_at: Time.zone.local(2026, 5, 26, 8, 0, 0))
      workspaces(:household).brews.create!(
        user: users(:one),
        bean: beans(:second_open_household),
        grinder: equipment(:household_grinder),
        machine: equipment(:household_machine),
        occurred_at: Time.zone.local(2026, 5, 1, 9, 30, 0),
        bean_weight_grams: 20,
        ground_weight_grams: 20,
        dose_grams: 20,
        beverage_grams: 50,
        total_time_seconds: 32,
        rating: 3
      )

      sign_in_as(users(:one))
      get statistics_path, params: { timeframe: "all_time" }

      assert_response :success
      assert_select "input[data-testid=statistics-start-date][value='2026-05-01']"
      assert_select "input[data-testid=statistics-end-date][value='2026-05-27']"
      assert_select "[data-testid=total-brews]", "2"
      assert_select "[data-testid=total-ground]", "38g"
      assert_select "a[data-testid=statistics-timeframe-all_time][aria-current=page]", text: I18n.t("statistics.index.timeframes.all_time")
    end
  end

  test "workspace member sees helpful empty states for current inventory and brew cost cards" do
    beans(:open_household).update!(purchase_price_cents: nil, remaining_grams: 0)
    beans(:second_open_household).update!(purchase_price_cents: nil, remaining_grams: 0)
    brews(:morning_espresso).update!(
      bean: beans(:second_open_household),
      occurred_at: Time.zone.local(2026, 5, 26, 8, 0, 0)
    )

    sign_in_as(users(:one))
    get statistics_path, params: { timeframe: "last_7_days" }

    assert_response :success
    assert_select "[data-testid=open-beans]", I18n.t("statistics.index.no_open_beans")
    assert_select "[data-testid=known-spend]", I18n.t("statistics.index.no_known_spend")
    assert_select "[data-testid=average-brew-cost]", I18n.t("statistics.index.no_average_brew_cost")
  end

  test "viewer can read statistics" do
    memberships(:member).update!(role: "viewer")
    user = users(:two)
    user.update!(active_workspace: workspaces(:household))
    sign_in_as(user)

    get statistics_path

    assert_response :success
    assert_select "h1", I18n.t("statistics.index.title")
  end

  test "dashboard links to statistics" do
    sign_in_as(users(:one))

    get root_path

    assert_response :success
    assert_select "a[data-testid=app-nav-statistics][href=?]", statistics_path, text: I18n.t("shared.app_navigation.statistics")
  end
end
