import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "groundWeight", "dose" ]

  connect() {
    this.doseTouched = this.doseTarget.value.length > 0
  }

  groundWeightChanged() {
    if (this.doseTouched) return

    this.doseTarget.value = this.groundWeightTarget.value
  }

  doseChanged() {
    this.doseTouched = true
  }
}
