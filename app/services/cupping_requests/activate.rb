require "ipaddr"

module CuppingRequests
  class Activate
    FEEDBACK_WINDOW = 24.hours

    def self.call(request:, ip_address:, now: Time.current)
      new(request:, ip_address:, now:).call
    end

    def initialize(request:, ip_address:, now:)
      @request = request
      @ip_address = IPAddr.new(ip_address.to_s.strip).to_s
      @now = now
    end

    def call
      request.with_lock do
        if request.opened_at.blank?
          activate!
        else
          request.update!(last_guest_ip: ip_address)
        end

        request
      end
    end

    private
      attr_reader :request, :ip_address, :now

      def activate!
        deadline = now + FEEDBACK_WINDOW
        request.update!(
          opened_at: now,
          feedback_expires_at: deadline,
          last_guest_ip: ip_address
        )
        Activity::Emitter.record!(
          action: "brew.cupping_accessed",
          workspace: request.workspace,
          subject: request.brew,
          actor_kind: "guest",
          actor_label: request.guest_label,
          occurred_at: now,
          details: { ip_address: }
        )
        CuppingRequestExpirationJob
          .set(wait_until: deadline)
          .perform_later(request.id, deadline.iso8601(6))
      end
  end
end
