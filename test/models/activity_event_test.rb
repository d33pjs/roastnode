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

  test "rejects metadata missing actor and action summary requirements" do
    base = {
      workspace: workspaces(:household),
      occurred_at: Time.current,
      metadata: { "actor_kind" => "user", "actor_label" => "Jens" }
    }
    events = [
      ActivityEvent.new(base.merge(
        category: "coffee", action: "brew.created", visibility: "workspace",
        metadata: { "actor_kind" => "user" }
      )),
      ActivityEvent.new(base.merge(
        category: "household_administration", action: "membership.role_changed", visibility: "workspace_admin",
        metadata: base.fetch(:metadata).merge("from_role" => "member")
      )),
      ActivityEvent.new(base.merge(
        category: "system_security", action: "data_import.completed", visibility: "workspace_admin",
        metadata: base.fetch(:metadata).merge("created_count" => 1)
      )),
      ActivityEvent.new(base.merge(
        category: "coffee", action: "brew.created", visibility: "workspace",
        metadata: { "actor_kind" => "user", "actor_label" => "" }
      )),
      ActivityEvent.new(base.merge(
        category: "coffee", action: "brew.created", visibility: "workspace",
        metadata: { "actor_kind" => "user", "actor_label" => "   " }
      ))
    ]

    events.each do |event|
      assert_not event.valid?
      assert_includes event.errors[:metadata], "is missing required keys"
      assert_raises(ActiveRecord::RecordInvalid) { event.save! }
    end
  end

  test "rejects control characters in metadata text" do
    [ "Jens\0", "Jens\a", "Jens\u007f" ].each do |actor_label|
      event = ActivityEvent.new(
        workspace: workspaces(:household), category: "coffee", action: "brew.created",
        occurred_at: Time.current, visibility: "workspace",
        metadata: { "actor_kind" => "user", "actor_label" => actor_label }
      )

      assert_not event.valid?
      assert_includes event.errors[:metadata], "contains unsafe text"
    end
  end

  test "direct model writes constrain guest cupping identities IP addresses and subjects" do
    brew = brews(:morning_espresso)
    base = {
      workspace: brew.workspace,
      category: "coffee",
      occurred_at: Time.current,
      visibility: "workspace"
    }
    non_cupping_guest = ActivityEvent.new(base.merge(
      actor: nil, action: "brew.created", subject: brew,
      metadata: { "actor_kind" => "guest", "actor_label" => "Alex" }
    ))
    guest_with_actor = ActivityEvent.new(base.merge(
      actor: users(:one), action: "brew.cupping_accessed", subject: brew,
      metadata: { "actor_kind" => "guest", "actor_label" => "Alex", "ip_address" => "203.0.113.4" }
    ))
    cupping_user = ActivityEvent.new(base.merge(
      actor: users(:one), action: "brew.cupping_accessed", subject: brew,
      metadata: { "actor_kind" => "user", "actor_label" => "Jens", "ip_address" => "203.0.113.4" }
    ))
    cupping_system = ActivityEvent.new(base.merge(
      actor: nil, action: "brew.cupping_accessed", subject: brew,
      metadata: { "actor_kind" => "system", "actor_label" => "System", "ip_address" => "203.0.113.4" }
    ))
    missing_cupping_subject = ActivityEvent.new(base.merge(
      actor: nil, action: "brew.cupping_accessed",
      metadata: { "actor_kind" => "guest", "actor_label" => "Alex", "ip_address" => "203.0.113.4" }
    ))
    invalid_ip = ActivityEvent.new(base.merge(
      actor: nil, action: "brew.cupping_accessed", subject: brew,
      metadata: { "actor_kind" => "guest", "actor_label" => "Alex", "ip_address" => "203.0.113.4, 10.0.0.1" }
    ))

    [ non_cupping_guest, guest_with_actor, cupping_user, cupping_system, missing_cupping_subject, invalid_ip ].each do |event|
      assert_not event.valid?
      assert_raises(ActiveRecord::RecordInvalid) { event.save! }
    end
    assert_includes non_cupping_guest.errors[:metadata], "has an invalid actor kind"
    assert_includes guest_with_actor.errors[:actor], "must be blank for guest activity"
    assert_includes cupping_user.errors[:metadata], "has an invalid actor kind"
    assert_includes cupping_system.errors[:metadata], "has an invalid actor kind"
    assert_includes missing_cupping_subject.errors[:subject], "must be present for action"
    assert_includes invalid_ip.errors[:metadata], "contains a value that does not match its action schema"

    event = ActivityEvent.create!(base.merge(
      actor: nil, action: "brew.cupping_accessed", subject: brew,
      metadata: {
        "actor_kind" => "guest", "actor_label" => "Alex",
        "ip_address" => "2001:0db8:0000:0000:0000:0000:0000:0001"
      }
    ))

    assert_equal "2001:db8::1", event.metadata.fetch("ip_address")
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
