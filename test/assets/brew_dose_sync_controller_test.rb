require "test_helper"

class BrewDoseSyncControllerTest < ActiveSupport::TestCase
  test "dose sync copies ground out one way until dose is manually edited" do
    controller = Rails.root.join("app/javascript/controllers/brew_dose_sync_controller.js")
    source = controller.read

    assert_includes source, "static targets = [ \"groundWeight\", \"dose\" ]"
    assert_includes source, "groundWeightChanged()"
    assert_includes source, "doseChanged()"
    assert_includes source, "this.doseTouched = true"
    assert_includes source, "if (this.doseTouched) return"
    assert_includes source, "this.doseTarget.value = this.groundWeightTarget.value"
    assert_not_includes source, "this.groundWeightTarget.value = this.doseTarget.value"
  end
end
