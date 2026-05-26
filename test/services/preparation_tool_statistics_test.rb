require "test_helper"

class PreparationToolStatisticsTest < ActiveSupport::TestCase
  test "builds preparation tool scoped analytics" do
    tool = preparation_tools(:wdt)
    user = users(:one)
    bean = beans(:open_household)

    brews(:morning_espresso).update!(
      occurred_at: Time.zone.local(2026, 5, 26, 8, 0, 0),
      bean_weight_grams: 18,
      beverage_grams: 40,
      total_time_seconds: 28,
      grind_setting: "12",
      taste_balance: "neutral",
      channeling: false,
      retention_marker: "normal",
      rating: 4
    )

    create_brew_with_tool!(
      tool:,
      bean:,
      user:,
      occurred_at: Time.zone.local(2026, 5, 24, 9, 30, 0),
      bean_weight_grams: 18,
      ground_weight_grams: 17.5,
      beverage_grams: 42,
      total_time_seconds: 30,
      grind_setting: "11",
      taste_balance: "sour",
      channeling: true,
      retention_marker: "retention",
      rating: 5
    )

    create_brew_with_tool!(
      tool:,
      bean:,
      user:,
      occurred_at: Time.zone.local(2026, 5, 25, 9, 30, 0),
      bean_weight_grams: 19,
      ground_weight_grams: 19.5,
      beverage_grams: 46,
      total_time_seconds: 34,
      grind_setting: "10",
      taste_balance: "bitter",
      channeling: false,
      retention_marker: "exchange",
      rating: 3
    )

    statistics = PreparationToolStatistics.new(preparation_tool: tool).call

    assert_equal 3, statistics[:totals][:brew_count]
    assert_equal 55.to_d, statistics[:totals][:total_bean_weight_grams]
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

  private
    def create_brew_with_tool!(tool:, bean:, user:, **attributes)
      brew = bean.brews.create!(
        {
          workspace: bean.workspace,
          user:,
          grinder: equipment(:household_grinder),
          machine: equipment(:household_machine),
          ground_weight_grams: attributes.fetch(:ground_weight_grams, attributes.fetch(:bean_weight_grams)),
          dose_grams: attributes.fetch(:bean_weight_grams)
        }.merge(attributes)
      )
      brew.brew_preparation_tools.create!(
        preparation_tool: tool,
        tool_name: tool.name,
        brew_method: tool.brew_method,
        position: 0
      )
      brew
    end
end
