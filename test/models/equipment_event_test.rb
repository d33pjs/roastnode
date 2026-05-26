require "test_helper"

class EquipmentEventTest < ActiveSupport::TestCase
  test "is valid with affected workspace equipment" do
    event = EquipmentEvent.new(
      workspace: workspaces(:household),
      user: users(:one),
      event_types: [ "grinder_cleaning" ],
      occurred_at: Time.current,
      equipment: [ equipment(:household_grinder) ]
    )

    assert event.valid?
  end

  test "can record multiple event types in one maintenance session" do
    event = EquipmentEvent.new(
      workspace: workspaces(:household),
      user: users(:one),
      event_types: [ "grinder_cleaning", "machine_backflush" ],
      occurred_at: Time.current,
      equipment: [ equipment(:household_grinder), equipment(:household_machine) ]
    )

    assert event.valid?
    assert_equal [ "grinder_cleaning", "machine_backflush" ], event.event_types
    assert_equal "Grinder cleaning and Machine backflush", event.event_type_summary
  end

  test "requires affected equipment" do
    event = EquipmentEvent.new(
      workspace: workspaces(:household),
      user: users(:one),
      event_types: [ "other" ],
      occurred_at: Time.current
    )

    assert_not event.valid?
    assert_includes event.errors[:equipment], "must include at least one item"
  end

  test "rejects equipment from another workspace" do
    event = EquipmentEvent.new(
      workspace: workspaces(:household),
      user: users(:one),
      event_types: [ "grinder_cleaning" ],
      occurred_at: Time.current,
      equipment: [ equipment(:other_workspace_grinder) ]
    )

    assert_not event.valid?
    assert_includes event.errors[:equipment], "must belong to the workspace"
  end
end
