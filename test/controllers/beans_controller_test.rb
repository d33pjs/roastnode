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
    assert_select "article[data-testid=bean-card]"
    assert_select "a[data-testid=?][href=?]", "bean-card-detail-#{bean.id}", bean_path(bean)
    assert_select "img[data-testid=bean-card-photo][src=?]", media_attachment_path(primary, variant: :thumbnail)
    assert_select "img[data-testid=bean-card-photo][src=?]", media_attachment_path(first, variant: :thumbnail), count: 0
    assert_select "[data-testid=?]", "bean-card-rating-#{bean.id}", text: /4/
    assert_select "[data-testid=?]", "bean-card-remaining-#{bean.id}", "150g of 250g"
    assert_select "[data-testid=?][data-remaining-state=plenty]", "bean-card-progress-#{bean.id}"
    assert_select "[data-testid^=bean-list-channeling]", count: 0
  end

  test "index bean cards use structured origin fallback" do
    sign_in_as(users(:one))
    region_bean = beans(:open_household)
    region_bean.update!(country: nil, region: "Huila", continent: "South America")
    continent_bean = beans(:second_open_household)
    continent_bean.update!(country: nil, region: nil, continent: "Africa", origin: "Legacy Origin")
    legacy_bean = workspaces(:household).beans.create!(
      name: "Legacy Origin Bag",
      roaster_name: "Archive Coffee",
      bag_size_grams: 250,
      remaining_grams: 250,
      opened_on: Date.current,
      origin: "Old Label"
    )

    get beans_path

    assert_response :success
    assert_select "[data-testid=?]", "bean-card-origin-#{region_bean.id}", text: "Huila"
    assert_select "[data-testid=?]", "bean-card-origin-#{continent_bean.id}", text: "Africa"
    assert_select "[data-testid=?]", "bean-card-origin-#{legacy_bean.id}", text: "Old Label"
  end

  test "index groups active beans before historical bags" do
    sign_in_as(users(:one))
    workspace = workspaces(:household)
    open_recent = beans(:open_household)
    open_never_used = beans(:second_open_household)
    stock = workspace.beans.create!(
      name: "Pantry Stock Bag",
      roaster_name: "Future Coffee",
      bag_size_grams: 250,
      remaining_grams: 250,
      opened_on: nil,
      purchased_on: Date.new(2026, 6, 2)
    )
    finished_recent = workspace.beans.create!(
      name: "Finished Recent Bag",
      roaster_name: "Past Coffee",
      bag_size_grams: 250,
      remaining_grams: 8,
      opened_on: Date.new(2026, 5, 1),
      finished_at: Time.zone.local(2026, 6, 2, 8, 0, 0)
    )
    archived = beans(:archived_household)
    open_newest = workspace.beans.create!(
      name: "Open Newest Bag",
      roaster_name: "Recent Coffee",
      bag_size_grams: 250,
      remaining_grams: 220,
      opened_on: Date.new(2026, 6, 1)
    )

    brews(:morning_espresso).update!(bean: open_recent, occurred_at: Time.zone.local(2026, 5, 20, 8, 0, 0))
    workspace.brews.create!(
      user: users(:one),
      bean: finished_recent,
      grinder: equipment(:household_grinder),
      machine: equipment(:household_machine),
      occurred_at: Time.zone.local(2026, 6, 3, 8, 0, 0),
      bean_weight_grams: 18,
      ground_weight_grams: 18,
      dose_grams: 18,
      beverage_grams: 42
    )
    workspace.brews.create!(
      user: users(:one),
      bean: open_newest,
      grinder: equipment(:household_grinder),
      machine: equipment(:household_machine),
      occurred_at: Time.zone.local(2026, 6, 1, 8, 0, 0),
      bean_weight_grams: 18,
      ground_weight_grams: 18,
      dose_grams: 18,
      beverage_grams: 42
    )

    get beans_path

    assert_response :success
    assert_select "[data-testid=bean-group][data-group=open]"
    assert_select "[data-testid=bean-group][data-group=stock]"
    assert_select "[data-testid=bean-group][data-group=finished]"
    assert_select "[data-testid=bean-group][data-group=archived]"
    assert_appears_before I18n.t("beans.index.groups.open"), open_newest.name
    assert_appears_before open_newest.name, open_recent.name
    assert_appears_before open_recent.name, open_never_used.name
    assert_appears_before open_never_used.name, I18n.t("beans.index.groups.stock")
    assert_appears_before I18n.t("beans.index.groups.stock"), stock.name
    assert_appears_before stock.name, I18n.t("beans.index.groups.finished")
    assert_appears_before I18n.t("beans.index.groups.finished"), finished_recent.name
    assert_appears_before finished_recent.name, I18n.t("beans.index.groups.archived")
    assert_appears_before I18n.t("beans.index.groups.archived"), archived.name
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
    assert_select "[data-testid=?][data-remaining-state=low]", "bean-card-progress-#{finished.id}"
  end

  test "index stock cards render rebuy and quick open actions for writers" do
    sign_in_as(users(:one))
    bean = workspaces(:household).beans.create!(
      name: "Shelf Bag",
      roaster_name: "Shelf Roaster",
      bag_size_grams: 250,
      remaining_grams: 250,
      opened_on: nil,
      purchase_url: "https://example.com/rebuy"
    )

    get beans_path

    assert_response :success
    assert_select "article[data-testid=bean-card].flex.h-full.flex-col"
    assert_select "a[data-testid=?].flex-1", "bean-card-detail-#{bean.id}"
    assert_select "[data-testid=?].shrink-0", "bean-card-actions-#{bean.id}" do
      assert_select "a[data-testid=?][href=?]", "bean-card-rebuy-#{bean.id}", bean.purchase_url
      assert_select "form[data-testid=?][action=?]", "bean-card-open-bag-#{bean.id}", open_bag_bean_path(bean)
    end
  end

  test "index does not render legacy invalid purchase urls as clickable or raw actions" do
    sign_in_as(users(:one))
    bean = workspaces(:household).beans.create!(
      name: "Legacy Bad Shelf",
      roaster_name: "Shelf Roaster",
      bag_size_grams: 250,
      remaining_grams: 250,
      opened_on: nil
    )
    bean.update_column(:purchase_url, "javascript:alert('bean')")

    get beans_path

    assert_response :success
    assert_select "a[data-testid=?]", "bean-card-rebuy-#{bean.id}", count: 0
    assert_select "a[href=?]", bean.reload.purchase_url, count: 0
    assert_select "body", text: /javascript:alert\('bean'\)/, count: 0
  end

  test "viewer index omits stock quick open forms" do
    memberships(:member).update!(role: "viewer")
    users(:two).update!(active_workspace: workspaces(:household))
    bean = workspaces(:household).beans.create!(
      name: "Viewer Stock Shelf",
      roaster_name: "Shelf Roaster",
      bag_size_grams: 250,
      remaining_grams: 250,
      opened_on: nil
    )
    sign_in_as(users(:two))

    get beans_path

    assert_response :success
    assert_select "form[data-testid=?]", "bean-card-open-bag-#{bean.id}", count: 0
  end

  test "new bean defaults to full unopened stock despite a submitted opened date" do
    user = users(:two)
    user.update!(active_workspace: workspaces(:household))
    sign_in_as(user)
    event = nil

    assert_no_difference -> { InventoryAdjustment.count } do
      assert_difference -> { workspaces(:household).beans.count }, 1 do
        event = assert_activity_event(action: "bean.created", workspace: workspaces(:household), actor: user) do
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
      end
    end

    bean = workspaces(:household).beans.order(:created_at).last
    assert_redirected_to bean_path(bean)
    assert_equal bean, event.subject
    assert_equal "stock", event.metadata.fetch("status")
    assert_equal "stock", bean.bag_status
    assert_equal 250.to_d, bean.remaining_grams
    assert_nil bean.opened_on
    assert_nil bean.finished_at
    assert_nil bean.archived_at
    assert_equal 1, bean.photos.count
  end

  test "member can explicitly create an open bean" do
    user = users(:two)
    user.update!(active_workspace: workspaces(:household))
    sign_in_as(user)
    event = nil

    assert_difference -> { workspaces(:household).beans.count }, 1 do
      event = assert_activity_event(action: "bean.created", workspace: workspaces(:household), actor: user) do
        post beans_path, params: {
          bean: {
            bag_status: "open",
            name: "Pantry Valley",
            roaster_name: "Calendar Coffee",
            bag_size_grams: "250",
            remaining_grams: "",
            opened_on: "2026-05-26"
          }
        }
      end
    end

    bean = workspaces(:household).beans.order(:created_at).last
    assert_redirected_to bean_path(bean)
    assert_equal bean, event.subject
    assert_equal "open", event.metadata.fetch("status")
    assert_equal "open", bean.bag_status
    assert_equal Date.new(2026, 5, 26), bean.opened_on
    assert_nil bean.finished_at
    assert_nil bean.archived_at
    assert_equal 250.to_d, bean.remaining_grams
  end

  test "new includes photo upload" do
    sign_in_as(users(:one))

    get new_bean_path

    assert_response :success
    assert_select "input[type=file][name=?][multiple=multiple]", "bean[photos][]"
    assert_select "select[name=?] option[value=stock][selected]", "bean[bag_status]"
    assert_select "input[name=?]", "bean[opened_on]" do |inputs|
      assert inputs.all? { |input| input["value"].blank? }
    end
    assert_select "input[name=?]", "bean[purchased_on]"
    assert_select "select[name=?]", "bean[bag_status]"
    assert_select "input[type=text][inputmode=decimal][name=?]", "bean[bag_size_grams]"
    assert_select "input[type=text][inputmode=decimal][name=?]", "bean[remaining_grams]"
    assert_select "input[type=text][inputmode=decimal][name=?]", "bean[purchase_price]"
    assert_select "input[name=?]", "bean[roast_date]"
    assert_select "select[name=?]", "bean[roast_type]"
    assert_select "select[name=?]", "bean[grind_state]"
    assert_select "input[type=text][inputmode=decimal][name=?]", "bean[roast_degree]"
    assert_select "input[name=?]", "bean[purchase_price]"
    assert_select "input[name=?]", "bean[decaffeinated]"
    assert_select "label[for=bean_purchase_url]", "Purchase Website"
    assert_select "input[type=url][name=?][placeholder=?]", "bean[purchase_url]", "URL to buy this bag again"
    assert_select "textarea[name=?]", "bean[tasting_notes]"
    assert_select "h2", I18n.t("beans.form.sections.origin")
    assert_select "input[name=?]", "bean[country]"
    assert_select "input[name=?]", "bean[blend_percentage]"
    assert_select "input[name=?][placeholder=?]", "bean[elevation]", "1100-1200m"
    assert_select "input[name=?][placeholder=?]", "bean[variety]", "Arabica and/or Robusta"
    assert_select "input[name=?][placeholder=?]", "bean[blend_percentage]", "50%/60%"
    assert_select "input[name=?][placeholder=?]", "bean[process]", "washed or natural"
    assert_select "label[for=bean_coffee_origin_url]", "Coffee Origin Website"
    assert_select "input[type=url][name=?][placeholder=?]", "bean[coffee_origin_url]", "URL to original Coffee"
    assert_select "[data-controller=roaster-suggestions][data-roaster-suggestions-url-value=?]", roaster_suggestions_beans_path(format: :json)
    assert_select "input[name=?][data-roaster-suggestions-target=input][data-action*=?]", "bean[roaster_name]", "input->roaster-suggestions#search"
    assert_select "[data-roaster-suggestions-target=list]"
  end

  test "new bean form uses stock-aware inventory sync and Brew-style rating control" do
    sign_in_as(users(:one))

    get new_bean_path

    assert_response :success
    assert_select "[data-controller=?]", "bean-inventory-form"
    assert_select "select[name=?][data-bean-inventory-form-target=?]", "bean[bag_status]", "status"
    assert_select "input[name=?][data-bean-inventory-form-target=?]", "bean[bag_size_grams]", "bagSize"
    assert_select "input[name=?][data-bean-inventory-form-target=?]", "bean[remaining_grams]", "remaining"
    assert_select "input[name=?][data-bean-inventory-form-target=?]", "bean[opened_on]", "openedOn"
    assert_select "[data-section=inventory] > div.grid", count: 1 do |grids|
      assert_includes grids.first["class"].split, "lg:grid-cols-5"
    end
    assert_select "[data-section=roast] > div.grid", count: 1 do |grids|
      assert_includes grids.first["class"].split, "lg:grid-cols-4"
    end
    assert_select "[data-section=roast] > fieldset[data-testid=bean-form-rating-row]" do
      assert_select "legend", text: I18n.t("beans.form.rating")
      assert_select "[data-testid=bean-rating-options]"
    end
    assert_select "[data-testid=bean-form-rating-row] input[type=radio][name=?]", "bean[rating]", count: 6
    assert_select "[data-testid=bean-form-rating-row] .rn-rating-scale input[type=radio]", count: 5
    assert_select "[data-testid=bean-form-rating-row] .rn-rating-empty", text: I18n.t("beans.form.no_rating")
  end

  test "new bean form renders origin and process fields in approved order" do
    sign_in_as(users(:one))

    get new_bean_path

    assert_response :success
    assert_appears_before "bean[continent]", "bean[country]"
    assert_appears_before "bean[country]", "bean[region]"
    assert_appears_before "bean[region]", "bean[elevation]"
    assert_appears_before "bean[elevation]", "bean[variety]"
    assert_appears_before "bean[variety]", "bean[blend_percentage]"
    assert_appears_before "bean[blend_percentage]", "bean[process]"
    assert_appears_before "bean[process]", "bean[coffee_origin_url]"
    assert_appears_before "bean[coffee_origin_url]", "bean[blend_type]"
    assert_appears_before "bean[blend_type]", "bean[country_of_manufacturer]"
    assert_appears_before "bean[country_of_manufacturer]", "bean[manufacturer]"
    assert_appears_before "bean[manufacturer]", "bean[farm]"
    assert_appears_before "bean[farm]", "bean[farmer]"
    assert_appears_before "bean[farmer]", "bean[harvested]"
  end

  test "writer can save new origin and manufacturer metadata" do
    sign_in_as(users(:one))

    assert_difference -> { workspaces(:household).beans.count }, 1 do
      post beans_path, params: {
        bean: {
          name: "Metadata Bag",
          roaster_name: "Calendar Coffee",
          bag_size_grams: "250",
          remaining_grams: "250",
          opened_on: "2026-06-13",
          continent: "South America",
          country: "Colombia",
          country_of_manufacturer: "Germany",
          manufacturer: "Calendar Coffee"
        }
      }
    end

    bean = workspaces(:household).beans.order(:created_at).last
    assert_equal "South America", bean.continent
    assert_equal "Germany", bean.country_of_manufacturer
    assert_equal "Calendar Coffee", bean.manufacturer
  end

  test "writer can save purchase and coffee origin websites separately" do
    sign_in_as(users(:one))

    post beans_path, params: {
      bean: {
        name: "Two Link Bag",
        bag_size_grams: "250",
        purchase_url: " https://shop.example/two-link ",
        coffee_origin_url: " https://origin.example/two-link "
      }
    }

    bean = workspaces(:household).beans.find_by!(name: "Two Link Bag")
    assert_redirected_to bean_path(bean)
    assert_equal "https://shop.example/two-link", bean.purchase_url
    assert_equal "https://origin.example/two-link", bean.coffee_origin_url
  end

  test "roaster suggestions match substring across active workspace bean history" do
    sign_in_as(users(:one))
    workspace = workspaces(:household)
    workspace.beans.create!(
      name: "Wildbad Espresso",
      roaster_name: "Kaffeemanufaktur Bad Wildbad",
      bag_size_grams: 250,
      remaining_grams: 0,
      opened_on: Date.new(2026, 4, 1),
      archived_at: Time.current
    )

    get roaster_suggestions_beans_path, params: { q: "bad" }, as: :json

    assert_response :success
    suggestions = JSON.parse(response.body).fetch("suggestions")
    assert_includes suggestions, "Kaffeemanufaktur Bad Wildbad"
  end

  test "roaster suggestions stay scoped to active workspace and skip blanks" do
    sign_in_as(users(:one))
    workspaces(:household).beans.create!(
      name: "Blank Roaster Bag",
      roaster_name: "",
      bag_size_grams: 250,
      remaining_grams: 250,
      opened_on: Date.current
    )
    workspaces(:other_household).beans.create!(
      name: "Outside Bad Bag",
      roaster_name: "Bad Outside Roaster",
      bag_size_grams: 250,
      remaining_grams: 250,
      opened_on: Date.current
    )

    get roaster_suggestions_beans_path, params: { q: "bad" }, as: :json

    assert_response :success
    suggestions = JSON.parse(response.body).fetch("suggestions")
    assert_not_includes suggestions, "Bad Outside Roaster"
    assert_not_includes suggestions, ""
  end

  test "blank roaster suggestion query returns no suggestions" do
    sign_in_as(users(:one))

    get roaster_suggestions_beans_path, params: { q: " " }, as: :json

    assert_response :success
    assert_equal [], JSON.parse(response.body).fetch("suggestions")
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
          grind_state: "pre_ground",
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
    assert_equal "pre_ground", bean.grind_state
    assert_equal 3.5.to_d, bean.roast_degree
    assert_equal "blend", bean.blend_type
    assert_equal 1490, bean.purchase_price_cents
    assert_predicate bean, :decaffeinated?
    assert_equal "Colombia", bean.country
  end

  test "writer can edit bean continent despite unchanged legacy invalid purchase url" do
    sign_in_as(users(:one))
    bean = beans(:open_household)
    bean.update_column(:purchase_url, "javascript:alert('bean')")

    patch bean_path(bean), params: {
      bean: {
        name: bean.name,
        continent: "Africa",
        country: "",
        region: ""
      }
    }

    assert_redirected_to bean_path(bean)
    bean.reload
    assert_equal "Africa", bean.continent
    assert_predicate bean.country, :blank?
    assert_predicate bean.region, :blank?
    assert_equal "javascript:alert('bean')", bean.purchase_url
  end

  test "member can create pre-ground bean" do
    user = users(:two)
    user.update!(active_workspace: workspaces(:household))
    sign_in_as(user)

    assert_difference -> { workspaces(:household).beans.count }, 1 do
      post beans_path, params: {
        bean: {
          name: "Ground Filter",
          roaster_name: "Calendar Coffee",
          grind_state: "pre_ground",
          bag_size_grams: "250",
          remaining_grams: "250",
          opened_on: "2026-05-26"
        }
      }
    end

    bean = workspaces(:household).beans.order(:created_at).last
    assert_redirected_to bean_path(bean)
    assert_equal "pre_ground", bean.grind_state
  end

  test "writer can edit bean with comma decimal values" do
    sign_in_as(users(:one))
    bean = beans(:open_household)

    assert_activity_event(action: "bean.updated", workspace: bean.workspace, actor: users(:one), subject: bean) do
      patch bean_path(bean), params: {
        bean: {
          name: "Comma Blend",
          bag_size_grams: "1.000,0 g",
          remaining_grams: "111,5g",
          roast_degree: "3,5",
          purchase_price: "14,90 €"
        }
      }
    end

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

    assert_activity_event(action: "bean.used_up", workspace: bean.workspace, actor: users(:one), subject: bean) do
      patch bean_path(bean), params: {
        bean: {
          bag_status: "used_up",
          name: bean.name,
          bag_size_grams: bean.bag_size_grams.to_s,
          remaining_grams: bean.remaining_grams.to_s,
          opened_on: bean.opened_on.iso8601
        }
      }
    end

    assert_redirected_to bean_path(bean)
    assert_equal "used_up", bean.reload.bag_status
    assert_equal 0.to_d, bean.remaining_grams

    assert_activity_event(action: "bean.archived", workspace: bean.workspace, actor: users(:one), subject: bean) do
      patch bean_path(bean), params: {
        bean: {
          bag_status: "archived",
          name: bean.name,
          bag_size_grams: bean.bag_size_grams.to_s,
          remaining_grams: bean.remaining_grams.to_s,
          opened_on: bean.opened_on.iso8601
        }
      }
    end

    assert_redirected_to bean_path(bean)
    assert_equal "archived", bean.reload.bag_status
    assert_not_nil bean.archived_at
  end

  test "update route emits bean opened when stock becomes open" do
    sign_in_as(users(:one))
    bean = beans(:second_open_household)
    bean.apply_bag_status("stock")
    bean.save!

    assert_activity_event(action: "bean.opened", workspace: bean.workspace, actor: users(:one), subject: bean) do
      patch bean_path(bean), params: {
        bean: {
          bag_status: "open",
          name: bean.name,
          bag_size_grams: bean.bag_size_grams.to_s,
          remaining_grams: bean.remaining_grams.to_s
        }
      }
    end

    assert_redirected_to bean_path(bean)
    assert_equal "open", bean.reload.bag_status
    assert_equal 0, ActivityEvent.where(action: "bean.updated", subject: bean).count
  end

  test "update route emits bean finished when open becomes finished" do
    sign_in_as(users(:one))
    bean = beans(:second_open_household)

    assert_activity_event(action: "bean.finished", workspace: bean.workspace, actor: users(:one), subject: bean) do
      patch bean_path(bean), params: {
        bean: {
          bag_status: "finished",
          name: bean.name,
          bag_size_grams: bean.bag_size_grams.to_s,
          remaining_grams: bean.remaining_grams.to_s,
          opened_on: bean.opened_on.iso8601
        }
      }
    end

    assert_redirected_to bean_path(bean)
    assert_equal "finished", bean.reload.bag_status
    assert_equal 0, ActivityEvent.where(action: "bean.updated", subject: bean).count
  end

  test "update route emits bean reopened when finished becomes open" do
    sign_in_as(users(:one))
    bean = beans(:second_open_household)
    bean.apply_bag_status("finished")
    bean.save!

    assert_activity_event(action: "bean.reopened", workspace: bean.workspace, actor: users(:one), subject: bean) do
      patch bean_path(bean), params: {
        bean: {
          bag_status: "open",
          name: bean.name,
          bag_size_grams: bean.bag_size_grams.to_s,
          remaining_grams: bean.remaining_grams.to_s,
          opened_on: bean.opened_on.iso8601
        }
      }
    end

    assert_redirected_to bean_path(bean)
    assert_equal "open", bean.reload.bag_status
    assert_equal 0, ActivityEvent.where(action: "bean.updated", subject: bean).count
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
    source_photo = attach_photo(source)
    source.set_primary_photo!(source_photo)
    source_remaining = source.remaining_grams
    source_inventory_adjustment_ids = source.inventory_adjustment_ids
    event = nil

    assert_no_difference -> { ActiveStorage::Blob.count } do
      assert_difference -> { ActiveStorage::Attachment.count }, 1 do
        assert_no_difference -> { InventoryAdjustment.count } do
          assert_difference -> { workspaces(:household).beans.count }, 1 do
            event = assert_activity_event(action: "bean.duplicated", workspace: source.workspace, actor: users(:one)) do
              post duplicate_bean_path(source)
            end
          end
        end
      end
    end

    duplicate = workspaces(:household).beans.order(:created_at).last
    duplicate_photo = duplicate.photos.attachments.first
    contract = Activity::EventContract.fetch("bean.duplicated")
    expected_metadata_keys = %w[actor_kind actor_label record_kind subject_label] +
      contract.fetch(:automatic_metadata_keys) + contract.fetch(:detail_keys)
    assert_redirected_to edit_bean_path(duplicate)
    assert_equal duplicate, event.subject
    assert_equal [ "source_label" ], contract.fetch(:detail_keys)
    assert_equal expected_metadata_keys.sort, event.metadata.keys.sort
    assert_equal source.display_name, event.metadata.fetch("source_label")
    assert_equal "stock", event.metadata.fetch("status")
    assert_equal source.name, duplicate.name
    assert_equal "stock", duplicate.bag_status
    assert_equal duplicate.bag_size_grams, duplicate.remaining_grams
    assert_nil duplicate.opened_on
    assert_nil duplicate.finished_at
    assert_nil duplicate.archived_at
    assert_equal source, duplicate.duplicated_from_bean
    assert_equal 1, duplicate.photos.count
    assert_not_equal source_photo.id, duplicate_photo.id
    assert_equal source_photo.blob_id, duplicate_photo.blob_id
    assert_equal duplicate, duplicate_photo.record
    assert_equal duplicate_photo, duplicate.primary_photo_attachment
    assert_equal source_remaining, source.reload.remaining_grams
    assert_equal source_inventory_adjustment_ids, source.inventory_adjustment_ids
  end

  test "activity failure rolls back a duplicated bean and its photo attachments" do
    sign_in_as(users(:one))
    source = beans(:open_household)
    source_photo = attach_photo(source)
    source.set_primary_photo!(source_photo)
    source_remaining = source.remaining_grams
    before_counts = {
      beans: Bean.count,
      adjustments: InventoryAdjustment.count,
      attachments: ActiveStorage::Attachment.count,
      blobs: ActiveStorage::Blob.count,
      activities: ActivityEvent.count
    }

    with_stubbed_singleton_method(Activity::Emitter, :record!, ->(**) { raise "activity write failed" }) do
      assert_raises(RuntimeError) do
        post duplicate_bean_path(source)
      end
    end

    assert_equal before_counts.fetch(:beans), Bean.count
    assert_equal before_counts.fetch(:adjustments), InventoryAdjustment.count
    assert_equal before_counts.fetch(:attachments), ActiveStorage::Attachment.count
    assert_equal before_counts.fetch(:blobs), ActiveStorage::Blob.count
    assert_equal before_counts.fetch(:activities), ActivityEvent.count
    assert_equal source_remaining, source.reload.remaining_grams
    assert_equal [ source_photo.id ], source.photos.attachments.ids
    assert_equal source_photo, source.primary_photo_attachment
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

  test "show back link ignores public bean share workflow referrers" do
    bean = beans(:open_household)
    sign_in_as(users(:one))

    get bean_path(bean), headers: { "HTTP_REFERER" => "http://www.example.com#{new_bean_public_bean_share_path(bean)}" }

    assert_response :success
    assert_select "a[data-testid=back-link][href=?][aria-label=?][title=?]",
      beans_path,
      I18n.t("beans.show.back"),
      I18n.t("beans.show.back")
    assert_select "a[data-testid=back-link] svg.material-symbol[data-symbol=arrow_back]"
    assert_select "a[data-testid=back-link]", text: /#{Regexp.escape(I18n.t("beans.show.back"))}/, count: 0
  end

  test "show uses structured origin fallback and renders cost metrics" do
    sign_in_as(users(:one))
    bean = beans(:second_open_household)
    bean.update!(
      origin: nil,
      country: nil,
      region: "Huila",
      continent: "South America",
      bag_size_grams: 250,
      purchase_price_cents: 1250
    )

    get bean_path(bean)

    assert_response :success
    assert_select "[data-testid=bean-header-origin]", "Huila"
    assert_select "[data-testid=bean-cost-per-kg]", text: /50/
    assert_select "[data-testid=bean-cost-per-package]", text: /12[,.]50/
    assert_select "[data-testid=bean-cost-per-shot]", text: /0[,.]90/
  end

  test "writer sees focused bean rating correction" do
    sign_in_as(users(:one))
    bean = beans(:open_household)

    get bean_path(bean)

    assert_response :success
    assert_select "[data-testid=bean-rating-correction]"
    assert_select "form[action=?][method=post]", rating_bean_path(bean)
    assert_select "input[name=_method][value=patch]"
    assert_select "[data-testid=bean-rating-correction] fieldset" do
      assert_select "legend", text: I18n.t("beans.form.rating")
      assert_select "input[type=radio][name=?]", "bean[rating]", count: 6
    end
    assert_select "[data-testid=bean-rating-correction] input[type=radio][value=?][checked]",
      bean.rating.to_s
    assert_select "input[type=submit][value=?]", I18n.t("beans.show.save_rating")
  end

  test "focused rating updates only rating emits activity and refreshes direct public snapshots" do
    user = users(:one)
    sign_in_as(user)
    bean = beans(:open_household)
    brew = brews(:morning_espresso)
    public_brew_share = create_public_brew_share_for(brew)
    public_bean_share = bean.create_public_bean_share!(
      workspace: bean.workspace,
      created_by: user,
      updated_by: user,
      enabled: true,
      title: "Rating refresh",
      selected_photo_attachment_ids: [],
      snapshot: PublicBeanShareSnapshotBuilder.new(
        bean:,
        title: "Rating refresh",
        selected_photo_attachment_ids: []
      ).call
    )
    original = {
      remaining_grams: bean.remaining_grams,
      opened_on: bean.opened_on,
      purchase_price_cents: bean.purchase_price_cents,
      notes: bean.notes,
      workspace_id: bean.workspace_id
    }
    original_comparisons = public_bean_share.snapshot.fetch("comparisons").deep_dup
    bean_generated_at = public_bean_share.snapshot.fetch("generated_at")
    brew_generated_at = public_brew_share.snapshot.fetch("generated_at")

    event = nil
    travel_to(Time.current + 1.minute) do
      event = assert_activity_event(
        action: "bean.updated", workspace: bean.workspace, actor: user, subject: bean
      ) do
        patch rating_bean_path(bean), params: {
          bean: {
            rating: "5",
            bag_status: "archived",
            remaining_grams: "1",
            opened_on: "2020-01-01",
            purchase_price: "999",
            notes: "Ignored private note",
            workspace_id: workspaces(:other_household).id
          }
        }
      end
    end

    assert_redirected_to bean_path(bean)
    bean.reload
    assert_equal 5, bean.rating
    original.each { |attribute, value| assert_equal value, bean.public_send(attribute) }

    assert_equal bean.workspace, event.workspace
    assert_equal "beans_inventory", event.category
    assert_equal "workspace", event.visibility
    assert_operator public_bean_share.reload.snapshot.fetch("generated_at"), :>, bean_generated_at
    assert_operator public_brew_share.reload.snapshot.fetch("generated_at"), :>, brew_generated_at
    assert_equal original_comparisons, public_bean_share.snapshot.fetch("comparisons")
  end

  test "writer can clear focused bean rating" do
    sign_in_as(users(:one))
    bean = beans(:open_household)

    assert_activity_event(
      action: "bean.updated", workspace: bean.workspace, actor: users(:one), subject: bean
    ) do
      patch rating_bean_path(bean), params: { bean: { rating: "" } }
    end

    assert_redirected_to bean_path(bean)
    assert_nil bean.reload.rating
  end

  test "member can update focused bean rating" do
    member = users(:two)
    member.update!(active_workspace: workspaces(:household))
    sign_in_as(member)
    bean = beans(:open_household)

    assert_activity_event(
      action: "bean.updated", workspace: bean.workspace, actor: member, subject: bean
    ) do
      patch rating_bean_path(bean), params: { bean: { rating: "3" } }
    end

    assert_redirected_to bean_path(bean)
    assert_equal 3, bean.reload.rating
  end

  test "invalid focused rating rolls back without activity" do
    sign_in_as(users(:one))
    bean = beans(:open_household)
    original_rating = bean.rating

    assert_no_difference -> { ActivityEvent.count } do
      patch rating_bean_path(bean), params: { bean: { rating: "6" } }
    end

    assert_response :unprocessable_entity
    assert_select "[data-testid=bean-rating-correction]"
    assert_select "[data-testid=bean-rating-correction]", text: /must be in 1\.\.5/
    assert_equal original_rating, bean.reload.rating
  end

  test "activity failure rolls back the focused rating" do
    sign_in_as(users(:one))
    bean = beans(:open_household)
    brew_share = create_public_brew_share_for(brews(:morning_espresso))
    bean_share = bean.create_public_bean_share!(
      workspace: bean.workspace,
      created_by: users(:one),
      updated_by: users(:one),
      enabled: true,
      title: "Emitter rollback",
      selected_photo_attachment_ids: [],
      snapshot: PublicBeanShareSnapshotBuilder.new(
        bean:, title: "Emitter rollback", selected_photo_attachment_ids: []
      ).call
    )
    original_rating = bean.rating
    original_brew_snapshot = brew_share.snapshot.deep_dup
    original_bean_snapshot = bean_share.snapshot.deep_dup
    emitter_failure = lambda do |**|
      raise ActiveRecord::RecordInvalid.new(ActivityEvent.new)
    end

    travel_to(Time.current + 1.minute) do
      assert_no_difference -> { ActivityEvent.count } do
        with_stubbed_singleton_method(Activity::Emitter, :record!, emitter_failure) do
          patch rating_bean_path(bean), params: { bean: { rating: "5" } }
        end
      end
    end

    assert_response :unprocessable_entity
    assert_equal original_rating, bean.reload.rating
    assert_equal original_brew_snapshot, brew_share.reload.snapshot
    assert_equal original_bean_snapshot, bean_share.reload.snapshot
    assert_select "[data-testid=bean-rating-correction] input[type=radio][value=?][checked]",
      original_rating.to_s
  end

  test "public snapshot refresh failure rolls back rating snapshots and activity" do
    sign_in_as(users(:one))
    bean = beans(:open_household)
    share = create_public_brew_share_for(brews(:morning_espresso))
    original_rating = bean.rating
    original_snapshot = share.snapshot.deep_dup
    refresh_failure = lambda do |*|
      raise ActiveRecord::RecordInvalid.new(PublicBeanShare.new)
    end

    assert_no_difference -> { ActivityEvent.count } do
      with_stubbed_singleton_method(PublicBeanShareRefresher, :refresh_for, refresh_failure) do
        patch rating_bean_path(bean), params: { bean: { rating: "5" } }
      end
    end

    assert_response :unprocessable_entity
    assert_equal original_rating, bean.reload.rating
    assert_equal original_snapshot, share.reload.snapshot
    assert_select "[data-testid=bean-rating-correction] input[type=radio][value=?][checked]",
      original_rating.to_s
  end

  test "viewer cannot see or submit focused bean rating" do
    memberships(:member).update!(role: "viewer")
    viewer = users(:two)
    viewer.update!(active_workspace: workspaces(:household))
    sign_in_as(viewer)
    bean = beans(:open_household)

    get bean_path(bean)
    assert_response :success
    assert_select "[data-testid=bean-rating-correction]", count: 0

    assert_no_difference -> { ActivityEvent.count } do
      assert_no_changes -> { bean.reload.rating } do
        patch rating_bean_path(bean), params: { bean: { rating: "5" } }
      end
    end
    assert_redirected_to root_path
  end

  test "focused rating is scoped to active workspace" do
    sign_in_as(users(:one))
    foreign = beans(:other_workspace_open)

    assert_no_difference -> { ActivityEvent.count } do
      assert_no_changes -> { foreign.reload.rating } do
        patch rating_bean_path(foreign), params: { bean: { rating: "5" } }
      end
    end

    assert_response :not_found
  end

  test "show falls back to legacy origin after structured origin fields" do
    sign_in_as(users(:one))
    bean = beans(:second_open_household)
    bean.update!(
      origin: "Antigua",
      country: nil,
      region: nil,
      continent: nil
    )

    get bean_path(bean)

    assert_response :success
    assert_select "[data-testid=bean-header-origin]", "Antigua"
  end

  test "show renders shortened website link and rebuy action" do
    sign_in_as(users(:one))
    bean = beans(:open_household)
    bean.update!(purchase_url: "https://example.com/beans/house-blend?ref=private")

    get bean_path(bean)

    assert_response :success
    assert_select "a[data-testid=bean-rebuy-link][href=?][target=_blank][rel=noopener]", bean.purchase_url
    assert_select "a[data-testid=bean-system-purchase-url][href=?][target=_blank][rel=noopener]", bean.purchase_url
    assert_select "[data-testid=bean-detail-purchase-url]", count: 0
    assert_select "body", text: /https:\/\/example.com\/beans\/house-blend\?ref=private/, count: 0
  end

  test "show does not render legacy invalid purchase url as clickable or raw text" do
    sign_in_as(users(:one))
    bean = beans(:open_household)
    bean.update_column(:purchase_url, "javascript:alert('bean')")

    get bean_path(bean)

    assert_response :success
    assert_select "a[data-testid=bean-rebuy-link]", count: 0
    assert_select "a[data-testid=bean-system-purchase-url]", count: 0
    assert_select "[data-testid=bean-detail-purchase-url]", count: 0
    assert_select "body", text: /javascript:alert\('bean'\)/, count: 0
  end

  test "viewer show omits stock quick open form" do
    memberships(:member).update!(role: "viewer")
    users(:two).update!(active_workspace: workspaces(:household))
    bean = workspaces(:household).beans.create!(
      name: "Viewer Detail Shelf",
      roaster_name: "Shelf Roaster",
      bag_size_grams: 250,
      remaining_grams: 250,
      opened_on: nil,
      coffee_origin_url: "https://origin.example/viewer-coffee"
    )
    sign_in_as(users(:two))

    get bean_path(bean)

    assert_response :success
    assert_select "form[data-testid=bean-open-bag-form]", count: 0
    assert_select "a[data-testid=bean-system-origin-url][href=?][target=_blank][rel=noopener]", bean.coffee_origin_url
  end

  test "show links writer to create public bean share for publishable bean" do
    sign_in_as(users(:one))
    bean = beans(:open_household)

    get bean_path(bean)

    assert_response :success
    assert_select "a[href=?]", new_bean_public_bean_share_path(bean), text: I18n.t("beans.show.share_publicly")
  end

  test "show links writer to create public bean share for archived opened bean" do
    sign_in_as(users(:one))
    bean = beans(:archived_household)

    get bean_path(bean)

    assert_response :success
    assert_select "a[href=?]", new_bean_public_bean_share_path(bean), text: I18n.t("beans.show.share_publicly")
  end

  test "show links writer to edit existing public bean share for publishable bean" do
    sign_in_as(users(:one))
    bean = beans(:open_household)
    share = bean.create_public_bean_share!(
      workspace: bean.workspace,
      created_by: users(:one),
      updated_by: users(:one),
      enabled: true,
      title: "Shared bean",
      selected_photo_attachment_ids: [],
      snapshot: PublicBeanShareSnapshotBuilder.new(
        bean:,
        title: "Shared bean",
        selected_photo_attachment_ids: []
      ).call
    )

    get bean_path(bean)

    assert_response :success
    assert_select "[data-testid=bean-detail-actions]"
    header = Nokogiri::HTML(response.body).at_css("[data-testid='bean-detail-header-controls']")
    assert_not_includes header["class"].to_s, "flex-col"
    actions = Nokogiri::HTML(response.body).at_css("[data-testid='bean-detail-actions']")
    assert_not_includes actions["class"].to_s, "overflow-x-auto"
    assert_select "[data-testid=bean-detail-actions] svg.material-symbol", minimum: 1
    assert_select "[data-testid=?][href=?]",
      "bean-edit-link-#{bean.id}-mobile",
      edit_bean_path(bean)
    assert_select "[data-testid=bean-detail-actions-more]"
    menu = Nokogiri::HTML(response.body).at_css("[data-testid='bean-detail-actions-menu']")
    assert_includes menu["class"].to_s, "rn-detail-menu-panel"
    assert_select "[data-testid=bean-detail-actions-menu] a[href=?]",
      new_bean_inventory_adjustment_path(bean),
      text: I18n.t("beans.show.adjust_inventory")
    assert_select "[data-testid=?][href=?]",
      "bean-share-public-link-#{bean.id}",
      edit_bean_public_bean_share_path(bean)
    assert_select "[data-testid=?][data-native-share-url-value=?]",
      "bean-native-share-button-#{bean.id}",
      public_bean_page_url(share.token)
    native_share_button = Nokogiri::HTML(response.body).at_css("[data-testid='bean-native-share-button-#{bean.id}']")
    assert_includes native_share_button["class"], "rounded-full"
    assert_not_includes native_share_button["class"], "border-stone-300"
    assert_select "[data-testid=?] svg.material-symbol[data-symbol=ios_share][aria-hidden=true]", "bean-native-share-button-#{bean.id}"
    assert_select "form[data-testid=?]", "bean-duplicate-form-#{bean.id}"
    assert_select "form[data-testid=bean-finish-form]"
    assert_select "[data-testid=?][href=?]", "bean-adjust-inventory-link-#{bean.id}", new_bean_inventory_adjustment_path(bean)
    assert_select "[data-testid=?][href=?]", "bean-edit-link-#{bean.id}", edit_bean_path(bean)
    assert_appears_before "bean-native-share-button-#{bean.id}", "bean-share-public-link-#{bean.id}"
    assert_appears_before "bean-share-public-link-#{bean.id}", "bean-duplicate-form-#{bean.id}"
    assert_appears_before "bean-duplicate-form-#{bean.id}", "bean-finish-form"
    assert_appears_before "bean-finish-form", "bean-adjust-inventory-link-#{bean.id}"
    assert_appears_before "bean-adjust-inventory-link-#{bean.id}", "bean-edit-link-#{bean.id}"
  end

  test "show hides public bean share actions from writer who cannot manage existing share" do
    user = users(:two)
    user.update!(active_workspace: workspaces(:household))
    other_writer = User.create!(
      email_address: "other-bean-show-share-writer@example.com",
      password: "password",
      active_workspace: workspaces(:household)
    )
    Membership.create!(user: other_writer, workspace: workspaces(:household), role: "member")
    bean = beans(:open_household)
    bean.create_public_bean_share!(
      workspace: bean.workspace,
      created_by: other_writer,
      updated_by: other_writer,
      enabled: true,
      title: "Other writer share",
      selected_photo_attachment_ids: [],
      snapshot: PublicBeanShareSnapshotBuilder.new(
        bean:,
        title: "Other writer share",
        selected_photo_attachment_ids: []
      ).call
    )
    sign_in_as(user)

    get bean_path(bean)

    assert_response :success
    assert_select "a[href=?]", edit_bean_public_bean_share_path(bean), count: 0
    assert_select "a[href=?]", new_bean_public_bean_share_path(bean), count: 0
  end

  test "show renders bean record links with visibility labels" do
    sign_in_as(users(:one))
    bean = beans(:open_household)
    bean.record_links.create!(label: "Buy beans", url: "https://example.test/beans", kind: "buy", visibility: "public")
    bean.record_links.create!(label: "Private cupping", url: "https://example.test/private", kind: "info", visibility: "private")

    get bean_path(bean)

    assert_response :success
    assert_select "[data-testid=record-links-list]"
    assert_select "a[href='https://example.test/beans']", text: /Buy beans/
    assert_select "a[href='https://example.test/private']", text: /Private cupping/
    assert_select "[data-testid=record-link-visibility]", text: I18n.t("shared.record_links.visibilities.public")
    assert_select "[data-testid=record-link-visibility]", text: I18n.t("shared.record_links.visibilities.private")
  end

  test "show synthesizes private url chips before normal record links without creating rows" do
    sign_in_as(users(:one))
    bean = beans(:open_household)
    bean.update!(
      purchase_url: "https://shop.example/bean?source=private",
      coffee_origin_url: "https://origin.example/coffee"
    )
    record_link = bean.record_links.create!(
      label: "Private cupping",
      url: "https://notes.example/cupping",
      kind: "info",
      visibility: "private",
      position: 10
    )

    assert_no_difference -> { bean.record_links.count } do
      get bean_path(bean)
    end

    assert_response :success
    assert_select "[data-testid=record-links-list]"
    assert_select "a[data-testid=bean-system-purchase-url][href=?][target=_blank][rel=noopener]", bean.purchase_url do
      assert_select "span", text: I18n.t("beans.show.system_links.purchase")
      assert_select "span", text: /#{I18n.t("shared.record_links.kinds.buy")}/i
      assert_select "span", text: /#{I18n.t("shared.record_links.visibilities.private")}/i
    end
    assert_select "a[data-testid=bean-system-origin-url][href=?][target=_blank][rel=noopener]", bean.coffee_origin_url do
      assert_select "span", text: I18n.t("beans.show.system_links.origin")
      assert_select "span", text: /#{I18n.t("shared.record_links.kinds.info")}/i
      assert_select "span", text: /#{I18n.t("shared.record_links.visibilities.private")}/i
    end
    assert_select "a[href=?][target=_blank][rel=noopener]", record_link.url, text: /Private cupping/
    assert_appears_before "bean-system-purchase-url", "bean-system-origin-url"
    assert_appears_before "bean-system-origin-url", "Private cupping"
    assert_select "[data-testid=bean-detail-purchase-url]", count: 0
  end

  test "show renders a links section for private urls without record links" do
    sign_in_as(users(:one))
    bean = beans(:open_household)
    bean.record_links.destroy_all
    bean.update!(purchase_url: "https://shop.example/only-url", coffee_origin_url: nil)

    get bean_path(bean)

    assert_response :success
    assert_select "[data-testid=record-links-list]"
    assert_select "a[data-testid=bean-system-purchase-url][href=?]", bean.purchase_url
    assert_select "a[data-testid=bean-system-origin-url]", count: 0
  end

  test "show keeps an origin-only url private and never treats it as rebuy" do
    sign_in_as(users(:one))
    bean = beans(:open_household)
    bean.update!(purchase_url: nil, coffee_origin_url: "https://origin.example/origin-only")

    get bean_path(bean)

    assert_response :success
    assert_select "a[data-testid=bean-system-origin-url][href=?]", bean.coffee_origin_url
    assert_select "a[data-testid=bean-system-purchase-url]", count: 0
    assert_select "a[data-testid=bean-rebuy-link]", count: 0
  end

  test "show omits unsafe legacy origin url without exposing raw text" do
    sign_in_as(users(:one))
    bean = beans(:open_household)
    bean.update!(purchase_url: nil)
    bean.update_column(:coffee_origin_url, "javascript:alert('origin')")

    get bean_path(bean)

    assert_response :success
    assert_select "a[data-testid=bean-system-origin-url]", count: 0
    assert_select "body", text: /javascript:alert\('origin'\)/, count: 0
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
    beans(:second_open_household).brews.create!(
      workspace: bean.workspace,
      user: users(:one),
      grinder: equipment(:household_grinder),
      machine: equipment(:household_machine),
      occurred_at: Time.zone.local(2026, 5, 24, 8, 15, 0),
      bean_weight_grams: 18,
      ground_weight_grams: 18,
      dose_grams: 18,
      beverage_grams: 42,
      total_time_seconds: 28,
      grind_setting: "11",
      taste_balance: "neutral",
      channeling: true,
      rating: 3
    )
    comparisons = BeanComparisonRanker.new(bean:).call
    rating_comparison = comparisons.fetch("average_rating")
    channeling_comparison = comparisons.fetch("channeling")

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
    assert_select "[data-testid=bean-channeling-count]", text: /1 of 2 espresso brews/
    assert_select(
      "[data-testid=bean-average-rating-comparison-badge][aria-label=?]",
      I18n.t(
        "shared.bean_comparison_rank",
        rank: rating_comparison.fetch("rank"),
        count: rating_comparison.fetch("eligible_count")
      )
    )
    assert_select(
      "[data-testid=bean-channeling-comparison-badge][aria-label=?]",
      I18n.t(
        "shared.bean_comparison_rank",
        rank: channeling_comparison.fetch("rank"),
        count: channeling_comparison.fetch("eligible_count")
      )
    )
    assert_select "[data-testid=bean-best-brews] a[href=?]", brew_path(brew), text: /45g/
    assert_select "[data-testid=bean-recent-brews-heading] a[href=?]",
      coffees_path(filter: "brews", bean_id: bean.id),
      text: I18n.t("beans.show.view_all_brews")
    assert_select "[data-testid=bean-recent-brews] a[href=?]", brew_path(brew), text: /10/
    assert_select "h3", I18n.t("beans.show.taste_balance")
    assert_select "h3", I18n.t("beans.show.retention_markers")
    assert_select "[data-testid=bean-grind-setting-distribution]", text: /10/
    assert_select "body", text: /Other Workspace Bean/, count: 0
  end

  test "show omits comparison badges when the bean has no current values" do
    sign_in_as(users(:one))

    get bean_path(beans(:second_open_household))

    assert_response :success
    assert_select "[data-testid^=bean-][data-testid$='-comparison-badge']", count: 0
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
    assert_select "[data-testid=bean-channeling-count]", text: /1 of 2 espresso brews/
  end

  test "show uses espresso brew count for bean channeling caption" do
    sign_in_as(users(:one))
    bean = beans(:open_household)
    bean.workspace.brews.create!(
      user: users(:one),
      method: "quick_drip",
      bean:,
      brewer: equipment(:household_brewer),
      machine_cups: 6,
      coffee_spoons: 6,
      channeling: true,
      taste_balance: "bitter"
    )

    get bean_path(bean)

    assert_response :success
    assert_select "[data-testid=bean-detail-brew-count]", "2"
    assert_select "[data-testid=bean-channeling-rate]", "0%"
    assert_select "[data-testid=bean-channeling-count]", text: /0 of 1 espresso brew/
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

  test "show ignores quick drip as first brew grinder calibration" do
    sign_in_as(users(:one))
    bean = beans(:second_open_household)
    bean.workspace.brews.create!(
      user: users(:one),
      method: "quick_drip",
      bean:,
      brewer: equipment(:household_brewer),
      grinder: equipment(:household_grinder),
      occurred_at: Time.zone.local(2026, 5, 25, 8, 15, 0),
      machine_cups: 6,
      coffee_spoons: 6,
      grind_setting: "filter 7",
      taste_balance: "neutral"
    )

    get bean_path(bean)

    assert_response :success
    assert_select "[data-testid=bean-grinder-calibration]", count: 0
    assert_select "[data-testid=bean-grinder-suggestions-empty]", text: /Log the first brew/
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
    duplicate.open_bag!
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
    duplicate.open_bag!
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

  test "quick open opens stock bag today and returns to safe origin" do
    travel_to Date.new(2026, 6, 13) do
      sign_in_as(users(:one))
      bean = workspaces(:household).beans.create!(
        name: "Shelf Bag",
        roaster_name: "Shelf Roaster",
        bag_size_grams: 250,
        remaining_grams: 199,
        opened_on: nil
      )

      patch open_bag_bean_path(bean), headers: { "HTTP_REFERER" => "http://www.example.com#{dashboard_path}" }

      assert_redirected_to dashboard_path
      bean.reload
      assert_equal "open", bean.bag_status
      assert_equal Date.new(2026, 6, 13), bean.opened_on
      assert_equal 199.to_d, bean.remaining_grams
    end
  end

  test "quick open rejects external redirect referrer" do
    travel_to Date.new(2026, 6, 13) do
      sign_in_as(users(:one))
      bean = workspaces(:household).beans.create!(
        name: "External Referrer Shelf",
        roaster_name: "Shelf Roaster",
        bag_size_grams: 250,
        remaining_grams: 199,
        opened_on: nil
      )

      patch open_bag_bean_path(bean), headers: { "HTTP_REFERER" => "https://evil.example/pantry" }

      assert_redirected_to bean_path(bean)
      assert_equal "open", bean.reload.bag_status
    end
  end

  test "quick open opens legacy stock bag with invalid purchase url" do
    travel_to Date.new(2026, 6, 13) do
      sign_in_as(users(:one))
      bean = workspaces(:household).beans.create!(
        name: "Legacy Shelf Bag",
        roaster_name: "Shelf Roaster",
        bag_size_grams: 250,
        remaining_grams: 199,
        opened_on: nil
      )
      bean.update_column(:purchase_url, "javascript:alert('bean')")

      patch open_bag_bean_path(bean)

      assert_redirected_to bean_path(bean)
      bean.reload
      assert_equal "open", bean.bag_status
      assert_equal Date.new(2026, 6, 13), bean.opened_on
      assert_equal 199.to_d, bean.remaining_grams
      assert_equal "javascript:alert('bean')", bean.purchase_url

      follow_redirect!
      assert_response :success
      assert_select "a[data-testid=bean-rebuy-link]", count: 0
      assert_select "a[data-testid=bean-system-purchase-url]", count: 0
      assert_select "[data-testid=bean-detail-purchase-url]", count: 0
      assert_select "body", text: /javascript:alert\('bean'\)/, count: 0
    end
  end

  test "quick open ignores non stock bags" do
    sign_in_as(users(:one))
    bean = beans(:open_household)
    original_opened_on = bean.opened_on

    patch open_bag_bean_path(bean)

    assert_redirected_to bean_path(bean)
    assert_equal original_opened_on, bean.reload.opened_on
  end

  test "viewer cannot quick open stock bean" do
    memberships(:member).update!(role: "viewer")
    users(:two).update!(active_workspace: workspaces(:household))
    bean = workspaces(:household).beans.create!(
      name: "Viewer Shelf",
      roaster_name: "Shelf Roaster",
      bag_size_grams: 250,
      remaining_grams: 250,
      opened_on: nil
    )
    sign_in_as(users(:two))

    patch open_bag_bean_path(bean)

    assert_redirected_to root_path
    assert_nil bean.reload.opened_on
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
    subject_label = Activity::Metadata.subject_label(bean)
    event = nil

    assert_difference -> { Bean.count }, -1 do
      assert_difference -> { Brew.count }, -1 do
        assert_difference -> { InventoryAdjustment.count }, -2 do
          event = assert_activity_event(action: "bean.deleted", workspace: bean.workspace, actor: users(:one)) do
            delete bean_path(bean)
          end
        end
      end
    end

    assert_redirected_to beans_path
    assert_equal I18n.t("beans.destroy.destroyed"), flash[:notice]
    assert_nil event.subject
    assert_equal subject_label, event.metadata.fetch("subject_label")
  end

  test "bean lifecycle routes emit the specific action rather than bean updated" do
    sign_in_as(users(:one))
    bean = beans(:second_open_household)
    bean.apply_bag_status("stock")
    bean.save!

    assert_activity_event(action: "bean.opened", workspace: bean.workspace, actor: users(:one), subject: bean) do
      patch open_bag_bean_path(bean)
    end
    assert_activity_event(action: "bean.finished", workspace: bean.workspace, actor: users(:one), subject: bean) do
      patch finish_bean_path(bean)
    end
    assert_activity_event(action: "bean.reopened", workspace: bean.workspace, actor: users(:one), subject: bean) do
      patch reopen_bean_path(bean)
    end
    assert_activity_event(action: "bean.archived", workspace: bean.workspace, actor: users(:one), subject: bean) do
      patch close_bean_path(bean)
    end
    assert_equal 0, ActivityEvent.where(action: "bean.updated", subject: bean).count
  end

  test "emitter failure rolls back the domain mutation" do
    sign_in_as(users(:one))
    bean = beans(:open_household)
    old_name = bean.name

    with_stubbed_singleton_method(Activity::Emitter, :record!, ->(**) { raise "activity write failed" }) do
      assert_raises(RuntimeError) do
        patch bean_path(bean), params: { bean: { name: "Must roll back", bag_size_grams: bean.bag_size_grams } }
      end
    end

    assert_equal old_name, bean.reload.name
  end

  test "deleting a bean refreshes remaining public bean comparison snapshots" do
    sign_in_as(users(:one))
    bean = beans(:open_household)
    peer_bean = beans(:second_open_household)
    peer_bean.workspace.brews.create!(
      user: users(:one),
      bean: peer_bean,
      method: "espresso",
      bean_weight_grams: 18,
      rating: 5,
      channeling: true
    )
    peer_share = PublicBeanShare.create!(
      workspace: peer_bean.workspace,
      bean: peer_bean,
      created_by: users(:one),
      updated_by: users(:one),
      enabled: true,
      title: "Shared peer bean",
      selected_photo_attachment_ids: [],
      snapshot: PublicBeanShareSnapshotBuilder.new(
        bean: peer_bean,
        title: "Shared peer bean",
        selected_photo_attachment_ids: []
      ).call
    )

    assert_equal 1, peer_share.snapshot.dig("comparisons", "average_rating", "rank")

    delete bean_path(bean)

    assert_redirected_to beans_path
    assert_nil peer_share.reload.snapshot.dig("comparisons", "average_rating")
    assert_nil peer_share.snapshot.dig("comparisons", "channeling")
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
