require "test_helper"

class RoasterSuggestionsControllerTest < ActiveSupport::TestCase
  test "roaster suggestions controller fetches and applies suggestions" do
    controller = Rails.root.join("app/javascript/controllers/roaster_suggestions_controller.js")
    source = controller.read

    assert_includes source, "static targets = [ \"input\", \"list\" ]"
    assert_includes source, "static values = { url: String }"
    assert_includes source, "encodeURIComponent(query)"
    assert_includes source, "fetch(`${this.urlValue}?q=${encodeURIComponent(query)}`"
    assert_includes source, "error.name === \"AbortError\""
    assert_includes source, "data.suggestions || []"
    assert_includes source, "button.dataset.roasterName = name"
    assert_includes source, "this.inputTarget.value = event.currentTarget.dataset.roasterName"
    assert_includes source, "this.inputTarget.focus()"
  end
end
