import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "input" ]

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
