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

  test "does not suggest before the current bean has a calibration brew" do
    bean = beans(:second_open_household)
    workspace = bean.workspace
    grinder = workspace.equipment.create!(name: "Eureka", kind: "grinder")

    create_history_brew(workspace:, grinder:, grind_setting: "1/4,75", dose: 18, beverage: 45, total_time: 28, rating: 5)
    create_history_brew(workspace:, grinder:, grind_setting: "1/5,00", dose: 18, beverage: 44, total_time: 29, rating: 4)

    assert_empty GrinderSettingSuggestion.new(bean:).call
  end

  test "suggests a relative coarser adjustment from a slow first brew" do
    bean = beans(:second_open_household)
    workspace = bean.workspace
    grinder = workspace.equipment.create!(name: "Eureka", kind: "grinder")
    other_grinder = workspace.equipment.create!(name: "Other test grinder", kind: "grinder")

    create_history_brew(workspace:, grinder:, grind_setting: "1/5,25", dose: 18, beverage: 45, total_time: 28, rating: 5)
    create_history_brew(workspace:, grinder:, grind_setting: "1/5,50", dose: 18, beverage: 44, total_time: 29, rating: 4)
    create_history_brew(workspace:, grinder:, grind_setting: "a little finer", dose: 18, beverage: 45, total_time: 28, rating: 5)
    create_history_brew(workspace:, grinder: other_grinder, grind_setting: "1/2,00", dose: 18, beverage: 45, total_time: 28, rating: 5)
    calibration_brew = create_history_brew(workspace:, bean:, grinder:, grind_setting: "1/3,0", dose: 17.9, beverage: 45.3, total_time: 42, rating: nil)

    suggestion = GrinderSettingSuggestion.new(bean:).call.detect { |result| result[:grinder] == grinder }

    assert_equal calibration_brew, suggestion[:calibration_brew]
    assert_equal "1/3,0", suggestion[:calibration_setting]
    assert_equal "1/3,75", suggestion[:suggested_setting]
    assert_equal :too_slow, suggestion[:time_status]
    assert_equal 2, suggestion[:comparable_brew_count]
    assert_equal 2.53.to_d, suggestion[:calibration_ratio]
    assert_equal 42, suggestion[:calibration_total_time_seconds]
    assert_equal 4.5.to_d, suggestion[:average_rating]
  end

  test "uses the known dial step when history settings are sparse" do
    bean = beans(:second_open_household)
    workspace = bean.workspace
    grinder = workspace.equipment.create!(name: "Sparse Eureka", kind: "grinder")

    create_history_brew(workspace:, grinder:, grind_setting: "1/5,25", dose: 18, beverage: 45, total_time: 28, rating: 5)
    create_history_brew(workspace:, grinder:, grind_setting: "1/5,25", dose: 18, beverage: 45, total_time: 29, rating: 4)
    create_history_brew(workspace:, bean:, grinder:, grind_setting: "1/3,0", dose: 17.9, beverage: 45.3, total_time: 42, rating: nil)

    suggestion = GrinderSettingSuggestion.new(bean:).call.detect { |result| result[:grinder] == grinder }

    assert_equal "1/3,75", suggestion[:suggested_setting]
  end

  test "prefers target ratio and total time over high rated outliers" do
    bean = beans(:second_open_household)
    workspace = bean.workspace
    grinder = workspace.equipment.create!(name: "Target grinder", kind: "grinder")

    create_history_brew(workspace:, grinder:, grind_setting: "1/8,00", dose: 18, beverage: 45, total_time: 50, rating: 5)
    create_history_brew(workspace:, grinder:, grind_setting: "1/4,75", dose: 18, beverage: 45, total_time: 28, rating: 3)
    create_history_brew(workspace:, bean:, grinder:, grind_setting: "1/3,00", dose: 18, beverage: 45, total_time: 28, rating: nil)

    suggestion = GrinderSettingSuggestion.new(bean:).call.detect { |result| result[:grinder] == grinder }

    assert_equal "1/3,00", suggestion[:suggested_setting]
    assert_equal :on_target, suggestion[:time_status]
  end

  private
    def create_history_brew(workspace:, grinder:, grind_setting:, dose:, beverage:, total_time:, rating:, bean: beans(:open_household))
      workspace.brews.create!(
        user: users(:one),
        bean:,
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
