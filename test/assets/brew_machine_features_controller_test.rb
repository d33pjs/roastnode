require "test_helper"

class BrewMachineFeaturesControllerTest < ActiveSupport::TestCase
  test "machine capabilities control feature visibility and submission" do
    source = Rails.root.join("app/javascript/controllers/brew_machine_features_controller.js").read

    assert_includes source, 'static targets = [ "machine", "feature" ]'
    assert_includes source, "machine.checked"
    assert_includes source, 'selectedMachine?.dataset[capability] === "true"'
    assert_includes source, "feature.hidden = !supported"
    assert_includes source, "input.disabled = !supported"
  end

  test "draft restoration notifies capability controls after restoring a machine" do
    source = Rails.root.join("app/javascript/controllers/brew_draft_controller.js").read

    assert_includes source, "notifyMachineSelectionChanged()"
    assert_includes source, 'name="brew[machine_id]"'
    assert_includes source, 'new Event("change", { bubbles: true })'
  end
end
