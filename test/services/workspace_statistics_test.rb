require "test_helper"

class WorkspaceStatisticsTest < ActiveSupport::TestCase
  test "builds workspace scoped coffee statistics" do
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
