require "test_helper"

class BrewGrinderReminderControllerTest < ActiveSupport::TestCase
  test "updates on connect and bean changes without mutating brew inputs" do
    source = Rails.root.join("app/javascript/controllers/brew_grinder_reminder_controller.js").read

    assert_includes source,
      'static targets = [ "bean", "notice", "selectedReference", "grindSetting", "applySetting" ]'
    assert_includes source, "connect()"
    assert_includes source, "beanChanged()"
    assert_includes source, "grindSettingChanged()"
    assert_includes source, "applySetting()"
    assert_includes source, "this.updateReminder()"
    assert_includes source, "bean.checked"
    assert_includes source, "selected.value === this.lastBeanIdValue"
    assert_includes source, "selected.dataset.grinderReferenceKey"
    assert_includes source, "selectedKey !== this.previousReferenceKeyValue"
    assert_includes source, "this.noticeTarget.hidden = !needsCheck"
    assert_includes source, "this.selectedReferenceTarget.textContent"
    assert_includes source, "this.grindSettingTarget.value = setting"
    assert_includes source, 'new Event("input", { bubbles: true })'
    assert_includes source, "this.applySettingTarget.hidden = !differs"
    assert_includes source, 'replace("%{value}", setting.trim())'
    assert_includes source, "trim().toLowerCase()"
    assert_not_includes source, "innerHTML"
    assert_not_includes source, "grinder_id"
  end
end
