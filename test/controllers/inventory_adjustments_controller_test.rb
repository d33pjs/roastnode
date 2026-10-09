require "test_helper"

class InventoryAdjustmentsControllerTest < ActionDispatch::IntegrationTest
  test "weighing refreshes curated public remaining and terminal waste without private notes" do
    sign_in_as(users(:one))
    bean = beans(:open_household)
    bean.finish!
    share = PublicBeanShare.create!(workspace: bean.workspace, bean:, created_by: users(:one), updated_by: users(:one), title: "Shared coffee")
    PublicBeanShareRefresher.refresh(share)
    post bean_inventory_adjustments_path(bean), params: { inventory_adjustment: {
      adjustment_mode: "set_remaining", target_remaining_grams: "12,5", note: "Private weighing note" } }
    assert_redirected_to bean_path(bean)
    assert_equal BigDecimal("12.5"), share.reload.snapshot.fetch("bean").fetch("remaining_grams").to_d
    assert_equal "12.5", share.snapshot.fetch("stats").fetch("dead_grams")
    assert_not_includes share.snapshot.to_json, "Private weighing note"
  end

  test "weighing form displays current inventory and target mode" do
    sign_in_as(users(:one))
    bean = beans(:open_household)
    get new_bean_inventory_adjustment_path(bean)
    assert_select "[data-testid=inventory-current-remaining]", text: /150/
    assert_select "select[name=?] option[value=set_remaining]", "inventory_adjustment[adjustment_mode]"
    assert_select "input[name=?][inputmode=decimal]", "inventory_adjustment[target_remaining_grams]"
  end

  test "writer can weigh with comma decimals and then set zero" do
    sign_in_as(users(:one))
    bean = beans(:open_household)
    post bean_inventory_adjustments_path(bean), params: { inventory_adjustment: {
      adjustment_mode: "set_remaining", target_remaining_grams: "12,5g" } }
    assert_redirected_to bean_path(bean)
    assert_equal BigDecimal("12.5"), bean.reload.remaining_grams
    assert_equal BigDecimal("-137.5"), bean.inventory_adjustments.manual.last.delta_grams

    post bean_inventory_adjustments_path(bean), params: { inventory_adjustment: {
      adjustment_mode: "set_remaining", target_remaining_grams: "0" } }
    assert_redirected_to bean_path(bean)
    assert_equal 0.to_d, bean.reload.remaining_grams
  end

  test "unchanged weighing creates no activity or adjustment" do
    sign_in_as(users(:one))
    bean = beans(:open_household)
    assert_no_difference [ -> { ActivityEvent.count }, -> { InventoryAdjustment.count } ] do
      post bean_inventory_adjustments_path(bean), params: { inventory_adjustment: {
        adjustment_mode: "set_remaining", target_remaining_grams: "150" } }
    end
    assert_redirected_to bean_path(bean)
  end

  test "weighing cannot reach a foreign workspace" do
    sign_in_as(users(:one))
    bean = beans(:other_workspace_open)
    post bean_inventory_adjustments_path(bean), params: { inventory_adjustment: {
      adjustment_mode: "set_remaining", target_remaining_grams: "0" } }
    assert_response :not_found
    assert_equal 200.to_d, bean.reload.remaining_grams
  end

  test "writer can open manual inventory adjustment form for bean" do
    sign_in_as(users(:one))
    bean = beans(:open_household)

    get new_bean_inventory_adjustment_path(bean)

    assert_response :success
    assert_select "h1", I18n.t("inventory_adjustments.new.title")
    assert_select "form[action=?]", bean_inventory_adjustments_path(bean)
    assert_select "form[data-controller=?]", "signed-decimal"
    assert_select "input[type=text][inputmode=text][name=?][data-signed-decimal-target=input]", "inventory_adjustment[delta_grams]"
    assert_select "button[type=button][data-action=?]", "signed-decimal#markAdd", text: I18n.t("inventory_adjustments.form.add")
    assert_select "button[type=button][data-action=?]", "signed-decimal#markRemove", text: I18n.t("inventory_adjustments.form.remove")
    assert_select "input[name=?]", "inventory_adjustment[occurred_at]"
    assert_select "textarea[name=?]", "inventory_adjustment[note]"
  end

  test "writer can create manual inventory adjustment with comma decimal amount" do
    sign_in_as(users(:one))
    bean = beans(:open_household)
    occurred_at = Time.find_zone!("Europe/Berlin").local(2026, 5, 27, 10, 15)

    assert_difference -> { InventoryAdjustment.manual.count }, 1 do
      event = assert_activity_event(action: "inventory_adjustment.created", workspace: bean.workspace, actor: users(:one)) do
        post bean_inventory_adjustments_path(bean), params: {
          inventory_adjustment: {
            delta_grams: "25,5g",
            occurred_at: "2026-05-27T10:15",
            note: "Found beans after cleaning."
          }
        }
      end
      assert_equal occurred_at, event.occurred_at
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

    assert_activity_event(
      action: "inventory_adjustment.created", workspace: bean.workspace, actor: users(:one),
      additional_actions: [ "bean.used_up" ]
    ) do
      post bean_inventory_adjustments_path(bean), params: {
        inventory_adjustment: {
          delta_grams: "-500",
          note: "Bag is empty."
        }
      }
    end

    assert_redirected_to bean_path(bean)
    assert_equal 0.to_d, bean.reload.remaining_grams
    assert_equal "used_up", bean.bag_status
  end

  test "invalid manual adjustment emits nothing" do
    sign_in_as(users(:one))
    bean = beans(:open_household)

    assert_no_difference -> { ActivityEvent.count } do
      post bean_inventory_adjustments_path(bean), params: {
        inventory_adjustment: { delta_grams: "0" }
      }
    end

    assert_response :unprocessable_entity
  end

  test "emitter failure rolls back manual adjustment and inventory" do
    sign_in_as(users(:one))
    bean = beans(:open_household)
    original_remaining = bean.remaining_grams

    with_stubbed_singleton_method(Activity::Emitter, :record!, ->(**) { raise "activity write failed" }) do
      assert_no_difference -> { InventoryAdjustment.count } do
        assert_raises(RuntimeError) do
          post bean_inventory_adjustments_path(bean), params: {
            inventory_adjustment: { delta_grams: "-20" }
          }
        end
      end
    end

    assert_equal original_remaining, bean.reload.remaining_grams
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
