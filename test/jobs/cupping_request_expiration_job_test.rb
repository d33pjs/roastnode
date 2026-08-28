require "test_helper"

class CuppingRequestExpirationJobTest < ActiveJob::TestCase
  setup do
    @request = cupping_requests(:guest_espresso)
    @request.brew.update!(recipient_kind: "guest", recipient_name: "Alex")
    @opened_at = Time.zone.parse("2026-08-28 12:00:00")
    CuppingRequests::Activate.call(
      request: @request,
      ip_address: "203.0.113.4",
      now: @opened_at
    )
    @deadline = @request.reload.feedback_expires_at
    @expected_deadline = @deadline.iso8601(6)
  end

  test "closes at the expected deadline and records the authoritative occurrence time and last IP" do
    CuppingRequests::Activate.call(
      request: @request,
      ip_address: "203.0.113.18",
      now: @opened_at + 3.hours
    )

    travel_to @deadline + 2.hours do
      event = assert_activity_event(
        action: "brew.cupping_closed",
        workspace: @request.workspace,
        actor: nil,
        subject: @request.brew
      ) do
        CuppingRequestExpirationJob.perform_now(@request.id, @expected_deadline)
      end

      assert_equal @deadline, @request.reload.closed_at
      assert_equal @deadline, event.occurred_at
      assert_equal "guest", event.metadata.fetch("actor_kind")
      assert_equal "Alex", event.metadata.fetch("actor_label")
      assert_equal "203.0.113.18", event.metadata.fetch("ip_address")
    end
  end

  test "a duplicate close job is a no-op" do
    travel_to @deadline do
      CuppingRequestExpirationJob.perform_now(@request.id, @expected_deadline)

      assert_no_difference -> { ActivityEvent.where(action: "brew.cupping_closed").count } do
        CuppingRequestExpirationJob.perform_now(@request.id, @expected_deadline)
      end
    end

    assert_equal @deadline, @request.reload.closed_at
  end

  test "a stale deadline is a no-op" do
    replacement_deadline = @deadline + 1.hour
    @request.update!(feedback_expires_at: replacement_deadline)

    travel_to replacement_deadline + 1.hour do
      assert_no_difference -> { ActivityEvent.where(action: "brew.cupping_closed").count } do
        CuppingRequestExpirationJob.perform_now(@request.id, @expected_deadline)
      end
    end

    assert_nil @request.reload.closed_at
  end

  test "an early job is a no-op" do
    travel_to @deadline - 1.second do
      assert_no_difference -> { ActivityEvent.where(action: "brew.cupping_closed").count } do
        CuppingRequestExpirationJob.perform_now(@request.id, @expected_deadline)
      end
    end

    assert_nil @request.reload.closed_at
  end

  test "a job for a revoked request is a no-op" do
    @request.destroy!

    assert_no_difference -> { ActivityEvent.where(action: "brew.cupping_closed").count } do
      CuppingRequestExpirationJob.perform_now(@request.id, @expected_deadline)
    end
  end
end
