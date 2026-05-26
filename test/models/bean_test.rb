require "test_helper"

class BeanTest < ActiveSupport::TestCase
  test "defaults remaining grams to bag size" do
    bean = workspaces(:household).beans.create!(
      name: "La Marianela",
      roaster_name: "Fjord",
      bag_size_grams: 250
    )

    assert_equal 250.to_d, bean.remaining_grams
  end

  test "open scope returns unarchived beans with remaining inventory first by opened date" do
    beans(:open_household).update!(opened_on: Date.new(2026, 5, 1))
    beans(:second_open_household).update!(opened_on: Date.new(2026, 5, 2))

    assert_equal [ beans(:open_household), beans(:second_open_household) ], workspaces(:household).beans.open.to_a
    assert_not_includes workspaces(:household).beans.open, beans(:archived_household)
    assert_not_includes workspaces(:household).beans.open, beans(:other_workspace_open)
  end
end
