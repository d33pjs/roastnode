require "test_helper"

class InstanceBackupJobsTest < ActiveJob::TestCase
  setup do
    @backup_root = Rails.root.join("tmp", "test-instance-backups-#{SecureRandom.hex(8)}")
  end

  teardown do
    FileUtils.rm_rf(@backup_root)
  end

  test "backup job writes a readable JSON run file and records metadata" do
    profile = InstanceBackupProfile.create!(
      name: "Readable backup",
      backup_kind: "readable_json",
      enabled: true,
      schedule: "manual",
      storage_path: @backup_root.relative_path_from(Rails.root).to_s,
      retention_count: 7
    )
    run = profile.instance_backup_runs.create!(backup_kind: profile.backup_kind)

    InstanceBackupJob.perform_now(run)

    run.reload
    assert_equal "succeeded", run.status
    assert_predicate run.started_at, :present?
    assert_predicate run.finished_at, :present?
    assert_predicate run.file_path, :present?
    assert_equal File.size(run.file_path), run.file_size_bytes
    assert_equal Digest::SHA256.file(run.file_path).hexdigest, run.checksum_sha256
    assert_equal "roastnode.instance_readable_export", JSON.parse(File.read(run.file_path)).fetch("format")
  end

  test "scheduler enqueues due enabled profiles through Solid Queue backed jobs" do
    due = InstanceBackupProfile.create!(
      name: "Due backup",
      backup_kind: "readable_json",
      enabled: true,
      schedule: "daily",
      storage_path: @backup_root.relative_path_from(Rails.root).to_s,
      retention_count: 7,
      last_enqueued_at: 2.days.ago
    )
    disabled = InstanceBackupProfile.create!(
      name: "Disabled backup",
      backup_kind: "full_archive",
      enabled: false,
      schedule: "daily",
      retention_count: 7,
      last_enqueued_at: 2.days.ago
    )

    assert_enqueued_with(job: InstanceBackupJob) do
      InstanceBackupSchedulerJob.perform_now(now: Time.current)
    end

    assert_equal 1, due.instance_backup_runs.count
    assert_equal 0, disabled.instance_backup_runs.count
    assert_predicate due.reload.last_enqueued_at, :present?
  end

  test "successful and failed runs emit safe instance events" do
    profile = InstanceBackupProfile.create!(
      name: "Full archive", backup_kind: "full_archive", enabled: true, schedule: "manual",
      storage_path: @backup_root.relative_path_from(Rails.root).to_s, retention_count: 7
    )
    run = profile.instance_backup_runs.create!(backup_kind: "full_archive")

    event = assert_activity_event(
      action: "instance_backup_run.succeeded", workspace: nil, actor: nil, subject: run
    ) do
      with_stubbed_singleton_method(InstanceBackupArchiveBuilder, :new, ->(*) { Struct.new(:call).new("zip-bytes") }) do
        InstanceBackupJob.perform_now(run)
      end
    end
    assert_nil event.workspace
    assert_equal "System", event.metadata.fetch("actor_label")
    assert_no_match(/file_path|checksum|storage\//i, event.metadata.to_json)

    failed_run = profile.instance_backup_runs.create!(backup_kind: "full_archive")
    failed_event = assert_activity_event(
      action: "instance_backup_run.failed", workspace: nil, actor: nil, subject: failed_run
    ) do
      assert_raises(RuntimeError) do
        with_stubbed_singleton_method(InstanceBackupArchiveBuilder, :new, ->(*) { raise "storage_path=/private/secret token=abc" }) do
          InstanceBackupJob.perform_now(failed_run)
        end
      end
    end
    assert_equal "failed", failed_event.metadata.fetch("status")
    assert_no_match(/storage|private|secret|token|abc/i, failed_event.metadata.to_json)
  end

  test "retention cleanup failure does not contradict a successful run" do
    profile = InstanceBackupProfile.create!(
      name: "Full archive", backup_kind: "full_archive", enabled: true, schedule: "manual",
      storage_path: @backup_root.relative_path_from(Rails.root).to_s, retention_count: 7
    )
    run = profile.instance_backup_runs.create!(backup_kind: "full_archive")

    with_stubbed_singleton_method(InstanceBackupArchiveBuilder, :new, ->(*) { Struct.new(:call).new("zip-bytes") }) do
      with_stubbed_singleton_method(profile, :enforce_retention!, -> { raise "retention failed" }) do
        InstanceBackupJob.perform_now(run)
      end
    end

    assert_equal "succeeded", run.reload.status
    assert_equal 1, ActivityEvent.where(action: "instance_backup_run.succeeded", subject: run).count
    assert_equal 0, ActivityEvent.where(action: "instance_backup_run.failed", subject: run).count
  end

  test "success activity persistence failure rolls back succeeded state and event together" do
    profile = InstanceBackupProfile.create!(
      name: "Full archive", backup_kind: "full_archive", enabled: true, schedule: "manual",
      storage_path: @backup_root.relative_path_from(Rails.root).to_s, retention_count: 7
    )
    run = profile.instance_backup_runs.create!(backup_kind: "full_archive")
    original_record = Activity::Emitter.method(:record!)
    failing_success = lambda do |**attributes|
      if attributes.fetch(:action) == "instance_backup_run.succeeded"
        raise ActiveRecord::RecordInvalid.new(ActivityEvent.new)
      end

      original_record.call(**attributes)
    end

    assert_raises(ActiveRecord::RecordInvalid) do
      with_stubbed_singleton_method(InstanceBackupArchiveBuilder, :new, ->(*) { Struct.new(:call).new("zip-bytes") }) do
        with_stubbed_singleton_method(Activity::Emitter, :record!, failing_success) do
          InstanceBackupJob.perform_now(run)
        end
      end
    end

    assert_equal "failed", run.reload.status
    assert_equal 0, ActivityEvent.where(action: "instance_backup_run.succeeded", subject: run).count
    assert_equal 1, ActivityEvent.where(action: "instance_backup_run.failed", subject: run).count
  end

  test "failed activity persistence failure rolls back failed state and event together" do
    profile = InstanceBackupProfile.create!(
      name: "Full archive", backup_kind: "full_archive", enabled: true, schedule: "manual",
      storage_path: @backup_root.relative_path_from(Rails.root).to_s, retention_count: 7
    )
    run = profile.instance_backup_runs.create!(backup_kind: "full_archive")
    original_record = Activity::Emitter.method(:record!)
    failing_failure = lambda do |**attributes|
      if attributes.fetch(:action) == "instance_backup_run.failed"
        raise ActiveRecord::RecordInvalid.new(ActivityEvent.new)
      end

      original_record.call(**attributes)
    end

    error = assert_raises(ActiveRecord::RecordInvalid) do
      with_stubbed_singleton_method(InstanceBackupArchiveBuilder, :new, ->(*) { raise "backup generation failed" }) do
        with_stubbed_singleton_method(Activity::Emitter, :record!, failing_failure) do
          InstanceBackupJob.perform_now(run)
        end
      end
    end

    assert_instance_of ActivityEvent, error.record
    assert_equal "running", run.reload.status
    assert_equal 0, ActivityEvent.where(action: "instance_backup_run.failed", subject: run).count
  end
end
