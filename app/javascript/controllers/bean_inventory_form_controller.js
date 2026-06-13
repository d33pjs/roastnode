import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "status", "bagSize", "remaining", "openedOn" ]

  connect() {
    this.remainingTouched = this.remainingTarget.value.length > 0
    this.syncOpenedOnState()
  }

  bagSizeChanged() {
    if (this.remainingTouched) return

    this.remainingTarget.value = this.bagSizeTarget.value
  }

  remainingChanged() {
    this.remainingTouched = true
  }

  statusChanged() {
    this.syncOpenedOnState()
  }

  syncOpenedOnState() {
    this.openedOnTarget.disabled = this.statusTarget.value === "stock"
  }
}
