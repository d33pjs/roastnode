require "test_helper"
require Rails.root.join("db/migrate/20260828120000_create_cupping_requests")

class CreateCuppingRequestsTest < ActiveSupport::TestCase
  include PhotoTestHelper

  test "backfill creates capabilities for existing guest espressos" do
    brew = brews(:morning_espresso)
    brew.update!(recipient_kind: "guest", recipient_name: "Alex")
    attach_photo(brew)
    CuppingRequest.delete_all

    CreateCuppingRequests.new.send(:backfill_guest_espressos)

    request = CuppingRequest.find_by!(brew:)
    assert_equal brew.workspace, request.workspace
    assert request.token.present?
    assert_equal Digest::SHA256.hexdigest(request.token), request.token_digest
    assert_equal "espresso", request.snapshot.dig("brew", "method")
    assert_equal "guest", request.snapshot.dig("brew", "recipient", "kind")
    assert_equal [], request.snapshot.fetch("photos")
    assert_nil request.snapshot.dig("hero", "brew_photo_attachment_id")
  end

  test "schema enforces the feedback comment length limit" do
    request = cupping_requests(:guest_espresso)

    assert_raises(ActiveRecord::StatementInvalid) do
      request.update_column(:feedback_comment, "x" * 2_001)
    end
  end
end
