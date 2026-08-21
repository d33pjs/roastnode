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
    assert_equal "Espresso with #{brew.bean.name}", event.metadata.fetch("subject_label")
    assert_equal "espresso", event.metadata.fetch("method")
    assert_equal "local_cafe", Activity::EventContract.fetch("brew.created").fetch(:icon)
  end

  test "uses Quick Drip copy and System actor snapshots" do
    brew = workspaces(:household).brews.new(method: "quick_drip", bean: beans(:open_household))
    metadata = Activity::Metadata.build(action: "brew.created", actor: nil, subject: brew)

    assert_equal "Quick Drip with #{brew.bean.name}", metadata.fetch("subject_label")
    assert_equal "System", metadata.fetch("actor_label")
    assert_equal "system", metadata.fetch("actor_kind")
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

  test "direct model writes reject arbitrary URI schemes and absolute paths" do
    [ "s3://private-bucket/key", "file://private/path", "C:\\private\\file", "\\\\server\\share" ].each do |unsafe_text|
      event = ActivityEvent.new(
        workspace: workspaces(:household), actor: users(:one), category: "coffee",
        action: "brew.created", occurred_at: Time.current, visibility: "workspace",
        metadata: { "actor_kind" => "user", "actor_label" => unsafe_text }
      )

      assert_not event.valid?
      assert_includes event.errors[:metadata], "contains unsafe text"
    end
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
