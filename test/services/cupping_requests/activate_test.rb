require "test_helper"
require "timeout"

class CuppingRequests::ActivateTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  self.use_transactional_tests = false

  setup do
    @request = cupping_requests(:guest_espresso)
    @original_brew_attributes = @request.brew.attributes.slice("recipient_kind", "recipient_name")
    reset_request!
    @request.brew.update!(recipient_kind: "guest", recipient_name: "Alex")
    delete_cupping_activity!
    clear_enqueued_jobs
  end

  teardown do
    clear_enqueued_jobs
    delete_cupping_activity!
    reset_request!
    @request.brew.update_columns(@original_brew_attributes) if @original_brew_attributes
  end

  test "first access starts one 24 hour deadline and records one scheduled guest access" do
    now = Time.zone.parse("2026-08-28 12:00:00")
    deadline = now + 24.hours

    travel_to now do
      event = nil
      assert_enqueued_jobs(1, only: CuppingRequestExpirationJob) do
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
      end

      assert_equal now, @request.reload.opened_at
      assert_equal deadline, @request.feedback_expires_at
      assert_equal now, @request.expiration_job_enqueued_at
      assert_nil @request.expiration_job_enqueueing_at
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
    assert_equal first_access, @request.expiration_job_enqueued_at
    assert_nil @request.expiration_job_enqueueing_at
    assert_equal "203.0.113.9", @request.last_guest_ip
  end

  test "a failed expiration enqueue leaves activation committed and returns the request" do
    now = Time.zone.parse("2026-08-28 12:00:00")
    adapter = CuppingRequestExpirationJob.queue_adapter
    enqueue_failure = ->(*) { raise SolidQueue::Job::EnqueueError, "queue unavailable" }

    travel_to now do
      assert_no_enqueued_jobs do
        with_stubbed_singleton_method(adapter, :enqueue_at, enqueue_failure) do
          assert_equal @request, CuppingRequests::Activate.call(request: @request, ip_address: "203.0.113.4")
        end
      end
    end

    assert_equal now, @request.reload.opened_at
    assert_equal now + 24.hours, @request.feedback_expires_at
    assert_nil @request.expiration_job_enqueued_at
    assert_nil @request.expiration_job_enqueueing_at
    assert_equal "203.0.113.4", @request.last_guest_ip
    assert_equal 1, ActivityEvent.where(action: "brew.cupping_accessed", subject: @request.brew).count
  end

  test "later access retries a failed expiration dispatch without duplicating activation" do
    first_access = Time.zone.parse("2026-08-28 12:00:00")
    later_access = first_access + 1.minute
    deadline = first_access + 24.hours
    adapter = CuppingRequestExpirationJob.queue_adapter
    enqueue_failure = ->(*) { raise SolidQueue::Job::EnqueueError, "queue unavailable" }

    travel_to first_access do
      with_stubbed_singleton_method(adapter, :enqueue_at, enqueue_failure) do
        assert_equal @request, CuppingRequests::Activate.call(request: @request, ip_address: "203.0.113.4")
      end
    end

    travel_to later_access do
      assert_enqueued_with(
        job: CuppingRequestExpirationJob,
        args: [ @request.id, deadline.iso8601(6) ],
        at: deadline
      ) do
        CuppingRequests::Activate.call(request: @request, ip_address: "203.0.113.9")
      end
    end

    assert_equal first_access, @request.reload.opened_at
    assert_equal deadline, @request.feedback_expires_at
    assert_equal later_access, @request.expiration_job_enqueued_at
    assert_nil @request.expiration_job_enqueueing_at
    assert_equal "203.0.113.9", @request.last_guest_ip
    assert_equal 1, ActivityEvent.where(action: "brew.cupping_accessed", subject: @request.brew).count
  end

  test "a surrounding transaction rollback leaves no activation or orphaned expiration job" do
    now = Time.zone.parse("2026-08-28 12:00:00")

    assert_no_enqueued_jobs do
      error = assert_raises(RuntimeError) do
        CuppingRequest.transaction do
          CuppingRequests::Activate.call(request: @request, ip_address: "203.0.113.4", now:)
          raise "roll back activation"
        end
      end
      assert_match(/roll back activation/, error.message)
    end

    assert_nil @request.reload.opened_at
    assert_nil @request.feedback_expires_at
    assert_nil @request.last_guest_ip
    assert_not ActivityEvent.exists?(action: "brew.cupping_accessed", subject: @request.brew)
  end

  test "expiration enqueue waits for the activation transaction to commit" do
    now = Time.zone.parse("2026-08-28 12:00:00")

    CuppingRequest.transaction do
      CuppingRequests::Activate.call(request: @request, ip_address: "203.0.113.4", now:)
      assert_enqueued_jobs 0, only: CuppingRequestExpirationJob
    end

    assert_enqueued_jobs 1, only: CuppingRequestExpirationJob
  end

  test "competing connections serialize first activation into one deadline event and scheduled job" do
    now = Time.zone.parse("2026-08-28 12:00:00")
    deadline = now + 24.hours
    first_locked = Queue.new
    release_first = Queue.new
    second_started = Queue.new
    second_pid = Queue.new
    results = Queue.new

    first = Thread.new do
      CuppingRequest.connection_pool.with_connection do
        competing_request = CuppingRequest.find(@request.id)
        competing_request.with_lock do
          first_locked << true
          release_first.pop
          results << CuppingRequests::Activate.call(
            request: competing_request, ip_address: "203.0.113.4", now:
          )
        end
      end
    rescue StandardError => error
      results << error
    end

    second = nil
    begin
      Timeout.timeout(5) { first_locked.pop }
      second = Thread.new do
        CuppingRequest.connection_pool.with_connection do |connection|
          second_pid << connection.select_value("SELECT pg_backend_pid()")
          second_started << true
          competing_request = CuppingRequest.find(@request.id)
          results << CuppingRequests::Activate.call(
            request: competing_request, ip_address: "203.0.113.9", now: now + 1.second
          )
        end
      rescue StandardError => error
        results << error
      end
      Timeout.timeout(5) { second_started.pop }
      assert_connection_waits_for_lock!(Timeout.timeout(5) { second_pid.pop })
    ensure
      release_first << true
      first.join
      second&.join
    end

    outcomes = 2.times.map { Timeout.timeout(5) { results.pop } }
    assert outcomes.all? { |outcome| outcome.is_a?(CuppingRequest) }, outcomes.inspect
    assert_equal now, @request.reload.opened_at
    assert_equal deadline, @request.feedback_expires_at
    assert_equal 1, ActivityEvent.where(action: "brew.cupping_accessed", subject: @request.brew).count
    assert_enqueued_jobs 1, only: CuppingRequestExpirationJob
    assert_enqueued_with(
      job: CuppingRequestExpirationJob,
      args: [ @request.id, deadline.iso8601(6) ],
      at: deadline
    )
  end

  private
    def assert_connection_waits_for_lock!(backend_pid)
      Timeout.timeout(5) do
        loop do
          wait_type = ActiveRecord::Base.connection.select_value(<<~SQL.squish)
            SELECT wait_event_type
            FROM pg_stat_activity
            WHERE pid = #{Integer(backend_pid)}
          SQL
          break if wait_type == "Lock"

          sleep 0.01
        end
      end
    end

    def delete_cupping_activity!
      return unless @request

      ActivityEvent.where(subject: @request.brew, action: Activity::EventContract::CUPPING_ACTIONS).delete_all
    end

    def reset_request!
      return unless @request

      @request.update_columns(
        opened_at: nil,
        feedback_expires_at: nil,
        expiration_job_enqueued_at: nil,
        expiration_job_enqueueing_at: nil,
        last_guest_ip: nil,
        closed_at: nil,
        feedback_comment: nil
      )
    end
end
