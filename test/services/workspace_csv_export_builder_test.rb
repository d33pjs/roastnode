require "test_helper"
require "csv"

class WorkspaceCsvExportBuilderTest < ActiveSupport::TestCase
  test "exports beans as workspace-scoped csv rows" do
    csv = WorkspaceCsvExportBuilder.new(workspaces(:household)).beans_csv
    rows = CSV.parse(csv, headers: true)

    assert_includes rows.headers, "id"
    assert_includes rows.headers, "name"
    assert_includes rows.headers, "remaining_grams"
    assert_includes rows.headers, "purchase_price"

    bean_ids = rows.map { |row| row.fetch("id").to_i }
    assert_includes bean_ids, beans(:open_household).id
    assert_not_includes bean_ids, beans(:other_workspace_open).id

    exported = rows.find { |row| row.fetch("id").to_i == beans(:open_household).id }
    assert_equal beans(:open_household).name, exported.fetch("name")
    assert_equal beans(:open_household).remaining_grams.to_s("F"), exported.fetch("remaining_grams")
    assert_equal "open", exported.fetch("status")

    archived = rows.find { |row| row.fetch("id").to_i == beans(:archived_household).id }
    assert_equal "archived", archived.fetch("status")
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
end
