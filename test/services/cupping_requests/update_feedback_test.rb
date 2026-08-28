require "test_helper"
require "timeout"

class CuppingRequests::UpdateFeedbackTest < ActiveSupport::TestCase
  setup do
    @request = cupping_requests(:guest_espresso)
    @brew = @request.brew
    @brew.update!(recipient_kind: "guest", recipient_name: "Alex", taste_balance: "unknown", rating: nil)
    @opened_at = Time.zone.parse("2026-08-28 12:00:00")
    CuppingRequests::Activate.call(
      request: @request,
      ip_address: "203.0.113.4",
      now: @opened_at
    )
  end

  test "initial feedback updates authoritative data and emits one safe event per changed concern" do
    events = assert_activity_events(
      actions: %w[brew.cupping_taste_set brew.cupping_rating_set brew.cupping_comment_added],
      workspace: @request.workspace,
      actor: nil
    ) do
      assert_equal @request, CuppingRequests::UpdateFeedback.call(
        request: @request,
        attributes: { taste_balance: "sour", rating: "5", feedback_comment: "A private bright note" },
        ip_address: "2001:0db8::5",
        now: @opened_at + 1.hour
      )
    end

    assert_equal "sour", @brew.reload.taste_balance
    assert_equal 5, @brew.rating
    assert_equal "A private bright note", @request.reload.feedback_comment
    assert_equal "2001:db8::5", @request.last_guest_ip
    assert_equal "sour", @request.snapshot.dig("brew", "taste_balance")

    taste_event = events.find { |event| event.action == "brew.cupping_taste_set" }
    rating_event = events.find { |event| event.action == "brew.cupping_rating_set" }
    assert_equal "sour", taste_event.metadata.fetch("to_taste")
    assert_equal 5, rating_event.metadata.fetch("to_rating")
    events.each do |event|
      assert_equal @brew, event.subject
      assert_equal "guest", event.metadata.fetch("actor_kind")
      assert_equal "Alex", event.metadata.fetch("actor_label")
      assert_equal "2001:db8::5", event.metadata.fetch("ip_address")
      assert_no_match(/private bright note/i, event.metadata.to_json)
    end
  end

  test "later feedback emits changed and updated actions with safe old and new values" do
    update_feedback(taste_balance: "sour", rating: 5, feedback_comment: "First comment")

    events = assert_activity_events(
      actions: %w[brew.cupping_taste_changed brew.cupping_rating_changed brew.cupping_comment_updated],
      workspace: @request.workspace,
      actor: nil
    ) do
      update_feedback(taste_balance: "bitter", rating: 3, feedback_comment: "Replacement comment")
    end

    taste_event = events.find { |event| event.action == "brew.cupping_taste_changed" }
    rating_event = events.find { |event| event.action == "brew.cupping_rating_changed" }
    assert_equal [ "sour", "bitter" ], taste_event.metadata.values_at("from_taste", "to_taste")
    assert_equal [ 5, 3 ], rating_event.metadata.values_at("from_rating", "to_rating")
    assert_no_match(/First comment|Replacement comment/, events.map(&:metadata).to_json)
  end

  test "clearing taste and rating restores their empty states with explicit safe activity" do
    update_feedback(taste_balance: "bitter", rating: 3, feedback_comment: nil)

    events = assert_activity_events(
      actions: %w[brew.cupping_taste_cleared brew.cupping_rating_cleared],
      workspace: @request.workspace,
      actor: nil
    ) do
      update_feedback(taste_balance: "", rating: "", feedback_comment: nil)
    end

    assert_equal "unknown", @brew.reload.taste_balance
    assert_nil @brew.rating
    assert_equal "unknown", @request.reload.snapshot.dig("brew", "taste_balance")

    taste_event = events.find { |event| event.action == "brew.cupping_taste_cleared" }
    rating_event = events.find { |event| event.action == "brew.cupping_rating_cleared" }
    assert_equal "bitter", taste_event.metadata.fetch("from_taste")
    assert_equal 3, rating_event.metadata.fetch("from_rating")
    assert_not taste_event.metadata.key?("to_taste")
    assert_not rating_event.metadata.key?("to_rating")
  end

  test "unchanged feedback is silent but refreshes the last observed IP" do
    update_feedback(taste_balance: "neutral", rating: 4, feedback_comment: "Same comment")

    assert_no_difference -> { ActivityEvent.count } do
      update_feedback(
        taste_balance: "neutral",
        rating: 4,
        feedback_comment: "Same comment",
        ip_address: "203.0.113.12"
      )
    end

    assert_equal "203.0.113.12", @request.reload.last_guest_ip
  end

  test "accepts a 2000 character comment and rejects a longer comment atomically" do
    update_feedback(taste_balance: "neutral", rating: 4, feedback_comment: "a" * 2_000)
    original_snapshot = @request.reload.snapshot.deep_dup
    original_ip = @request.last_guest_ip

    assert_no_difference -> { ActivityEvent.count } do
      assert_raises(ActiveRecord::RecordInvalid) do
        update_feedback(
          taste_balance: "bitter",
          rating: 2,
          feedback_comment: "b" * 2_001,
          ip_address: "203.0.113.99"
        )
      end
    end

    assert_equal "neutral", @brew.reload.taste_balance
    assert_equal 4, @brew.rating
    assert_equal "a" * 2_000, @request.reload.feedback_comment
    assert_equal original_ip, @request.last_guest_ip
    assert_equal original_snapshot, @request.snapshot
  end

  test "cupping and ordinary public snapshot changes and events all roll back when a refresher fails" do
    brew_share = create_public_brew_share
    bean_share = create_public_bean_share
    originals = {
      request: @request.reload.snapshot.deep_dup,
      brew_share: brew_share.snapshot.deep_dup,
      bean_share: bean_share.snapshot.deep_dup
    }
    real_refresh = PublicBeanShareRefresher.method(:refresh_comparisons_for)
    failing_refresh = lambda do |record|
      real_refresh.call(record)
      raise "public bean refresh failed"
    end

    assert_no_difference -> { ActivityEvent.count } do
      with_stubbed_singleton_method(PublicBeanShareRefresher, :refresh_comparisons_for, failing_refresh) do
        assert_raises(RuntimeError) do
          update_feedback(taste_balance: "very_bitter", rating: 1, feedback_comment: "Must roll back")
        end
      end
    end

    assert_equal "unknown", @brew.reload.taste_balance
    assert_nil @brew.rating
    assert_nil @request.reload.feedback_comment
    assert_equal originals.fetch(:request), @request.snapshot
    assert_equal originals.fetch(:brew_share), brew_share.reload.snapshot
    assert_equal originals.fetch(:bean_share), bean_share.reload.snapshot
  end

  test "a submission at the exact deadline is rejected without writes or events" do
    original_snapshot = @request.reload.snapshot.deep_dup

    assert_no_difference -> { ActivityEvent.count } do
      assert_raises(CuppingRequests::FeedbackClosed) do
        update_feedback(
          taste_balance: "sour",
          rating: 5,
          feedback_comment: "Too late",
          now: @request.feedback_expires_at
        )
      end
    end

    assert_equal "unknown", @brew.reload.taste_balance
    assert_nil @brew.rating
    assert_nil @request.reload.feedback_comment
    assert_equal original_snapshot, @request.snapshot
  end

  private
    def update_feedback(taste_balance:, rating:, feedback_comment:, ip_address: "203.0.113.8", now: @opened_at + 2.hours)
      CuppingRequests::UpdateFeedback.call(
        request: @request,
        attributes: { taste_balance:, rating:, feedback_comment: },
        ip_address:,
        now:
      )
    end

    def create_public_brew_share
      @brew.create_public_brew_share!(
        workspace: @brew.workspace,
        created_by: @brew.user,
        updated_by: @brew.user,
        enabled: true,
        title: "Shared shot",
        selected_photo_attachment_ids: [],
        snapshot: PublicBrewShareSnapshotBuilder.new(
          brew: @brew,
          title: "Shared shot",
          selected_photo_attachment_ids: []
        ).call
      )
    end

    def create_public_bean_share
      bean = @brew.bean
      bean.create_public_bean_share!(
        workspace: bean.workspace,
        created_by: @brew.user,
        updated_by: @brew.user,
        enabled: true,
        title: "Shared bean",
        selected_photo_attachment_ids: [],
        snapshot: PublicBeanShareSnapshotBuilder.new(
          bean:,
          title: "Shared bean",
          selected_photo_attachment_ids: []
        ).call
      )
    end
end

class CuppingRequests::UpdateFeedbackLockTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    @request = cupping_requests(:guest_espresso)
    @brew = @request.brew
    @original_brew_attributes = @brew.attributes.slice("recipient_kind", "recipient_name", "taste_balance", "rating")
    @original_request_attributes = @request.attributes.slice(
      "opened_at", "feedback_expires_at", "closed_at", "last_guest_ip", "feedback_comment", "snapshot"
    )
    @brew.update!(recipient_kind: "guest", recipient_name: "Alex", taste_balance: "neutral", rating: 4)
    ActivityEvent.where(subject: @brew, action: Activity::EventContract::CUPPING_ACTIONS).delete_all
  end

  teardown do
    ActivityEvent.where(subject: @brew, action: Activity::EventContract::CUPPING_ACTIONS).delete_all if @brew
    @request&.update_columns(@original_request_attributes) if @original_request_attributes
    @brew&.update_columns(@original_brew_attributes) if @original_brew_attributes
  end

  test "a submission without injected time that waits past the deadline reads time after acquiring the row lock" do
    deadline = 2.seconds.from_now
    @request.update_columns(
      opened_at: Time.current,
      feedback_expires_at: deadline,
      closed_at: nil,
      last_guest_ip: "203.0.113.4",
      feedback_comment: nil
    )
    first_locked = Queue.new
    release_first = Queue.new
    second_lock_attempted = Queue.new
    result = Queue.new

    first = Thread.new do
      CuppingRequest.connection_pool.with_connection do
        CuppingRequest.find(@request.id).with_lock do
          first_locked << true
          release_first.pop
        end
      end
    end

    second = nil
    begin
      Timeout.timeout(5) { first_locked.pop }
      second = Thread.new do
        CuppingRequest.connection_pool.with_connection do
          request = CuppingRequest.find(@request.id)
          real_with_lock = request.method(:with_lock)
          request.define_singleton_method(:with_lock) do |*args, **kwargs, &block|
            second_lock_attempted << Time.current
            real_with_lock.call(*args, **kwargs, &block)
          end
          result << CuppingRequests::UpdateFeedback.call(
            request:,
            attributes: { taste_balance: "sour", rating: "5", feedback_comment: "Too late" },
            ip_address: "203.0.113.9"
          )
        end
      rescue StandardError => error
        result << error
      end

      assert_operator Timeout.timeout(5) { second_lock_attempted.pop }, :<, deadline
      Timeout.timeout(5) do
        sleep 0.01 while Time.current < deadline + 0.05
      end
    ensure
      release_first << true
      first.join
      second&.join
    end

    assert_instance_of CuppingRequests::FeedbackClosed, Timeout.timeout(5) { result.pop }
    assert_equal "neutral", @brew.reload.taste_balance
    assert_equal 4, @brew.rating
    assert_nil @request.reload.feedback_comment
  end
end
