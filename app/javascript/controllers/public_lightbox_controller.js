import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog", "image"]

  open(event) {
    const source = event.currentTarget.dataset.fullSrc
    if (!source) return

    this.imageTarget.src = source
    this.dialogTarget.classList.remove("hidden")
    this.dialogTarget.setAttribute("aria-hidden", "false")
    document.documentElement.classList.add("overflow-hidden")
  }

  close() {
    this.dialogTarget.classList.add("hidden")
    this.dialogTarget.setAttribute("aria-hidden", "true")
    this.imageTarget.removeAttribute("src")
    document.documentElement.classList.remove("overflow-hidden")
  }

  closeFromKeyboard(event) {
    if (event.key === "Escape") this.close()
  }
}
