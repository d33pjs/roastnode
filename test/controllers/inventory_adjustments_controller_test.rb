require "test_helper"

class InventoryAdjustmentsControllerTest < ActionDispatch::IntegrationTest
  test "writer can open manual inventory adjustment form for bean" do
    sign_in_as(users(:one))
    bean = beans(:open_household)

    get new_bean_inventory_adjustment_path(bean)

    assert_response :success
    assert_select "h1", I18n.t("inventory_adjustments.new.title")
    assert_select "form[action=?]", bean_inventory_adjustments_path(bean)
    assert_select "input[type=text][inputmode=decimal][name=?]", "inventory_adjustment[delta_grams]"
    assert_select "input[name=?]", "inventory_adjustment[occurred_at]"
    assert_select "textarea[name=?]", "inventory_adjustment[note]"
  end

  test "writer can create manual inventory adjustment with comma decimal amount" do
    sign_in_as(users(:one))
    bean = beans(:open_household)

    assert_difference -> { InventoryAdjustment.manual.count }, 1 do
      post bean_inventory_adjustments_path(bean), params: {
        inventory_adjustment: {
          delta_grams: "25,5g",
          occurred_at: "2026-05-27T10:15",
          note: "Found beans after cleaning."
        }
      }
    end

    adjustment = InventoryAdjustment.manual.order(:created_at).last
    assert_redirected_to bean_path(bean)
    assert_equal 175.5.to_d, bean.reload.remaining_grams
    assert_equal 25.5.to_d, adjustment.delta_grams
    assert_equal users(:one), adjustment.user
    assert_equal bean, adjustment.bean
  end

  test "writer can create negative manual adjustment and clamp inventory at zero" do
    sign_in_as(users(:one))
    bean = beans(:open_household)

    post bean_inventory_adjustments_path(bean), params: {
      inventory_adjustment: {
        delta_grams: "-500",
        note: "Bag is empty."
      }
    }

    assert_redirected_to bean_path(bean)
    assert_equal 0.to_d, bean.reload.remaining_grams
    assert_equal "used_up", bean.bag_status
  end

  test "viewer cannot create manual inventory adjustment" do
    memberships(:member).update!(role: "viewer")
    user = users(:two)
    user.update!(active_workspace: workspaces(:household))
    sign_in_as(user)
    bean = beans(:open_household)

    get new_bean_inventory_adjustment_path(bean)
    assert_redirected_to root_path

    assert_no_difference -> { InventoryAdjustment.manual.count } do
      post bean_inventory_adjustments_path(bean), params: {
        inventory_adjustment: { delta_grams: "10" }
      }
    end
    assert_redirected_to root_path
  end

  test "new is scoped to active workspace bean" do
    sign_in_as(users(:one))

    get new_bean_inventory_adjustment_path(beans(:other_workspace_open))

    assert_response :not_found
  end
end
