require "test_helper"

class BrewGrinderReminderTest < ActiveSupport::TestCase
  test "uses operator history before newer workspace history and stays method scoped" do
    workspace = workspaces(:household)
    operator = users(:one)
    bean = beans(:open_household)
    other_bean = beans(:second_open_household)
    grinder = equipment(:household_grinder)
    brews(:morning_espresso).update!(user: users(:two), occurred_at: 3.days.ago)
    operator_brew = create_espresso(
      workspace:, user: operator, bean:, grinder:, setting: "1/1,75",
      rating: 3, occurred_at: 2.days.ago
    )
    create_espresso(
      workspace:, user: users(:two), bean: other_bean, grinder:, setting: "1/2,00",
      rating: 5, occurred_at: 1.hour.ago
    )
    workspace.brews.create!(
      user: operator,
      bean: other_bean,
      brewer: equipment(:household_brewer),
      grinder:,
      method: "quick_drip",
      occurred_at: 1.minute.ago,
      machine_cups: 4,
      bean_weight_grams: 1,
      grind_setting: "filter 8",
      rating: 5
    )

    result = BrewGrinderReminder.new(
      workspace:, user: operator, method: "espresso", beans: [ bean, other_bean ]
    ).call

    assert_equal operator_brew.bean_id, result.last_bean_id
    assert_equal operator_brew, result.previous.brew
  end

  test "falls back to the workspace and never reads another workspace" do
    workspace = workspaces(:household)
    operator = users(:two)
    bean = beans(:open_household)
    local = create_espresso(
      workspace:, user: users(:one), bean:, grinder: equipment(:household_grinder),
      setting: "12", rating: 4, occurred_at: 2.hours.ago
    )
    create_espresso(
      workspace: workspaces(:other_household), user: operator,
      bean: beans(:other_workspace_open), grinder: equipment(:other_workspace_grinder),
      setting: "secret", rating: 5, occurred_at: 1.minute.ago
    )

    result = BrewGrinderReminder.new(
      workspace:, user: operator, method: "espresso", beans: [ bean ]
    ).call

    assert_equal local, result.previous.brew
    assert_equal bean.id, result.last_bean_id
    assert_not_includes result.previous.display_parts, "secret"
  end

  test "chooses the highest-rated usable bean reference and breaks ties by recency" do
    workspace = workspaces(:household)
    bean = beans(:second_open_household)
    grinder = equipment(:household_grinder)
    create_espresso(
      workspace:, user: users(:one), bean:, grinder:, setting: "old five",
      rating: 5, occurred_at: 2.days.ago
    )
    chosen = create_espresso(
      workspace:, user: users(:one), bean:, grinder:, setting: "new five",
      rating: 5, occurred_at: 1.day.ago
    )
    create_espresso(
      workspace:, user: users(:one), bean:, grinder:, setting: "recent four",
      rating: 4, occurred_at: 1.minute.ago
    )
    create_espresso(
      workspace:, user: users(:one), bean:, grinder: nil, setting: " ",
      rating: 5, occurred_at: Time.current
    )

    result = BrewGrinderReminder.new(
      workspace:, user: users(:one), method: "espresso", beans: [ bean ]
    ).call

    assert_equal chosen, result.best_for(bean).brew
  end

  test "bounds best references in PostgreSQL to one ordered brew per available bean" do
    workspace = workspaces(:household)
    available_beans = [ beans(:open_household), beans(:second_open_household) ]
    grinder = equipment(:household_grinder)
    selected = create_espresso(
      workspace:, user: users(:one), bean: available_beans.second, grinder:,
      setting: "selected", rating: 5, occurred_at: 2.days.ago
    )
    3.times do |index|
      create_espresso(
        workspace:, user: users(:one), bean: available_beans.second, grinder:,
        setting: "lower #{index}", rating: 4, occurred_at: index.hours.ago
      )
    end

    sql = capture_sql do
      @bounded_result = BrewGrinderReminder.new(
        workspace:, user: users(:one), method: "espresso", beans: available_beans
      ).call
    end
    best_query = sql.find { |statement| statement.include?("DISTINCT ON") }

    assert best_query, "expected a DISTINCT ON query, got:\n#{sql.join("\n")}"
    assert_match(/DISTINCT ON \(brews\.bean_id\)/, best_query)
    assert_match(/brews\.rating DESC/, best_query)
    assert_match(/brews\.occurred_at DESC NULLS LAST/, best_query)
    assert_match(/brews\.created_at DESC NULLS LAST/, best_query)
    assert_operator @bounded_result.best_by_bean_id.size, :<=, available_beans.size
    assert_equal selected, @bounded_result.best_for(available_beans.second).brew
  end

  test "uses created at as the isolated final tie breaker" do
    workspace = workspaces(:household)
    bean = beans(:second_open_household)
    occurred_at = 3.days.ago.change(usec: 0)
    older = create_espresso(
      workspace:, user: users(:one), bean:, grinder: equipment(:household_grinder),
      setting: "older", rating: 5, occurred_at:
    )
    newer = create_espresso(
      workspace:, user: users(:one), bean:, grinder: equipment(:household_grinder),
      setting: "newer", rating: 5, occurred_at:
    )
    older.update_columns(created_at: 2.hours.ago)
    newer.update_columns(created_at: 1.hour.ago)

    result = BrewGrinderReminder.new(
      workspace:, user: users(:one), method: "espresso", beans: [ bean ]
    ).call

    assert_equal newer, result.best_for(bean).brew
  end

  test "normalizes reference keys and omits beans without usable rated references" do
    workspace = workspaces(:household)
    grinder = equipment(:household_grinder)
    first = create_espresso(
      workspace:, user: users(:one), bean: beans(:open_household), grinder:,
      setting: "  Dial A  ", rating: 5, occurred_at: 2.minutes.ago
    )
    create_espresso(
      workspace:, user: users(:one), bean: beans(:second_open_household),
      grinder: nil, setting: nil, rating: 5, occurred_at: 1.minute.ago
    )

    result = BrewGrinderReminder.new(
      workspace:, user: users(:one), method: "espresso",
      beans: [ beans(:open_household), beans(:second_open_household) ]
    ).call

    assert_equal [ grinder.id.to_s, "dial a" ].to_json, result.best_for(first.bean).comparison_key
    assert_nil result.best_for(beans(:second_open_household))
  end

  test "ignores higher-rated POSIX whitespace-only settings in the PostgreSQL reference query" do
    workspace = workspaces(:household)
    bean = beans(:second_open_household)
    usable = create_espresso(
      workspace:, user: users(:one), bean:, grinder: nil,
      setting: "\tusable 7\n", rating: 4, occurred_at: 2.days.ago
    )
    create_espresso(
      workspace:, user: users(:one), bean:, grinder: nil,
      setting: " \t\n\v\f\r", rating: 5, occurred_at: 1.day.ago
    )

    result = BrewGrinderReminder.new(
      workspace:, user: users(:one), method: "espresso", beans: [ bean ]
    ).call

    assert_equal usable, result.best_for(bean).brew
    assert_equal [ bean.display_name, "usable 7" ], result.best_for(bean).display_parts
  end

  test "returns the actual workspace last bean when it is not selectable" do
    workspace = workspaces(:household)
    closed_bean = beans(:open_household)
    closed_bean.update!(remaining_grams: 0)
    brews(:morning_espresso).update!(occurred_at: 1.minute.ago)

    result = BrewGrinderReminder.new(
      workspace:, user: users(:one), method: "espresso",
      beans: [ beans(:second_open_household) ]
    ).call

    assert_equal closed_bean, result.last_bean
    assert_equal closed_bean.id, result.last_bean_id
    assert_equal brews(:morning_espresso), result.previous.brew
  end

  test "keeps archived grinders and deleted grinder settings presentation safe" do
    workspace = workspaces(:household)
    bean = beans(:second_open_household)
    archived_grinder = workspace.equipment.create!(name: "Archived Grinder", kind: "grinder", archived_at: 1.day.ago)
    archived_brew = create_espresso(
      workspace:, user: users(:one), bean:, grinder: archived_grinder,
      setting: "archive 4", rating: 5, occurred_at: 2.days.ago
    )

    archived_result = BrewGrinderReminder.new(
      workspace:, user: users(:one), method: "espresso", beans: [ bean ]
    ).call
    assert_equal [ bean.display_name, archived_grinder.name, "archive 4" ],
      archived_result.best_for(bean).display_parts

    archived_grinder.destroy_with_history!
    archived_brew.reload
    deleted_result = BrewGrinderReminder.new(
      workspace:, user: users(:one), method: "espresso", beans: [ bean ]
    ).call

    assert_nil archived_brew.grinder
    assert_equal [ bean.display_name, "archive 4" ], deleted_result.best_for(bean).display_parts
  end

  private
    def capture_sql
      statements = []
      callback = lambda do |_name, _started, _finished, _unique_id, payload|
        next if payload[:cached] || payload[:name] == "SCHEMA"

        statements << payload[:sql].squish
      end

      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { yield }
      statements
    end

    def create_espresso(workspace:, user:, bean:, grinder:, setting:, rating:, occurred_at:)
      workspace.brews.create!(
        user:,
        bean:,
        grinder:,
        machine: workspace.equipment.machine.first,
        method: "espresso",
        occurred_at:,
        bean_weight_grams: 1,
        grind_setting: setting,
        rating:
      )
    end
end
