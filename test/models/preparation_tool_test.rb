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
end
