require "test_helper"

class PreparationToolsControllerTest < ActionDispatch::IntegrationTest
  test "index lists active workspace tools only" do
    sign_in_as(users(:one))
    preparation_tools(:wdt).update!(position: 20)
    preparation_tools(:puck_screen).update!(position: 10)

    get preparation_tools_path

    assert_response :success
    assert_select "h1", I18n.t("preparation_tools.index.title")
    assert_select "tr#preparation_tool_#{preparation_tools(:wdt).id}"
    assert_select "a[href=?]", preparation_tool_path(preparation_tools(:wdt)), text: preparation_tools(:wdt).name
    assert_select "tbody tr:first-child a[href=?]", preparation_tool_path(preparation_tools(:puck_screen)),
      text: preparation_tools(:puck_screen).name
    assert_select "td", text: preparation_tools(:other_workspace_tool).name, count: 0
  end

  test "show renders tool details photos and usage" do
    sign_in_as(users(:one))
    attachment = attach_photo(preparation_tools(:wdt))

    get preparation_tool_path(preparation_tools(:wdt))

    assert_response :success
    assert_select "h1", preparation_tools(:wdt).name
    assert_select "[data-testid=preparation-tool-status]", I18n.t("preparation_tools.show.active")
    assert_select "[data-testid=preparation-tool-brew-count]", "1"
    assert_select "[data-testid=preparation-tool-total-ground]", "18 g"
    assert_select "[data-testid=preparation-tool-channeling-rate]", "0%"
    assert_select "[data-testid=preparation-tool-recent-brews] a[href=?]", brew_path(brews(:morning_espresso))
    assert_select "a[href=?]", brew_path(brews(:morning_espresso)), text: /#{beans(:open_household).name}/
    assert_select "img[src=?]", media_attachment_path(attachment)
    assert_select "a[href=?]", edit_preparation_tool_path(preparation_tools(:wdt)), text: I18n.t("preparation_tools.show.edit")
    assert_select "form[action=?]", archive_preparation_tool_path(preparation_tools(:wdt))
    assert_select "[data-testid=preparation-tool-danger-zone]"
    assert_select "form[action=?]", preparation_tool_path(preparation_tools(:wdt))
  end

  test "show is scoped to active workspace" do
    sign_in_as(users(:one))

    get preparation_tool_path(preparation_tools(:other_workspace_tool))

    assert_response :not_found
  end

  test "new shows photo upload" do
    sign_in_as(users(:one))

    get new_preparation_tool_path

    assert_response :success
    assert_select "input[type=file][name=?][multiple=multiple]", "preparation_tool[photos][]"
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
          notes: "Bottom filter",
          photos: [ photo_upload ]
        }
      }
    end

    assert_redirected_to preparation_tools_path
    tool = workspaces(:household).preparation_tools.order(:created_at).last
    assert_equal "Paper filter", tool.name
    assert_equal 1, tool.photos.count
    assert_equal 30, tool.position
  end

  test "edit renders current photos and update adds photos" do
    sign_in_as(users(:one))
    tool = preparation_tools(:wdt)
    existing_photo = attach_photo(tool)

    get edit_preparation_tool_path(tool)

    assert_response :success
    assert_select "h1", I18n.t("preparation_tools.edit.title")
    assert_select "img[src=?]", media_attachment_path(existing_photo)
    assert_select "input[name=?][value=?]", "preparation_tool[position]", tool.position.to_s
    assert_select "input[type=file][name=?][multiple=multiple]", "preparation_tool[photos][]"

    assert_difference -> { tool.reload.photos.count }, 1 do
      patch preparation_tool_path(tool), params: {
        preparation_tool: {
          name: "Precision WDT",
          brew_method: "espresso",
          notes: "Nine needles.",
          position: "12",
          photos: [ photo_upload ]
        }
      }
    end

    assert_redirected_to preparation_tool_path(tool)
    assert_equal "Precision WDT", tool.reload.name
    assert_equal "Nine needles.", tool.notes
    assert_equal 12, tool.position
  end

  test "archive and reopen preparation tool" do
    sign_in_as(users(:one))
    tool = preparation_tools(:wdt)

    patch archive_preparation_tool_path(tool)

    assert_redirected_to preparation_tool_path(tool)
    assert_not tool.reload.active?

    patch reopen_preparation_tool_path(tool)

    assert_redirected_to preparation_tool_path(tool)
    assert tool.reload.active?
  end

  test "destroy removes preparation tool without deleting brew snapshots" do
    sign_in_as(users(:one))
    tool = preparation_tools(:wdt)
    snapshot = brew_preparation_tools(:morning_espresso_wdt)

    assert_difference -> { workspaces(:household).preparation_tools.count }, -1 do
      assert_no_difference -> { Brew.count } do
        assert_no_difference -> { BrewPreparationTool.count } do
          delete preparation_tool_path(tool)
        end
      end
    end

    assert_redirected_to preparation_tools_path
    assert_nil snapshot.reload.preparation_tool
    assert_equal "WDT", snapshot.tool_name
  end

  test "viewer cannot manage preparation tool" do
    memberships(:member).update!(role: "viewer")
    user = users(:two)
    user.update!(active_workspace: workspaces(:household))
    sign_in_as(user)
    tool = preparation_tools(:wdt)

    get edit_preparation_tool_path(tool)
    assert_redirected_to root_path

    patch preparation_tool_path(tool), params: { preparation_tool: { name: "Nope", brew_method: "espresso" } }
    assert_redirected_to root_path

    patch archive_preparation_tool_path(tool)
    assert_redirected_to root_path

    delete preparation_tool_path(tool)
    assert_redirected_to root_path
    assert tool.reload.active?
  ensure
    memberships(:member)&.update!(role: "member")
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
