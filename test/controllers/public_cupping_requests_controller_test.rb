require "test_helper"

class PublicCuppingRequestsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @cupping_request = cupping_requests(:guest_espresso)
    @brew = @cupping_request.brew
    @brew.update!(
      recipient_kind: "guest",
      recipient_name: "Private Guest Name",
      taste_balance: "neutral",
      rating: 4,
      notes: "Private brew notes must stay private."
    )
    @brew.bean.update!(
      purchase_price_cents: 876_543,
      purchase_url: "https://private.example.test/buy",
      coffee_origin_url: "https://private.example.test/origin"
    )
    @brew.record_links.create!(
      label: "Private brew link",
      url: "https://private.example.test/brew",
      kind: "info",
      visibility: "private",
      position: 0
    )
    @cupping_request.update_columns(
      opened_at: nil,
      feedback_expires_at: nil,
      expiration_job_enqueued_at: nil,
      expiration_job_enqueueing_at: nil,
      last_guest_ip: nil,
      closed_at: nil,
      feedback_comment: nil
    )
    @cupping_request.refresh_snapshot!
    clear_enqueued_jobs
  end

  teardown do
    clear_enqueued_jobs
  end

  test "first English access activates the request and renders snapshot feedback controls with a server deadline" do
    now = Time.zone.parse("2026-08-29 10:15:30")

    travel_to now do
      get public_cupping_request_path(@cupping_request.token),
        headers: { "HTTP_ACCEPT_LANGUAGE" => "en-US,en;q=0.9", "REMOTE_ADDR" => "203.0.113.10" }
    end

    assert_response :success
    assert_equal "en", response.headers["Content-Language"]
    assert_equal now + 24.hours, @cupping_request.reload.feedback_expires_at
    assert_select "[data-testid=public-cupping-page]"
    assert_select "[data-controller=cupping-countdown][data-cupping-countdown-deadline-value=?]",
      ((now + 24.hours).to_f * 1000).round.to_s
    assert_select "[data-cupping-countdown-target=value]", text: "24:00:00"
    assert_select "form[action=?]", public_cupping_feedback_path(@cupping_request.token)
    assert_select "input[type=radio][name=?]", "feedback[taste_balance]", count: 6
    assert_select "input[type=radio][name=?][value=unknown]", "feedback[taste_balance]"
    assert_select "input[type=radio][name=?]", "feedback[rating]", count: 6
    assert_select "input[type=radio][name=?][value='']", "feedback[rating]"
    assert_select "textarea[name=?][maxlength=2000]", "feedback[feedback_comment]"
    assert_select "body", text: /Share your tasting notes/
    assert_select "body", text: /Time remaining/
    assert_select "body", text: /No rating/
  end

  test "German browser preference localizes the complete public page and reused Hero copy" do
    get public_cupping_request_path(@cupping_request.token),
      headers: { "HTTP_ACCEPT_LANGUAGE" => "fr-FR;q=1,de-DE;q=0.9,en;q=0.7" }

    assert_response :success
    assert_equal "de", response.headers["Content-Language"]
    assert_select "body", text: /Deine Verkostung/
    assert_select "body", text: /Verbleibende Zeit/
    assert_select "body", text: /Noch unsicher/
    assert_select "body", text: /Keine Bewertung/
    assert_select "body", text: /Dosis/
    assert_select "body", text: /Mahlgrad/
    assert_select "body", text: /Ausgewogen/
    assert_no_match(/translation missing/i, response.body)
  end

  test "English wins when preferred over German and unsupported languages fall back to English" do
    get public_cupping_request_path(@cupping_request.token),
      headers: { "HTTP_ACCEPT_LANGUAGE" => "de;q=0.4,en-GB;q=0.8" }

    assert_response :success
    assert_equal "en", response.headers["Content-Language"]
    assert_select "body", text: /Share your tasting notes/

    get public_cupping_request_path(@cupping_request.token),
      headers: { "HTTP_ACCEPT_LANGUAGE" => "fr-FR,es;q=0.8" }

    assert_response :success
    assert_equal "en", response.headers["Content-Language"]
    assert_select "body", text: /Share your tasting notes/
  end

  test "renders only stored snapshot presentation and omits private data and raw media details" do
    avatar = attach_named_photo(@brew.user, :avatar, filename: "logger-secret-name.jpg")
    @cupping_request.refresh_snapshot!
    stored_title = @cupping_request.snapshot.fetch("title")
    stored_bean_name = @cupping_request.snapshot.dig("bean", "name")

    @brew.update_columns(dose_grams: 99, notes: "Changed live private note")
    @brew.bean.update_columns(name: "Changed live bean", purchase_price_cents: 999_999)
    @brew.workspace.update_columns(name: "Changed live household")

    get public_cupping_request_path(@cupping_request.token)

    assert_response :success
    assert_select "body", text: /#{Regexp.escape(stored_title)}/
    assert_select "body", text: /#{Regexp.escape(stored_bean_name)}/
    assert_select "[data-testid=public-brew-dose]", text: /18g/
    assert_no_match(/Changed live bean|Changed live household|Changed live private note/, response.body)
    assert_no_match(/Private brew notes|Private Guest Name|one@example.com|two@example.com/, response.body)
    assert_no_match(/Private brew link|private\.example\.test|876[,.]543|999[,.]999/, response.body)
    assert_no_match(/logger-secret-name\.jpg|rails\/active_storage|media_attachments/, response.body)
    assert_no_match(%r{/media/#{avatar.id}(?:\D|\z)}, response.body)
  end

  test "accepted feedback updates taste rating and private comment and shows localized confirmation" do
    get public_cupping_request_path(@cupping_request.token),
      headers: { "REMOTE_ADDR" => "203.0.113.10" }

    patch public_cupping_feedback_path(@cupping_request.token), params: {
      feedback: { taste_balance: "very_sour", rating: "5", feedback_comment: "Bright and clean" }
    }, headers: { "REMOTE_ADDR" => "203.0.113.11" }

    assert_redirected_to public_cupping_request_path(@cupping_request.token)
    assert_equal "very_sour", @brew.reload.taste_balance
    assert_equal 5, @brew.rating
    assert_equal "Bright and clean", @cupping_request.reload.feedback_comment
    follow_redirect!
    assert_select "body", text: /Feedback saved/
  end

  test "explicit unknown taste and no-rating controls clear earlier feedback" do
    @brew.update!(taste_balance: "very_bitter", rating: 5)
    @cupping_request.refresh_snapshot!
    open_feedback_window!

    patch public_cupping_feedback_path(@cupping_request.token), params: {
      feedback: { taste_balance: "unknown", rating: "", feedback_comment: "" }
    }

    assert_redirected_to public_cupping_request_path(@cupping_request.token)
    assert_equal "unknown", @brew.reload.taste_balance
    assert_nil @brew.rating
    assert_nil @cupping_request.reload.feedback_comment
  end

  test "invalid feedback rerenders localized controls without committing any field" do
    open_feedback_window!
    original_snapshot = @cupping_request.snapshot.deep_dup

    patch public_cupping_feedback_path(@cupping_request.token), params: {
      feedback: { taste_balance: "very_bitter", rating: "1", feedback_comment: "x" * 2_001 }
    }, headers: { "HTTP_ACCEPT_LANGUAGE" => "de" }

    assert_response :unprocessable_entity
    assert_select "body", text: /Feedback konnte nicht gespeichert werden/
    assert_select "textarea[name=?]", "feedback[feedback_comment]", text: "x" * 2_001
    assert_equal "neutral", @brew.reload.taste_balance
    assert_equal 4, @brew.rating
    assert_nil @cupping_request.reload.feedback_comment
    assert_equal original_snapshot, @cupping_request.snapshot
  end

  test "expired requests remain readable but replace the form and reject writes authoritatively" do
    deadline = 1.second.ago
    @cupping_request.update!(opened_at: 24.hours.ago, feedback_expires_at: deadline)
    original_snapshot = @cupping_request.snapshot.deep_dup

    get public_cupping_request_path(@cupping_request.token)

    assert_response :success
    assert_select "[data-testid=public-brew-hero-card]"
    assert_select "[data-testid=cupping-feedback-form]", count: 0
    assert_select "[data-testid=cupping-feedback-expired]", text: /feedback window has expired/i

    patch public_cupping_feedback_path(@cupping_request.token), params: {
      feedback: { taste_balance: "very_sour", rating: "5", feedback_comment: "Too late" }
    }

    assert_response :unprocessable_entity
    assert_select "[data-testid=cupping-feedback-form]", count: 0
    assert_select "[data-testid=cupping-feedback-expired]", text: /feedback window has expired/i
    assert_equal "neutral", @brew.reload.taste_balance
    assert_equal 4, @brew.rating
    assert_nil @cupping_request.reload.feedback_comment
    assert_equal original_snapshot, @cupping_request.snapshot
  end

  test "feedback writes are limited to 20 per ten minutes for each token digest and remote IP" do
    ActionController::Base.cache_store.clear
    open_feedback_window!
    cache_keys = []
    callback = lambda do |_name, _started, _finished, _unique_id, payload|
      cache_keys << payload.fetch(:cache_key)
    end
    params = { feedback: { taste_balance: "neutral", rating: "4", feedback_comment: "" } }

    ActiveSupport::Notifications.subscribed(callback, "rate_limit.action_controller") do
      20.times do
        patch public_cupping_feedback_path(@cupping_request.token), params:,
          headers: { "REMOTE_ADDR" => "203.0.113.40" }
        assert_response :redirect
      end

      patch public_cupping_feedback_path(@cupping_request.token), params:,
        headers: { "REMOTE_ADDR" => "203.0.113.40" }
    end

    assert_response :too_many_requests
    assert_select "body", text: /Too many feedback attempts/
    assert_equal 1, cache_keys.length
    assert_not_includes cache_keys.first, @cupping_request.token
    assert_includes cache_keys.first, CuppingRequest.token_digest_for(@cupping_request.token)
    assert_includes cache_keys.first, "203.0.113.40"
  ensure
    ActionController::Base.cache_store.clear
  end

  test "unknown malformed revoked and ineligible bearer URLs return not found" do
    get public_cupping_request_path("not a real bearer")
    assert_response :not_found

    token = @cupping_request.token
    @brew.update_columns(recipient_kind: "self", recipient_name: nil)
    get public_cupping_request_path(token)
    assert_response :not_found

    @brew.update_columns(recipient_kind: "guest", recipient_name: "Private Guest Name")
    @brew.update_column(:method, "quick_drip")
    get public_cupping_request_path(token)
    assert_response :not_found

    @brew.update_column(:method, "espresso")
    @cupping_request.destroy!
    get public_cupping_request_path(token)
    assert_response :not_found
  end

  test "activation failures render a generic unavailable response without leaking exception details" do
    leaked_token = @cupping_request.token
    failure = lambda do |**|
      raise "activation failed for #{leaked_token} and Private Guest Name"
    end

    with_stubbed_singleton_method(CuppingRequests::Activate, :call, failure) do
      get public_cupping_request_path(@cupping_request.token)
    end

    assert_response :not_found
    assert_empty response.body
    assert_no_match(/activation failed|Private Guest Name/, response.body)
  end

  test "cupping request paths and redirects redact bearer tokens and media handles from logs" do
    media_handle = "opaque-media-handle"
    request = ActionDispatch::Request.new(
      Rack::MockRequest.env_for("/c/#{@cupping_request.token}/media/#{media_handle}?token=secret")
    )
    request.set_header("action_dispatch.parameter_filter", Rails.application.config.filter_parameters)

    assert_equal "/c/[FILTERED]/media/[FILTERED]?token=[FILTERED]", request.filtered_path
    assert_equal "[FILTERED]", request.parameter_filter.filter(media_id: media_handle).fetch(:media_id)

    open_feedback_window!
    patch public_cupping_feedback_path(@cupping_request.token), params: {
      feedback: { taste_balance: "neutral", rating: "4", feedback_comment: "" }
    }

    assert_redirected_to public_cupping_request_path(@cupping_request.token)
    assert_equal "[FILTERED]", response.filtered_location
  end

  private
    def open_feedback_window!
      now = Time.current
      @cupping_request.update!(
        opened_at: now,
        feedback_expires_at: now + 1.hour,
        closed_at: nil,
        last_guest_ip: "203.0.113.1"
      )
    end
end
