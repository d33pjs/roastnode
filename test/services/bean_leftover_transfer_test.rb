require "test_helper"

class BeanLeftoverTransferTest < ActiveSupport::TestCase
  setup do
    @source = beans(:open_household)
    @source.update!(remaining_grams: 14)
    @destination = @source.duplicate_for_new_bag!
  end

  test "moves leftovers atomically opens stock and preserves bag sizes and used grams" do
    assert_difference -> { InventoryAdjustment.count }, 2 do
      assert_equal @destination, transfer(@destination)
    end
    assert_equal 0.to_d, @source.reload.remaining_grams
    assert @source.finished?
    assert_equal 264.to_d, @destination.reload.remaining_grams
    assert @destination.open?
    assert_equal 250.to_d, @destination.bag_size_grams
    assert_equal 236.to_d, @source.finished_used_grams
    assert_equal 0.to_d, @destination.finished_used_grams
    assert_equal 0.to_d, InventoryAdjustment.where(reason: "transfer").sum(:delta_grams)
    assert_no_difference -> { InventoryAdjustment.count } do
      assert_raises(BeanLeftoverTransfer::InvalidTransfer) { transfer(@destination) }
    end
  end

  test "can duplicate a new bag and can recover leftovers from a finished source" do
    @source.finish!
    assert_difference -> { Bean.count }, 1 do
      destination = transfer("new")
      assert_equal @source, destination.duplicated_from_bean
      assert_equal 264.to_d, destination.remaining_grams
      assert destination.open?
    end
  end

  test "rejects self foreign mismatched closed and different grind destinations" do
    foreign = beans(:other_workspace_open)
    mismatched = beans(:second_open_household)
    closed = @source.duplicate_for_new_bag!
    closed.finish!
    ground = @source.duplicate_for_new_bag!
    ground.update!(grind_state: "pre_ground")
    [ @source, foreign, mismatched, closed, ground ].each do |destination|
      assert_no_difference [ -> { InventoryAdjustment.count }, -> { ActivityEvent.count } ] do
        assert_raises(BeanLeftoverTransfer::InvalidTransfer, ActiveRecord::RecordNotFound) { transfer(destination) }
      end
      assert_equal 14.to_d, @source.reload.remaining_grams
    end
  end

  test "matches independently entered beans by normalized name and roaster" do
    @destination.update!(coffee_history: beans(:second_open_household).coffee_history,
      name: " house   BLEND ", roaster_name: " good COFFEE ")
    assert_includes BeanLeftoverTransfer.destinations(@source), @destination
    transfer(@destination)
    assert_equal 264.to_d, @destination.reload.remaining_grams
  end

  test "activity failure rolls back both balances lifecycle and ledger" do
    with_stubbed_singleton_method(Activity::Emitter, :record!, ->(**) { raise "activity failed" }) do
      assert_no_difference -> { InventoryAdjustment.count } do
        assert_raises(RuntimeError) { transfer(@destination) }
      end
    end
    assert_equal 14.to_d, @source.reload.remaining_grams
    assert_equal 250.to_d, @destination.reload.remaining_grams
    assert @source.open?
    assert @destination.stock?
  end

  private
    def transfer(destination)
      BeanLeftoverTransfer.new(source: @source, destination: destination == "new" ? "new" : destination.id,
        user: users(:one)).call
    end
end
