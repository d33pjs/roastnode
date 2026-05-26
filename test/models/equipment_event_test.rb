require "test_helper"

class EquipmentEventTest < ActiveSupport::TestCase
  test "is valid with affected workspace equipment" do
    event = EquipmentEvent.new(
      workspace: workspaces(:household),
      user: users(:one),
      event_type: "grinder_cleaning",
      occurred_at: Time.current,
      equipment: [ equipment(:household_grinder) ]
    )

    assert event.valid?
  end

  test "requires affected equipment" do
    event = EquipmentEvent.new(
      workspace: workspaces(:household),
      user: users(:one),
      event_type: "other",
      occurred_at: Time.current
    )

    assert_not event.valid?
    assert_includes event.errors[:equipment], "must include at least one item"
  end

  test "rejects equipment from another workspace" do
    event = EquipmentEvent.new(
      workspace: workspaces(:household),
      user: users(:one),
      event_type: "grinder_cleaning",
      occurred_at: Time.current,
      equipment: [ equipment(:other_workspace_grinder) ]
    )

    assert_not event.valid?
    assert_includes event.errors[:equipment], "must belong to the workspace"
  end
end
