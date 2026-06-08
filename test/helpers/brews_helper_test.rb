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

  test "quick drip taste labels use weak balanced harsh" do
    assert_equal "Weak", brew_taste_label("sour", method: "quick_drip")
    assert_equal "Balanced", brew_taste_label("neutral", method: "quick_drip")
    assert_equal "Harsh", brew_taste_label("bitter", method: "quick_drip")
  end
end
