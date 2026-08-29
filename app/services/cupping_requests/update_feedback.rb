require "ipaddr"

module CuppingRequests
  class UpdateFeedback
    FEEDBACK_KEYS = %i[taste_balance rating feedback_comment].freeze
    TASTE_VALUES = Brew.taste_balances.keys.freeze
    RATING_VALUES = (1..5).map(&:to_s).freeze

    class InvalidFeedback < StandardError; end
    class PersistenceError < StandardError
      attr_reader :diagnostic_class

      def initialize(error)
        @diagnostic_class = error.class.name.to_s.presence || "StandardError"
        super("Cupping feedback could not be persisted")
      end
    end

    def self.call(request:, attributes:, ip_address:, now: nil)
      new(request:, attributes:, ip_address:, now:).call
    end

    def initialize(request:, attributes:, ip_address:, now:)
      @request = request
      @attributes = attributes.to_h.symbolize_keys.slice(*FEEDBACK_KEYS)
      @attributes[:taste_balance] = normalize_taste_balance(@attributes[:taste_balance]) if @attributes.key?(:taste_balance)
      @attributes[:rating] = normalize_rating(@attributes[:rating]) if @attributes.key?(:rating)
      @attributes[:feedback_comment] = @attributes[:feedback_comment].presence if @attributes.key?(:feedback_comment)
      @ip_address = IPAddr.new(ip_address.to_s.strip).to_s
      @injected_now = now
    end

    def call
      request.with_lock do
        @now = injected_now || Time.current
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
    rescue FeedbackClosed, InvalidFeedback, ActiveRecord::RecordInvalid
      raise
    rescue StandardError => error
      raise PersistenceError.new(error), cause: nil
    end

    private
      attr_reader :request, :attributes, :ip_address, :injected_now, :now

      def normalize_taste_balance(value)
        value = value.to_s.presence || "unknown"
        raise InvalidFeedback unless TASTE_VALUES.include?(value)

        value
      end

      def normalize_rating(value)
        return if value.nil? || value == ""

        value = value.to_s
        raise InvalidFeedback unless RATING_VALUES.include?(value)

        value.to_i
      end

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
        if to == "unknown"
          emit_event("brew.cupping_taste_cleared", brew:, details: { from_taste: from })
        elsif from.blank? || from == "unknown"
          emit_event("brew.cupping_taste_set", brew:, details: { to_taste: to })
        else
          emit_event("brew.cupping_taste_changed", brew:, details: { from_taste: from, to_taste: to })
        end
      end

      def emit_rating_event(from, to, brew:)
        if to.nil?
          emit_event("brew.cupping_rating_cleared", brew:, details: { from_rating: from })
        elsif from.nil?
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
