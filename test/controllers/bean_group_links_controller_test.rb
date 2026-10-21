require "test_helper"

class BeanGroupLinksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @bean = beans(:open_household)
    @target = beans(:second_open_household)
    @user = users(:one)
    sign_in_as(@user)
  end

  test "writer links bags with different names and can separate again" do
    original = @bean.coffee_history_id
    patch bean_group_link_path(@bean), params: { bean_group_link: { target_bean_id: @target.id } }
    assert_redirected_to @bean
    assert_equal @target.coffee_history_id, @bean.reload.coffee_history_id
    assert_not_equal original, @bean.coffee_history_id
    assert_equal 150, @bean.remaining_grams
    patch bean_group_link_path(@bean), params: { bean_group_link: { target_bean_id: "separate" } }
    assert_redirected_to @bean
    assert_not_equal @target.coffee_history_id, @bean.reload.coffee_history_id
  end

  test "foreign bags and targets cannot be linked and viewers cannot write" do
    original = @bean.coffee_history_id
    patch bean_group_link_path(@bean), params: { bean_group_link: { target_bean_id: beans(:other_workspace_open).id } }
    assert_response :not_found
    assert_equal original, @bean.reload.coffee_history_id
    patch bean_group_link_path(beans(:other_workspace_open)), params: { bean_group_link: { target_bean_id: @target.id } }
    assert_response :not_found
    @bean.workspace.memberships.find_by!(user: @user).update!(role: "viewer")
    patch bean_group_link_path(@bean), params: { bean_group_link: { target_bean_id: @target.id } }
    assert_redirected_to root_path
    assert_equal original, @bean.reload.coffee_history_id
  end

  test "public price parsing is explicit and private price never copied" do
    post bean_public_bean_share_path(@bean), params: { public_bean_share: {
      title: "Price", enabled: "1", public_price: "14,90", public_price_currency: "eur", public_price_recorded_on: "2026-10-21"
    } }
    share = @bean.reload.public_bean_share
    assert_equal 1490, share.public_price_cents
    assert_equal "EUR", share.public_price_currency
    assert_equal "14.90", share.snapshot.dig("bean", "public_price", "amount")
    assert_equal 1290, @bean.purchase_price_cents
    patch bean_public_bean_share_path(@bean), params: { public_bean_share: {
      title: "Price", enabled: "1", public_price: "nonsense", public_price_currency: "EUR", public_price_recorded_on: "2026-10-21"
    } }
    assert_response :unprocessable_entity
    assert_equal 1490, share.reload.public_price_cents
  end
end
