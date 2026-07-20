require "test_helper"

class BrewDraftControllerTest < ActiveSupport::TestCase
  test "draft controller stores restorable fields and ignores file inputs" do
    controller = Rails.root.join("app/javascript/controllers/brew_draft_controller.js")
    source = controller.read

    assert_includes source, "localStorage.setItem"
    assert_includes source, "localStorage.removeItem"
    assert_includes source, 'addEventListener("submit"'
    assert_includes source, 'field.type === "file"'
    assert_includes source, 'static targets = [ "notice" ]'
    assert_includes source, "this.serializeFields(this.restorableFields)"
    assert_includes source, "return this.restorableFields.reduce"
    assert_includes source, "return this.restorableFields.filter((field) => !field.disabled)"
    assert_not_includes source, "if (!field.name || field.disabled) return false"
  end
end
