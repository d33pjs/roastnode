require "test_helper"

class BrewPreparationToolTest < ActiveSupport::TestCase
  test "stores a snapshot of the selected tool" do
    snapshot = BrewPreparationTool.new(
      brew: brews(:morning_espresso),
      preparation_tool: preparation_tools(:wdt),
      tool_name: preparation_tools(:wdt).name,
      brew_method: preparation_tools(:wdt).brew_method,
      position: 1
    )

    assert snapshot.valid?
  end
end
