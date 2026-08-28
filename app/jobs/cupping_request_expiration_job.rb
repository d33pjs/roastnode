require "time"

class CuppingRequestExpirationJob < ApplicationJob
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
end
