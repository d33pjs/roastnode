import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "kind", "machineFeatures" ]

  connect() {
    this.updateMachineFeatures()
  }

  kindChanged() {
    this.updateMachineFeatures()
  }

  updateMachineFeatures() {
    const machineSelected = this.kindTarget.value === "machine"

    this.machineFeaturesTarget.hidden = !machineSelected
    this.machineFeaturesTarget.querySelectorAll("input").forEach((input) => {
      input.disabled = !machineSelected
    })
  }
}
