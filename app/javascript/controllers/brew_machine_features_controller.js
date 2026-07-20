import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "machine", "feature" ]

  connect() {
    this.updateFeatures()
  }

  machineChanged() {
    this.updateFeatures()
  }

  updateFeatures() {
    const selectedMachine = this.machineTargets.find((machine) => machine.checked)

    this.featureTargets.forEach((feature) => {
      const capability = `${feature.dataset.feature}Enabled`
      const supported = selectedMachine?.dataset[capability] === "true"

      feature.hidden = !supported
      feature.querySelectorAll("input").forEach((input) => {
        input.disabled = !supported
      })
    })
  }
}
