require "test_helper"
require "yaml"

class CuppingRequestExpirationRecoveryJobTest < ActiveJob::TestCase
  setup do
    @request = cupping_requests(:guest_espresso)
    @request.brew.update!(recipient_kind: "guest", recipient_name: "Alex")
    @opened_at = Time.zone.parse("2026-08-28 12:00:00")
    @deadline = @opened_at + 24.hours
    @request.update_columns(
      opened_at: @opened_at,
      feedback_expires_at: @deadline,
      expiration_job_enqueued_at: nil,
      expiration_job_enqueueing_at: nil,
      last_guest_ip: "203.0.113.4",
      closed_at: nil
    )
    ActivityEvent.where(subject: @request.brew, action: "brew.cupping_closed").delete_all
    clear_enqueued_jobs
  end

  teardown do
    clear_enqueued_jobs
    ActivityEvent.where(subject: @request.brew, action: "brew.cupping_closed").delete_all
    @request.update_columns(
      opened_at: nil,
      feedback_expires_at: nil,
      expiration_job_enqueued_at: nil,
      expiration_job_enqueueing_at: nil,
      last_guest_ip: nil,
      closed_at: nil
    )
  end

  test "sweep schedules an unscheduled future expiration and records its dispatch" do
    now = @opened_at + 2.hours

    travel_to now do
      assert_enqueued_with(
        job: CuppingRequestExpirationJob,
        args: [ @request.id, @deadline.iso8601(6) ],
        at: @deadline
      ) do
        CuppingRequestExpirationRecoveryJob.perform_now(now:)
      end
    end

    assert_equal now, @request.reload.expiration_job_enqueued_at
    assert_nil @request.closed_at
  end

  test "sweep skips a future expiration whose dispatch is already recorded" do
    dispatched_at = @opened_at + 1.minute
    @request.update_column(:expiration_job_enqueued_at, dispatched_at)

    travel_to @opened_at + 2.hours do
      assert_no_enqueued_jobs(only: CuppingRequestExpirationJob) do
        CuppingRequestExpirationRecoveryJob.perform_now
      end
    end

    assert_equal dispatched_at, @request.reload.expiration_job_enqueued_at
    assert_nil @request.closed_at
  end

  test "sweep recovers a future expiration after an abandoned dispatch lease expires" do
    now = @opened_at + 2.hours
    @request.update_column(
      :expiration_job_enqueueing_at,
      now - CuppingRequest::EXPIRATION_DISPATCH_LEASE - 1.second
    )

    travel_to now do
      assert_enqueued_with(job: CuppingRequestExpirationJob, at: @deadline) do
        CuppingRequestExpirationRecoveryJob.perform_now(now:)
      end
    end

    assert_equal now, @request.reload.expiration_job_enqueued_at
    assert_nil @request.expiration_job_enqueueing_at
  end

  test "sweep leaves an active dispatch lease for a future expiration alone" do
    now = @opened_at + 2.hours
    enqueueing_at = now - CuppingRequest::EXPIRATION_DISPATCH_LEASE + 1.second
    @request.update_column(:expiration_job_enqueueing_at, enqueueing_at)

    travel_to now do
      assert_no_enqueued_jobs(only: CuppingRequestExpirationJob) do
        CuppingRequestExpirationRecoveryJob.perform_now(now:)
      end
    end

    assert_nil @request.reload.expiration_job_enqueued_at
    assert_equal enqueueing_at, @request.expiration_job_enqueueing_at
  end

  test "sweep directly closes an expired request even when a dispatch was recorded" do
    @request.update_column(:expiration_job_enqueued_at, @opened_at)

    travel_to @deadline + 2.hours do
      event = assert_activity_event(
        action: "brew.cupping_closed",
        workspace: @request.workspace,
        actor: nil,
        subject: @request.brew
      ) do
        assert_no_enqueued_jobs(only: CuppingRequestExpirationJob) do
          CuppingRequestExpirationRecoveryJob.perform_now
        end
      end

      assert_equal @deadline, @request.reload.closed_at
      assert_equal @deadline, event.occurred_at
    end
  end

  test "repeated sweeps leave an expired request and its closure event unchanged" do
    travel_to @deadline + 2.hours do
      CuppingRequestExpirationRecoveryJob.perform_now

      assert_no_difference -> { ActivityEvent.where(action: "brew.cupping_closed", subject: @request.brew).count } do
        assert_no_enqueued_jobs(only: CuppingRequestExpirationJob) do
          CuppingRequestExpirationRecoveryJob.perform_now
        end
      end
    end

    assert_equal @deadline, @request.reload.closed_at
  end

  test "production recurring schedule runs the recovery sweep in the background queue" do
    recurring = YAML.load_file(Rails.root.join("config/recurring.yml")).fetch("production")
    task = recurring.fetch("cupping_request_expiration_recovery")

    assert_equal "CuppingRequestExpirationRecoveryJob", task.fetch("class")
    assert_equal "background", task.fetch("queue")
    assert_equal "every minute", task.fetch("schedule")
  end
end
