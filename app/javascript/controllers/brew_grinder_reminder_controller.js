import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "bean", "notice", "selectedReference" ]
  static values = {
    lastBeanId: String,
    previousReferenceKey: String,
    unavailable: String
  }

  connect() {
    this.updateReminder()
  }

  beanChanged() {
    this.updateReminder()
  }

  updateReminder() {
    const selected = this.beanTargets.find((bean) => bean.checked)
    const selectedKey = (selected && selected.dataset.grinderReferenceKey) || ""
    const sameBean = selected && selected.value === this.lastBeanIdValue
    const needsCheck = Boolean(
      selected &&
      !sameBean &&
      this.previousReferenceKeyValue &&
      (!selectedKey || selectedKey !== this.previousReferenceKeyValue)
    )

    this.noticeTarget.hidden = !needsCheck
    if (!needsCheck) return

    this.selectedReferenceTarget.textContent =
      selected.dataset.grinderReferenceLabel || this.unavailableValue
  }
}
