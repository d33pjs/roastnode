import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "input", "mode", "deltaFields", "targetFields" ]

  connect() {
    this.updateMode(false)
  }

  updateMode(focus = true) {
    if (!this.hasModeTarget) return

    const weighing = this.modeTarget.value === "set_remaining"
    for (const [fields, active] of [[this.targetFieldsTarget, weighing], [this.deltaFieldsTarget, !weighing]]) {
      fields.hidden = !active
      for (const input of fields.querySelectorAll("input")) {
        input.disabled = !active
        if (active && focus) input.focus()
      }
    }
  }

  markAdd() {
    this.mark("+")
  }

  markRemove() {
    this.mark("-")
  }

  mark(sign) {
    const unsignedValue = this.inputTarget.value.trim().replace(/^[+-]/, "")

    this.inputTarget.value = `${sign}${unsignedValue}`
    this.inputTarget.focus()
    this.moveCursorToEnd()
    this.inputTarget.dispatchEvent(new Event("input", { bubbles: true }))
  }

  moveCursorToEnd() {
    const end = this.inputTarget.value.length

    if (this.inputTarget.setSelectionRange) {
      this.inputTarget.setSelectionRange(end, end)
    }
  }
}
