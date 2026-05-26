require "test_helper"

class BrandAssetTest < ActiveSupport::TestCase
  test "brand logos are vendored and used for browser icons" do
    layout = Rails.root.join("app/views/layouts/application.html.erb").read

    assert_path_exists Rails.root.join("app/assets/images/brand/logo_font_transparent_bg.png")
    assert_path_exists Rails.root.join("app/assets/images/brand/logo_font_white_bg.png")
    assert_path_exists Rails.root.join("app/assets/images/brand/logo_only_transparent_bg.png")
    assert_path_exists Rails.root.join("app/assets/images/brand/logo_only_white_bg.png")
    assert_path_exists Rails.root.join("app/assets/images/brand/logo_wordmark_web.png")
    assert_path_exists Rails.root.join("app/assets/images/brand/logo_mark_icon.png")
    assert_includes layout, 'asset_path("brand/logo_mark_icon.png")'
    assert_match %r{/assets/brand/logo_mark_icon-[a-f0-9]+\.png},
      ActionController::Base.helpers.asset_path("brand/logo_mark_icon.png")
  end
end
