require "test_helper"

class ExternalCoffeesControllerTest < ActionDispatch::IntegrationTest
  test "new renders external coffee log tab and optional fields" do
    workspaces(:household).external_coffees.create!(
      user: users(:one),
      drink_type: "Orange Cappuccino",
      place_name: "Tiny Shop"
    )
    sign_in_as(users(:one))

    get new_external_coffee_path

    assert_response :success
    assert_select "[data-testid=log-tabs] a[aria-current=page]", text: "External Coffee"
    assert_select "input[name=?]", "external_coffee[drink_type]"
    assert_select "datalist#external-coffee-drink-types option[value=?]", "Americano"
    assert_select "datalist#external-coffee-drink-types option[value=?]", "Latte Macchiato"
    assert_select "datalist#external-coffee-drink-types option[value=?]", "Orange Cappuccino"
    assert_select "input[name=?]", "external_coffee[place_name]"
    assert_select "input[name=?]", "external_coffee[price]"
    assert_select "[data-testid=external-coffee-occurred-at-field].overflow-hidden"
    assert_select "input[type=datetime-local][name=?][step=?].rn-datetime-input.min-w-0.max-w-full", "external_coffee[occurred_at]", "1"
    assert_select "textarea[name=?]", "external_coffee[notes]"
    assert_select "textarea[name=?]", "external_coffee[public_note]"
    assert_select "input[type=file][name=?][multiple=multiple][data-testid=photo-upload-input]", "external_coffee[photos][]"
    assert_select "input[type=hidden][name=?]", "external_coffee[photos][]", count: 0
    assert_select "[data-controller=external-coffee-location][data-insecure-message]"
  end

  test "new places external coffee log time at the end of the form" do
    sign_in_as(users(:one))

    get new_external_coffee_path

    assert_response :success
    form_body = Nokogiri::HTML(response.body).at_css("form[action='#{external_coffees_path}']").inner_html
    log_time_index = form_body.index('data-testid="external-coffee-occurred-at-field"')
    record_links_index = form_body.index('data-testid="record-links-fields"')
    submit_index = form_body.index('type="submit"')

    assert_not_nil log_time_index
    assert_not_nil record_links_index
    assert_not_nil submit_index
    assert_operator log_time_index, :>, record_links_index
    assert_operator log_time_index, :<, submit_index
  end

  test "new renders external taste and rating as styled choices" do
    sign_in_as(users(:one))

    get new_external_coffee_path

    assert_response :success
    assert_select "select[name=?]", "external_coffee[acidity_balance]", count: 0
    assert_select "select[name=?]", "external_coffee[intensity]", count: 0
    assert_select "select[name=?]", "external_coffee[rating]", count: 0
    assert_select "[data-testid=external-coffee-acidity-balance-options]"
    assert_select "[data-testid=external-coffee-acidity-balance-scale] input[type=radio][name=?]", "external_coffee[acidity_balance]", count: 3
    assert_select "input[type=radio][name=?][value=?]", "external_coffee[acidity_balance]", "sour"
    assert_select "input[type=radio][name=?][value=?]", "external_coffee[acidity_balance]", "balanced"
    assert_select "input[type=radio][name=?][value=?]", "external_coffee[acidity_balance]", "bitter"
    assert_select "input[type=radio][name=?][value=?]", "external_coffee[acidity_balance]", "very_sour", count: 0
    assert_select "input[type=radio][name=?][value=?]", "external_coffee[acidity_balance]", "very_bitter", count: 0
    assert_select "[data-testid=external-coffee-intensity-scale] input[type=radio][name=?]", "external_coffee[intensity]", count: 3
    assert_select "input[type=radio][name=?][value=?]", "external_coffee[intensity]", "weak"
    assert_select "input[type=radio][name=?][value=?]", "external_coffee[intensity]", "balanced"
    assert_select "input[type=radio][name=?][value=?]", "external_coffee[intensity]", "strong"
    assert_select "input[type=radio][name=?][value=?]", "external_coffee[intensity]", "harsh", count: 0
    assert_select "[data-testid=external-coffee-rating-options]"
    assert_select "input[type=radio][name=?]", "external_coffee[rating]", count: 6
  end

  test "create saves localized price and record links" do
    sign_in_as(users(:one))

    assert_difference -> { ExternalCoffee.count }, 1 do
      post external_coffees_path, params: {
        external_coffee: {
          drink_type: "Matcha Latte",
          drink_size: "grande",
          place_name: "Starbucks",
          place_location: "Main station",
          price: "4,50",
          acidity_balance: "balanced",
          intensity: "weak",
          rating: "3",
          notes: "Private note",
          public_note: "Public note",
          record_links_attributes: {
            "0" => {
              label: "Menu",
              url: "https://example.com/menu",
              kind: "info",
              visibility: "private",
              position: "10"
            }
          }
        }
      }
    end

    coffee = ExternalCoffee.order(:id).last
    assert_redirected_to external_coffee_path(coffee)
    assert_equal 450, coffee.price_cents
    assert_equal "EUR", coffee.currency
    assert_equal "Menu", coffee.record_links.first.label
  end

  test "update without choosing another photo keeps existing photos" do
    sign_in_as(users(:one))
    coffee = workspaces(:household).external_coffees.create!(
      user: users(:one),
      drink_type: "Americano",
      occurred_at: 1.hour.ago,
      currency: "EUR"
    )
    photo = attach_photo(coffee)

    patch external_coffee_path(coffee), params: {
      external_coffee: {
        drink_type: "Americano",
        occurred_at: coffee.occurred_at,
        currency: "EUR",
        photos: [ "" ]
      }
    }

    assert_redirected_to external_coffee_path(coffee)
    assert_equal [ photo.id ], coffee.reload.photos.attachments.pluck(:id)
  end

  test "edit and update allow changing external coffee log time" do
    sign_in_as(users(:one))
    coffee = workspaces(:household).external_coffees.create!(
      user: users(:one),
      drink_type: "Americano",
      occurred_at: Time.zone.local(2026, 6, 8, 9, 30, 0),
      currency: "EUR"
    )

    get edit_external_coffee_path(coffee)

    assert_response :success
    assert_select "input[type=datetime-local][name=?][required=required][step=?]", "external_coffee[occurred_at]", "1"

    patch external_coffee_path(coffee), params: {
      external_coffee: {
        drink_type: "Americano",
        occurred_at: "2026-06-08T14:45:28",
        currency: "EUR"
      }
    }

    assert_redirected_to external_coffee_path(coffee)
    assert_equal Time.find_zone("Europe/Berlin").local(2026, 6, 8, 14, 45, 28), coffee.reload.occurred_at
  end

  test "datetime field renders in user timezone" do
    user = users(:one)
    user.update!(time_zone: "Europe/Berlin")
    sign_in_as(user)
    coffee = workspaces(:household).external_coffees.create!(
      user:,
      drink_type: "Americano",
      occurred_at: Time.utc(2026, 6, 14, 8, 15, 28),
      currency: "EUR"
    )

    get edit_external_coffee_path(coffee)

    assert_response :success
    assert_select "input[type=datetime-local][name=?][value=?]",
      "external_coffee[occurred_at]",
      "2026-06-14T10:15:28"
  end

  test "show hero card renders brand mark identity images footer timestamp bean rating and symbol price" do
    workspace = workspaces(:household)
    user = users(:one)
    attach_named_photo(workspace, :logo, filename: "household-logo.jpg")
    attach_named_photo(user, :avatar, filename: "user-avatar.jpg")
    coffee = workspace.external_coffees.create!(
      user:,
      drink_type: "Flat White",
      drink_size: "Large cup",
      occurred_at: Time.find_zone("Europe/Berlin").local(2026, 6, 9, 14, 5, 45),
      price_cents: 450,
      currency: "EUR",
      rating: 4
    )
    sign_in_as(user)

    get external_coffee_path(coffee)

    assert_response :success
    assert_select "[data-testid=external-coffee-card-brand-mark]"
    assert_select "[data-testid=external-coffee-workspace-logo]"
    assert_select "[data-testid=external-coffee-user-avatar]"
    assert_select "[data-testid=external-coffee-price]", text: "4,50€"
    assert_select "[data-testid=external-coffee-price]", text: /EUR/, count: 0
    assert_select "[data-testid=external-coffee-metrics] [data-testid=external-coffee-logged-at]", count: 0
    assert_select "[data-testid=external-coffee-footer] [data-testid=external-coffee-logged-at].rounded-full", text: "09.06.2026 14:05"
    assert_select "[data-testid=external-coffee-logged-at]", text: /:45/, count: 0
    assert_select "[data-testid=external-coffee-drink-size]", text: "Large cup"
    assert_select "[data-testid=external-coffee-rating] .brew-rating-bean", count: 5
    assert_select "[data-testid=external-coffee-rating] .rating-bean--filled", count: 4
    assert_select "[data-testid=external-coffee-rating] .rating-bean--empty", count: 1
  end

  test "show keeps delete action in the bottom danger zone" do
    coffee = workspaces(:household).external_coffees.create!(
      user: users(:one),
      drink_type: "Macchiato"
    )
    sign_in_as(users(:one))

    get external_coffee_path(coffee)

    assert_response :success
    header = Nokogiri::HTML(response.body).at_css("[data-testid='external-coffee-header-controls']")
    assert_not_includes header["class"].to_s, "flex-col"
    assert_select "[data-testid=external-coffee-actions] a[href=?][title=?]",
      edit_external_coffee_path(coffee),
      I18n.t("external_coffees.show.edit")
    assert_select "[data-testid=external-coffee-actions] svg.material-symbol[data-symbol=edit]"
    assert_select "[data-testid=external-coffee-actions] form[action=?]", external_coffee_path(coffee), count: 0
    assert_select "[data-testid=external-coffee-danger-zone] form[action=?]", external_coffee_path(coffee)
    assert_appears_before "data-testid=\"external-coffee-details\"", "data-testid=\"external-coffee-danger-zone\""
  end

  test "show back link returns to the previous in-app page" do
    coffee = workspaces(:household).external_coffees.create!(
      user: users(:one),
      drink_type: "Macchiato"
    )
    previous_path = "/coffees?filter=external"
    sign_in_as(users(:one))

    get external_coffee_path(coffee), headers: { "HTTP_REFERER" => "http://www.example.com#{previous_path}" }

    assert_response :success
    assert_select "a[data-testid=back-link][href=?][aria-label=?][title=?]",
      previous_path,
      I18n.t("shared.back_link.previous"),
      I18n.t("shared.back_link.previous")
  end

  test "show back link ignores external referrers" do
    coffee = workspaces(:household).external_coffees.create!(
      user: users(:one),
      drink_type: "Macchiato"
    )
    sign_in_as(users(:one))

    get external_coffee_path(coffee), headers: { "HTTP_REFERER" => "https://example.org/coffees" }

    assert_response :success
    assert_select "a[data-testid=back-link][href=?][aria-label=?][title=?]",
      external_coffees_path,
      I18n.t("external_coffees.show.back"),
      I18n.t("external_coffees.show.back")
  end

  test "viewer cannot create external coffee" do
    memberships(:member).update!(role: "viewer")
    users(:two).update!(active_workspace: workspaces(:household))
    sign_in_as(users(:two))

    get new_external_coffee_path

    assert_redirected_to root_path
    assert_equal I18n.t("authorization.denied"), flash[:alert]
  end

  private
    def assert_appears_before(first, second)
      first_index = response.body.index(first)
      second_index = response.body.index(second)

      assert first_index, "Expected #{first.inspect} to appear in response body"
      assert second_index, "Expected #{second.inspect} to appear in response body"
      assert first_index < second_index, "Expected #{first.inspect} to appear before #{second.inspect}"
    end
end
