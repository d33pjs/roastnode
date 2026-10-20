require "test_helper"

class GrinderUseTest < ActiveSupport::TestCase
  test "confirmation preserves exact text and matches only the complete brew context" do
    assert Object.const_defined?(:GrinderUse), "confirmed grinder uses must be available"
    use = build_use
    use.save!
    brew = workspaces(:household).brews.new(user: users(:one), bean: beans(:open_household),
      grinder: equipment(:household_grinder), method: "espresso", grind_setting: "1/2,50")
    assert use.matches_brew?(brew)
    %i[workspace_id user_id bean_id grinder_id].each do |attribute|
      altered = brew.dup
      altered.public_send("#{attribute}=", -1)
      assert_not use.matches_brew?(altered), attribute.to_s
    end
    brew.grind_setting = "1/2,5"
    assert_not use.matches_brew?(brew)
    brew.grind_setting = "1/2,50"
    brew.method = "quick_drip"
    assert_not use.matches_brew?(brew)
    assert_equal "1/2,50", use.reload.grind_setting
  end

  test "foreign bean and grinder and wrong equipment kind are invalid" do
    assert Object.const_defined?(:GrinderUse), "confirmed grinder uses must be available"
    use = build_use
    use.bean = beans(:other_workspace_open)
    assert_not use.valid?
    use = build_use
    use.grinder = equipment(:other_workspace_grinder)
    assert_not use.valid?
    use.grinder = equipment(:household_machine)
    assert_not use.valid?
  end

  test "confirmation context and time cannot be updated" do
    assert Object.const_defined?(:GrinderUse), "confirmed grinder uses must be available"
    use = build_use
    use.save!
    assert_not use.update(grind_setting: "changed", occurred_at: 1.day.from_now)
    assert_equal "1/2,50", use.reload.grind_setting
  end

  test "bean equipment workspace and user deletion keep established contracts" do
    assert Object.const_defined?(:GrinderUse), "confirmed grinder uses must be available"
    use = build_use
    use.save!
    assert_raises(ActiveRecord::DeleteRestrictionError) { users(:one).destroy! }
    equipment(:household_grinder).destroy_with_history!
    assert_nil use.reload.grinder_id
    beans(:open_household).destroy_with_history!
    assert_not GrinderUse.exists?(use.id)
    use = build_use
    beans(:second_open_household).update!(grind_state: "whole_bean")
    use.bean = beans(:second_open_household)
    use.grinder = workspaces(:household).equipment.create!(name: "Replacement", kind: "grinder")
    use.save!
    workspaces(:household).destroy_with_history!
    assert_not GrinderUse.exists?(use.id)
  end

  private
    def build_use
      GrinderUse.new(workspace: workspaces(:household), user: users(:one), bean: beans(:open_household),
        grinder: equipment(:household_grinder), method: "espresso", grind_setting: "1/2,50", confirmation_key: SecureRandom.uuid)
    end
end
