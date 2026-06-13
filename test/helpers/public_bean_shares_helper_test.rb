require "test_helper"

class PublicBeanSharesHelperTest < ActionView::TestCase
  test "timeline events preserve time order while separating clustered brews" do
    timeline = {
      "opened_on" => "2026-06-01",
      "end_at" => "2026-06-02T00:00:00Z",
      "brews" => [
        { "occurred_at" => "2026-06-01T01:00:00Z", "method" => "espresso", "rating" => 4 },
        { "occurred_at" => "2026-06-01T01:00:00Z", "method" => "quick_drip", "rating" => 5 },
        { "occurred_at" => "2026-06-01T01:03:00Z", "method" => "espresso", "rating" => 3 },
        { "occurred_at" => "2026-06-01T20:00:00Z", "method" => "espresso", "rating" => 4 }
      ]
    }

    positions = public_bean_timeline_events(timeline).map { |event| event.fetch("display_position") }

    assert_equal positions.sort, positions
    assert_operator positions[1] - positions[0], :>=, PublicBeanSharesHelper::TIMELINE_CLUSTER_GAP_PERCENT
    assert_operator positions[2] - positions[1], :>=, PublicBeanSharesHelper::TIMELINE_CLUSTER_GAP_PERCENT
    assert_operator positions.first, :>, 0
    assert_operator positions.last, :<, 100
  end
end
