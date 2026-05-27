require "test_helper"

class InventoryAdjustmentTest < ActiveSupport::TestCase
  test "manual adjustment updates bean remaining inventory" do
    bean = beans(:open_household)

    adjustment = bean.inventory_adjustments.build(
      workspace: bean.workspace,
      user: users(:one),
      delta_grams: 25.5,
      reason: "manual",
      note: "Found a sample dose."
    )

    assert_difference -> { InventoryAdjustment.manual.count }, 1 do
      assert adjustment.save_with_inventory_update
    end

    assert_equal 175.5.to_d, bean.reload.remaining_grams
    assert_equal "manual", adjustment.reason
  end

  test "manual adjustment does not make remaining inventory negative" do
    bean = beans(:open_household)

    adjustment = bean.inventory_adjustments.build(
      workspace: bean.workspace,
      user: users(:one),
      delta_grams: -500,
      reason: "manual"
    )

    assert adjustment.save_with_inventory_update

    assert_equal 0.to_d, bean.reload.remaining_grams
    assert_equal "used_up", bean.bag_status
  end
end
