require "test_helper"

class CuppingRequests::SynchronizeTest < ActiveSupport::TestCase
  test "synchronize creates for guest espresso and revokes after recipient change" do
    brew = brews(:morning_espresso)
    brew.update!(recipient_kind: "guest", recipient_name: "Alex")

    assert_difference -> { CuppingRequest.count }, 1 do
      CuppingRequests::Synchronize.call(brew)
    end

    request = brew.reload.cupping_request
    assert_equal brew.workspace, request.workspace
    assert_equal "neutral", request.snapshot.dig("brew", "taste_balance")

    brew.update!(recipient_kind: "self", recipient_name: nil)

    assert_difference -> { CuppingRequest.count }, -1 do
      CuppingRequests::Synchronize.call(brew)
    end
  end

  test "synchronize does not create for self, household member, or quick drip brews" do
    brew = brews(:morning_espresso)

    assert_no_difference -> { CuppingRequest.count } do
      CuppingRequests::Synchronize.call(brew)
    end

    brew.update!(recipient_kind: "household_member", recipient_user: users(:two))
    assert_no_difference -> { CuppingRequest.count } do
      CuppingRequests::Synchronize.call(brew)
    end

    brew.update!(
      recipient_kind: "guest",
      recipient_name: "Alex",
      method: "quick_drip",
      machine: nil,
      brewer: equipment(:household_brewer),
      machine_cups: 6
    )
    assert_no_difference -> { CuppingRequest.count } do
      CuppingRequests::Synchronize.call(brew)
    end
  end

  test "synchronize returns the existing request without replacing its token" do
    request = cupping_requests(:guest_espresso)
    request.brew.update!(recipient_kind: "guest", recipient_name: "Alex")

    assert_equal request, CuppingRequests::Synchronize.call(request.brew)
    assert_equal request.token, request.reload.token
  end

  test "synchronize creates a fresh request when an in-memory association was revoked and the brew becomes eligible again" do
    brew = brews(:morning_espresso)
    brew.update!(recipient_kind: "guest", recipient_name: "Alex")
    CuppingRequests::Synchronize.call(brew)
    cached_request = brew.cupping_request

    brew.update!(recipient_kind: "self", recipient_name: nil)
    CuppingRequests::Synchronize.call(brew)
    assert_predicate cached_request, :destroyed?

    brew.update!(recipient_kind: "guest", recipient_name: "Alex")
    replacement_request = CuppingRequests::Synchronize.call(brew)

    assert_not_predicate replacement_request, :destroyed?
    assert_equal brew, replacement_request.brew
    assert_equal replacement_request, brew.reload.cupping_request
  end
end
