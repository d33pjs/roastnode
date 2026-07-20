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

  test "limited feed fills the requested size when one activity type dominates" do
    workspace = workspaces(:household)
    bean = beans(:open_household)
    user = users(:one)
    machine = equipment(:household_machine)
    grinder = equipment(:household_grinder)
    equipment_events(:grinder_cleaning).update!(occurred_at: Time.zone.local(2026, 6, 1, 5, 0, 0))

    9.times do |index|
      workspace.brews.create!(
        user:,
        bean:,
        grinder:,
        machine:,
        occurred_at: Time.zone.local(2026, 6, 2, 12, index, 0),
        bean_weight_grams: 1,
        ground_weight_grams: 1,
        dose_grams: 1,
        beverage_grams: 2,
        taste_balance: "neutral"
      )
    end

    records = WorkspaceActivityFeed.new(workspace).records(limit: 8)

    assert_equal 8, records.size
    assert records.all? { |record| record.is_a?(Brew) }
    assert_equal records.sort_by { |record| [ record.occurred_at, record.created_at ] }.reverse, records
  end
end
