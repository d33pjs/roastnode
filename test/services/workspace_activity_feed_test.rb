require "test_helper"

class WorkspaceActivityFeedTest < ActiveSupport::TestCase
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
    records = WorkspaceActivityFeed.new(workspaces(:household)).records

    assert_includes records, brews(:morning_espresso)
    assert_includes records, equipment_events(:grinder_cleaning)
    assert_not_includes records, brews(:other_workspace_brew)
    assert_not_includes records, equipment_events(:other_workspace_event)
  end
end
