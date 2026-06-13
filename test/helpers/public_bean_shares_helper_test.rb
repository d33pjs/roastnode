require "test_helper"

class PublicBeanSharesHelperTest < ActionView::TestCase
  test "timeline items cluster nearby brews and preserve relative order" do
    timeline = {
      "opened_on" => "2026-06-01",
      "end_at" => "2026-06-10T00:00:00Z",
      "brews" => [
        { "occurred_at" => "2026-06-01T01:00:00Z", "method" => "espresso", "rating" => 0 },
        { "occurred_at" => "2026-06-01T01:00:00Z", "method" => "quick_drip", "rating" => 0 },
        { "occurred_at" => "2026-06-01T01:03:00Z", "method" => "espresso", "rating" => 1 },
        { "occurred_at" => "2026-06-01T01:06:00Z", "method" => "espresso", "rating" => 5 },
        { "occurred_at" => "2026-06-05T12:00:00Z", "method" => "espresso", "rating" => 3 },
        { "occurred_at" => "2026-06-09T09:00:00Z", "method" => "quick_drip", "rating" => 4 }
      ]
    }

    items = public_bean_timeline_items(timeline)
    positions = items.map { |item| item.fetch("display_position") }
    cluster = items.first

    assert_equal positions.sort, positions
    assert_equal "cluster", cluster.fetch("type")
    assert_equal 4, cluster.fetch("count")
    assert_equal [ 0, 0, 1, 5 ], cluster.fetch("ratings")
    assert_equal %w[espresso quick_drip espresso espresso], cluster.fetch("methods")
    assert_operator positions.first, :>, 0
    assert_operator positions.last, :<, 100
  end

  test "timeline items carry label lane placement for dense readable labels" do
    timeline = {
      "opened_on" => "2026-05-21",
      "end_at" => "2026-05-22T00:00:00Z",
      "brews" => [
        { "occurred_at" => "2026-05-21T02:00:00Z", "method" => "espresso", "rating" => 1 },
        { "occurred_at" => "2026-05-21T03:24:00Z", "method" => "espresso", "rating" => 3 },
        { "occurred_at" => "2026-05-21T04:48:00Z", "method" => "espresso", "rating" => 2 },
        { "occurred_at" => "2026-05-21T06:12:00Z", "method" => "quick_drip", "rating" => 2 },
        { "occurred_at" => "2026-05-21T07:36:00Z", "method" => "espresso", "rating" => 3 },
        { "occurred_at" => "2026-05-21T09:00:00Z", "method" => "espresso", "rating" => 2 }
      ]
    }

    items = public_bean_timeline_items(timeline)

    assert items.all? { |item| %w[top bottom].include?(item.fetch("label_side")) }
    assert items.all? { |item| item.fetch("label_lane").is_a?(Integer) }
    assert_operator items.map { |item| item.fetch("label_lane") }.uniq.size, :>, 1
  end
end
