require "test_helper"

class WorkspacesControllerTest < ActionDispatch::IntegrationTest
  test "user can switch to workspace they belong to" do
    user = users(:two)
    sign_in_as(user)

    patch switch_workspace_path(workspaces(:other_household))

    assert_redirected_to root_path
    assert_equal workspaces(:other_household), user.reload.active_workspace
  end

  test "user cannot switch to workspace they do not belong to" do
    user = users(:one)
    sign_in_as(user)

    patch switch_workspace_path(workspaces(:other_household))

    assert_redirected_to root_path
    assert_not_equal workspaces(:other_household), user.reload.active_workspace
  end
end

