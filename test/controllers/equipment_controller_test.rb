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
          model: "Specialita",
          photos: [ photo_upload ]
        }
      }
    end

    assert_redirected_to equipment_index_path
    equipment = workspaces(:household).equipment.order(:created_at).last
    assert_equal "grinder", equipment.kind
    assert_equal 1, equipment.photos.count
  end

  test "new includes photo upload" do
    sign_in_as(users(:one))

    get new_equipment_path

    assert_response :success
    assert_select "input[type=file][name=?][multiple=multiple]", "equipment[photos][]"
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

  test "show renders usage analytics" do
    sign_in_as(users(:one))
    grinder = equipment(:household_grinder)
    brew = beans(:open_household).brews.create!(
      workspace: grinder.workspace,
      user: users(:one),
      grinder:,
      machine: equipment(:household_machine),
      occurred_at: Time.zone.local(2026, 5, 25, 8, 15, 0),
      bean_weight_grams: 19,
      ground_weight_grams: 19,
      dose_grams: 19,
      beverage_grams: 45,
      rating: 5,
      channeling: true
    )

    get equipment_path(grinder)

    assert_response :success
    assert_select "h2", I18n.t("equipment.show.analytics")
    assert_select "[data-testid=equipment-total-brews]", "2"
    assert_select "[data-testid=equipment-total-ground]", "37 g"
    assert_select "[data-testid=equipment-brews-since-service]"
    assert_select "[data-testid=equipment-grams-since-service]"
    assert_select "[data-testid=equipment-recent-brews] a[href=?]", brew_path(brew), text: /House Blend/
    assert_select "h3", I18n.t("equipment.show.brews_by_day")
    assert_select "h3", I18n.t("equipment.show.maintenance_markers")
    assert_select "body", text: /Other Grinder/, count: 0
  end

  test "show renders private photos through scoped media route" do
    sign_in_as(users(:one))
    attachment = attach_photo(equipment(:household_grinder))

    get equipment_path(equipment(:household_grinder))

    assert_response :success
    assert_select "img[src=?]", media_attachment_path(attachment)
  end

  test "show is scoped to active workspace" do
    sign_in_as(users(:one))

    get equipment_path(equipment(:other_workspace_grinder))

    assert_response :not_found
  end
end
