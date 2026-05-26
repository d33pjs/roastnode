require "test_helper"

class BeansControllerTest < ActionDispatch::IntegrationTest
  test "index lists active workspace beans only" do
    sign_in_as(users(:one))

    get beans_path

    assert_response :success
    assert_select "h1", I18n.t("beans.index.title")
    assert_select "td", text: beans(:open_household).name
    assert_select "td", text: beans(:other_workspace_open).name, count: 0
  end

  test "member can create bean" do
    user = users(:two)
    user.update!(active_workspace: workspaces(:household))
    sign_in_as(user)

    assert_difference -> { workspaces(:household).beans.count }, 1 do
      post beans_path, params: {
        bean: {
          name: "Sweet Valley",
          roaster_name: "Calendar Coffee",
          bag_size_grams: "250",
          remaining_grams: "",
          opened_on: "2026-05-26"
        }
      }
    end

    bean = workspaces(:household).beans.order(:created_at).last
    assert_redirected_to bean_path(bean)
    assert_equal 250.to_d, bean.remaining_grams
  end

  test "viewer cannot create bean" do
    memberships(:member).update!(role: "viewer")
    user = users(:two)
    user.update!(active_workspace: workspaces(:household))
    sign_in_as(user)

    assert_no_difference -> { workspaces(:household).beans.count } do
      post beans_path, params: { bean: { name: "Nope", bag_size_grams: "250" } }
    end

    assert_redirected_to root_path
  end

  test "show is scoped to active workspace" do
    sign_in_as(users(:one))

    get bean_path(beans(:other_workspace_open))

    assert_response :not_found
  end
end
