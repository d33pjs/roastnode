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
  end
end
