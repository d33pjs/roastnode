require "test_helper"

class BrewTest < ActiveSupport::TestCase
  test "creating espresso brew subtracts bean inventory and records adjustment" do
    bean = beans(:open_household)

    assert_difference -> { InventoryAdjustment.count }, 1 do
      brew = workspaces(:household).brews.create!(
        user: users(:one),
        bean:,
        grinder: equipment(:household_grinder),
        machine: equipment(:household_machine),
        bean_weight_grams: 18.2,
        ground_weight_grams: 18.1,
        dose_grams: 18,
        beverage_grams: 40,
        total_time_seconds: 29
      )

      assert_equal "normal", brew.retention_marker
    end

    assert_equal 131.8.to_d, bean.reload.remaining_grams

    adjustment = InventoryAdjustment.order(:created_at).last
    assert_equal bean, adjustment.bean
    assert_equal users(:one), adjustment.user
    assert_equal "brew", adjustment.reason
    assert_equal(-18.2.to_d, adjustment.delta_grams)
  end

  test "calculates grinder retention marker" do
    brew = workspaces(:household).brews.create!(
      user: users(:one),
      bean: beans(:open_household),
      bean_weight_grams: 18.5,
      ground_weight_grams: 18.0
    )

    assert_equal "retention", brew.retention_marker
  end

  test "calculates old grounds exchange marker" do
    brew = workspaces(:household).brews.create!(
      user: users(:one),
      bean: beans(:open_household),
      bean_weight_grams: 18.0,
      ground_weight_grams: 18.4
    )

    assert_equal "exchange", brew.retention_marker
  end

  test "rejects bean from another workspace" do
    brew = workspaces(:household).brews.new(
      user: users(:one),
      bean: beans(:other_workspace_open),
      bean_weight_grams: 18
    )

    assert_not brew.valid?
    assert_includes brew.errors[:bean], "must belong to the workspace"
  end
end
