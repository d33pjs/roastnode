require "ipaddr"

module CuppingRequests
  class UpdateFeedback
    FEEDBACK_KEYS = %i[taste_balance rating feedback_comment].freeze

    def self.call(request:, attributes:, ip_address:, now: Time.current)
      new(request:, attributes:, ip_address:, now:).call
    end

    def initialize(request:, attributes:, ip_address:, now:)
      @request = request
      @attributes = attributes.to_h.symbolize_keys.slice(*FEEDBACK_KEYS)
      @attributes[:feedback_comment] = @attributes[:feedback_comment].presence if @attributes.key?(:feedback_comment)
      @ip_address = IPAddr.new(ip_address.to_s.strip).to_s
      @now = now
    end

    def call
      request.with_lock do
        raise FeedbackClosed unless request.feedback_open?(at: now)

        brew = request.brew.reload
        old = {
          taste: brew.taste_balance,
          rating: brew.rating,
          comment: request.feedback_comment
        }
        brew.update!(attributes.slice(:taste_balance, :rating))
        request.update!(attributes.slice(:feedback_comment).merge(last_guest_ip: ip_address))
        request.refresh_snapshot!
        PublicBrewShareRefresher.refresh_for(brew)
        PublicBeanShareRefresher.refresh_comparisons_for(brew)
        emit_changed_events(old:, brew:)
        request
      end
    end

    private
      attr_reader :request, :attributes, :ip_address, :now

      def emit_changed_events(old:, brew:)
        emit_taste_event(old.fetch(:taste), brew.taste_balance, brew:) if old.fetch(:taste) != brew.taste_balance
        emit_rating_event(old.fetch(:rating), brew.rating, brew:) if old.fetch(:rating) != brew.rating
        if old.fetch(:comment) != request.feedback_comment
          emit_event(
            old.fetch(:comment).blank? ? "brew.cupping_comment_added" : "brew.cupping_comment_updated",
            brew:
          )
        end
      end

      def emit_taste_event(from, to, brew:)
        if from.blank? || from == "unknown"
          emit_event("brew.cupping_taste_set", brew:, details: { to_taste: to })
        else
          emit_event("brew.cupping_taste_changed", brew:, details: { from_taste: from, to_taste: to })
        end
      end

      def emit_rating_event(from, to, brew:)
        if from.nil?
          emit_event("brew.cupping_rating_set", brew:, details: { to_rating: to })
        else
          emit_event("brew.cupping_rating_changed", brew:, details: { from_rating: from, to_rating: to })
        end
      end

      def emit_event(action, brew:, details: {})
        Activity::Emitter.record!(
          action:,
          workspace: request.workspace,
          subject: brew,
          actor_kind: "guest",
          actor_label: request.guest_label,
          occurred_at: now,
          details: details.merge(ip_address:)
        )
      end
  end
end
