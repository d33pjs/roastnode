require "test_helper"

class EquipmentTest < ActiveSupport::TestCase
  test "equipment supports brewer kind" do
    brewer = workspaces(:household).equipment.new(name: "Moccamaster", kind: "brewer")

    assert_predicate brewer, :valid?
    assert_predicate brewer, :brewer?
  end

  test "machine extraction settings persist for machines" do
    machine = workspaces(:household).equipment.create!(
      name: "Feature machine",
      kind: "machine",
      preinfusion_enabled: true,
      low_flow_start_enabled: true,
      flow_control_enabled: true
    )

    assert_predicate machine, :preinfusion_enabled?
    assert_predicate machine, :low_flow_start_enabled?
    assert_predicate machine, :flow_control_enabled?
  end

  test "machine extraction settings are cleared for other equipment kinds" do
    grinder = workspaces(:household).equipment.create!(
      name: "Featureless grinder",
      kind: "grinder",
      preinfusion_enabled: true,
      low_flow_start_enabled: true,
      flow_control_enabled: true
    )

    assert_not_predicate grinder, :preinfusion_enabled?
    assert_not_predicate grinder, :low_flow_start_enabled?
    assert_not_predicate grinder, :flow_control_enabled?
  end
end
