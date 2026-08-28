require "test_helper"

class AddCuppingRequestExpirationDispatchTest < ActiveSupport::TestCase
  test "schema stores successful expiration dispatches and indexes open deadlines for recovery" do
    column = CuppingRequest.columns_hash.fetch("expiration_job_enqueued_at")
    lease_column = CuppingRequest.columns_hash.fetch("expiration_job_enqueueing_at")
    index = CuppingRequest.connection.indexes(:cupping_requests)
      .find { |candidate| candidate.name == "index_cupping_requests_on_open_expiration" }

    assert_equal :datetime, column.type
    assert_equal :datetime, lease_column.type
    assert_not_nil index
    assert_equal [ "feedback_expires_at" ], index.columns
    assert_match(/opened_at IS NOT NULL/, index.where)
    assert_match(/closed_at IS NULL/, index.where)
  end
end
