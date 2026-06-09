require "test_helper"

class ExternalCoffeeExportTest < ActiveSupport::TestCase
  test "workspace exports include external coffees" do
    coffee = workspaces(:household).external_coffees.create!(
      user: users(:one),
      drink_type: "Americano",
      place_name: "Local Shop",
      price_cents: 320,
      currency: "EUR",
      acidity_balance: "bitter",
      intensity: "harsh",
      rating: 2,
      notes: "Too rough",
      public_note: "Not my favorite"
    )

    payload = WorkspaceExportBuilder.new(workspaces(:household)).call
    exported = payload.fetch(:external_coffees).find { |row| row.fetch(:id) == coffee.id }

    assert_equal "Americano", exported.fetch(:drink_type)
    assert_equal "Local Shop", exported.fetch(:place_name)
    assert_equal 320, exported.fetch(:price_cents)
    assert_equal "harsh", exported.fetch(:intensity)
  end

  test "external coffees csv includes comparison fields" do
    coffee = workspaces(:household).external_coffees.create!(
      user: users(:one),
      drink_type: "Latte Macchiato",
      drink_size: "large",
      place_name: "Cafe One",
      place_location: "Ehrenfeld",
      price_cents: 510,
      currency: "EUR",
      acidity_balance: "balanced",
      intensity: "strong",
      rating: 5
    )

    csv = CSV.parse(WorkspaceCsvExportBuilder.new(workspaces(:household)).external_coffees_csv, headers: true)
    row = csv.find { |candidate| candidate.fetch("id").to_i == coffee.id }

    assert_equal "Latte Macchiato", row.fetch("drink_type")
    assert_equal "large", row.fetch("drink_size")
    assert_equal "Cafe One", row.fetch("place_name")
    assert_equal "5.10", row.fetch("price")
  end
end
