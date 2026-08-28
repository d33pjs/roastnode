class CuppingRequestExpirationRecoveryJob < ApplicationJob
  queue_as :background

  def perform(now: Time.current)
    close_expired_requests(now)
    schedule_future_requests(now)
  end

  private
    def close_expired_requests(now)
      CuppingRequest
        .where(closed_at: nil, feedback_expires_at: ..now)
        .where.not(opened_at: nil)
        .find_each do |request|
          CuppingRequestExpirationJob.perform_now(
            request.id,
            request.feedback_expires_at.iso8601(6)
          )
        end
    end

    def schedule_future_requests(now)
      CuppingRequest
        .where(closed_at: nil, expiration_job_enqueued_at: nil)
        .where.not(opened_at: nil)
        .where("feedback_expires_at > ?", now)
        .where(
          "expiration_job_enqueueing_at IS NULL OR expiration_job_enqueueing_at <= ?",
          now - CuppingRequest::EXPIRATION_DISPATCH_LEASE
        )
        .find_each do |request|
          request.with_lock do
            next unless request.expiration_dispatch_pending?(at: now)

            dispatch_started_at = request.claim_expiration_dispatch!(at: now)
            CuppingRequestExpirationJob.schedule(request, dispatch_started_at:)
          end
        end
    end
end
