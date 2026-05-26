require "test_helper"

class DemoDataSeederTest < ActiveSupport::TestCase
  test "creates a complete demo household workspace" do
    result = DemoDataSeeder.new.call

    user = User.find_by!(email_address: DemoDataSeeder::EMAIL)
    workspace = Workspace.find_by!(name: DemoDataSeeder::WORKSPACE_NAME)

    assert_equal workspace, user.active_workspace
    assert_equal "owner", user.membership_for(workspace).role
    assert_equal 2, workspace.beans.count
    assert_equal 2, workspace.equipment.count
    assert_equal 4, workspace.preparation_tools.count
    assert_equal 2, workspace.brews.count
    assert_equal 1, workspace.equipment_events.count
    assert_equal "created", result.fetch(:status)
  end

  test "is idempotent when run more than once" do
    seeder = DemoDataSeeder.new

    seeder.call

    assert_no_difference -> { User.count } do
      assert_no_difference -> { Workspace.count } do
        assert_no_difference -> { Bean.count } do
          assert_no_difference -> { Equipment.count } do
            assert_no_difference -> { PreparationTool.count } do
              assert_no_difference -> { Brew.count } do
                assert_no_difference -> { EquipmentEvent.count } do
                  result = seeder.call
                  assert_equal "already_present", result.fetch(:status)
                end
              end
            end
          end
        end
      end
    end
  end
end
