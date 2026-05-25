require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "shows the public home page" do
    get root_path

    assert_response :success
    assert_select "h1", I18n.t("home.index.title")
  end
end
