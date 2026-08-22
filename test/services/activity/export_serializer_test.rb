require "test_helper"

class Activity::ExportSerializerTest < ActiveSupport::TestCase
  test "serializes the complete safe restore contract" do
    event = activity_events(:morning_brew_created)
    payload = Activity::ExportSerializer.call(event)

    assert_equal %i[action actor_id category created_at id metadata occurred_at subject_id subject_type updated_at visibility workspace_id], payload.keys.sort
    assert_equal event.occurred_at.iso8601, payload.fetch(:occurred_at)
    assert_equal event.metadata, payload.fetch(:metadata)
    assert_not_same event.metadata, payload.fetch(:metadata)
    assert_no_match(/password|digest|token|signed_id|attachment|filename|file_path|https?:\/\//i, payload.fetch(:metadata).to_json)
  end
end
