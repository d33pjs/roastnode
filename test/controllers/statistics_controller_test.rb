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

  test "statistics offers private safe current and historical people filters" do
    users(:one).update!(
      display_name: "Jens",
      email_address: "current-private@example.test"
    )
    users(:two).update!(
      display_name: "Petra",
      email_address: "member-private@example.test"
    )
    brews(:morning_espresso).update!(
      user: users(:one),
      recipient_kind: "household_member",
      recipient_user: users(:two)
    )
    historical = User.create!(
      email_address: "former-private@example.test",
      password: "password",
      display_name: "Former person"
    )
    membership = workspaces(:household).memberships.create!(
      user: historical,
      role: "member"
    )
    workspaces(:household).brews.create!(
      user: historical,
      recipient_kind: "self",
      bean: beans(:second_open_household),
      grinder: equipment(:household_grinder),
      machine: equipment(:household_machine),
      bean_weight_grams: 20,
      ground_weight_grams: 20,
      dose_grams: 20,
      beverage_grams: 40
    )
    membership.destroy!
    workspaces(:household).brews.create!(
      user: users(:one),
      recipient_kind: "guest",
      recipient_name: "Secret Guest Sentinel",
      bean: beans(:second_open_household),
      grinder: equipment(:household_grinder),
      machine: equipment(:household_machine),
      bean_weight_grams: 20,
      ground_weight_grams: 20,
      dose_grams: 20,
      beverage_grams: 40
    )
    sign_in_as(users(:one))

    get statistics_path,
      params: {
        logger_id: users(:one).id,
        recipient: "user:#{users(:two).id}"
      }

    assert_response :success
    assert_select "select[data-testid=statistics-logger-filter]" do
      assert_select "option", text: I18n.t("statistics.index.all_loggers")
      assert_select "option[selected][value=?]", users(:one).id.to_s, text: "Jens"
      assert_select "option", text: "Petra"
      assert_select "option", text: "Former person"
    end
    assert_select "select[data-testid=statistics-recipient-filter]" do
      assert_select "option", text: I18n.t("statistics.index.all_recipients")
      assert_select "option[value=self]", text: I18n.t("statistics.index.self_served")
      assert_select "option[value=guests]", text: I18n.t("statistics.index.guests")
      assert_select "option[selected][value=?]", "user:#{users(:two).id}", text: "Petra"
      assert_select "option", text: "Former person"
    end
    assert_select "[data-testid=statistics-people-help]",
      I18n.t("statistics.index.people_filter_help")
    assert_select "body", text: /Secret Guest Sentinel/, count: 0
    assert_select "body", text: /current-private@example\.test/, count: 0
    assert_select "body", text: /member-private@example\.test/, count: 0
    assert_select "body", text: /former-private@example\.test/, count: 0
    assert_select "[data-testid=total-brews]", "1"
  end

  test "statistics combines logger recipient and date filters" do
    workspace = workspaces(:household)
    petra = users(:two)
    brews(:morning_espresso).update!(
      user: users(:one),
      recipient_kind: "household_member",
      recipient_user: petra,
      occurred_at: Time.zone.local(2026, 5, 26, 8, 0, 0)
    )
    workspace.brews.create!(
      user: petra,
      recipient_kind: "self",
      bean: beans(:second_open_household),
      grinder: equipment(:household_grinder),
      machine: equipment(:household_machine),
      occurred_at: Time.zone.local(2026, 5, 26, 9, 0, 0),
      bean_weight_grams: 20,
      ground_weight_grams: 20,
      dose_grams: 20,
      beverage_grams: 40
    )
    sign_in_as(users(:one))

    get statistics_path,
      params: {
        start_date: "2026-05-26",
        end_date: "2026-05-26",
        logger_id: users(:one).id,
        recipient: "user:#{petra.id}"
      }

    assert_response :success
    assert_select "[data-testid=total-brews]", "1"
    assert_select "[data-testid=total-ground]", "18g"
  end

  test "statistics rejects people identifiers outside the active workspace" do
    memberships(:member).destroy!
    sign_in_as(users(:one))

    get statistics_path, params: { logger_id: users(:two).id }
    assert_response :not_found

    get statistics_path, params: { recipient: "user:#{users(:two).id}" }
    assert_response :not_found
  end

  test "statistics rejects array and hash people parameters including blank values" do
    sign_in_as(users(:one))
    malformed_queries = [
      "logger_id[]=",
      "logger_id[]=#{users(:one).id}",
      "logger_id[value]=",
      "logger_id[value]=#{users(:one).id}",
      "recipient[]=",
      "recipient[]=self",
      "recipient[value]=",
      "recipient[value]=self"
    ]

    malformed_queries.each do |query|
      get "#{statistics_path}?#{query}"
      assert_response :not_found, "expected #{query.inspect} to be rejected"
    end
  end

  test "statistics rejects noncanonical numeric people identifiers" do
    sign_in_as(users(:one))
    valid_id = users(:one).id.to_s

    [ "+#{valid_id}", "0#{valid_id}", "0_#{valid_id}", " #{valid_id}", "#{valid_id} " ].each do |logger_id|
      get statistics_path, params: { logger_id: logger_id }
      assert_response :not_found, "expected logger_id #{logger_id.inspect} to be rejected"
    end

    get statistics_path, params: { recipient: "user:0#{valid_id}" }
    assert_response :not_found
  end

  test "timeframe links preserve people while reset actions clear deliberate scopes" do
    users(:one).update!(display_name: "Jens")
    sign_in_as(users(:one))

    get statistics_path,
      params: {
        timeframe: "last_30_days",
        logger_id: users(:one).id,
        recipient: "self"
      }

    assert_response :success
    assert_select "a[data-testid=statistics-timeframe-last_7_days][href=?]",
      statistics_path(
        timeframe: "last_7_days",
        logger_id: users(:one).id,
        recipient: "self"
      )
    assert_select "a[href=?]", statistics_path(
      logger_id: users(:one).id,
      recipient: "self"
    ), text: I18n.t("statistics.index.reset_timerange")
    assert_select "a[data-testid=statistics-clear-people][href=?]",
      statistics_path(timeframe: "last_30_days"),
      text: I18n.t("statistics.index.clear_people")
    assert_select "a[data-testid=statistics-reset-all][href=?]",
      statistics_path,
      text: I18n.t("statistics.index.reset_all")
  end

  test "clearing people preserves a manual inclusive date range" do
    sign_in_as(users(:one))

    get statistics_path,
      params: {
        start_date: "2026-05-01",
        end_date: "2026-05-15",
        logger_id: users(:one).id,
        recipient: "self"
      }

    assert_response :success
    assert_select "a[data-testid=statistics-clear-people][href=?]",
      statistics_path(start_date: "2026-05-01", end_date: "2026-05-15")
  end

  test "statistics filter panel is semantic responsive and touch friendly" do
    sign_in_as(users(:one))

    get statistics_path

    assert_response :success
    assert_select "form[data-testid=statistics-filter-panel]" do
      assert_select "fieldset[data-testid=statistics-date-filters] legend",
        I18n.t("statistics.index.date_range")
      assert_select "fieldset[data-testid=statistics-date-filters] nav[data-testid=statistics-timeframes]"
      assert_select "fieldset[data-testid=statistics-people-filters] legend",
        I18n.t("statistics.index.people")
    end
    %w[
      statistics-start-date
      statistics-end-date
      statistics-logger-filter
      statistics-recipient-filter
    ].each do |testid|
      assert_select "[data-testid=#{testid}]" do |nodes|
        classes = nodes.first["class"]
        assert_includes classes, "h-11"
        assert_includes classes, "w-full"
        assert_includes classes, "min-w-0"
        assert_includes classes, "max-w-full"
        assert_includes classes, "focus:outline-2"
      end
    end
    %w[
      statistics-apply-filters
      statistics-reset-date-range
      statistics-clear-people
      statistics-reset-all
    ].each do |testid|
      assert_select "[data-testid=#{testid}]" do |nodes|
        classes = nodes.first["class"]
        assert_includes classes, "w-full"
        assert_includes classes, "sm:w-auto"
      end
    end
  end

  test "statistics templates use theme tokens instead of fixed stone and white UI colors" do
    template_paths = %w[
      app/views/statistics/index.html.erb
      app/views/statistics/_bar_list.html.erb
      app/views/statistics/_day_bars.html.erb
      app/views/statistics/_breakdown_list.html.erb
    ]

    template_paths.each do |path|
      contents = Rails.root.join(path).read

      assert_no_match(/(?:bg-white|text-white|(?:bg|border|text|decoration)-stone-\d+)/, contents, path)
      assert_no_match(/text-\[\#f8faf6\]/, contents, path)
    end
    assert_includes Rails.root.join("app/views/statistics/index.html.erb").read,
      "text-[var(--rn-canvas)]"
  end

  test "empty people results show honest brew states and retain current bean catalog facts" do
    sign_in_as(users(:one))

    get statistics_path,
      params: {
        timeframe: "last_7_days",
        logger_id: users(:two).id,
        recipient: "guests"
      }

    assert_response :success
    assert_select "[data-testid=total-brews]", "0"
    assert_select "[data-testid=statistics-no-brew-data]",
      I18n.t("statistics.index.no_filtered_brew_data")
    assert_select "[data-testid=average-brew-cost]",
      I18n.t("statistics.index.no_average_brew_cost")
    assert_select "[data-testid=open-beans]", "2"
    assert_select "[data-testid=known-spend]", text: /12[,.]90 EUR/
    assert_select "[data-testid=statistics-current-catalog-note]", {
      text: I18n.t("statistics.index.current_inventory_note"),
      count: 3
    }
    assert_select "section[data-testid=statistics-equipment] p", {
      text: I18n.t("statistics.index.no_equipment_data"),
      count: 2
    }
    assert_select "[data-testid=statistics-channeling-rate]",
      I18n.t("statistics.index.no_channeling_data")
    assert_select "[data-testid=statistics-channeling-rate]", text: /0%/, count: 0
    assert_select "[data-testid=statistics-equipment]", text: /Unknown|0 brews/, count: 0
    assert_select "[data-testid=statistics-retention] p",
      I18n.t("statistics.index.no_retention_data")
    assert_select "[data-testid=statistics-taste] p",
      I18n.t("statistics.index.no_taste_data")
    assert_select "[data-testid=statistics-day-series-empty]", {
      text: I18n.t("statistics.index.no_day_series_data"),
      count: 2
    }
    assert_select "[data-testid=statistics-day-series-point]", count: 0
  end

  test "channeling renders zero percent when matching Espresso brews exist" do
    brews(:morning_espresso).update!(channeling: false)
    sign_in_as(users(:one))

    get statistics_path

    assert_response :success
    assert_select "[data-testid=statistics-channeling-rate]", "0%"
  end

  test "Quick Drip only results keep total brews but do not invent a channeling rate" do
    brews(:morning_espresso).update!(
      method: "quick_drip",
      machine: nil,
      brewer: equipment(:household_brewer),
      machine_cups: 2,
      channeling: nil
    )
    sign_in_as(users(:one))

    get statistics_path

    assert_response :success
    assert_select "[data-testid=total-brews]", "1"
    assert_select "[data-testid=statistics-channeling-rate]",
      I18n.t("statistics.index.no_channeling_data")
    assert_select "[data-testid=statistics-channeling-rate]", text: /0%/, count: 0
  end

  test "day series emptiness is based on the ten visible days" do
    brews(:morning_espresso).update!(
      occurred_at: Time.zone.local(2026, 5, 14, 8, 0, 0)
    )
    sign_in_as(users(:one))

    get statistics_path,
      params: {
        start_date: "2026-05-14",
        end_date: "2026-05-27"
      }

    assert_response :success
    assert_select "[data-testid=total-brews]", "1"
    assert_select "[data-testid=statistics-day-series-empty]",
      { text: I18n.t("statistics.index.no_day_series_data"), count: 2 }
    assert_select "[data-testid=statistics-day-series-point]", count: 0
  end

  test "day series empty copy names the displayed chart window" do
    assert_equal "No matching brew data in the displayed chart window.",
      I18n.t("statistics.index.no_day_series_data")
  end

  test "day series reserves mobile width for labels and bars" do
    template = Rails.root.join("app/views/statistics/_day_bars.html.erb").read

    assert_includes template, "grid-cols-[minmax(0,1fr)_auto]"
    assert_includes template, "sm:grid-cols-[5.5rem_minmax(0,1fr)_3rem]"
    assert_includes template, "col-span-2"
  end

  test "bean breakdown labels wrap long unbroken user text" do
    template = Rails.root.join("app/views/statistics/_breakdown_list.html.erb").read

    assert_includes template, "min-w-0"
    assert_includes template, "max-w-full"
    assert_includes template, "break-words"
    assert_includes template, "[overflow-wrap:anywhere]"
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
