require "test_helper"

class ExternalCoffeesControllerTest < ActionDispatch::IntegrationTest
  test "new renders external coffee log tab and optional fields" do
    sign_in_as(users(:one))

    get new_external_coffee_path

    assert_response :success
    assert_select "[data-testid=log-tabs] a[aria-current=page]", text: "External Coffee"
    assert_select "input[name=?]", "external_coffee[drink_type]"
    assert_select "input[name=?]", "external_coffee[place_name]"
    assert_select "input[name=?]", "external_coffee[price]"
    assert_select "textarea[name=?]", "external_coffee[notes]"
    assert_select "textarea[name=?]", "external_coffee[public_note]"
    assert_select "input[type=file][name=?][multiple=multiple]", "external_coffee[photos][]"
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
