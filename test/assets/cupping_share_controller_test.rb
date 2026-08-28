require "test_helper"

class CuppingShareControllerTest < ActiveSupport::TestCase
  test "cupping sharing uses native share only on coarse pointers and otherwise copies the URL" do
    source = Rails.root.join("app/javascript/controllers/cupping_share_controller.js").read

    assert_includes source, 'window.matchMedia("(pointer: coarse)").matches'
    assert_includes source, "if (mobile && navigator.share)"
    assert_includes source, "await navigator.share(this.shareData)"
    assert_includes source, "await navigator.clipboard.writeText(this.urlValue)"
    assert_includes source, "event.preventDefault()"
    assert_includes source, "setTimeout"
    assert_includes source, "this.labelTarget.textContent"
  end
end
