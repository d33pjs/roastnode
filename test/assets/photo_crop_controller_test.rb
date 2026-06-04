require "test_helper"

class PhotoCropControllerTest < ActiveSupport::TestCase
  test "crop math maps selection through the displayed image rectangle" do
    source = Rails.root.join("app/javascript/controllers/photo_crop_controller.js").read

    assert_includes source, "displayedImageRect"
    assert_includes source, "naturalWidth / imageRect.width"
    assert_includes source, "selection.x - imageRect.left"
    assert_includes source, "selection.y - imageRect.top"
  end
end
