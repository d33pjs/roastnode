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

  test "cupping sharing falls back to clipboard after a non-abort native share rejection" do
    source = Rails.root.join("app/javascript/controllers/cupping_share_controller.js").read

    assert_match(
      /if \(mobile && navigator\.share\)\s+\{\s+try \{\s+await navigator\.share\(this\.shareData\)\s+return\s+\}\s+catch \(error\) \{\s+if \(error\.name === "AbortError"\) return\s+\}\s+\}\s+await this\.copyFallback\(\)/m,
      source
    )
    assert_includes source, "async copyFallback()"
    assert_includes source, "if (!navigator.clipboard?.writeText) throw new Error(\"Clipboard unavailable\")"
  end
end
