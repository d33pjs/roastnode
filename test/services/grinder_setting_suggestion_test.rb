require "test_helper"

class GrinderSettingSuggestionTest < ActiveSupport::TestCase
  test "safely parses known grinder setting formats" do
    eureka = GrinderSettingSuggestion.parse_setting("1/3,25")
    numeric = GrinderSettingSuggestion.parse_setting("12,5")

    assert_equal :dial_turns, eureka.format
    assert_equal 23.25.to_d, eureka.coordinate
    assert_equal "1/3,25", eureka.raw
    assert_equal :plain_numeric, numeric.format
    assert_equal 12.5.to_d, numeric.coordinate

    assert_nil GrinderSettingSuggestion.parse_setting(nil)
    assert_nil GrinderSettingSuggestion.parse_setting("")
    assert_nil GrinderSettingSuggestion.parse_setting("a little finer")
  end

  test "suggests from parseable same-grinder brew history only" do
    bean = beans(:second_open_household)
    workspace = bean.workspace
    grinder = workspace.equipment.create!(name: "Eureka", kind: "grinder")
    other_grinder = workspace.equipment.create!(name: "Other test grinder", kind: "grinder")

    create_history_brew(workspace:, grinder:, grind_setting: "1/4,75", dose: 18, beverage: 45, total_time: 28, rating: 5)
    create_history_brew(workspace:, grinder:, grind_setting: "1/5,00", dose: 18, beverage: 44, total_time: 29, rating: 4)
    create_history_brew(workspace:, grinder:, grind_setting: "a little finer", dose: 18, beverage: 45, total_time: 28, rating: 5)
    create_history_brew(workspace:, grinder: other_grinder, grind_setting: "1/2,00", dose: 18, beverage: 45, total_time: 28, rating: 5)

    suggestion = GrinderSettingSuggestion.new(bean:).call.detect { |result| result[:grinder] == grinder }

    assert_equal "1/4,75", suggestion[:suggested_setting]
    assert_equal 2, suggestion[:comparable_brew_count]
    assert_equal 2, suggestion[:sample_brew_count]
    assert_equal 2.47.to_d, suggestion[:average_ratio]
    assert_equal 29, suggestion[:average_total_time_seconds]
    assert_equal 4.5.to_d, suggestion[:average_rating]
  end

  test "prefers target ratio and total time over high rated outliers" do
    bean = beans(:second_open_household)
    workspace = bean.workspace
    grinder = workspace.equipment.create!(name: "Target grinder", kind: "grinder")

    create_history_brew(workspace:, grinder:, grind_setting: "1/8,00", dose: 18, beverage: 45, total_time: 50, rating: 5)
    create_history_brew(workspace:, grinder:, grind_setting: "1/4,75", dose: 18, beverage: 45, total_time: 28, rating: 3)

    suggestion = GrinderSettingSuggestion.new(bean:).call.detect { |result| result[:grinder] == grinder }

    assert_equal "1/4,75", suggestion[:suggested_setting]
  end

  private
    def create_history_brew(workspace:, grinder:, grind_setting:, dose:, beverage:, total_time:, rating:)
      workspace.brews.create!(
        user: users(:one),
        bean: beans(:open_household),
        grinder:,
        machine: equipment(:household_machine),
        occurred_at: Time.current,
        bean_weight_grams: dose,
        ground_weight_grams: dose,
        dose_grams: dose,
        beverage_grams: beverage,
        total_time_seconds: total_time,
        grind_setting:,
        rating:
      )
    end
end
