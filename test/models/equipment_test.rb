require "test_helper"

class EquipmentTest < ActiveSupport::TestCase
  test "equipment supports brewer kind" do
    brewer = workspaces(:household).equipment.new(name: "Moccamaster", kind: "brewer")

    assert_predicate brewer, :valid?
    assert_predicate brewer, :brewer?
  end
end
