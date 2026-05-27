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
end
