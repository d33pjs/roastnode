require "test_helper"

class ActivityEventTest < ActiveSupport::TestCase
  test "requires a scope category action occurrence visibility and JSON object metadata" do
    event = ActivityEvent.new(metadata: nil)

    assert_not event.valid?
    assert_includes event.errors[:category], "can't be blank"
    assert_includes event.errors[:action], "can't be blank"
    assert_includes event.errors[:occurred_at], "can't be blank"
    assert_includes event.errors[:visibility], "can't be blank"
    assert_includes event.errors[:metadata], "must be a JSON object"
  end

  test "requires workspace visibility rows to have a workspace" do
    event = ActivityEvent.new(
      actor: users(:one),
      category: "coffee",
      action: "brew.created",
      occurred_at: Time.current,
      visibility: "workspace",
      metadata: {}
    )

    assert_not event.valid?
    assert_includes event.errors[:workspace], "must be present for workspace activity"
  end

  test "requires instance events to have no workspace" do
    event = ActivityEvent.new(
      workspace: workspaces(:household),
      actor: users(:one),
      category: "system_security",
      action: "instance_backup_run.queued",
      occurred_at: Time.current,
      visibility: "instance_admin",
      metadata: {}
    )

    assert_not event.valid?
    assert_includes event.errors[:workspace], "must be blank for instance activity"
  end

  test "persisted events cannot be updated touched or destroyed" do
    event = activity_events(:morning_brew_created)

    assert_predicate event, :readonly?
    assert_raises(ActiveRecord::ReadOnlyRecord) { event.update!(action: "brew.updated") }
    assert_raises(ActiveRecord::ReadOnlyRecord) { event.touch }
    assert_raises(ActiveRecord::ReadOnlyRecord) { event.destroy! }
  end

  test "deleting a subject retains the event as a tombstone" do
    equipment = workspaces(:household).equipment.create!(name: "Temporary grinder", kind: "grinder")
    event = ActivityEvent.create!(
      workspace: workspaces(:household),
      actor: users(:one),
      category: "gear_maintenance",
      action: "equipment.deleted",
      occurred_at: Time.current,
      visibility: "workspace",
      subject: equipment,
      metadata: {
        "actor_kind" => "user",
        "actor_label" => "Jens",
        "record_kind" => "equipment",
        "subject_label" => "Temporary grinder"
      }
    )

    equipment.destroy!

    assert_equal event.id, ActivityEvent.find(event.id).id
    assert_nil event.reload.subject
    assert_equal "Temporary grinder", event.metadata.fetch("subject_label")
  end

  test "workspace deletion cascades its private history while an instance tombstone survives" do
    workspace = Workspace.create!(name: "Disposable household", default_currency: "EUR")
    scoped = ActivityEvent.create!(
      workspace:,
      actor: users(:one),
      category: "household_administration",
      action: "workspace.created",
      occurred_at: Time.current,
      visibility: "workspace_admin",
      subject: workspace,
      metadata: { "actor_kind" => "user", "actor_label" => "Jens", "record_kind" => "workspace", "subject_label" => workspace.name }
    )
    tombstone = ActivityEvent.create!(
      actor: users(:one),
      category: "household_administration",
      action: "workspace.deleted",
      occurred_at: Time.current,
      visibility: "instance_admin",
      subject: workspace,
      metadata: { "actor_kind" => "user", "actor_label" => "Jens", "record_kind" => "workspace", "subject_label" => workspace.name }
    )

    workspace.destroy!

    assert_not ActivityEvent.exists?(scoped.id)
    assert ActivityEvent.exists?(tombstone.id)
    assert_nil tombstone.reload.subject
  end

  test "recent uses occurrence time and id as stable descending order" do
    same_time = Time.zone.local(2026, 8, 21, 12, 0, 0)
    older_id = ActivityEvent.create!(
      workspace: workspaces(:household), actor: users(:one), category: "coffee", action: "brew.created",
      occurred_at: same_time, visibility: "workspace",
      metadata: { "actor_kind" => "user", "actor_label" => "Jens" }
    )
    newer_id = ActivityEvent.create!(
      workspace: workspaces(:household), actor: users(:one), category: "coffee", action: "brew.updated",
      occurred_at: same_time, visibility: "workspace",
      metadata: { "actor_kind" => "user", "actor_label" => "Jens" }
    )

    assert_equal [ newer_id, older_id ], ActivityEvent.where(id: [ older_id.id, newer_id.id ]).recent.to_a
  end
end
