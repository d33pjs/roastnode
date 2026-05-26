require "test_helper"

class BeansControllerTest < ActionDispatch::IntegrationTest
  test "index lists active workspace beans only" do
    sign_in_as(users(:one))
    bean = beans(:open_household)

    get beans_path

    assert_response :success
    assert_select "h1", I18n.t("beans.index.title")
    assert_select "a[href=?]", bean_path(bean), text: /#{bean.name}/
    assert_select "td", text: beans(:other_workspace_open).name, count: 0
  end

  test "index renders primary bean photo and channeling summary" do
    sign_in_as(users(:one))
    bean = beans(:open_household)
    first = attach_photo(bean)
    primary = attach_photo(bean)
    bean.set_primary_photo!(primary)
    bean.brews.create!(
      workspace: bean.workspace,
      user: users(:one),
      grinder: equipment(:household_grinder),
      machine: equipment(:household_machine),
      occurred_at: Time.zone.local(2026, 5, 25, 8, 15, 0),
      bean_weight_grams: 18,
      ground_weight_grams: 17.8,
      dose_grams: 18,
      beverage_grams: 42,
      total_time_seconds: 30,
      channeling: true,
      rating: 3
    )

    get beans_path

    assert_response :success
    assert_select "img[data-testid=bean-list-photo][src=?]", media_attachment_path(primary)
    assert_select "img[data-testid=bean-list-photo][src=?]", media_attachment_path(first), count: 0
    assert_select "[data-testid=?]", "bean-list-channeling-#{bean.id}", text: /50%/
    assert_select "[data-testid=?]", "bean-list-channeling-#{bean.id}", text: /1 of 2/
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
          opened_on: "2026-05-26",
          photos: [ photo_upload ]
        }
      }
    end

    bean = workspaces(:household).beans.order(:created_at).last
    assert_redirected_to bean_path(bean)
    assert_equal 250.to_d, bean.remaining_grams
    assert_equal 1, bean.photos.count
  end

  test "new includes photo upload" do
    sign_in_as(users(:one))

    get new_bean_path

    assert_response :success
    assert_select "input[type=file][name=?][multiple=multiple]", "bean[photos][]"
    assert_select "input[name=?]", "bean[purchased_on]"
    assert_select "input[name=?]", "bean[roast_date]"
    assert_select "select[name=?]", "bean[roast_type]"
    assert_select "input[name=?][step=?]", "bean[roast_degree]", "0.5"
    assert_select "input[name=?]", "bean[purchase_price]"
    assert_select "input[name=?]", "bean[decaffeinated]"
    assert_select "input[name=?]", "bean[purchase_url]"
    assert_select "textarea[name=?]", "bean[tasting_notes]"
    assert_select "h2", I18n.t("beans.form.variety_information")
    assert_select "input[name=?]", "bean[country]"
    assert_select "input[name=?]", "bean[blend_percentage]"
  end

  test "writer can edit bean with rich metadata and additive photos" do
    user = users(:one)
    sign_in_as(user)
    bean = beans(:open_household)
    attach_photo(bean)

    get edit_bean_path(bean)

    assert_response :success
    assert_select "form[action=?]", bean_path(bean)
    assert_select "input[type=file][name=?][multiple=multiple]", "bean[photos][]"

    assert_difference -> { bean.reload.photos.count }, 1 do
      patch bean_path(bean), params: {
        bean: {
          name: "House Blend Updated",
          roaster_name: "Good Coffee",
          bag_size_grams: "250",
          remaining_grams: "111.5",
          purchased_on: "2026-05-03",
          roast_date: "2026-05-10",
          roast_type: "omni",
          roast_degree: "3.5",
          rating: "5",
          blend_type: "blend",
          purchase_price: "14.90",
          tasting_notes: "Chocolate, almond",
          decaffeinated: "1",
          purchase_url: "https://example.com/house-blend",
          notes: "Updated bag notes.",
          country: "Colombia",
          region: "Huila",
          farm: "La Esperanza",
          farmer: "Ana Gomez",
          elevation: "1,700 masl",
          variety: "Caturra",
          process: "washed",
          harvested: "2025",
          blend_percentage: "70%",
          photos: [ photo_upload ]
        }
      }
    end

    assert_redirected_to bean_path(bean)
    bean.reload
    assert_equal "House Blend Updated", bean.name
    assert_equal 111.5.to_d, bean.remaining_grams
    assert_equal Date.new(2026, 5, 3), bean.purchased_on
    assert_equal "omni", bean.roast_type
    assert_equal 3.5.to_d, bean.roast_degree
    assert_equal "blend", bean.blend_type
    assert_equal 1490, bean.purchase_price_cents
    assert_predicate bean, :decaffeinated?
    assert_equal "Colombia", bean.country
  end

  test "writer can close and reopen bean" do
    sign_in_as(users(:one))
    bean = beans(:open_household)

    patch close_bean_path(bean)
    assert_redirected_to bean_path(bean)
    assert_not_nil bean.reload.archived_at

    bean.update!(remaining_grams: 0)
    patch reopen_bean_path(bean)
    assert_redirected_to bean_path(bean)
    assert_nil bean.reload.archived_at
    assert_equal bean.bag_size_grams, bean.remaining_grams
  end

  test "writer can duplicate bean with photos" do
    sign_in_as(users(:one))
    source = beans(:open_household)
    attach_photo(source)

    assert_difference -> { workspaces(:household).beans.count }, 1 do
      post duplicate_bean_path(source)
    end

    duplicate = workspaces(:household).beans.order(:created_at).last
    assert_redirected_to edit_bean_path(duplicate)
    assert_equal source.name, duplicate.name
    assert_equal Date.current, duplicate.opened_on
    assert_equal duplicate.bag_size_grams, duplicate.remaining_grams
    assert_equal 1, duplicate.photos.count
  end

  test "show renders private photos through scoped media route" do
    sign_in_as(users(:one))
    attachment = attach_photo(beans(:open_household))

    get bean_path(beans(:open_household))

    assert_response :success
    assert_select "img[src=?]", media_attachment_path(attachment)
  end

  test "show renders bean analytics" do
    sign_in_as(users(:one))
    bean = beans(:open_household)
    brew = bean.brews.create!(
      workspace: bean.workspace,
      user: users(:one),
      grinder: equipment(:household_grinder),
      machine: equipment(:household_machine),
      occurred_at: Time.zone.local(2026, 5, 25, 8, 15, 0),
      bean_weight_grams: 19,
      ground_weight_grams: 18.5,
      dose_grams: 18.5,
      beverage_grams: 45,
      total_time_seconds: 31,
      grind_setting: "10",
      taste_balance: "bitter",
      channeling: true,
      rating: 5
    )

    get bean_path(bean)

    assert_response :success
    assert_select "h2", I18n.t("beans.show.analytics")
    assert_select "[data-testid=bean-brew-count]", "2"
    assert_select "[data-testid=bean-consumed]", "37 g"
    assert_select "[data-testid=bean-channeling-rate]", "50%"
    assert_select "[data-testid=bean-channeling-count]", text: /1 of 2/
    assert_select "[data-testid=bean-best-brews] a[href=?]", brew_path(brew), text: /45 g/
    assert_select "[data-testid=bean-recent-brews] a[href=?]", brew_path(brew), text: /10/
    assert_select "h3", I18n.t("beans.show.taste_balance")
    assert_select "h3", I18n.t("beans.show.retention_markers")
    assert_select "body", text: /Other Workspace Bean/, count: 0
  end

  test "show renders danger zone for writers" do
    sign_in_as(users(:one))
    bean = beans(:open_household)

    get bean_path(bean)

    assert_response :success
    assert_select "[data-testid=bean-danger-zone]"
    assert_select "form[action=?][method=post]", bean_path(bean)
    assert_select "input[name=_method][value=delete]"
    assert_select "button", text: I18n.t("beans.show.delete")
    assert_select "[data-turbo-confirm=?]", I18n.t("beans.show.delete_confirmation", count: bean.brews.count)
  end

  test "writer can delete bean with brew history" do
    sign_in_as(users(:one))
    bean = beans(:open_household)
    bean.inventory_adjustments.create!(
      workspace: bean.workspace,
      user: users(:one),
      delta_grams: 12,
      reason: "manual",
      note: "Manual correction."
    )

    assert_difference -> { Bean.count }, -1 do
      assert_difference -> { Brew.count }, -1 do
        assert_difference -> { InventoryAdjustment.count }, -2 do
          delete bean_path(bean)
        end
      end
    end

    assert_redirected_to beans_path
    assert_equal I18n.t("beans.destroy.destroyed"), flash[:notice]
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

  test "viewer cannot edit close reopen duplicate or delete bean" do
    memberships(:member).update!(role: "viewer")
    user = users(:two)
    user.update!(active_workspace: workspaces(:household))
    sign_in_as(user)
    bean = beans(:open_household)

    get bean_path(bean)
    assert_response :success
    assert_select "[data-testid=bean-danger-zone]", count: 0

    get edit_bean_path(bean)
    assert_redirected_to root_path

    assert_no_changes -> { bean.reload.name } do
      patch bean_path(bean), params: { bean: { name: "Nope", bag_size_grams: "250" } }
    end
    assert_redirected_to root_path

    assert_no_changes -> { bean.reload.archived_at } do
      patch close_bean_path(bean)
    end
    assert_redirected_to root_path

    assert_no_difference -> { workspaces(:household).beans.count } do
      post duplicate_bean_path(bean)
    end
    assert_redirected_to root_path

    assert_no_difference -> { workspaces(:household).beans.count } do
      delete bean_path(bean)
    end
    assert_redirected_to root_path
  end

  test "show is scoped to active workspace" do
    sign_in_as(users(:one))

    get bean_path(beans(:other_workspace_open))

    assert_response :not_found
  end
end
