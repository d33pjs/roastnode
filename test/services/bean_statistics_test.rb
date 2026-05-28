require "test_helper"

class BeanStatisticsTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  test "builds bean scoped analytics" do
    travel_to Time.zone.local(2026, 5, 26, 12, 0, 0) do
      bean = beans(:open_household)

      bean.brews.create!(
        workspace: bean.workspace,
        user: users(:one),
        grinder: equipment(:household_grinder),
        machine: equipment(:household_machine),
        occurred_at: Time.zone.local(2026, 5, 24, 9, 30, 0),
        bean_weight_grams: 18,
        ground_weight_grams: 17.6,
        dose_grams: 18,
        beverage_grams: 42,
        total_time_seconds: 30,
        grind_setting: "11",
        taste_balance: "sour",
        channeling: true,
        rating: 5
      )

      bean.brews.create!(
        workspace: bean.workspace,
        user: users(:one),
        grinder: equipment(:household_grinder),
        machine: equipment(:household_machine),
        occurred_at: Time.zone.local(2026, 5, 25, 9, 30, 0),
        bean_weight_grams: 19,
        ground_weight_grams: 19.4,
        dose_grams: 19,
        beverage_grams: 46,
        total_time_seconds: 34,
        grind_setting: "10",
        taste_balance: "bitter",
        channeling: false,
        rating: 3
      )

      statistics = BeanStatistics.new(bean:).call

      assert_equal 3, statistics[:totals][:brew_count]
      assert_equal 55.to_d, statistics[:totals][:total_bean_weight_grams]
      assert_equal 45, statistics[:totals][:remaining_percent]
      assert_equal 16, statistics[:totals][:open_age_days]
      assert_equal 4, statistics[:averages][:rating]
      assert_equal 42.7.to_d, statistics[:averages][:beverage_grams]
      assert_equal 31, statistics[:averages][:total_time_seconds]
      assert_equal 1, statistics[:rates][:channeling_count]
      assert_equal 33, statistics[:rates][:channeling_percent]
      assert_equal({ "neutral" => 1, "sour" => 1, "bitter" => 1 }, statistics[:distributions][:taste_balance])
      assert_equal({ "normal" => 1, "retention" => 1, "exchange" => 1 }, statistics[:distributions][:retention_marker])

      assert_equal [ 5, 4, 3 ], statistics[:best_brews].map(&:rating)
      assert_equal [ "12", "10", "11" ], statistics[:recent_brews].map(&:grind_setting)
    end
  end

  test "filters brew-derived bean analytics by date range while keeping inventory current" do
    travel_to Time.zone.local(2026, 5, 26, 12, 0, 0) do
      bean = beans(:open_household)
      brews(:morning_espresso).update!(occurred_at: Time.zone.local(2026, 5, 26, 8, 0, 0))
      bean.brews.create!(
        workspace: bean.workspace,
        user: users(:one),
        grinder: equipment(:household_grinder),
        machine: equipment(:household_machine),
        occurred_at: Time.zone.local(2026, 5, 20, 9, 30, 0),
        bean_weight_grams: 20,
        ground_weight_grams: 20.4,
        dose_grams: 20,
        beverage_grams: 50,
        total_time_seconds: 32,
        grind_setting: "10",
        taste_balance: "bitter",
        channeling: true,
        rating: 3
      )

      statistics = BeanStatistics.new(
        bean:,
        start_date: Date.new(2026, 5, 26),
        end_date: Date.new(2026, 5, 26)
      ).call

      assert_equal 1, statistics[:totals][:brew_count]
      assert_equal 18.to_d, statistics[:totals][:total_bean_weight_grams]
      assert_equal 52, statistics[:totals][:remaining_percent]
      assert_equal 0, statistics[:rates][:channeling_count]
      assert_equal 0, statistics[:rates][:channeling_percent]
      assert_equal({ "neutral" => 1 }, statistics[:distributions][:taste_balance])
      assert_equal [ 4 ], statistics[:best_brews].map(&:rating)
      assert_equal [ "12" ], statistics[:recent_brews].map(&:grind_setting)
    end
  end

  test "adds finished bag totals and grind setting distribution" do
    bean = workspaces(:household).beans.create!(
      name: "Finished Stats",
      bag_size_grams: 250,
      remaining_grams: 250,
      opened_on: Date.new(2026, 5, 10)
    )
    grinder = equipment(:household_grinder)
    machine = equipment(:household_machine)

    create_brew(bean:, grinder:, machine:, grind_setting: "10")
    create_brew(bean:, grinder:, machine:, grind_setting: "10")
    create_brew(bean:, grinder:, machine:, grind_setting: "1/3,0")
    create_brew(bean:, grinder:, machine:, grind_setting: "")
    bean.update!(remaining_grams: 14, finished_at: Time.zone.local(2026, 5, 23, 9))

    statistics = BeanStatistics.new(bean:).call

    assert_equal 236.to_d, statistics[:totals][:finished_used_grams]
    assert_equal 13, statistics[:totals][:finished_open_days]
    assert_equal BigDecimal("18.15"), statistics[:totals][:finished_grams_per_day]
    assert_equal({ "10" => 2, "1/3,0" => 1 }, statistics[:distributions][:grind_setting])
  end

  private
    def create_brew(bean:, grinder:, machine:, grind_setting:)
      bean.workspace.brews.create!(
        workspace: bean.workspace,
        user: users(:one),
        bean:,
        grinder:,
        machine:,
        occurred_at: Time.zone.local(2026, 5, 24, 9, 30, 0),
        bean_weight_grams: 18,
        ground_weight_grams: 18,
        dose_grams: 18,
        beverage_grams: 45,
        total_time_seconds: 28,
        grind_setting:
      )
    end
end
