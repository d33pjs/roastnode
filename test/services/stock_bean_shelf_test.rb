require "test_helper"

class StockBeanShelfTest < ActiveSupport::TestCase
  test "returns stock beans scoped to workspace in freshness order" do
    workspace = workspaces(:household)
    older = workspace.beans.create!(
      name: "Older Stock",
      roaster_name: "Shelf",
      bag_size_grams: 250,
      remaining_grams: 250,
      opened_on: nil,
      purchased_on: Date.new(2026, 6, 1)
    )
    newer = workspace.beans.create!(
      name: "Newer Stock",
      roaster_name: "Shelf",
      bag_size_grams: 250,
      remaining_grams: 250,
      opened_on: nil,
      purchased_on: Date.new(2026, 6, 10)
    )
    workspaces(:other_household).beans.create!(
      name: "Other Stock",
      roaster_name: "Other",
      bag_size_grams: 250,
      remaining_grams: 250,
      opened_on: nil
    )

    names = StockBeanShelf.new(workspace:).call.map { |entry| entry.bean.name }

    assert_operator names.index(newer.name), :<, names.index(older.name)
    assert_not_includes names, "Other Stock"
  end
end
