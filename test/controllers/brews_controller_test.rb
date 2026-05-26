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
            rating: "4"
          }
        }
      end
    end

    brew = workspaces(:household).brews.order(:created_at).last
    assert_redirected_to brew_path(brew)
    assert_equal 201.5.to_d, bean.reload.remaining_grams
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
