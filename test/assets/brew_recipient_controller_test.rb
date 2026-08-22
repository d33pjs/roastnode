require "test_helper"

class BrewRecipientControllerTest < ActiveSupport::TestCase
  test "name input selects guest and explicit self or member clears stale free text" do
    source = Rails.root.join("app/javascript/controllers/brew_recipient_controller.js").read
    assert_includes source, 'static targets = [ "selection", "guest", "name" ]'
    assert_includes source, "this.guestTarget.checked = true"
    assert_includes source, 'event.target.value !== "guest"'
    assert_includes source, 'this.nameTarget.value = ""'
  end
end
