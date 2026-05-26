require "test_helper"

class PreparationToolTest < ActiveSupport::TestCase
  test "is valid for a workspace espresso checklist item" do
    tool = PreparationTool.new(workspace: workspaces(:household), name: "WDT", brew_method: "espresso")

    assert tool.valid?
    assert tool.active?
  end

  test "requires a name" do
    tool = PreparationTool.new(workspace: workspaces(:household), brew_method: "espresso")

    assert_not tool.valid?
    assert_includes tool.errors[:name], "can't be blank"
  end

  test "ordered sorts by position then name" do
    preparation_tools(:wdt).update!(position: 20)
    preparation_tools(:puck_screen).update!(position: 10)

    assert_equal [ preparation_tools(:puck_screen), preparation_tools(:wdt), preparation_tools(:archived_tool) ],
      workspaces(:household).preparation_tools.ordered.to_a
  end

  test "archive and reopen toggle active state" do
    tool = preparation_tools(:wdt)

    tool.archive!
    assert_not tool.active?

    tool.reopen!
    assert tool.active?
  end

  test "destroy with history removes tool but keeps brew snapshots readable" do
    tool = preparation_tools(:wdt)
    snapshot = brew_preparation_tools(:morning_espresso_wdt)

    assert_no_difference -> { Brew.count } do
      assert_no_difference -> { BrewPreparationTool.count } do
        tool.destroy_with_history!
      end
    end

    assert_nil snapshot.reload.preparation_tool
    assert_equal "WDT", snapshot.tool_name
  end
end
