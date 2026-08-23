import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "trigger", "content" ]

  connect() {
    this.conceal()
  }

  show() {
    this.contentTarget.hidden = false
    this.triggerTarget.setAttribute("aria-expanded", "true")
  }

  hide(event) {
    if (event.type === "mouseleave" && this.element.contains(document.activeElement)) return
    if (event.relatedTarget && this.element.contains(event.relatedTarget)) return

    this.conceal()
  }

  dismiss(event) {
    event.preventDefault()
    event.stopPropagation()
    this.conceal()
  }

  conceal() {
    this.contentTarget.hidden = true
    this.triggerTarget.setAttribute("aria-expanded", "false")
  }
}
