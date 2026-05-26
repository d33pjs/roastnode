require "test_helper"

class BrewsControllerTest < ActionDispatch::IntegrationTest
  test "new redirects to new bean when workspace has no open beans" do
    workspaces(:household).beans.update_all(remaining_grams: 0, archived_at: Time.current)
    sign_in_as(users(:one))

    get new_brew_path

    assert_redirected_to new_bean_path
  end

  test "new defaults to current user's last active bean" do
    sign_in_as(users(:one))

    get new_brew_path

    assert_response :success
    assert_select "h1", I18n.t("brews.new.title")
    assert_select "option[selected][value=?]", beans(:open_household).id.to_s
    assert_select "option[selected][value=?]", equipment(:household_grinder).id.to_s
    assert_select "option[selected][value=?]", equipment(:household_machine).id.to_s
    assert_select "input[name=?][value=?]", "brew[bean_weight_grams]", "18.0"
    assert_select "input[name=?][value=?]", "brew[ground_weight_grams]", "18.0", count: 0
    assert_select "input[name=?][value=?]", "brew[dose_grams]", "18.0"
    assert_select "input[name=?][value=?]", "brew[beverage_grams]", "40.0"
    assert_select "input[name=?][value=?]", "brew[grind_setting]", "12"
    assert_select "input[name=?][value=?]", "brew[brew_temperature_celsius]", "93.0"
    assert_select "input[name=?][value=?]", "brew[total_time_seconds]", "28", count: 0
    assert_select "input[name=?][value=?]", "brew[preinfusion_seconds]", "5"
    assert_select "input[name=?][value=?]", "brew[first_drip_seconds]", "8", count: 0
    assert_select "input[name=?][value=?]", "brew[rating]", "4", count: 0
    assert_select "textarea[name=?]", "brew[notes]", text: ""
    assert_select "input[type=checkbox][name=?][value=?][checked]", "brew[preparation_tool_ids][]", preparation_tools(:wdt).id.to_s
    assert_select "input[type=checkbox][name=?][value=?]", "brew[preparation_tool_ids][]", preparation_tools(:puck_screen).id.to_s
    assert_select "input[type=checkbox][name=?][value=?]", "brew[preparation_tool_ids][]", preparation_tools(:other_workspace_tool).id.to_s, count: 0
    assert_select "input[type=file][name=?][multiple=multiple]", "brew[photos][]"
  end

  test "new falls back to first open bean when last bean is closed" do
    beans(:open_household).update!(archived_at: Time.current, remaining_grams: 0)
    sign_in_as(users(:one))

    get new_brew_path

    assert_response :success
    assert_select "option[selected][value=?]", beans(:second_open_household).id.to_s
  end

  test "member can create espresso brew and consume selected bean" do
    user = users(:two)
    user.update!(active_workspace: workspaces(:household))
    sign_in_as(user)
    bean = beans(:second_open_household)

    assert_difference -> { workspaces(:household).brews.count }, 1 do
      assert_difference -> { InventoryAdjustment.count }, 1 do
        assert_difference -> { BrewPreparationTool.count }, 2 do
          post brews_path, params: {
            brew: {
              bean_id: bean.id,
              grinder_id: equipment(:household_grinder).id,
              machine_id: equipment(:household_machine).id,
              bean_weight_grams: "18.5",
              ground_weight_grams: "18.3",
              dose_grams: "18.2",
              beverage_grams: "42",
              grind_setting: "14",
              total_time_seconds: "31",
              taste_balance: "neutral",
              rating: "4",
              photos: [ photo_upload ],
              preparation_tool_ids: [
                preparation_tools(:wdt).id,
                preparation_tools(:other_workspace_tool).id,
                preparation_tools(:puck_screen).id
              ]
            }
          }
        end
      end
    end

    brew = workspaces(:household).brews.order(:created_at).last
    assert_redirected_to brew_path(brew)
    assert_equal 201.5.to_d, bean.reload.remaining_grams
    assert_equal [ "WDT", "Puck screen" ], brew.brew_preparation_tools.order(:position).pluck(:tool_name)
    assert_equal 1, brew.photos.count
  end

  test "show renders private photos through scoped media route" do
    sign_in_as(users(:one))
    attachment = attach_photo(brews(:morning_espresso))

    get brew_path(brews(:morning_espresso))

    assert_response :success
    assert_select "img[src=?]", media_attachment_path(attachment)
  end

  test "viewer cannot create brew" do
    memberships(:member).update!(role: "viewer")
    user = users(:two)
    user.update!(active_workspace: workspaces(:household))
    sign_in_as(user)

    assert_no_difference -> { workspaces(:household).brews.count } do
      post brews_path, params: { brew: { bean_id: beans(:open_household).id, bean_weight_grams: "18" } }
    end

    assert_redirected_to root_path
  end
end
