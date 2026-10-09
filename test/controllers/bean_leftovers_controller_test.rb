require "test_helper"

class BeanLeftoversControllerTest < ActionDispatch::IntegrationTest
  test "HEAD on finish is read only" do
    sign_in_as(users(:one))
    source = beans(:open_household)
    assert_no_difference -> { ActivityEvent.count } do
      head finish_bean_path(source)
    end
    assert_response :success
    assert_nil source.reload.finished_at
    assert_equal 150.to_d, source.remaining_grams
  end

  test "finish page suggests only matching workspace bags and shows leftover amount" do
    sign_in_as(users(:one))
    source = beans(:open_household)
    destination = source.duplicate_for_new_bag!
    get finish_bean_path(source)
    assert_response :success
    assert_select "[data-testid=bean-finish-remaining]", text: /150/
    assert_select "option[value=?]", destination.id.to_s
    assert_select "option[value=?]", beans(:other_workspace_open).id.to_s, count: 0
    assert_select "option[value=?]", beans(:second_open_household).id.to_s, count: 0
  end

  test "writer transfers leftovers and repeated request cannot duplicate inventory" do
    sign_in_as(users(:one))
    source = beans(:open_household)
    destination = source.duplicate_for_new_bag!
    patch finish_bean_path(source), params: { destination: destination.id }
    assert_redirected_to bean_path(destination)
    assert_equal 400.to_d, destination.reload.remaining_grams
    assert_equal 0.to_d, source.reload.remaining_grams
    assert_no_difference -> { InventoryAdjustment.count } do
      patch finish_bean_path(source), params: { destination: destination.id }
    end
    assert_response :unprocessable_entity
    assert_equal 400.to_d, destination.reload.remaining_grams
  end

  test "viewer cannot use finish page or transfers" do
    memberships(:member).update!(role: "viewer")
    users(:two).update!(active_workspace: workspaces(:household))
    sign_in_as(users(:two))
    source = beans(:open_household)
    get finish_bean_path(source)
    assert_redirected_to root_path
    assert_no_difference -> { InventoryAdjustment.count } do
      patch finish_bean_path(source), params: { destination: "new" }
    end
    assert_redirected_to root_path
  end

  test "foreign source and destination are inaccessible" do
    sign_in_as(users(:one))
    get finish_bean_path(beans(:other_workspace_open))
    assert_response :not_found
    patch finish_bean_path(beans(:open_household)), params: { destination: beans(:other_workspace_open).id }
    assert_response :not_found
  end
end
