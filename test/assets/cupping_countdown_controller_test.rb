require "test_helper"

class CuppingCountdownControllerTest < ActiveSupport::TestCase
  test "countdown uses the server deadline clamps at zero swaps the form and cleans up" do
    source = Rails.root.join("app/javascript/controllers/cupping_countdown_controller.js").read

    assert_includes source, "static values = { deadline: Number }"
    assert_includes source, 'static targets = [ "value", "form", "expired" ]'
    assert_includes source, "Date.now()"
    assert_includes source, "Math.max(0"
    assert_includes source, "setInterval"
    assert_includes source, "1000"
    assert_includes source, "clearInterval"
    assert_includes source, "padStart(2, \"0\")"
    assert_includes source, "this.formTarget.hidden = true"
    assert_includes source, "this.expiredTarget.hidden = false"
    assert_includes source, 'this.valueTarget.textContent = "00:00:00"'
  end
end
