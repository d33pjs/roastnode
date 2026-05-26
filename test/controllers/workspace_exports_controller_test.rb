require "test_helper"

class WorkspaceExportsControllerTest < ActionDispatch::IntegrationTest
  test "owner downloads active workspace export as json attachment" do
    sign_in_as(users(:one))

    get workspace_export_path

    assert_response :success
    assert_equal "application/json", response.media_type
    assert_match "attachment", response.headers["Content-Disposition"]
    assert_match "jens-household-export.json", response.headers["Content-Disposition"]

    payload = JSON.parse(response.body)
    assert_equal "roastnode.workspace_export", payload.fetch("format")
    assert_equal workspaces(:household).id, payload.fetch("workspace").fetch("id")
    assert_includes payload.fetch("beans").map { |bean| bean.fetch("id") }, beans(:open_household).id
    assert_not_includes payload.fetch("beans").map { |bean| bean.fetch("id") }, beans(:other_workspace_open).id
  end

  test "member cannot export workspace" do
    user = users(:two)
    user.update!(active_workspace: workspaces(:household))
    sign_in_as(user)

    get workspace_export_path

    assert_redirected_to root_path
  end
end
