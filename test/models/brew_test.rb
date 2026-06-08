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

  test "rejects recipe from another workspace" do
    brew = workspaces(:household).brews.new(
      user: users(:one),
      bean: beans(:open_household),
      recipe: recipes(:other_workspace_recipe),
      bean_weight_grams: 18
    )

    assert_not brew.valid?
    assert_includes brew.errors[:recipe], "must belong to the workspace"
  end

  test "rejects brewer from another workspace" do
    other_brewer = workspaces(:other_household).equipment.create!(name: "Other Brewer", kind: "brewer")
    brew = workspaces(:household).brews.new(
      user: users(:one),
      bean: beans(:open_household),
      brewer: other_brewer,
      bean_weight_grams: 18
    )

    assert_not brew.valid?
    assert_includes brew.errors[:base], "Other Brewer must belong to the workspace"
  end

  test "rejects non brewer equipment assigned as brewer" do
    brew = workspaces(:household).brews.new(
      user: users(:one),
      bean: beans(:open_household),
      brewer: equipment(:household_machine),
      bean_weight_grams: 18
    )

    assert_not brew.valid?
    assert_includes brew.errors[:brewer], "must be a brewer"
  end

  test "rating accepts blank and one through five only" do
    brew = brews(:morning_espresso)

    [ nil, 1, 2, 3, 4, 5 ].each do |rating|
      brew.rating = rating
      assert brew.valid?, "expected rating #{rating.inspect} to be valid"
    end

    [ 0, 6, 2.5, "bad" ].each do |rating|
      brew.rating = rating
      assert_not brew.valid?, "expected rating #{rating.inspect} to be invalid"
    end
  end

  test "updating brew weight adjusts inventory by delta" do
    brew = brews(:morning_espresso)
    bean = beans(:open_household)

    brew.update_with_inventory_correction!(
      { bean_weight_grams: 20, beverage_grams: 42 },
      preparation_tools: brew.preparation_tools
    )

    assert_equal 148.to_d, bean.reload.remaining_grams
    assert_equal(-20.to_d, brew.inventory_adjustment.reload.delta_grams)
    assert_equal bean, brew.inventory_adjustment.bean
  end

  test "changing brew bean returns inventory to old bean and deducts new bean" do
    brew = brews(:morning_espresso)
    old_bean = beans(:open_household)
    new_bean = beans(:second_open_household)

    brew.update_with_inventory_correction!(
      { bean: new_bean, bean_weight_grams: 21 },
      preparation_tools: brew.preparation_tools
    )

    assert_equal 168.to_d, old_bean.reload.remaining_grams
    assert_equal 199.to_d, new_bean.reload.remaining_grams
    assert_equal new_bean, brew.reload.bean
    assert_equal new_bean, brew.inventory_adjustment.reload.bean
    assert_equal(-21.to_d, brew.inventory_adjustment.delta_grams)
  end

  test "updating brew replaces preparation tool snapshots" do
    brew = brews(:morning_espresso)

    brew.update_with_inventory_correction!(
      { beverage_grams: 43 },
      preparation_tools: [ preparation_tools(:puck_screen) ]
    )

    assert_equal [ "Puck screen" ], brew.brew_preparation_tools.order(:position).pluck(:tool_name)
  end

  test "destroying brew reverses inventory and removes adjustment" do
    brew = brews(:morning_espresso)
    bean = beans(:open_household)

    assert_difference -> { Brew.count }, -1 do
      assert_difference -> { InventoryAdjustment.count }, -1 do
        brew.destroy_with_inventory_reversal!
      end
    end

    assert_equal 168.to_d, bean.reload.remaining_grams
  end
end
