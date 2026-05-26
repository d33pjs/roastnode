require "test_helper"

class TypographyAssetTest < ActiveSupport::TestCase
  test "Elms Sans is self hosted and configured as the app font" do
    tailwind_css = Rails.root.join("app/assets/tailwind/application.css").read
    layout = Rails.root.join("app/views/layouts/application.html.erb").read
    license = Rails.root.join("app/assets/fonts/elmssans/OFL.txt").read

    assert_includes layout, 'font-family: "Elms Sans"'
    assert_includes layout, 'asset_path("elmssans/ElmsSans-Variable.ttf")'
    assert_includes layout, 'asset_path("elmssans/ElmsSans-Italic-Variable.ttf")'
    assert_includes tailwind_css, '--font-sans: "Elms Sans"'
    assert_no_match %r{fonts\.(googleapis|gstatic)\.com}, layout
    assert_no_match %r{fonts\.(googleapis|gstatic)\.com}, tailwind_css
    assert_path_exists Rails.root.join("app/assets/fonts/elmssans/ElmsSans-Variable.ttf")
    assert_path_exists Rails.root.join("app/assets/fonts/elmssans/ElmsSans-Italic-Variable.ttf")
    assert_includes license, "SIL OPEN FONT LICENSE Version 1.1"
    assert_match %r{/assets/elmssans/ElmsSans-Variable-[a-f0-9]+\.ttf},
      ActionController::Base.helpers.asset_path("elmssans/ElmsSans-Variable.ttf")
  end
end
