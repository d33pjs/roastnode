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
    assert_select "input[type=datetime-local][name=?].min-w-0.max-w-full", "external_coffee[occurred_at]"
    assert_select "textarea[name=?]", "external_coffee[notes]"
    assert_select "textarea[name=?]", "external_coffee[public_note]"
    assert_select "input[type=file][name=?][multiple=multiple][data-testid=photo-upload-input]", "external_coffee[photos][]"
    assert_select "[data-controller=external-coffee-location][data-insecure-message]"
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

  test "viewer cannot create external coffee" do
    memberships(:member).update!(role: "viewer")
    users(:two).update!(active_workspace: workspaces(:household))
    sign_in_as(users(:two))

    get new_external_coffee_path

    assert_redirected_to root_path
    assert_equal I18n.t("authorization.denied"), flash[:alert]
  end
end
