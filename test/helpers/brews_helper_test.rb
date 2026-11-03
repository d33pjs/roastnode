require "test_helper"

class BrewsHelperTest < ActionView::TestCase
  include ApplicationHelper

  test "quick drip estimate display uses tilde for spoon estimates" do
    brew = brews(:morning_espresso)
    brew.method = "quick_drip"
    brew.bean_weight_grams = 30
    brew.coffee_amount_source = "estimated_spoons"

    assert_equal "~30g", quick_drip_consumed_grams(brew)
  end

  test "quick drip estimate calculation shows spoon math" do
    brew = brews(:morning_espresso)
    brew.method = "quick_drip"
    brew.bean_weight_grams = 30
    brew.coffee_amount_source = "estimated_spoons"
    brew.coffee_spoons = 6
    brew.grams_per_coffee_spoon = 5

    assert_equal "6 spoons x 5g = ~30g", quick_drip_estimate_calculation(brew)
  end

  test "quick drip estimate calculation is blank for measured coffee with spoon metadata" do
    brew = brews(:morning_espresso)
    brew.method = "quick_drip"
    brew.bean_weight_grams = 28
    brew.coffee_amount_source = "measured"
    brew.coffee_spoons = 6
    brew.grams_per_coffee_spoon = 5

    assert_nil quick_drip_estimate_calculation(brew)
  end

  test "quick drip taste labels use weak balanced harsh" do
    assert_equal "Weak", brew_taste_label("sour", method: "quick_drip")
    assert_equal "Balanced", brew_taste_label("neutral", method: "quick_drip")
    assert_equal "Harsh", brew_taste_label("bitter", method: "quick_drip")
  end

  test "grinder setting last brew measurements respect number preferences and retain missing values" do
    Current.session = Session.new(user: users(:one))
    Current.user.number_format = "comma_decimal"
    rows = brew_grinder_setting_rows([
      { setting: "1/3,00", count: 2, average_rating: 4.5, rating_count: 2, occurred_at: Time.current,
        total_time_seconds: 32, dose_grams: 18.5.to_d, beverage_grams: 42.5.to_d },
      { setting: "other", count: 1, rating_count: 0, total_time_seconds: 0, dose_grams: nil, beverage_grams: nil }
    ])

    assert_equal "Total time: 32s · Beverage: 42,5g · Ratio: 1:2,3", rows.first[:last_brew]
    assert_equal "★ 4,5/5 · 2 rated", rows.first[:rating_label]
    assert_equal "Total time: 0s · Beverage: Unknown · Ratio: Unknown", rows.last[:last_brew]
    Current.user.number_format = "dot_decimal"
    assert_equal "Total time: 32s · Beverage: 42.5g · Ratio: 1:2.3", brew_grinder_setting_rows([
      { setting: "1/3,00", count: 1, rating_count: 0, total_time_seconds: 32, dose_grams: 18.5.to_d, beverage_grams: 42.5.to_d }
    ]).first[:last_brew]
  ensure
    Current.reset
  end
end
