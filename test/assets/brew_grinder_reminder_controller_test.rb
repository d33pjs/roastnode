require "test_helper"

class BrewGrinderReminderControllerTest < ActiveSupport::TestCase
  test "updates on connect and bean changes without mutating brew inputs" do
    source = Rails.root.join("app/javascript/controllers/brew_grinder_reminder_controller.js").read

    assert_includes source, 'static targets = [ "bean", "notice", "selectedReference" ]'
    assert_includes source, "connect()"
    assert_includes source, "beanChanged()"
    assert_includes source, "this.updateReminder()"
    assert_includes source, "bean.checked"
    assert_includes source, "selected.value === this.lastBeanIdValue"
    assert_includes source, "selected.dataset.grinderReferenceKey"
    assert_includes source, "selectedKey !== this.previousReferenceKeyValue"
    assert_includes source, "this.noticeTarget.hidden = !needsCheck"
    assert_includes source, "this.selectedReferenceTarget.textContent"
    assert_not_includes source, "innerHTML"
    assert_not_includes source, "grind_setting"
    assert_not_includes source, "grinder_id"
  end
end
