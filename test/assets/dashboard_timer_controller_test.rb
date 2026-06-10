require "test_helper"

class DashboardTimerControllerTest < ActiveSupport::TestCase
  test "timer controller updates elapsed seconds and cleans up interval" do
    controller = Rails.root.join("app/javascript/controllers/dashboard_timer_controller.js")
    source = controller.read

    assert_includes source, "static values = { sinceAt: Number }"
    assert_includes source, "static targets = [ \"value\" ]"
    assert_includes source, "setInterval"
    assert_includes source, "clearInterval"
    assert_includes source, "1000"
    assert_includes source, "formatDuration"
    assert_includes source, "Date.now()"
  end
end
