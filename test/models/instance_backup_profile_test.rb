require "test_helper"

class InstanceBackupProfileTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "reads backup defaults from environment" do
    with_env(
      "ROASTNODE_BACKUP_STORAGE_PATH" => "storage/nightly",
      "ROASTNODE_BACKUP_RETENTION_COUNT" => "14"
    ) do
      assert_equal "storage/nightly", InstanceBackupProfile.default_storage_path
      assert_equal 14, InstanceBackupProfile.default_retention_count
    end
  end

  test "validates backup kind schedule and retention" do
    profile = InstanceBackupProfile.new(
      name: "Nightly backup",
      backup_kind: "unknown",
      schedule: "hourly",
      retention_count: 0
    )

    assert_not profile.valid?
    assert_includes profile.errors[:backup_kind], "is not included in the list"
    assert_includes profile.errors[:schedule], "is not included in the list"
    assert_includes profile.errors[:retention_count], "must be greater than or equal to 1"
  end

  test "detects due enabled daily profiles" do
    profile = InstanceBackupProfile.create!(
      name: "Daily full archive",
      backup_kind: "full_archive",
      enabled: true,
      schedule: "daily",
      retention_count: 7,
      last_enqueued_at: Time.zone.parse("2026-05-26 08:00:00")
    )

    assert profile.due_for_enqueue?(Time.zone.parse("2026-05-27 08:00:01"))
    assert_not profile.due_for_enqueue?(Time.zone.parse("2026-05-27 07:59:59"))
  end

  test "does not enqueue disabled or manual profiles" do
    disabled = InstanceBackupProfile.create!(
      name: "Disabled backup",
      backup_kind: "full_archive",
      enabled: false,
      schedule: "daily",
      retention_count: 7
    )
    manual = InstanceBackupProfile.create!(
      name: "Manual readable export",
      backup_kind: "readable_json",
      enabled: true,
      schedule: "manual",
      retention_count: 7
    )

    assert_not disabled.due_for_enqueue?(Time.current)
    assert_not manual.due_for_enqueue?(Time.current)
  end

  test "scheduled enqueue emits a system instance event in the run transaction" do
    profile = InstanceBackupProfile.create!(
      name: "Daily full archive", backup_kind: "full_archive", enabled: true,
      schedule: "daily", storage_path: "storage/instance_backups", retention_count: 7
    )
    now = Time.zone.parse("2026-08-21 07:08:09")

    before_ids = ActivityEvent.pluck(:id)
    assert_difference -> { ActivityEvent.where(action: "instance_backup_run.queued").count }, 1 do
      assert_enqueued_with(job: InstanceBackupJob) do
        @run = profile.enqueue_run!(now:)
      end
    end
    event = ActivityEvent.where.not(id: before_ids).find_by!(action: "instance_backup_run.queued")

    assert_nil event.workspace
    assert_nil event.actor
    assert_equal @run, event.subject
    assert_equal "System", event.metadata.fetch("actor_label")
    assert_equal "full_archive", event.metadata.fetch("backup_kind")
    assert_equal "queued", event.metadata.fetch("status")
    assert_equal now, profile.reload.last_enqueued_at
  end

  test "queued activity failure rolls back the run schedule timestamp and enqueue" do
    profile = InstanceBackupProfile.create!(
      name: "Daily full archive", backup_kind: "full_archive", enabled: true,
      schedule: "daily", storage_path: "storage/instance_backups", retention_count: 7
    )
    failure = lambda do |**|
      raise ActiveRecord::RecordInvalid.new(ActivityEvent.new)
    end

    assert_no_difference -> { profile.instance_backup_runs.count } do
      assert_no_difference -> { ActivityEvent.count } do
        with_stubbed_singleton_method(Activity::Emitter, :record!, failure) do
          assert_raises(ActiveRecord::RecordInvalid) { profile.enqueue_run! }
        end
      end
    end
    assert_nil profile.reload.last_enqueued_at
  end

  private
    def with_env(values)
      previous_values = values.to_h { |key, _value| [ key, ENV[key] ] }
      values.each { |key, value| ENV[key] = value }
      yield
    ensure
      previous_values.each do |key, value|
        value.nil? ? ENV.delete(key) : ENV[key] = value
      end
    end
end
