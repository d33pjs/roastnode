require "test_helper"

class WorkspaceStatisticsTest < ActiveSupport::TestCase
  test "builds workspace scoped coffee statistics" do
    travel_to Time.zone.local(2026, 5, 27, 12, 0, 0) do
      workspace = workspaces(:household)
      brews(:morning_espresso).update!(occurred_at: Time.zone.local(2026, 5, 26, 8, 0, 0))
      workspace.brews.create!(
        user: users(:one),
        bean: beans(:second_open_household),
        grinder: equipment(:household_grinder),
        machine: equipment(:household_machine),
        occurred_at: Time.zone.local(2026, 5, 26, 9, 30, 0),
        bean_weight_grams: 20,
        ground_weight_grams: 20.4,
        dose_grams: 20,
        beverage_grams: 50,
        total_time_seconds: 32,
        channeling: true,
        taste_balance: "bitter",
        rating: 3
      )

      statistics = WorkspaceStatistics.new(workspace:).call

      assert_equal 2, statistics[:totals][:total_brews]
      assert_equal 38.to_d, statistics[:totals][:total_bean_weight_grams]
      assert_equal 2, statistics[:totals][:open_beans]
      assert_equal 1290, statistics[:totals][:known_spend_cents]
      assert_equal 93, statistics[:totals][:average_known_brew_cost_cents]
      assert_equal 1, statistics[:totals][:priced_brew_count]

      assert_equal({ name: "Niche Zero", count: 2 }, statistics[:leaders][:grinder])
      assert_equal({ name: "Bianca", count: 2 }, statistics[:leaders][:machine])

      assert_equal 50, statistics[:rates][:channeling_percent]
      assert_equal({ "neutral" => 1, "bitter" => 1 }, statistics[:distributions][:taste_balance])
      assert_equal({ "normal" => 1, "exchange" => 1 }, statistics[:distributions][:retention_marker])

      statistics_date = Date.new(2026, 5, 26)
      assert_equal 2, statistics[:series][:brews_by_day].detect { |point| point[:date] == statistics_date }[:count]
      assert_equal 38.to_d, statistics[:series][:consumption_by_day].detect { |point| point[:date] == statistics_date }[:grams]

      assert_includes statistics[:breakdowns][:roasters], { label: "Good Coffee", count: 1 }
      assert_includes statistics[:breakdowns][:origins], { label: "Colombia", count: 1 }
      assert_includes statistics[:breakdowns][:processes], { label: "natural", count: 2 }
    end
  end

  test "filters brew statistics to the requested date range while keeping bean catalog current" do
    workspace = workspaces(:household)
    brews(:morning_espresso).update!(occurred_at: Time.zone.local(2026, 5, 26, 8, 0, 0))
    workspace.brews.create!(
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
      retention_marker: "exchange",
      rating: 3
    )

    statistics = WorkspaceStatistics.new(
      workspace:,
      start_date: Date.new(2026, 5, 26),
      end_date: Date.new(2026, 5, 26)
    ).call

    assert_equal 1, statistics[:totals][:total_brews]
    assert_equal 18.to_d, statistics[:totals][:total_bean_weight_grams]
    assert_equal 2, statistics[:totals][:open_beans]
    assert_equal 1290, statistics[:totals][:known_spend_cents]
    assert_equal 93, statistics[:totals][:average_known_brew_cost_cents]

    assert_equal({ name: "Niche Zero", count: 1 }, statistics[:leaders][:grinder])
    assert_equal 0, statistics[:rates][:channeling_percent]
    assert_equal({ "neutral" => 1 }, statistics[:distributions][:taste_balance])
    assert_equal({ "normal" => 1 }, statistics[:distributions][:retention_marker])

    assert_equal [ Date.new(2026, 5, 26) ], statistics[:series][:brews_by_day].map { |point| point[:date] }
    assert_equal 1, statistics[:series][:brews_by_day].first[:count]
    assert_equal 18.to_d, statistics[:series][:consumption_by_day].first[:grams]

    assert_includes statistics[:breakdowns][:roasters], { label: "North Star", count: 1 }
  end

  test "includes quick drip in shared totals but excludes from espresso specific channeling and retention" do
    workspace = workspaces(:household)
    brews(:morning_espresso).update!(
      occurred_at: Time.zone.local(2026, 5, 26, 8, 0, 0),
      channeling: false,
      retention_marker: "normal"
    )
    quick_drip = workspace.brews.create!(
      user: users(:one),
      method: "quick_drip",
      bean: beans(:second_open_household),
      brewer: equipment(:household_brewer),
      machine_cups: 6,
      coffee_spoons: 6,
      occurred_at: Time.zone.local(2026, 5, 26, 9, 0, 0),
      channeling: true,
      taste_balance: "bitter"
    )
    quick_drip.update_columns(retention_marker: "retention")

    statistics = WorkspaceStatistics.new(
      workspace:,
      start_date: Date.new(2026, 5, 26),
      end_date: Date.new(2026, 5, 26)
    ).call

    assert_equal 2, statistics[:totals][:total_brews]
    assert_equal 48.to_d, statistics[:totals][:total_bean_weight_grams]
    assert_equal 1, statistics[:rates][:channeling_brew_count]
    assert_equal 0, statistics[:rates][:channeling_percent]
    assert_equal({ "normal" => 1 }, statistics[:distributions][:retention_marker])
    assert_equal({ "espresso" => 1, "quick_drip" => 1 }, statistics[:distributions][:method])
  end

  test "filters every brew aggregate by logger while keeping bean catalog totals current" do
    travel_to Time.zone.local(2026, 5, 27, 12, 0, 0) do
      workspace = workspaces(:household)
      owner = users(:one)
      member = users(:two)
      brews(:morning_espresso).update!(
        user: owner,
        recipient_kind: "self",
        occurred_at: Time.zone.local(2026, 5, 26, 8, 0, 0),
        taste_balance: "neutral",
        channeling: false
      )
      create_statistics_brew!(
        workspace:,
        user: member,
        recipient_kind: "self",
        bean_weight_grams: 20,
        taste_balance: "bitter",
        channeling: true
      )

      statistics = WorkspaceStatistics.new(
        workspace:,
        logger_id: member.id
      ).call

      assert_equal 1, statistics[:totals][:total_brews]
      assert_equal 20.to_d, statistics[:totals][:total_bean_weight_grams]
      assert_nil statistics[:totals][:average_known_brew_cost_cents]
      assert_equal 0, statistics[:totals][:priced_brew_count]
      assert_equal({ "bitter" => 1 }, statistics[:distributions][:taste_balance])
      assert_equal({ "espresso" => 1 }, statistics[:distributions][:method])
      assert_equal 1, statistics[:rates][:channeling_brew_count]
      assert_equal 100, statistics[:rates][:channeling_percent]
      assert_equal({ name: "Niche Zero", count: 1 }, statistics[:leaders][:grinder])
      assert_equal 1, statistics[:series][:brews_by_day].sum { |point| point[:count] }

      assert_equal 2, statistics[:totals][:open_beans]
      assert_equal 1290, statistics[:totals][:known_spend_cents]
      assert_includes statistics[:breakdowns][:roasters], { label: "North Star", count: 1 }
    end
  end

  test "filters self and guest recipients independently" do
    travel_to Time.zone.local(2026, 5, 27, 12, 0, 0) do
      workspace = workspaces(:household)
      brews(:morning_espresso).update!(
        recipient_kind: "self",
        occurred_at: Time.zone.local(2026, 5, 26, 8, 0, 0)
      )
      create_statistics_brew!(
        workspace:,
        user: users(:two),
        recipient_kind: "guest",
        bean_weight_grams: 20
      )

      self_statistics = WorkspaceStatistics.new(
        workspace:,
        recipient_filter: "self"
      ).call
      guest_statistics = WorkspaceStatistics.new(
        workspace:,
        recipient_filter: "guests"
      ).call

      assert_equal 1, self_statistics[:totals][:total_brews]
      assert_equal 18.to_d, self_statistics[:totals][:total_bean_weight_grams]
      assert_equal 1, guest_statistics[:totals][:total_brews]
      assert_equal 20.to_d, guest_statistics[:totals][:total_bean_weight_grams]
    end
  end

  test "specific recipient includes their self brews and household member servings" do
    travel_to Time.zone.local(2026, 5, 27, 12, 0, 0) do
      workspace = workspaces(:household)
      petra = users(:two)
      brews(:morning_espresso).update!(
        user: users(:one),
        recipient_kind: "household_member",
        recipient_user: petra,
        occurred_at: Time.zone.local(2026, 5, 26, 8, 0, 0)
      )
      create_statistics_brew!(
        workspace:,
        user: petra,
        recipient_kind: "self",
        bean_weight_grams: 20
      )
      create_statistics_brew!(
        workspace:,
        user: users(:one),
        recipient_kind: "guest",
        occurred_at: Time.zone.local(2026, 5, 26, 11, 0, 0),
        bean_weight_grams: 22
      )

      statistics = WorkspaceStatistics.new(
        workspace:,
        recipient_filter: "user:#{petra.id}"
      ).call

      assert_equal 2, statistics[:totals][:total_brews]
      assert_equal 38.to_d, statistics[:totals][:total_bean_weight_grams]
      assert_equal 2, statistics[:series][:brews_by_day].sum { |point| point[:count] }
    end
  end

  test "combines logger recipient and inclusive date filters across all brew metrics" do
    workspace = workspaces(:household)
    logger = users(:one)
    recipient = users(:two)
    included = brews(:morning_espresso)
    included.update!(
      user: logger,
      recipient_kind: "household_member",
      recipient_user: recipient,
      occurred_at: Time.zone.local(2026, 5, 26, 8, 0, 0),
      taste_balance: "neutral",
      channeling: false
    )
    create_statistics_brew!(
      workspace:,
      user: users(:two),
      recipient_kind: "self",
      occurred_at: Time.zone.local(2026, 5, 26, 9, 0, 0),
      bean_weight_grams: 20
    )
    create_statistics_brew!(
      workspace:,
      user: logger,
      recipient_kind: "household_member",
      recipient_user: recipient,
      occurred_at: Time.zone.local(2026, 5, 20, 9, 0, 0),
      bean_weight_grams: 22
    )

    statistics = WorkspaceStatistics.new(
      workspace:,
      start_date: Date.new(2026, 5, 26),
      end_date: Date.new(2026, 5, 26),
      logger_id: logger.id,
      recipient_filter: "user:#{recipient.id}"
    ).call

    assert_equal 1, statistics[:totals][:total_brews]
    assert_equal 18.to_d, statistics[:totals][:total_bean_weight_grams]
    assert_equal 93, statistics[:totals][:average_known_brew_cost_cents]
    assert_equal 1, statistics[:totals][:priced_brew_count]
    assert_equal({ "neutral" => 1 }, statistics[:distributions][:taste_balance])
    assert_equal({ "normal" => 1 }, statistics[:distributions][:retention_marker])
    assert_equal({ "espresso" => 1 }, statistics[:distributions][:method])
    assert_equal 0, statistics[:rates][:channeling_percent]
    assert_equal({ name: "Niche Zero", count: 1 }, statistics[:leaders][:grinder])
    assert_equal({ name: "Bianca", count: 1 }, statistics[:leaders][:machine])
    assert_equal [ 1 ], statistics[:series][:brews_by_day].map { |point| point[:count] }
    assert_equal [ 18.to_d ], statistics[:series][:consumption_by_day].map { |point| point[:grams] }
  end

  private
    def create_statistics_brew!(
      workspace: workspaces(:household),
      user: users(:one),
      recipient_kind: "self",
      recipient_user: nil,
      occurred_at: Time.zone.local(2026, 5, 26, 10, 0, 0),
      bean: beans(:second_open_household),
      grinder: equipment(:household_grinder),
      machine: equipment(:household_machine),
      bean_weight_grams: 20,
      taste_balance: "bitter",
      channeling: true
    )
      workspace.brews.create!(
        user:,
        recipient_kind:,
        recipient_user:,
        bean:,
        grinder:,
        machine:,
        occurred_at:,
        bean_weight_grams:,
        ground_weight_grams: bean_weight_grams,
        dose_grams: bean_weight_grams,
        beverage_grams: 40,
        total_time_seconds: 30,
        taste_balance:,
        channeling:,
        rating: 4
      )
    end
end
