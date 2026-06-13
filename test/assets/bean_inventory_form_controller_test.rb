require "test_helper"

class BeanInventoryFormControllerTest < ActiveSupport::TestCase
  test "bean inventory form syncs bag size one way and disables opened date for stock" do
    controller = Rails.root.join("app/javascript/controllers/bean_inventory_form_controller.js")
    source = controller.read

    assert_includes source, "static targets = [ \"status\", \"bagSize\", \"remaining\", \"openedOn\" ]"
    assert_includes source, "bagSizeChanged()"
    assert_includes source, "remainingChanged()"
    assert_includes source, "statusChanged()"
    assert_includes source, "this.remainingTouched = true"
    assert_includes source, "if (this.remainingTouched) return"
    assert_includes source, "this.remainingTarget.value = this.bagSizeTarget.value"
    assert_includes source, "this.openedOnTarget.disabled = this.statusTarget.value === \"stock\""
    assert_not_includes source, "this.bagSizeTarget.value = this.remainingTarget.value"
  end
end
