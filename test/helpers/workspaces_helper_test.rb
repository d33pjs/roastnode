require "test_helper"

class WorkspacesHelperTest < ActionView::TestCase
  include ApplicationHelper

  test "dashboard line charts honor comparison scale instead of normalizing each line" do
    steep_drop = {
      values: [ 8, 8, 8, 8, 2 ],
      scale_min: 0,
      scale_max: 8,
      baseline_average: 8
    }
    deeper_drop = {
      values: [ 8, 8, 8, 8, 1 ],
      scale_min: 0,
      scale_max: 8,
      baseline_average: 8
    }

    assert_equal "152,50", dashboard_line_chart_points(steep_drop).split.last
    assert_equal "152,57", dashboard_line_chart_points(deeper_drop).split.last
    assert_equal "8,64 #{dashboard_line_chart_points(steep_drop)} 152,64", dashboard_line_chart_area_points(steep_drop)
    assert_equal "8", dashboard_line_chart_baseline_y(steep_drop)
    assert_equal({ x: "152", y: "50" }, dashboard_line_chart_current_point(steep_drop))
  end
end
