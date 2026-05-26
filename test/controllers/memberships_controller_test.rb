require "test_helper"

class MembershipsControllerTest < ActionDispatch::IntegrationTest
  test "member list shows only active workspace members" do
    sign_in_as(users(:one))

    get memberships_path

    assert_response :success
    assert_select "h1", I18n.t("memberships.index.title")
    assert_select "td", text: users(:one).email_address
    assert_select "td", text: users(:two).email_address
  end

  test "non-member cannot read another workspace through active workspace id" do
    user = users(:one)
    user.update!(active_workspace: workspaces(:other_household))
    sign_in_as(user)

    get memberships_path

    assert_redirected_to root_path
    assert_not_equal workspaces(:other_household), user.reload.active_workspace
  end
end
