require "test_helper"
require Rails.root.join("db/migrate/20260917090000_add_coffee_histories").to_s

class AddCoffeeHistoriesTest < ActiveSupport::TestCase
  test "backfill creates deterministic workspace-local duplicate components" do
    household = workspaces(:household)
    other_household = workspaces(:other_household)
    cycle_a = create_bean(household, "Cycle A")
    cycle_b = create_bean(household, "Cycle B")
    cycle_c = create_bean(household, "Cycle C")
    cycle_a.update_column(:duplicated_from_bean_id, cycle_b.id)
    cycle_b.update_column(:duplicated_from_bean_id, cycle_c.id)
    cycle_c.update_column(:duplicated_from_bean_id, cycle_a.id)

    same_name_a = create_bean(household, "Repeated Name")
    same_name_b = create_bean(household, "Repeated Name")
    broken = create_bean(household, "Broken ancestry")
    foreign = create_bean(other_household, "Foreign ancestry")
    foreign.update_column(:duplicated_from_bean_id, cycle_a.id)
    connection = ActiveRecord::Base.connection
    connection.disable_referential_integrity do
      broken.update_column(:duplicated_from_bean_id, -99)
      connection.change_column_null(:beans, :coffee_history_id, true)
      Bean.update_all(coffee_history_id: nil)
      CoffeeHistory.delete_all

      AddCoffeeHistories.new.send(:backfill_coffee_histories)
    end

    cycle_history_ids = [ cycle_a, cycle_b, cycle_c ].map { |bean| bean.reload.coffee_history_id }
    assert_equal 1, cycle_history_ids.uniq.size
    assert_not_equal same_name_a.reload.coffee_history_id, same_name_b.reload.coffee_history_id
    assert_not_equal broken.reload.coffee_history_id, cycle_a.coffee_history_id
    assert_not_equal foreign.reload.coffee_history_id, cycle_a.coffee_history_id
    assert_equal other_household.id, foreign.coffee_history.workspace_id
    assert Bean.where(coffee_history_id: nil).none?
    assert Bean.includes(:coffee_history).all? { |bean| bean.workspace_id == bean.coffee_history.workspace_id }
  ensure
    if defined?(connection) && connection.column_exists?(:beans, :coffee_history_id)
      connection.change_column_null(:beans, :coffee_history_id, false)
    end
    Bean.reset_column_information
  end

  private
    def create_bean(workspace, name)
      workspace.beans.create!(name:, bag_size_grams: 250)
    end
end
