require "test_helper"

class PreparationToolsControllerTest < ActionDispatch::IntegrationTest
  test "index lists active workspace tools only" do
    sign_in_as(users(:one))

    get preparation_tools_path

    assert_response :success
    assert_select "h1", I18n.t("preparation_tools.index.title")
    assert_select "td", text: preparation_tools(:wdt).name
    assert_select "td", text: preparation_tools(:other_workspace_tool).name, count: 0
  end

  test "member can create preparation tool" do
    user = users(:two)
    user.update!(active_workspace: workspaces(:household))
    sign_in_as(user)

    assert_difference -> { workspaces(:household).preparation_tools.count }, 1 do
      post preparation_tools_path, params: {
        preparation_tool: {
          name: "Paper filter",
          brew_method: "espresso",
          notes: "Bottom filter"
        }
      }
    end

    assert_redirected_to preparation_tools_path
    assert_equal "Paper filter", workspaces(:household).preparation_tools.order(:created_at).last.name
  end

  test "viewer cannot create preparation tool" do
    memberships(:member).update!(role: "viewer")
    user = users(:two)
    user.update!(active_workspace: workspaces(:household))
    sign_in_as(user)

    assert_no_difference -> { workspaces(:household).preparation_tools.count } do
      post preparation_tools_path, params: { preparation_tool: { name: "Nope", brew_method: "espresso" } }
    end

    assert_redirected_to root_path
  end
end
