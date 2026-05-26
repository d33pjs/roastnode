require "test_helper"

class EquipmentControllerTest < ActionDispatch::IntegrationTest
  test "index lists active workspace equipment only" do
    sign_in_as(users(:one))

    get equipment_index_path

    assert_response :success
    assert_select "h1", I18n.t("equipment.index.title")
    assert_select "td", text: equipment(:household_grinder).name
    assert_select "a[href=?]", equipment_path(equipment(:household_grinder)), text: equipment(:household_grinder).name
    assert_select "td", text: equipment(:other_workspace_grinder).name, count: 0
  end

  test "member can create equipment" do
    user = users(:two)
    user.update!(active_workspace: workspaces(:household))
    sign_in_as(user)

    assert_difference -> { workspaces(:household).equipment.count }, 1 do
      post equipment_index_path, params: {
        equipment: {
          name: "Eureka Mignon",
          kind: "grinder",
          model: "Specialita"
        }
      }
    end

    assert_redirected_to equipment_index_path
    assert_equal "grinder", workspaces(:household).equipment.order(:created_at).last.kind
  end

  test "viewer cannot create equipment" do
    memberships(:member).update!(role: "viewer")
    user = users(:two)
    user.update!(active_workspace: workspaces(:household))
    sign_in_as(user)

    assert_no_difference -> { workspaces(:household).equipment.count } do
      post equipment_index_path, params: { equipment: { name: "Nope", kind: "machine" } }
    end

    assert_redirected_to root_path
  end

  test "show lists active workspace equipment activity" do
    sign_in_as(users(:one))

    get equipment_path(equipment(:household_grinder))

    assert_response :success
    assert_select "h1", equipment(:household_grinder).name
    assert_select "a[href=?]", equipment_event_path(equipment_events(:grinder_cleaning)), text: /Grinder cleaning/
    assert_select "a[href=?]", brew_path(brews(:morning_espresso)), text: /#{beans(:open_household).name}/
    assert_select "p", text: /18 g/
  end

  test "show is scoped to active workspace" do
    sign_in_as(users(:one))

    get equipment_path(equipment(:other_workspace_grinder))

    assert_response :not_found
  end
end
