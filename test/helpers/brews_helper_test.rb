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
end
