require "test_helper"

class InstanceOperationsSnapshotTest < ActiveSupport::TestCase
  FailedJob = Data.define(:id, :class_name, :queue_name, :failed_at, :error_message)

  class FakeQueueReader
    attr_reader :unavailable_detail

    def initialize(available:, counts: {}, failed_jobs: [], unavailable_detail: nil)
      @available = available
      @counts = counts
      @failed_jobs = failed_jobs
      @unavailable_detail = unavailable_detail
    end

    def available?
      @available
    end

    def counts
      @counts
    end

    def recent_failures(limit:)
      @failed_jobs.first(limit)
    end
  end

  test "reports queue counts and redacted failed job details" do
    reader = FakeQueueReader.new(
      available: true,
      counts: {
        ready_jobs: 2,
        scheduled_jobs: 1,
        claimed_jobs: 0,
        blocked_jobs: 0,
        failed_jobs: 1,
        worker_processes: 1
      },
      failed_jobs: [
        FailedJob.new(
          id: 12,
          class_name: "InstanceBackupJob",
          queue_name: "background",
          failed_at: Time.zone.parse("2026-05-28 11:30:00"),
          error_message: "RuntimeError: upload failed password=super-secret access_token=abc123"
        )
      ]
    )

    snapshot = InstanceOperationsSnapshot.new(queue_reader: reader)

    assert_equal :attention, snapshot.queue_status.status
    assert_equal 1, snapshot.queue_counts.detect { |count| count.key == :failed_jobs }.value

    failure = snapshot.failed_jobs.first
    assert_equal "InstanceBackupJob", failure.class_name
    assert_equal "background", failure.queue_name
    assert_includes failure.error_message, "[REDACTED]"
    assert_no_match(/super-secret|abc123/, failure.error_message)
    assert_raises(NoMethodError) { failure.arguments }
  end

  test "degrades cleanly when queue storage is unavailable" do
    reader = FakeQueueReader.new(
      available: false,
      unavailable_detail: "Solid Queue tables are not prepared."
    )

    snapshot = InstanceOperationsSnapshot.new(queue_reader: reader)

    assert_equal :attention, snapshot.queue_status.status
    assert_match(/Solid Queue tables/, snapshot.queue_status.detail)
    assert_equal [], snapshot.queue_counts
    assert_equal [], snapshot.failed_jobs
  end

  test "reports backup coverage and redacted backup failures" do
    profile = InstanceBackupProfile.create!(
      name: "Readable backup",
      backup_kind: "readable_json",
      enabled: true,
      schedule: "daily",
      storage_path: "tmp/test-instance-backups",
      retention_count: 7
    )
    profile.instance_backup_runs.create!(
      backup_kind: profile.backup_kind,
      status: "succeeded",
      file_path: Rails.root.join("tmp/test-instance-backups/backup.json").to_s,
      file_size_bytes: 1234,
      checksum_sha256: "abc123",
      started_at: 2.hours.ago,
      finished_at: 90.minutes.ago
    )
    failed_run = profile.instance_backup_runs.create!(
      backup_kind: profile.backup_kind,
      status: "failed",
      error_message: "RuntimeError: write failed token=super-secret",
      started_at: 20.minutes.ago,
      finished_at: 19.minutes.ago
    )

    snapshot = InstanceOperationsSnapshot.new(queue_reader: FakeQueueReader.new(available: false))

    assert_equal :attention, snapshot.backup_status.status
    assert_match(/1 failed/, snapshot.backup_status.detail)
    assert_equal 1, snapshot.backup_profile_rows.length

    failure = snapshot.backup_failures.first
    assert_equal failed_run.id, failure.id
    assert_equal "Readable backup", failure.profile_name
    assert_includes failure.error_message, "[REDACTED]"
    assert_no_match(/super-secret/, failure.error_message)
  end

  test "reports smtp status and redacted mail failures" do
    reader = FakeQueueReader.new(
      available: true,
      counts: {
        ready_jobs: 0,
        scheduled_jobs: 0,
        claimed_jobs: 0,
        blocked_jobs: 0,
        failed_jobs: 2,
        worker_processes: 1
      },
      failed_jobs: [
        FailedJob.new(
          id: 21,
          class_name: "ActionMailer::MailDeliveryJob",
          queue_name: "mailers",
          failed_at: Time.zone.parse("2026-05-31 09:15:00"),
          error_message: "Net::SMTPAuthenticationError: bad credentials password=super-secret token=abc123"
        ),
        FailedJob.new(
          id: 22,
          class_name: "InstanceBackupJob",
          queue_name: "background",
          failed_at: Time.zone.parse("2026-05-31 09:16:00"),
          error_message: "RuntimeError: disk full"
        )
      ]
    )
    enabled_settings = Roastnode::RuntimeSettings.new(
      "SMTP_ENABLED" => "true",
      "SMTP_ADDRESS" => "smtp.example.test"
    )

    snapshot = InstanceOperationsSnapshot.new(queue_reader: reader, runtime_settings: enabled_settings)

    assert_equal :ok, snapshot.mail_status.status
    assert_match(/smtp.example.test/, snapshot.mail_status.detail)

    mail_failure = snapshot.mail_failures.first
    assert_equal 1, snapshot.mail_failures.length
    assert_equal 21, mail_failure.id
    assert_equal "ActionMailer::MailDeliveryJob", mail_failure.class_name
    assert_includes mail_failure.error_message, "[REDACTED]"
    assert_no_match(/super-secret|abc123/, mail_failure.error_message)

    disabled_snapshot = InstanceOperationsSnapshot.new(
      queue_reader: reader,
      runtime_settings: Roastnode::RuntimeSettings.new({})
    )

    assert_equal :attention, disabled_snapshot.mail_status.status
  end
end
