require "test_helper"

class CuppingRequestTest < ActiveSupport::TestCase
  test "only guest espresso requests are valid" do
    request = CuppingRequest.new(brew: brews(:morning_espresso), workspace: workspaces(:household))
    request.brew.update!(recipient_kind: "guest", recipient_name: "Alex")

    assert_predicate request, :valid?

    request.brew.update!(
      method: "quick_drip",
      machine: nil,
      brewer: equipment(:household_brewer),
      machine_cups: 6
    )

    assert_not_predicate request, :valid?
    assert_includes request.errors[:brew], "must be a guest espresso brew"
  end

  test "generates a token and finds eligible requests by its digest" do
    brew = brews(:morning_espresso)
    brew.update!(recipient_kind: "guest", recipient_name: "Alex")
    request = CuppingRequest.create!(brew:, workspace: brew.workspace)

    assert request.token.present?
    assert_equal Digest::SHA256.hexdigest(request.token), request.token_digest
    assert_equal request, CuppingRequest.find_by_token!(request.token)
    assert_raises(ActiveRecord::RecordNotFound) { CuppingRequest.find_by_token!("wrong") }
  end

  test "token lookup rejects a request whose workspace no longer matches its brew" do
    request = guest_request
    request.update_column(:workspace_id, workspaces(:household).id)

    assert_raises(ActiveRecord::RecordNotFound) { CuppingRequest.find_by_token!(request.token) }
  end

  test "feedback is open only after activation and before closure or expiry" do
    request = guest_request

    assert_not_predicate request, :feedback_open?

    request.update!(opened_at: Time.current, feedback_expires_at: 1.hour.from_now)
    assert_predicate request, :feedback_open?
    assert_not request.feedback_open?(at: 2.hours.from_now)

    request.update!(closed_at: Time.current)
    assert_not_predicate request, :feedback_open?
  end

  test "uses the bounded guest name or the Guest fallback label" do
    request = guest_request

    assert_equal "Alex", request.guest_label

    request.brew.update!(recipient_name: nil)
    assert_equal "Guest", request.guest_label
  end

  test "refreshes its safe snapshot without selecting record photos" do
    request = guest_request
    request.brew.update!(taste_balance: "sour")

    request.refresh_snapshot!

    assert_equal "sour", request.reload.snapshot.dig("brew", "taste_balance")
    assert_equal [], request.snapshot.fetch("photos")
    assert_nil request.snapshot.dig("hero", "brew_photo_attachment_id")
  end

  private
    def guest_request
      request = cupping_requests(:guest_espresso)
      request.brew.update!(recipient_kind: "guest", recipient_name: "Alex")
      request
    end
end
