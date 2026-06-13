require "test_helper"
require "csv"

class WorkspaceCsvExportBuilderTest < ActiveSupport::TestCase
  test "exports beans as workspace-scoped csv rows" do
    finished_at = Time.zone.parse("2026-05-24 18:30:00")
    beans(:open_household).update!(remaining_grams: 14, finished_at:)

    csv = WorkspaceCsvExportBuilder.new(workspaces(:household)).beans_csv
    rows = CSV.parse(csv, headers: true)

    assert_includes rows.headers, "id"
    assert_includes rows.headers, "name"
    assert_includes rows.headers, "remaining_grams"
    assert_includes rows.headers, "finished_at"
    assert_includes rows.headers, "purchase_price"
    assert_includes rows.headers, "grind_state"
    assert_includes rows.headers, "continent"
    assert_includes rows.headers, "country_of_manufacturer"
    assert_includes rows.headers, "manufacturer"

    bean_ids = rows.map { |row| row.fetch("id").to_i }
    assert_includes bean_ids, beans(:open_household).id
    assert_not_includes bean_ids, beans(:other_workspace_open).id

    exported = rows.find { |row| row.fetch("id").to_i == beans(:open_household).id }
    assert_equal beans(:open_household).name, exported.fetch("name")
    assert_equal beans(:open_household).remaining_grams.to_s("F"), exported.fetch("remaining_grams")
    assert_equal "finished", exported.fetch("status")
    assert_equal finished_at.iso8601, exported.fetch("finished_at")

    archived = rows.find { |row| row.fetch("id").to_i == beans(:archived_household).id }
    assert_equal "archived", archived.fetch("status")

    pre_ground = rows.find { |row| row.fetch("id").to_i == beans(:second_open_household).id }
    assert_equal "pre_ground", pre_ground.fetch("grind_state")
  end

  test "exports brews as workspace-scoped csv rows with tool snapshots" do
    csv = WorkspaceCsvExportBuilder.new(workspaces(:household)).brews_csv
    rows = CSV.parse(csv, headers: true)

    assert_includes rows.headers, "id"
    assert_includes rows.headers, "bean_name"
    assert_includes rows.headers, "preparation_tools"
    assert_includes rows.headers, "brew_ratio"

    brew_ids = rows.map { |row| row.fetch("id").to_i }
    assert_includes brew_ids, brews(:morning_espresso).id
    assert_not_includes brew_ids, brews(:other_workspace_brew).id

    exported = rows.find { |row| row.fetch("id").to_i == brews(:morning_espresso).id }
    assert_equal brews(:morning_espresso).bean.name, exported.fetch("bean_name")
    assert_equal "WDT", exported.fetch("preparation_tools")
    assert_equal "1:2.22", exported.fetch("brew_ratio")
  end

  test "exports quick drip csv columns" do
    brew = workspaces(:household).brews.create!(
      user: users(:one),
      method: "quick_drip",
      bean: beans(:second_open_household),
      brewer: equipment(:household_brewer),
      machine_cups: 6,
      coffee_spoons: 6
    )

    rows = CSV.parse(WorkspaceCsvExportBuilder.new(workspaces(:household)).brews_csv, headers: true)
    exported = rows.find { |row| row.fetch("id").to_i == brew.id }

    assert_equal "quick_drip", exported.fetch("method")
    assert_equal equipment(:household_brewer).id.to_s, exported.fetch("brewer_id")
    assert_equal "Moccamaster", exported.fetch("brewer_name")
    assert_equal "6.0", exported.fetch("machine_cups")
    assert_equal "6.0", exported.fetch("coffee_spoons")
    assert_equal "5.0", exported.fetch("grams_per_coffee_spoon")
    assert_equal "estimated_spoons", exported.fetch("coffee_amount_source")
  end
end
