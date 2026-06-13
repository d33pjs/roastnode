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
    assert_select "[data-testid=?]", "bean-card-actions-#{bean.id}" do
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
    assert_select "select[name=?]", "bean[grind_state]"
    assert_select "input[type=text][inputmode=decimal][name=?]", "bean[roast_degree]"
    assert_select "input[name=?]", "bean[purchase_price]"
    assert_select "input[name=?]", "bean[decaffeinated]"
    assert_select "input[name=?]", "bean[purchase_url]"
    assert_select "textarea[name=?]", "bean[tasting_notes]"
    assert_select "h2", I18n.t("beans.form.sections.origin")
    assert_select "input[name=?]", "bean[country]"
    assert_select "input[name=?]", "bean[blend_percentage]"
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
    assert_select "[data-testid=bean-rating-options] .rn-rating-scale"
    assert_select "input[type=radio][name=?][value='']", "bean[rating]"
    assert_select "input[type=radio][name=?][value='5']", "bean[rating]"
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
    assert_appears_before "bean[process]", "bean[blend_type]"
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

  test "show back link ignores public bean share workflow referrers" do
    bean = beans(:open_household)
    sign_in_as(users(:one))

    get bean_path(bean), headers: { "HTTP_REFERER" => "http://www.example.com#{new_bean_public_bean_share_path(bean)}" }

    assert_response :success
    assert_select "a[data-testid=back-link][href=?]", beans_path, text: /#{Regexp.escape(I18n.t("beans.show.back"))}/
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
    assert_select "dd[data-testid=bean-detail-purchase-url] a[href=?]", bean.purchase_url, text: /example\.com/
    assert_select "body", text: /https:\/\/example.com\/beans\/house-blend\?ref=private/, count: 0
  end

  test "show does not render legacy invalid purchase url as clickable or raw text" do
    sign_in_as(users(:one))
    bean = beans(:open_household)
    bean.update_column(:purchase_url, "javascript:alert('bean')")

    get bean_path(bean)

    assert_response :success
    assert_select "a[data-testid=bean-rebuy-link]", count: 0
    assert_select "dd[data-testid=bean-detail-purchase-url] a[href=?]", bean.reload.purchase_url, count: 0
    assert_select "dd[data-testid=bean-detail-purchase-url]", text: I18n.t("beans.show.unknown")
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
      opened_on: nil
    )
    sign_in_as(users(:two))

    get bean_path(bean)

    assert_response :success
    assert_select "form[data-testid=bean-open-bag-form]", count: 0
  end

  test "show links writer to create public bean share for publishable bean" do
    sign_in_as(users(:one))
    bean = beans(:open_household)

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
    assert_includes response.body, "sm:flex-nowrap"
    assert_select "[data-testid=?][href=?]",
      "bean-share-public-link-#{bean.id}",
      edit_bean_public_bean_share_path(bean),
      text: I18n.t("beans.show.share_publicly")
    assert_select "[data-testid=?][data-native-share-url-value=?]",
      "bean-native-share-button-#{bean.id}",
      public_bean_page_url(share.token)
    native_share_button = Nokogiri::HTML(response.body).at_css("[data-testid='bean-native-share-button-#{bean.id}']")
    assert_includes native_share_button["class"], "rounded-full"
    assert_not_includes native_share_button["class"], "border-stone-300"
    assert_select "[data-testid=?] svg[aria-hidden=true]", "bean-native-share-button-#{bean.id}"
    assert_select "[data-testid=?] span.sr-only", "bean-native-share-button-#{bean.id}", I18n.t("shared.native_share.share_public_bean")
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
    assert_select "[data-testid=bean-channeling-count]", text: /1 of 2 espresso brews/
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
      assert_select "dd[data-testid=bean-detail-purchase-url] a[href=?]", bean.purchase_url, count: 0
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
