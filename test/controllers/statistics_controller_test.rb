require "test_helper"

class StatisticsControllerTest < ActionDispatch::IntegrationTest
  test "workspace member sees scoped statistics" do
    sign_in_as(users(:one))

    get statistics_path

    assert_response :success
    assert_select "h1", I18n.t("statistics.index.title")
    assert_select "[data-testid=total-brews]", "1"
    assert_select "[data-testid=total-ground]", "18 g"
    assert_select "[data-testid=open-beans]", "2"
    assert_select "h2", I18n.t("statistics.index.equipment")
    assert_select "p", text: /Niche Zero/
    assert_select "p", text: /Other Grinder/, count: 0
  end

  test "viewer can read statistics" do
    memberships(:member).update!(role: "viewer")
    user = users(:two)
    user.update!(active_workspace: workspaces(:household))
    sign_in_as(user)

    get statistics_path

    assert_response :success
    assert_select "h1", I18n.t("statistics.index.title")
  end

  test "dashboard links to statistics" do
    sign_in_as(users(:one))

    get root_path

    assert_response :success
    assert_select "a[href=?]", statistics_path, text: I18n.t("workspaces.show.actions.statistics")
  end
end
