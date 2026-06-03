require "test_helper"

class SignedDecimalControllerTest < ActiveSupport::TestCase
  test "signed decimal controller prefixes add and remove signs without duplicating existing signs" do
    controller = Rails.root.join("app/javascript/controllers/signed_decimal_controller.js")
    source = controller.read

    assert_includes source, "static targets = [ \"input\" ]"
    assert_includes source, "markAdd()"
    assert_includes source, "markRemove()"
    assert_includes source, "this.mark(\"+\")"
    assert_includes source, "this.mark(\"-\")"
    assert_includes source, "replace(/^[+-]/, \"\")"
    assert_includes source, "this.inputTarget.dispatchEvent(new Event(\"input\", { bubbles: true }))"
  end
end
