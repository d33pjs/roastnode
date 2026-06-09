require "test_helper"

class ExternalCoffeeTest < ActiveSupport::TestCase
  test "creates workspace private external coffee without inventory movement" do
    bean = beans(:open_household)
    original_remaining = bean.remaining_grams

    assert_no_difference -> { InventoryAdjustment.count } do
      coffee = workspaces(:household).external_coffees.create!(
        user: users(:one),
        drink_type: "Flat White",
        drink_size: "medium",
        place_name: "Local Shop",
        place_location: "Cologne",
        price_cents: 450,
        currency: "eur",
        acidity_balance: "balanced",
        intensity: "strong",
        rating: 4
      )

      assert_equal "EUR", coffee.currency
      assert_predicate coffee.occurred_at, :present?
    end

    assert_equal original_remaining, bean.reload.remaining_grams
  end

  test "requires only drink type beyond workspace and user" do
    coffee = workspaces(:household).external_coffees.new(user: users(:one))

    assert_not coffee.valid?
    assert_includes coffee.errors[:drink_type], "can't be blank"

    coffee.drink_type = "Americano"

    assert_predicate coffee, :valid?
  end

  test "rejects user outside workspace" do
    outsider = User.create!(email_address: "outsider@example.com", password: "password")

    coffee = workspaces(:household).external_coffees.new(user: outsider, drink_type: "Espresso")

    assert_not coffee.valid?
    assert_includes coffee.errors[:user], "must belong to the workspace"
  end
end
