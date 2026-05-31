require "test_helper"

class GearControllerTest < ActionDispatch::IntegrationTest
  test "index combines equipment tools and maintenance action" do
    sign_in_as(users(:one))

    get gear_path

    assert_response :success
    assert_select "h1", I18n.t("gear.index.title")
    assert_select "a[href=?]", new_equipment_event_path, text: I18n.t("gear.index.log_maintenance")
    assert_select "a[href=?]", new_equipment_path, text: I18n.t("gear.index.new_equipment")
    assert_select "a[href=?]", new_preparation_tool_path, text: I18n.t("gear.index.new_tool")
    assert_select "[data-testid=gear-equipment-section]"
    assert_select "[data-testid=gear-tools-section]"
    assert_select "a[data-testid=gear-equipment-card][href=?]", equipment_path(equipment(:household_grinder)),
      text: /#{equipment(:household_grinder).name}/
    assert_select "a[data-testid=gear-tool-card][href=?]", preparation_tool_path(preparation_tools(:wdt)),
      text: /#{preparation_tools(:wdt).name}/
    assert_select "body", text: equipment(:other_workspace_grinder).name, count: 0
    assert_select "body", text: preparation_tools(:other_workspace_tool).name, count: 0
  end

  test "member sees gear and maintenance action but not gear creation actions" do
    user = users(:two)
    user.update!(active_workspace: workspaces(:household))
    sign_in_as(user)

    get gear_path

    assert_response :success
    assert_select "a[href=?]", new_equipment_event_path, text: I18n.t("gear.index.log_maintenance")
    assert_select "a[href=?]", new_equipment_path, count: 0
    assert_select "a[href=?]", new_preparation_tool_path, count: 0
    assert_select "a[data-testid=gear-equipment-card][href=?]", equipment_path(equipment(:household_grinder))
    assert_select "a[data-testid=gear-tool-card][href=?]", preparation_tool_path(preparation_tools(:wdt))
  end

  test "viewer sees gear cards but cannot log maintenance" do
    memberships(:member).update!(role: "viewer")
    user = users(:two)
    user.update!(active_workspace: workspaces(:household))
    sign_in_as(user)

    get gear_path

    assert_response :success
    assert_select "a[data-testid=gear-equipment-card][href=?]", equipment_path(equipment(:household_grinder))
    assert_select "a[data-testid=gear-tool-card][href=?]", preparation_tool_path(preparation_tools(:wdt))
    assert_select "a[href=?]", new_equipment_event_path, count: 0
  ensure
    memberships(:member)&.update!(role: "member")
  end
end
