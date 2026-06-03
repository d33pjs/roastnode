require "test_helper"

class BeansControllerTest < ActionDispatch::IntegrationTest
  test "index lists active workspace beans only" do
    sign_in_as(users(:one))
    bean = beans(:open_household)

    get beans_path

    assert_response :success
    assert_select "h1", I18n.t("beans.index.title")
    assert_select "a[href=?]", bean_path(bean), text: /#{bean.name}/
    assert_select "body", text: beans(:other_workspace_open).name, count: 0
  end

  test "index renders primary bean photo and remaining summary" do
    sign_in_as(users(:one))
    bean = beans(:open_household)
    first = attach_photo(bean)
    primary = attach_photo(bean)
    bean.set_primary_photo!(primary)

    get beans_path

    assert_response :success
    assert_select "th", text: "Channeling", count: 0
    assert_select "table", count: 0
    assert_select "[data-testid=bean-card-list]"
    assert_select "[data-testid=bean-desktop-table]", count: 0
    assert_select "a[data-testid=bean-card][href=?]", bean_path(bean)
    assert_select "img[data-testid=bean-card-photo][src=?]", media_attachment_path(primary, variant: :thumbnail)
    assert_select "img[data-testid=bean-card-photo][src=?]", media_attachment_path(first, variant: :thumbnail), count: 0
    assert_select "[data-testid=?]", "bean-card-rating-#{bean.id}", text: /4/
    assert_select "[data-testid=?]", "bean-card-remaining-#{bean.id}", "150g of 250g"
    assert_select "[data-testid=?][data-remaining-state=plenty]", "bean-card-progress-#{bean.id}"
    assert_select "[data-testid^=bean-list-channeling]", count: 0
  end

  test "index renders low inventory warnings and finished bag statistics" do
    sign_in_as(users(:one))
    low = workspaces(:household).beans.create!(
      name: "Low Bag",
      roaster_name: "Good Coffee",
      bag_size_grams: 250,
      remaining_grams: 14,
      opened_on: Date.new(2026, 5, 20)
    )
    finished = workspaces(:household).beans.create!(
      name: "Finished Stats Bag",
      roaster_name: "Good Coffee",
      bag_size_grams: 250,
      remaining_grams: 14,
      opened_on: Date.new(2026, 5, 10),
      finished_at: Time.zone.local(2026, 5, 23, 9)
    )

    get beans_path

    assert_response :success
    assert_select "[data-testid=?][data-remaining-state=low]", "bean-card-progress-#{low.id}"
    assert_select "[data-testid=?]", "bean-card-low-warning-#{low.id}", text: /Low/
    assert_select "[data-testid=?]", "bean-card-finished-stats-#{finished.id}", text: /236g/
    assert_select "[data-testid=?]", "bean-card-finished-stats-#{finished.id}", text: /13 days/
    assert_select "[data-testid=?]", "bean-card-finished-stats-#{finished.id}", text: /18[,.]2g\/day/
    assert_select "[data-testid=?]", "bean-card-finished-on-#{finished.id}", text: /Finished/
    assert_select "[data-testid=?]", "bean-card-progress-#{finished.id}", count: 0
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

  test "member can create stock bean" do
    user = users(:two)
    user.update!(active_workspace: workspaces(:household))
    sign_in_as(user)

    assert_difference -> { workspaces(:household).beans.count }, 1 do
      post beans_path, params: {
        bean: {
          bag_status: "stock",
          name: "Pantry Valley",
          roaster_name: "Calendar Coffee",
          bag_size_grams: "250",
          remaining_grams: "",
          opened_on: "2026-05-26"
        }
      }
    end

    bean = workspaces(:household).beans.order(:created_at).last
    assert_redirected_to bean_path(bean)
    assert_equal "stock", bean.bag_status
    assert_nil bean.opened_on
    assert_equal 250.to_d, bean.remaining_grams
  end

  test "new includes photo upload" do
    sign_in_as(users(:one))

    get new_bean_path

    assert_response :success
    assert_select "input[type=file][name=?][multiple=multiple]", "bean[photos][]"
    assert_select "input[name=?]", "bean[purchased_on]"
    assert_select "select[name=?]", "bean[bag_status]"
    assert_select "input[type=text][inputmode=decimal][name=?]", "bean[bag_size_grams]"
    assert_select "input[type=text][inputmode=decimal][name=?]", "bean[remaining_grams]"
    assert_select "input[type=text][inputmode=decimal][name=?]", "bean[purchase_price]"
    assert_select "input[name=?]", "bean[roast_date]"
    assert_select "select[name=?]", "bean[roast_type]"
    assert_select "input[type=text][inputmode=decimal][name=?]", "bean[roast_degree]"
    assert_select "input[name=?]", "bean[purchase_price]"
    assert_select "input[name=?]", "bean[decaffeinated]"
    assert_select "input[name=?]", "bean[purchase_url]"
    assert_select "textarea[name=?]", "bean[tasting_notes]"
    assert_select "h2", I18n.t("beans.form.sections.origin")
    assert_select "input[name=?]", "bean[country]"
    assert_select "input[name=?]", "bean[blend_percentage]"
  end

  test "new renders mobile-first bean form sections in approved order" do
    sign_in_as(users(:one))

    get new_bean_path

    assert_response :success
    assert_select "[data-testid=bean-form-section][data-section=identity]"
    assert_select "[data-testid=bean-form-section][data-section=inventory]"
    assert_select "[data-testid=bean-form-section][data-section=roast]"
    assert_select "[data-testid=bean-form-section][data-section=origin]"
    assert_select "[data-testid=bean-form-section][data-section=purchase]"
    assert_select "[data-testid=bean-form-section][data-section=taste]"

    assert_appears_before "data-section=\"identity\"", "data-section=\"inventory\""
    assert_appears_before "data-section=\"inventory\"", "data-section=\"roast\""
    assert_appears_before "data-section=\"roast\"", "data-section=\"origin\""
    assert_appears_before "data-section=\"origin\"", "data-section=\"purchase\""
    assert_appears_before "data-section=\"purchase\"", "data-section=\"taste\""

    assert_appears_before "bean[name]", "bean[roaster_name]"
    assert_appears_before "bean[photos][]", "bean[bag_status]"
    assert_appears_before "bean[bag_status]", "bean[bag_size_grams]"
    assert_appears_before "bean[remaining_grams]", "bean[opened_on]"
    assert_appears_before "bean[roast_date]", "bean[roast_type]"
    assert_appears_before "bean[country]", "bean[region]"
    assert_appears_before "bean[purchased_on]", "bean[purchase_price]"
    assert_appears_before "bean[tasting_notes]", "bean[notes]"
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

  test "writer can edit bean with comma decimal values" do
    sign_in_as(users(:one))
    bean = beans(:open_household)

    patch bean_path(bean), params: {
      bean: {
        name: "Comma Blend",
        bag_size_grams: "1.000,0 g",
        remaining_grams: "111,5g",
        roast_degree: "3,5",
        purchase_price: "14,90 €"
      }
    }

    assert_redirected_to bean_path(bean)
    bean.reload
    assert_equal "Comma Blend", bean.name
    assert_equal 1000.to_d, bean.bag_size_grams
    assert_equal 111.5.to_d, bean.remaining_grams
    assert_equal 3.5.to_d, bean.roast_degree
    assert_equal 1490, bean.purchase_price_cents
  end

  test "writer can edit bean public note and public links" do
    sign_in_as(users(:one))
    bean = beans(:open_household)
    share = create_public_brew_share_for(brews(:morning_espresso))

    get edit_bean_path(bean)

    assert_response :success
    assert_select "textarea[name=?]", "bean[public_note]"
    assert_select "[data-testid=record-links-fields]"

    patch bean_path(bean), params: {
      bean: {
        name: bean.name,
        bag_size_grams: bean.bag_size_grams.to_s,
        remaining_grams: bean.remaining_grams.to_s,
        bag_status: bean.bag_status,
        public_note: "Public bean note.",
        record_links_attributes: {
          "0" => {
            label: "Buy beans",
            url: "https://example.com/beans",
            kind: "affiliate",
            visibility: "public",
            position: "10"
          }
        }
      }
    }

    assert_redirected_to bean_path(bean)
    assert_equal "Public bean note.", bean.reload.public_note
    assert_equal "Buy beans", bean.record_links.first.label
    assert_includes share.reload.snapshot.dig("bean", "links").map { |link| link.fetch("label") }, "Buy beans"
  end

  test "writer can update bean lifecycle status" do
    sign_in_as(users(:one))
    bean = beans(:open_household)

    patch bean_path(bean), params: {
      bean: {
        bag_status: "used_up",
        name: bean.name,
        bag_size_grams: bean.bag_size_grams.to_s,
        remaining_grams: bean.remaining_grams.to_s,
        opened_on: bean.opened_on.iso8601
      }
    }

    assert_redirected_to bean_path(bean)
    assert_equal "used_up", bean.reload.bag_status
    assert_equal 0.to_d, bean.remaining_grams

    patch bean_path(bean), params: {
      bean: {
        bag_status: "archived",
        name: bean.name,
        bag_size_grams: bean.bag_size_grams.to_s,
        remaining_grams: bean.remaining_grams.to_s,
        opened_on: bean.opened_on.iso8601
      }
    }

    assert_redirected_to bean_path(bean)
    assert_equal "archived", bean.reload.bag_status
    assert_not_nil bean.archived_at
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

  test "writer can finish archive and reopen bean" do
    sign_in_as(users(:one))
    bean = beans(:open_household)
    bean.update!(remaining_grams: 14)

    patch finish_bean_path(bean)
    assert_redirected_to bean_path(bean)
    bean.reload
    assert_equal "finished", bean.bag_status
    assert_not_nil bean.finished_at
    assert_nil bean.archived_at
    assert_equal 14.to_d, bean.remaining_grams

    patch close_bean_path(bean)
    assert_redirected_to bean_path(bean)
    bean.reload
    assert_equal "archived", bean.bag_status
    assert_nil bean.finished_at
    assert_not_nil bean.archived_at

    patch reopen_bean_path(bean)
    assert_redirected_to bean_path(bean)
    bean.reload
    assert_equal "open", bean.bag_status
    assert_nil bean.finished_at
    assert_nil bean.archived_at
    assert_equal 14.to_d, bean.remaining_grams
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
    bean = beans(:open_household)
    attachment = attach_photo(bean)
    bean.set_primary_photo!(attachment)

    get bean_path(bean)

    assert_response :success
    assert_select "a[href='#bean-photos'] img[data-testid=bean-header-photo][src=?]", media_attachment_path(attachment, variant: :thumbnail)
    assert_select "section#bean-photos"
    assert_select "img[src=?]", media_attachment_path(attachment, variant: :thumbnail)
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
    assert_select "[data-testid=bean-remaining-card]"
    assert_select "[data-testid=bean-remaining-value].leading-8", "131g"
    assert_select "[data-testid=bean-remaining-context]", "from 250g bag size"
    assert_select "[data-testid=bean-detail-progress][data-remaining-state=plenty]"
    assert_select "h2", text: I18n.t("beans.show.bag_size"), count: 0
    assert_select "[data-testid=bean-detail-brew-count]", "2"
    assert_select "h2", I18n.t("beans.show.analytics")
    assert_select "[data-testid=bean-brew-count]", count: 0
    assert_select "[data-testid=bean-consumed]", "37g"
    assert_select "[data-testid=bean-channeling-rate]", "50%"
    assert_select "[data-testid=bean-channeling-count]", text: /1 of 2/
    assert_select "[data-testid=bean-best-brews] a[href=?]", brew_path(brew), text: /45g/
    assert_select "[data-testid=bean-recent-brews] a[href=?]", brew_path(brew), text: /10/
    assert_select "h3", I18n.t("beans.show.taste_balance")
    assert_select "h3", I18n.t("beans.show.retention_markers")
    assert_select "[data-testid=bean-grind-setting-distribution]", text: /10/
    assert_select "body", text: /Other Workspace Bean/, count: 0
  end

  test "show keeps bean analytics all time without date filters" do
    sign_in_as(users(:one))
    bean = beans(:open_household)
    brews(:morning_espresso).update!(occurred_at: Time.zone.local(2026, 5, 26, 8, 0, 0))
    bean.brews.create!(
      workspace: bean.workspace,
      user: users(:one),
      grinder: equipment(:household_grinder),
      machine: equipment(:household_machine),
      occurred_at: Time.zone.local(2026, 5, 20, 9, 30, 0),
      bean_weight_grams: 20,
      ground_weight_grams: 20.4,
      dose_grams: 20,
      beverage_grams: 50,
      total_time_seconds: 32,
      grind_setting: "10",
      taste_balance: "bitter",
      channeling: true,
      rating: 3
    )

    get bean_path(bean), params: { start_date: "2026-05-26", end_date: "2026-05-26" }

    assert_response :success
    assert_select "input[data-testid=bean-statistics-start-date]", count: 0
    assert_select "input[data-testid=bean-statistics-end-date]", count: 0
    assert_select "[data-testid=bean-detail-brew-count]", "2"
    assert_select "[data-testid=bean-consumed]", "38g"
    assert_select "[data-testid=bean-channeling-rate]", "50%"
    assert_select "[data-testid=bean-channeling-count]", text: /1 of 2/
  end

  test "show always renders grinder tendency with no-first-brew empty state" do
    sign_in_as(users(:one))
    bean = beans(:second_open_household)
    grinder = equipment(:household_grinder)
    create_suggestion_history(grinder:)

    get bean_path(bean)

    assert_response :success
    assert_select "[data-testid=bean-grinder-suggestions]"
    assert_select "[data-testid=bean-grinder-suggestions-empty]", text: /Log the first brew/
    assert_select "a", text: I18n.t("beans.show.suggest_grinder"), count: 0
  end

  test "show renders first brew calibration facts without enough history" do
    sign_in_as(users(:one))
    bean = beans(:second_open_household)
    grinder = equipment(:household_grinder)
    create_suggestion_calibration_brew(bean:, grinder:)

    get bean_path(bean)

    assert_response :success
    assert_select "[data-testid=bean-grinder-suggestions]"
    assert_select "[data-testid=bean-grinder-calibration]", text: /1\/3,0/
    assert_select "[data-testid=bean-grinder-calibration]", text: /1:2[,.]53/
    assert_select "[data-testid=bean-grinder-calibration]", text: /42s/
    assert_select "[data-testid=bean-grinder-suggestions-empty]", text: /Not enough comparable/
  end

  test "show automatically renders grinder suggestions from the first brew for non duplicated beans" do
    sign_in_as(users(:one))
    bean = beans(:second_open_household)
    grinder = equipment(:household_grinder)
    create_suggestion_history(grinder:)
    create_suggestion_calibration_brew(bean:, grinder:)

    get bean_path(bean)

    assert_response :success
    assert_select "[data-testid=bean-grinder-suggestions]"
    assert_select "[data-testid=bean-grinder-suggestion]", text: /#{grinder.name}/
    assert_select "[data-testid=bean-grinder-suggestion]", text: /1\/3,75/
    assert_select "[data-testid=bean-grinder-suggestion]", text: /1\/3,0/
    assert_select "[data-testid=bean-grinder-suggestion]", text: /42s/
  end

  test "show suppresses automatic grinder calculation for duplicated beans" do
    sign_in_as(users(:one))
    duplicate = beans(:open_household).duplicate_for_new_bag!
    grinder = equipment(:household_grinder)
    create_suggestion_history(grinder:)
    create_suggestion_calibration_brew(bean: duplicate, grinder:)

    get bean_path(duplicate)

    assert_response :success
    assert_select "[data-testid=bean-grinder-suggestions]"
    assert_select "[data-testid=bean-grinder-suggestion]", count: 0
    assert_select "[data-testid=bean-grinder-suggestions-empty]", text: /Automatic calculation is skipped/
    assert_select "a[data-testid=bean-grinder-manual-suggest][href=?]", bean_path(duplicate, suggest_grinder: "1")
    assert_select "body", text: /1\/3,75/, count: 0
    assert_select "a", text: I18n.t("beans.show.suggest_grinder"), count: 0
  end

  test "show renders manual grinder suggestions for duplicated beans" do
    sign_in_as(users(:one))
    duplicate = beans(:open_household).duplicate_for_new_bag!
    grinder = equipment(:household_grinder)
    create_suggestion_history(grinder:)
    create_suggestion_calibration_brew(bean: duplicate, grinder:)

    get bean_path(duplicate), params: { suggest_grinder: "1" }

    assert_response :success
    assert_select "[data-testid=bean-grinder-suggestions]"
    assert_select "[data-testid=bean-grinder-suggestion]", text: /#{grinder.name}/
    assert_select "[data-testid=bean-grinder-suggestion]", text: /1\/3,75/
  end

  test "show renders danger zone for writers" do
    sign_in_as(users(:one))
    bean = beans(:open_household)

    get bean_path(bean)

    assert_response :success
    assert_select "a[href=?]", new_bean_inventory_adjustment_path(bean), text: I18n.t("beans.show.adjust_inventory")
    assert_select "form[data-testid=bean-finish-form][action=?]", finish_bean_path(bean)
    assert_select "form[data-testid=bean-finish-form] input[name=_method][value=patch]"
    assert_select "[data-testid=bean-issues-zone]"
    assert_select "[data-testid=bean-issues-zone] form[action=?]", close_bean_path(bean)
    assert_select "[data-testid=bean-issues-zone]", text: /best before/i
    assert_select "[data-testid=bean-danger-zone]"
    assert_select "form[action=?][method=post]", bean_path(bean)
    assert_select "input[name=_method][value=delete]"
    assert_select "button", text: I18n.t("beans.show.delete")
    assert_select "[data-testid=bean-danger-zone]", text: I18n.t("beans.show.close"), count: 0
    assert_select "[data-turbo-confirm=?]", I18n.t("beans.show.delete_confirmation", count: bean.brews.count)
  end

  test "finished beans render finished status and reopen action" do
    sign_in_as(users(:one))
    bean = beans(:open_household)

    patch finish_bean_path(bean)
    assert_redirected_to bean_path(bean)

    get bean_path(bean)

    assert_response :success
    assert_select "[data-testid=bean-status-card]", text: /Finished/
    assert_select "body", text: /Translation missing/, count: 0
    assert_select "form[action=?]", reopen_bean_path(bean)
    assert_select "form[data-testid=bean-finish-form]", count: 0
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

  test "viewer cannot edit finish close reopen duplicate or delete bean" do
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

    assert_no_changes -> { bean.reload.finished_at } do
      patch finish_bean_path(bean)
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

  private
    def assert_appears_before(first, second)
      first_index = response.body.index(first)
      second_index = response.body.index(second)

      assert first_index, "Expected #{first.inspect} to appear in response body"
      assert second_index, "Expected #{second.inspect} to appear in response body"
      assert first_index < second_index, "Expected #{first.inspect} to appear before #{second.inspect}"
    end

    def create_suggestion_history(grinder:)
      workspace = grinder.workspace
      [
        [ "1/5,25", 18, 45, 28, 5 ],
        [ "1/5,50", 18, 44, 29, 4 ],
        [ "a little finer", 18, 45, 28, 5 ]
      ].each do |grind_setting, dose, beverage, total_time, rating|
        workspace.brews.create!(
          user: users(:one),
          bean: beans(:open_household),
          grinder:,
          machine: equipment(:household_machine),
          occurred_at: Time.current,
          bean_weight_grams: dose,
          ground_weight_grams: dose,
          dose_grams: dose,
          beverage_grams: beverage,
          total_time_seconds: total_time,
          grind_setting:,
          rating:
        )
      end
    end

    def create_suggestion_calibration_brew(bean:, grinder:)
      grinder.workspace.brews.create!(
        user: users(:one),
        bean:,
        grinder:,
        machine: equipment(:household_machine),
        occurred_at: Time.current,
        bean_weight_grams: 17.9,
        ground_weight_grams: 17.9,
        dose_grams: 17.9,
        beverage_grams: 45.3,
        total_time_seconds: 42,
        grind_setting: "1/3,0"
      )
    end

    def create_public_brew_share_for(brew, selected_photo_attachment_ids: [])
      brew.create_public_brew_share!(
        workspace: brew.workspace,
        created_by: users(:one),
        updated_by: users(:one),
        enabled: true,
        title: "Shared shot",
        selected_photo_attachment_ids:,
        snapshot: PublicBrewShareSnapshotBuilder.new(
          brew:,
          title: "Shared shot",
          selected_photo_attachment_ids:
        ).call
      )
    end
end
