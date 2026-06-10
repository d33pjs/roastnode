require "test_helper"

class WorkspacesHelperTest < ActionView::TestCase
  include ApplicationHelper

  test "dashboard sparklines honor comparison scale instead of normalizing each line" do
    steep_drop = {
      values: [ 8, 8, 8, 8, 2 ],
      scale_min: 0,
      scale_max: 8
    }
    deeper_drop = {
      values: [ 8, 8, 8, 8, 1 ],
      scale_min: 0,
      scale_max: 8
    }

    assert_equal "120,22.5", dashboard_sparkline_points(steep_drop).split.last
    assert_equal "120,25.75", dashboard_sparkline_points(deeper_drop).split.last
    assert_equal "0,32 #{dashboard_sparkline_points(steep_drop)} 120,32", dashboard_sparkline_area_points(steep_drop)
  end
end
