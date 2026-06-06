require "test_helper"

class NativeShareControllerTest < ActiveSupport::TestCase
  test "native share controller opens web share and falls back to clipboard" do
    controller = Rails.root.join("app/javascript/controllers/native_share_controller.js")
    source = controller.read

    assert_includes source, "static values"
    assert_includes source, "navigator.share"
    assert_includes source, "await navigator.share(shareData)"
    assert_includes source, "navigator.clipboard.writeText(this.urlValue)"
    assert_includes source, "event.preventDefault()"
    assert_includes source, "setTimeout"
    assert_includes source, "this.labelTarget.textContent"
  end
end
