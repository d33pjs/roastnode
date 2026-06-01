require "test_helper"

class WorkspaceActivityFeedTest < ActiveSupport::TestCase
  setup do
    equipment_events(:machine_backflush).update!(occurred_at: Time.zone.local(2026, 6, 1, 6, 0, 0))
  end

  test "returns workspace activity sorted newest first" do
    workspace = workspaces(:household)
    adjustment = workspace.inventory_adjustments.create!(
      bean: beans(:open_household),
      user: users(:one),
      delta_grams: 12.5,
      reason: "manual",
      note: "Found extra beans.",
      occurred_at: Time.zone.local(2026, 6, 1, 9, 30, 0)
    )
    brews(:morning_espresso).update!(occurred_at: Time.zone.local(2026, 6, 1, 8, 0, 0))
    equipment_events(:grinder_cleaning).update!(occurred_at: Time.zone.local(2026, 6, 1, 7, 0, 0))

    records = WorkspaceActivityFeed.new(workspace).records

    assert_equal [ adjustment, brews(:morning_espresso), equipment_events(:grinder_cleaning) ], records.first(3)
  end

  test "does not include other workspace activity" do
    other_workspace_adjustment = workspaces(:other_household).inventory_adjustments.create!(
      bean: beans(:other_workspace_open),
      user: users(:two),
      delta_grams: 12.5,
      reason: "manual",
      note: "Other workspace correction.",
      occurred_at: Time.zone.local(2026, 6, 1, 9, 30, 0)
    )

    records = WorkspaceActivityFeed.new(workspaces(:household)).records

    assert_includes records, brews(:morning_espresso)
    assert_includes records, equipment_events(:grinder_cleaning)
    assert_not_includes records, brews(:other_workspace_brew)
    assert_not_includes records, equipment_events(:other_workspace_event)
    assert_not_includes records, other_workspace_adjustment
  end

  test "does not include brew inventory adjustments" do
    records = WorkspaceActivityFeed.new(workspaces(:household)).records

    assert_not_includes records, inventory_adjustments(:morning_espresso_consumption)
  end

  test "sorts records with the same occurred at by created at newest first" do
    occurred_at = Time.zone.local(2026, 6, 1, 9, 30, 0)
    older_created_at = Time.zone.local(2026, 6, 1, 9, 31, 0)
    newer_created_at = Time.zone.local(2026, 6, 1, 9, 32, 0)

    brews(:morning_espresso).update_columns(occurred_at:, created_at: older_created_at, updated_at: older_created_at)
    equipment_events(:grinder_cleaning).update_columns(occurred_at:, created_at: newer_created_at, updated_at: newer_created_at)

    records = WorkspaceActivityFeed.new(workspaces(:household)).records

    assert_equal [ equipment_events(:grinder_cleaning), brews(:morning_espresso) ], records.first(2)
  end
end
