require "test_helper"

class CuppingRequests::ActivateTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @request = cupping_requests(:guest_espresso)
    @request.brew.update!(recipient_kind: "guest", recipient_name: "Alex")
    clear_enqueued_jobs
  end

  test "first access starts one 24 hour deadline and records one scheduled guest access" do
    now = Time.zone.parse("2026-08-28 12:00:00")
    deadline = now + 24.hours

    travel_to now do
      event = assert_activity_event(
        action: "brew.cupping_accessed",
        workspace: @request.workspace,
        actor: nil,
        subject: @request.brew
      ) do
        assert_enqueued_with(
          job: CuppingRequestExpirationJob,
          args: [ @request.id, deadline.iso8601(6) ],
          at: deadline
        ) do
          assert_equal @request, CuppingRequests::Activate.call(
            request: @request,
            ip_address: "2001:0db8:0:0:0:0:0:4"
          )
        end
      end

      assert_equal now, @request.reload.opened_at
      assert_equal deadline, @request.feedback_expires_at
      assert_equal "2001:db8::4", @request.last_guest_ip
      assert_nil event.actor
      assert_equal "guest", event.metadata.fetch("actor_kind")
      assert_equal "Alex", event.metadata.fetch("actor_label")
      assert_equal "2001:db8::4", event.metadata.fetch("ip_address")
    end
  end

  test "later access refreshes only the last IP without extending or duplicating activation" do
    first_access = Time.zone.parse("2026-08-28 12:00:00")
    deadline = first_access + 24.hours

    travel_to first_access do
      CuppingRequests::Activate.call(request: @request, ip_address: "203.0.113.4")
    end
    clear_enqueued_jobs

    travel_to first_access + 6.hours do
      assert_no_difference -> { ActivityEvent.where(action: "brew.cupping_accessed").count } do
        assert_no_enqueued_jobs do
          CuppingRequests::Activate.call(request: @request, ip_address: "203.0.113.9")
        end
      end
    end

    assert_equal first_access, @request.reload.opened_at
    assert_equal deadline, @request.feedback_expires_at
    assert_equal "203.0.113.9", @request.last_guest_ip
  end
end
