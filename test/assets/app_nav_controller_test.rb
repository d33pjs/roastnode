require "test_helper"

class AppNavControllerTest < ActiveSupport::TestCase
  test "app nav controller closes details menus from outside clicks and sibling opens" do
    controller = Rails.root.join("app/javascript/controllers/app_nav_controller.js")
    source = controller.read

    assert_includes source, "static targets = [ \"menu\" ]"
    assert_includes source, "closeFromOutside(event)"
    assert_includes source, "if (this.element.contains(event.target)) return"
    assert_includes source, "closeOtherMenus(event)"
    assert_includes source, "if (!event.target.open) return"
    assert_includes source, "this.closeMenusExcept(event.target)"
    assert_includes source, "menu.open = false"
  end
end
