require "test_helper"

class EquipmentKindControllerTest < ActiveSupport::TestCase
  test "machine feature controls follow the selected equipment kind" do
    source = Rails.root.join("app/javascript/controllers/equipment_kind_controller.js").read

    assert_includes source, 'static targets = [ "kind", "machineFeatures" ]'
    assert_includes source, 'this.kindTarget.value === "machine"'
    assert_includes source, "this.machineFeaturesTarget.hidden = !machineSelected"
    assert_includes source, "input.disabled = !machineSelected"
  end
end
