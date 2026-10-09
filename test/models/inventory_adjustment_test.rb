require "test_helper"

class InventoryAdjustmentTest < ActiveSupport::TestCase
  test "weighing sets inventory and records only the difference from current inventory" do
    bean = beans(:open_household)
    adjustment = bean.inventory_adjustments.build(workspace: bean.workspace, user: users(:one),
      reason: "manual", adjustment_mode: "set_remaining", target_remaining_grams: "12.5")
    Bean.find(bean.id).update!(remaining_grams: 140)

    assert adjustment.save_with_inventory_update
    assert_equal BigDecimal("12.5"), bean.reload.remaining_grams
    assert_equal BigDecimal("-127.5"), adjustment.delta_grams
  end

  test "weighing unchanged inventory succeeds without a ledger entry" do
    bean = beans(:open_household)
    adjustment = bean.inventory_adjustments.build(workspace: bean.workspace, user: users(:one),
      reason: "manual", adjustment_mode: "set_remaining", target_remaining_grams: "150")
    assert_no_difference -> { InventoryAdjustment.count } do
      assert adjustment.save_with_inventory_update
    end
  end

  test "weighing rejects negative malformed and missing targets" do
    bean = beans(:open_household)
    [ "-1", "oops", "", "NaN", "Infinity" ].each do |target|
      adjustment = bean.inventory_adjustments.build(workspace: bean.workspace, user: users(:one),
        reason: "manual", adjustment_mode: "set_remaining", target_remaining_grams: target)
      assert_not adjustment.save_with_inventory_update, target
      assert_equal 150.to_d, bean.reload.remaining_grams
    end
  end

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
