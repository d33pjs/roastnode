import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "bean", "notice", "selectedReference", "grindSetting", "applySetting" ]
  static values = {
    lastBeanId: String,
    previousReferenceKey: String,
    unavailable: String,
    useSettingTemplate: String
  }

  connect() {
    this.updateReminder()
  }

  beanChanged() {
    this.updateReminder()
  }

  grindSettingChanged() {
    this.updateSettingAction()
  }

  applySetting() {
    const setting = this.selectedGrindSetting
    if (!setting || !this.hasGrindSettingTarget) return

    this.grindSettingTarget.value = setting
    this.grindSettingTarget.dispatchEvent(new Event("input", { bubbles: true }))
    this.updateSettingAction()
  }

  updateReminder() {
    const selected = this.selectedBean
    const selectedKey = (selected && selected.dataset.grinderReferenceKey) || ""
    const sameBean = selected && selected.value === this.lastBeanIdValue
    const needsCheck = Boolean(
      selected &&
      !sameBean &&
      this.previousReferenceKeyValue &&
      (!selectedKey || selectedKey !== this.previousReferenceKeyValue)
    )

    if (this.hasNoticeTarget) this.noticeTarget.hidden = !needsCheck
    this.updateSettingAction()
    if (!needsCheck || !this.hasSelectedReferenceTarget) return

    this.selectedReferenceTarget.textContent =
      selected.dataset.grinderReferenceLabel || this.unavailableValue
  }

  updateSettingAction() {
    if (!this.hasGrindSettingTarget || !this.hasApplySettingTarget) return

    const setting = this.selectedGrindSetting
    const differs = Boolean(
      setting &&
      this.normalizedSetting(setting) !== this.normalizedSetting(this.grindSettingTarget.value)
    )

    this.applySettingTarget.hidden = !differs
    if (!differs) return

    this.applySettingTarget.textContent =
      this.useSettingTemplateValue.replace("%{value}", setting.trim())
  }

  normalizedSetting(value) {
    return value.trim().toLowerCase()
  }

  get selectedBean() {
    return this.beanTargets.find((bean) => bean.checked)
  }

  get selectedGrindSetting() {
    const setting = this.selectedBean?.dataset.grindSetting || ""
    return setting.trim() ? setting : ""
  }
}
