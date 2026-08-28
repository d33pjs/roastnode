require "test_helper"

class Activity::EmitterTest < ActiveSupport::TestCase
  test "derives category visibility icon and safe actor subject snapshots" do
    users(:one).update!(display_name: "Jens")
    brew = brews(:morning_espresso)

    event = Activity::Emitter.record!(
      action: "brew.created",
      workspace: workspaces(:household),
      actor: users(:one),
      subject: brew,
      occurred_at: brew.occurred_at
    )

    assert_equal "coffee", event.category
    assert_equal "workspace", event.visibility
    assert_equal "Jens", event.metadata.fetch("actor_label")
    assert_equal "user", event.metadata.fetch("actor_kind")
    assert_equal "Espresso with #{brew.bean.name} for me", event.metadata.fetch("subject_label")
    assert_equal "espresso", event.metadata.fetch("method")
    assert_equal "local_cafe", Activity::EventContract.fetch("brew.created").fetch(:icon)
  end

  test "uses Quick Drip copy and System actor snapshots" do
    brew = workspaces(:household).brews.new(method: "quick_drip", bean: beans(:open_household))
    metadata = Activity::Metadata.build(action: "brew.created", actor: nil, subject: brew)

    assert_equal "Quick Drip with #{brew.bean.name} for me", metadata.fetch("subject_label")
    assert_equal "System", metadata.fetch("actor_label")
    assert_equal "system", metadata.fetch("actor_kind")
  end

  test "records strict guest cupping events without feedback content" do
    brew = brews(:morning_espresso)
    brew.update!(recipient_kind: "guest", recipient_name: "Alex")
    actor = { actor_kind: "guest", actor_label: "Alex" }

    event = assert_activity_event(
      action: "brew.cupping_taste_changed", workspace: brew.workspace, actor: nil, subject: brew
    ) do
      Activity::Emitter.record!(
        action: "brew.cupping_taste_changed", workspace: brew.workspace, subject: brew, **actor,
        details: { ip_address: "203.0.113.4", from_taste: "neutral", to_taste: "sour" }
      )
    end

    assert_nil event.actor
    assert_equal "guest", event.metadata.fetch("actor_kind")
    assert_equal "Alex", event.metadata.fetch("actor_label")
    assert_equal "203.0.113.4", event.metadata.fetch("ip_address")
    assert_equal "Espresso with #{brew.bean.name} for Alex", event.metadata.fetch("subject_label")
    assert_no_match(/feedback text/, event.metadata.to_json)
    assert_raises(ArgumentError) do
      Activity::Emitter.record!(
        action: "brew.cupping_accessed", workspace: brew.workspace, actor: users(:one), subject: brew,
        **actor, details: { ip_address: "203.0.113.4" }
      )
    end
    assert_raises(ArgumentError) do
      Activity::Emitter.record!(
        action: "brew.cupping_accessed", workspace: brew.workspace, subject: brew,
        actor_kind: "guest", details: { ip_address: "203.0.113.4" }
      )
    end
  end

  test "records every allowlisted guest cupping action with its required values" do
    brew = brews(:morning_espresso)
    brew.update!(recipient_kind: "guest", recipient_name: "Alex")
    actor = { actor_kind: "guest", actor_label: "Alex" }

    events = assert_activity_events(
      actions: [
        "brew.cupping_accessed", "brew.cupping_taste_set", "brew.cupping_taste_changed",
        "brew.cupping_taste_cleared", "brew.cupping_rating_set", "brew.cupping_rating_changed",
        "brew.cupping_rating_cleared", "brew.cupping_comment_added", "brew.cupping_comment_updated",
        "brew.cupping_closed"
      ], workspace: brew.workspace, actor: nil
    ) do
      Activity::Emitter.record!(action: "brew.cupping_accessed", workspace: brew.workspace, subject: brew, **actor, details: { ip_address: "203.0.113.4" })
      Activity::Emitter.record!(action: "brew.cupping_taste_set", workspace: brew.workspace, subject: brew, **actor, details: { ip_address: "203.0.113.4", to_taste: "neutral" })
      Activity::Emitter.record!(action: "brew.cupping_taste_changed", workspace: brew.workspace, subject: brew, **actor, details: { ip_address: "203.0.113.4", from_taste: "neutral", to_taste: "sour" })
      Activity::Emitter.record!(action: "brew.cupping_taste_cleared", workspace: brew.workspace, subject: brew, **actor, details: { ip_address: "203.0.113.4", from_taste: "sour" })
      Activity::Emitter.record!(action: "brew.cupping_rating_set", workspace: brew.workspace, subject: brew, **actor, details: { ip_address: "203.0.113.4", to_rating: 4 })
      Activity::Emitter.record!(action: "brew.cupping_rating_changed", workspace: brew.workspace, subject: brew, **actor, details: { ip_address: "203.0.113.4", from_rating: 4, to_rating: 5 })
      Activity::Emitter.record!(action: "brew.cupping_rating_cleared", workspace: brew.workspace, subject: brew, **actor, details: { ip_address: "203.0.113.4", from_rating: 5 })
      Activity::Emitter.record!(action: "brew.cupping_comment_added", workspace: brew.workspace, subject: brew, **actor, details: { ip_address: "203.0.113.4" })
      Activity::Emitter.record!(action: "brew.cupping_comment_updated", workspace: brew.workspace, subject: brew, **actor, details: { ip_address: "203.0.113.4" })
      Activity::Emitter.record!(action: "brew.cupping_closed", workspace: brew.workspace, subject: brew, **actor, details: { ip_address: "203.0.113.4" })
    end

    assert events.all? { |event| event.metadata.fetch("ip_address") == "203.0.113.4" }
  end

  test "limits guest actors and requires canonical IP-addressed Brew subjects for cupping" do
    brew = brews(:morning_espresso)
    guest = { actor_kind: "guest", actor_label: "Alex" }

    assert_raises(ArgumentError) do
      Activity::Emitter.record!(action: "brew.created", workspace: brew.workspace, subject: brew, **guest)
    end
    assert_raises(ArgumentError) do
      Activity::Emitter.record!(
        action: "brew.cupping_accessed", workspace: brew.workspace, **guest,
        details: { ip_address: "203.0.113.4" }
      )
    end
    [ "not-an-ip", "203.0.113.4, 10.0.0.1" ].each do |ip_address|
      assert_raises(ArgumentError) do
        Activity::Emitter.record!(
          action: "brew.cupping_accessed", workspace: brew.workspace, subject: brew, **guest,
          details: { ip_address: }
        )
      end
    end

    event = Activity::Emitter.record!(
      action: "brew.cupping_accessed", workspace: brew.workspace, subject: brew, **guest,
      details: { ip_address: "2001:0db8:0000:0000:0000:0000:0000:0001" }
    )

    assert_equal "2001:db8::1", event.metadata.fetch("ip_address")
  end

  test "rejects unknown actions cross-workspace subjects and unexpected details" do
    assert_raises(KeyError) do
      Activity::Emitter.record!(action: "future.unknown", workspace: workspaces(:household))
    end
    assert_raises(ArgumentError) do
      Activity::Emitter.record!(
        action: "brew.created", workspace: workspaces(:household), actor: users(:one),
        subject: brews(:other_workspace_brew)
      )
    end
    assert_raises(ArgumentError) do
      Activity::Emitter.record!(
        action: "brew.created", workspace: workspaces(:household), actor: users(:one),
        subject: beans(:open_household)
      )
    end
    assert_raises(ArgumentError) do
      Activity::Emitter.record!(
        action: "brew.created", workspace: workspaces(:household), actor: users(:one),
        subject: brews(:morning_espresso), details: { "token" => "bearer-secret" }
      )
    end
    assert_raises(ArgumentError) do
      Activity::Emitter.record!(
        action: "brew.created", workspace: workspaces(:household), actor: users(:one),
        subject: brews(:morning_espresso), details: { "backup_kind" => "full_archive" }
      )
    end
    assert_raises(ArgumentError) do
      Activity::Emitter.record!(
        action: "brew.created", workspace: workspaces(:household),
        actor: users(:one), visibility: "workspace_admin"
      )
    end
  end

  test "rejects cross-workspace user and passkey subjects while allowing compatible account placement" do
    assert_raises(ArgumentError) do
      Activity::Emitter.record!(
        action: "profile.updated", workspace: workspaces(:other_household), actor: users(:two), subject: users(:one)
      )
    end
    assert_raises(ArgumentError) do
      Activity::Emitter.record!(
        action: "passkey.created", workspace: workspaces(:other_household), actor: users(:two),
        subject: passkey_credentials(:one_touch_id)
      )
    end

    user_event = Activity::Emitter.record!(
      action: "profile.updated", workspace: workspaces(:household), actor: users(:one), subject: users(:one)
    )
    passkey_event = Activity::Emitter.record!(
      action: "passkey.created", workspace: workspaces(:household), actor: users(:one),
      subject: passkey_credentials(:one_touch_id)
    )
    instance_event = Activity::Emitter.record!(
      action: "passkey.created", workspace: nil, actor: users(:one),
      subject: passkey_credentials(:one_touch_id), visibility: "instance_admin"
    )

    assert_equal workspaces(:household), user_event.workspace
    assert_equal workspaces(:household), passkey_event.workspace
    assert_nil instance_event.workspace
  end

  test "redacts path url and secret-shaped label text" do
    users(:one).update!(display_name: "https://private.example/token=abc")

    event = Activity::Emitter.record!(
      action: "profile.updated",
      workspace: workspaces(:household), actor: users(:one), subject: users(:one)
    )

    assert_equal "[redacted]", event.metadata.fetch("actor_label")
    assert_no_match(/https|token|abc/i, event.metadata.to_json)
  end

  test "redacts arbitrary URI schemes and absolute paths" do
    [ "s3://private-bucket/key", "file://private/path", "C:\\private\\file", "\\\\server\\share" ].each do |unsafe_text|
      assert_equal "[redacted]", Activity::Metadata.safe_text(unsafe_text)
    end
  end

  test "redacts Windows parent paths through runtime emission" do
    users(:one).update!(display_name: "..\\private\\backup")

    event = Activity::Emitter.record!(
      action: "profile.updated", workspace: workspaces(:household), actor: users(:one), subject: users(:one)
    )

    assert_equal "[redacted]", event.metadata.fetch("actor_label")
    assert_no_match(/private|backup/i, event.metadata.to_json)
  end

  test "sanitizes every item in automatic subject-derived arrays" do
    grinder = equipment(:household_grinder)
    grinder.update_column(:name, "../private/grinder")

    metadata = Activity::Metadata.build(
      action: "equipment_event.created", actor: users(:one),
      subject: equipment_events(:grinder_cleaning)
    )

    assert_equal [ "[redacted]" ], metadata.fetch("equipment_labels")
    assert_no_match(/private|\.\./i, metadata.to_json)
  end

  test "system instance events have no workspace and actor snapshots survive actor changes" do
    event = Activity::Emitter.record!(
      action: "instance_backup_run.succeeded",
      workspace: nil,
      details: { "backup_kind" => "full_archive", "status" => "succeeded" }
    )
    users(:one).update!(display_name: "Changed later")
    actor_event = Activity::Emitter.record!(
      action: "workspace.updated", workspace: workspaces(:household), actor: users(:one),
      subject: workspaces(:household)
    )
    users(:one).update!(display_name: "Changed again")

    assert_nil event.workspace
    assert_equal "instance_admin", event.visibility
    assert_equal "System", event.metadata.fetch("actor_label")
    assert_equal "Changed later", actor_event.reload.metadata.fetch("actor_label")
  end

  test "a surrounding rollback leaves no event" do
    assert_no_difference -> { ActivityEvent.count } do
      ActivityEvent.transaction do
        Activity::Emitter.record!(
          action: "bean.updated", workspace: workspaces(:household), actor: users(:one), subject: beans(:open_household)
        )
        raise ActiveRecord::Rollback
      end
    end
  end

  test "model validation rejects unsafe and action-incompatible metadata from direct callers" do
    unsafe_event = ActivityEvent.new(
      workspace: workspaces(:household), actor: users(:one), category: "coffee",
      action: "brew.created", occurred_at: Time.current, visibility: "workspace",
      metadata: { "actor_kind" => "user", "actor_label" => "https://private.example/token=abc" }
    )
    wrong_key_event = ActivityEvent.new(
      workspace: workspaces(:household), actor: users(:one), category: "coffee",
      action: "brew.created", occurred_at: Time.current, visibility: "workspace",
      metadata: { "actor_kind" => "user", "actor_label" => "Jens", "backup_kind" => "full_archive" }
    )
    unsafe_array_event = ActivityEvent.new(
      workspace: workspaces(:household), actor: users(:one), category: "gear_maintenance",
      action: "equipment_event.created", occurred_at: Time.current, visibility: "workspace",
      subject: equipment_events(:grinder_cleaning),
      metadata: {
        "actor_kind" => "user", "actor_label" => "Jens", "record_kind" => "equipment_event",
        "subject_label" => "Grinder cleaning", "event_types" => [ "../private/event", "x" * 161 ]
      }
    )

    assert_not unsafe_event.valid?
    assert_includes unsafe_event.errors[:metadata], "contains unsafe text"
    assert_not wrong_key_event.valid?
    assert_includes wrong_key_event.errors[:metadata], "contains unsupported keys"
    assert_not unsafe_array_event.valid?
    assert_includes unsafe_array_event.errors[:metadata], "contains unsafe text"
    assert_includes unsafe_array_event.errors[:metadata], "contains overlong text"
    assert_raises(ActiveRecord::RecordInvalid) { wrong_key_event.save! }
    assert_raises(ActiveRecord::RecordInvalid) { unsafe_array_event.save! }
  end

  test "metadata schema rejects invalid caller and automatic value types" do
    data_import = DataImport.create!(
      workspace: workspaces(:household), user: users(:one), source: "beanconqueror", status: "completed"
    )
    backup_profile = InstanceBackupProfile.new(name: "Full archive", backup_kind: "full_archive")
    backup_run = backup_profile.instance_backup_runs.build(
      backup_kind: "full_archive", status: "succeeded", file_size_bytes: 42
    )

    assert_raises(ArgumentError) do
      Activity::Metadata.build(
        action: "data_import.completed", actor: users(:one), subject: data_import,
        details: { "created_count" => "private note" }
      )
    end
    assert_raises(ArgumentError) do
      Activity::Emitter.record!(
        action: "data_import.completed", workspace: workspaces(:household), actor: users(:one), subject: data_import,
        details: { "created_count" => "private note" }
      )
    end
    assert_raises(ArgumentError) do
      Activity::Metadata.build(
        action: "instance_backup_run.succeeded", actor: nil, subject: backup_run,
        details: { "backup_kind" => "full_archive", "status" => "succeeded", "file_size_bytes" => [ "unknown" ] }
      )
    end
    assert_raises(ArgumentError) { Activity::Metadata.safe_value([ { "label" => "private" } ]) }
  end

  test "direct writes enforce the complete per-action metadata schema" do
    base = {
      occurred_at: Time.current,
      metadata: { "actor_kind" => "user", "actor_label" => "Jens" }
    }
    invalid_count = ActivityEvent.new(base.merge(
      workspace: workspaces(:household), actor: users(:one), category: "system_security",
      action: "data_import.completed", visibility: "workspace_admin",
      metadata: base.fetch(:metadata).merge("created_count" => "private note")
    ))
    invalid_file_size = ActivityEvent.new(base.merge(
      category: "system_security", action: "instance_backup_run.succeeded", visibility: "instance_admin",
      metadata: base.fetch(:metadata).merge(
        "backup_kind" => "full_archive", "status" => "succeeded", "file_size_bytes" => [ "unknown" ]
      )
    ))
    invalid_enabled = ActivityEvent.new(base.merge(
      workspace: workspaces(:household), actor: users(:one), category: "sharing_recipes",
      action: "public_brew_share.updated", visibility: "workspace",
      metadata: base.fetch(:metadata).merge("enabled" => "maybe")
    ))
    invalid_array_item = ActivityEvent.new(base.merge(
      workspace: workspaces(:household), actor: users(:one), category: "gear_maintenance",
      action: "equipment_event.created", visibility: "workspace",
      metadata: base.fetch(:metadata).merge("event_types" => [ { "name" => "grinder_cleaning" } ])
    ))

    [ invalid_count, invalid_file_size, invalid_enabled, invalid_array_item ].each do |event|
      assert_not event.valid?
      assert_includes event.errors[:metadata], "contains a value that does not match its action schema"
      assert_raises(ActiveRecord::RecordInvalid) { event.save! }
    end
  end

  test "direct writes still require a schema-valid actor kind" do
    event = ActivityEvent.new(
      workspace: workspaces(:household), actor: users(:one), category: "coffee",
      action: "brew.created", occurred_at: Time.current, visibility: "workspace",
      metadata: { "actor_label" => "Jens" }
    )

    assert_not event.valid?
    assert_includes event.errors[:metadata], "has an invalid actor kind"
  end

  test "direct model writes reject arbitrary URI schemes and absolute paths" do
    [ "s3://private-bucket/key", "file://private/path", "C:\\private\\file", "\\\\server\\share", "..\\private\\backup" ].each do |unsafe_text|
      event = ActivityEvent.new(
        workspace: workspaces(:household), actor: users(:one), category: "coffee",
        action: "brew.created", occurred_at: Time.current, visibility: "workspace",
        metadata: { "actor_kind" => "user", "actor_label" => unsafe_text }
      )

      assert_not event.valid?
      assert_includes event.errors[:metadata], "contains unsafe text"
    end
  end

  test "direct writes reject cross-workspace user and passkey subjects" do
    base = {
      workspace: workspaces(:other_household), actor: users(:two), category: "system_security",
      occurred_at: Time.current, visibility: "workspace_admin",
      metadata: { "actor_kind" => "user", "actor_label" => "Petra" }
    }
    wrong_user = ActivityEvent.new(base.merge(action: "profile.updated", subject: users(:one)))
    wrong_passkey = ActivityEvent.new(
      base.merge(action: "passkey.created", subject: passkey_credentials(:one_touch_id))
    )
    valid_user = ActivityEvent.new(
      base.merge(workspace: workspaces(:household), actor: users(:one), action: "profile.updated", subject: users(:one))
    )
    valid_passkey = ActivityEvent.new(
      base.merge(
        workspace: workspaces(:household), actor: users(:one), action: "passkey.created",
        subject: passkey_credentials(:one_touch_id)
      )
    )
    valid_instance_passkey = ActivityEvent.new(
      base.merge(
        workspace: nil, actor: users(:one), action: "passkey.created", visibility: "instance_admin",
        subject: passkey_credentials(:one_touch_id)
      )
    )

    [ wrong_user, wrong_passkey ].each do |event|
      assert_not event.valid?
      assert_includes event.errors[:subject], "belongs to another workspace"
      assert_raises(ActiveRecord::RecordInvalid) { event.save! }
    end
    assert_predicate valid_user, :valid?
    assert_predicate valid_passkey, :valid?
    assert_predicate valid_instance_passkey, :valid?
  end

  test "direct model writes enforce action category visibility subject type and workspace" do
    attributes = {
      workspace: workspaces(:household), actor: users(:one), category: "coffee",
      action: "brew.created", occurred_at: Time.current, visibility: "workspace",
      subject: brews(:morning_espresso), metadata: { "actor_kind" => "user", "actor_label" => "Jens" }
    }
    wrong_category = ActivityEvent.new(attributes.merge(category: "system_security"))
    wrong_visibility = ActivityEvent.new(attributes.merge(visibility: "workspace_admin"))
    wrong_type = ActivityEvent.new(attributes.merge(subject: beans(:open_household)))
    wrong_workspace = ActivityEvent.new(attributes.merge(subject: brews(:other_workspace_brew)))
    tombstone = ActivityEvent.new(attributes.merge(action: "brew.deleted", subject: nil))

    assert_not wrong_category.valid?
    assert_includes wrong_category.errors[:category], "does not match action"
    assert_not wrong_visibility.valid?
    assert_includes wrong_visibility.errors[:visibility], "is not permitted for action"
    assert_not wrong_type.valid?
    assert_includes wrong_type.errors[:subject], "type does not match action"
    assert_not wrong_workspace.valid?
    assert_includes wrong_workspace.errors[:subject], "belongs to another workspace"
    assert_predicate tombstone, :valid?
    [ wrong_category, wrong_visibility, wrong_type, wrong_workspace ].each do |event|
      assert_raises(ActiveRecord::RecordInvalid) { event.save! }
    end
  end

  test "workspace wrapper resolves lazy values and records a truthy mutation in one transaction" do
    user = users(:one)
    user.update!(active_workspace: workspaces(:household))
    Current.session = user.sessions.create!
    brew = brews(:morning_espresso)
    occurred_at = 1.minute.ago

    result = assert_difference -> { ActivityEvent.count }, 1 do
      ApplicationController.new.send(
        :with_workspace_activity,
        action: -> { "brew.updated" },
        subject: -> { brew },
        occurred_at: -> { occurred_at },
        details: -> { {} }
      ) do
        brew.update!(notes: "Wrapper mutation")
        brew
      end
    end

    event = ActivityEvent.order(:id).last
    assert_equal brew, result
    assert_equal occurred_at.to_i, event.occurred_at.to_i
    assert_equal "brew.updated", event.action
    assert_equal user, event.actor
  ensure
    Current.reset
  end

  test "workspace wrapper rolls back a false mutation and an emission failure" do
    user = users(:one)
    user.update!(active_workspace: workspaces(:household))
    Current.session = user.sessions.create!
    brew = brews(:morning_espresso)
    original_notes = brew.notes
    controller = ApplicationController.new

    result = assert_no_difference -> { ActivityEvent.count } do
      controller.send(:with_workspace_activity, action: "brew.updated", subject: brew) do
        brew.update!(notes: "Must roll back")
        false
      end
    end
    assert_equal false, result
    assert_equal original_notes, brew.reload.notes

    assert_no_difference -> { ActivityEvent.count } do
      assert_raises(ArgumentError) do
        controller.send(
          :with_workspace_activity,
          action: "brew.updated",
          subject: brew,
          details: { "token" => "must-not-persist" }
        ) do
          brew.update!(notes: "Also rolls back")
        end
      end
    end
    assert_equal original_notes, brew.reload.notes
  ensure
    Current.reset
  end

  test "workspace wrapper normalizes a nil mutation result to false and rolls back" do
    user = users(:one)
    user.update!(active_workspace: workspaces(:household))
    Current.session = user.sessions.create!
    brew = brews(:morning_espresso)
    original_notes = brew.notes

    result = assert_no_difference -> { ActivityEvent.count } do
      ApplicationController.new.send(:with_workspace_activity, action: "brew.updated", subject: brew) do
        brew.update!(notes: "Must roll back from nil")
        nil
      end
    end

    assert_equal false, result
    assert_equal original_notes, brew.reload.notes
  ensure
    Current.reset
  end

  test "account wrapper selects workspace or instance placement from the active workspace" do
    user = users(:one)
    workspace = workspaces(:household)
    controller = ApplicationController.new

    user.update!(active_workspace: workspace)
    controller.send(:with_account_activity, action: "profile.updated", user:) { user }
    workspace_event = ActivityEvent.order(:id).last
    assert_equal workspace, workspace_event.workspace
    assert_equal "workspace_admin", workspace_event.visibility

    user.update!(active_workspace: nil)
    controller.send(:with_account_activity, action: "password.changed", user:) { user }
    instance_event = ActivityEvent.order(:id).last
    assert_nil instance_event.workspace
    assert_equal "instance_admin", instance_event.visibility
  end
end
