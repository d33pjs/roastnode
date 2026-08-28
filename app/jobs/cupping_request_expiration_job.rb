require "time"

class CuppingRequestExpirationJob < ApplicationJob
  self.enqueue_after_transaction_commit = true

  around_enqueue do |job, enqueue|
    begin
      enqueue.call
    ensure
      job.send(:record_dispatch_result)
    end
  end

  attr_accessor :dispatch_started_at

  def self.schedule(request, dispatch_started_at:)
    job = new(request.id, request.feedback_expires_at.iso8601(6))
    job.dispatch_started_at = dispatch_started_at
    job.enqueue(wait_until: request.feedback_expires_at)
  end

  def perform(request_id, expected_deadline_iso8601)
    request = CuppingRequest.find_by(id: request_id)
    return unless request

    expected_deadline = Time.iso8601(expected_deadline_iso8601)
    request.with_lock do
      return if request.closed_at.present?
      return unless request.feedback_expires_at == expected_deadline
      return if Time.current < expected_deadline

      request.update!(closed_at: expected_deadline)
      Activity::Emitter.record!(
        action: "brew.cupping_closed",
        workspace: request.workspace,
        subject: request.brew,
        actor_kind: "guest",
        actor_label: request.guest_label,
        occurred_at: expected_deadline,
        details: { ip_address: request.last_guest_ip }
      )
    end
  end

  private
    def record_dispatch_result
      request_id, expected_deadline_iso8601 = arguments
      expected_deadline = Time.iso8601(expected_deadline_iso8601)
      recorded_at = Time.current
      dispatch = CuppingRequest.where(
        id: request_id,
        feedback_expires_at: expected_deadline,
        expiration_job_enqueueing_at: dispatch_started_at,
        closed_at: nil
      )

      if successfully_enqueued?
        dispatch.where(expiration_job_enqueued_at: nil).update_all(
          expiration_job_enqueued_at: recorded_at,
          expiration_job_enqueueing_at: nil,
          updated_at: recorded_at
        )
      else
        dispatch.update_all(expiration_job_enqueueing_at: nil, updated_at: recorded_at)
      end
    end
end
