import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "label" ]
  static values = {
    copiedLabel: String,
    failedLabel: String,
    text: String,
    title: String,
    url: String
  }

  connect() {
    this.defaultLabel = this.labelTarget.textContent
  }

  get shareData() {
    return {
      title: this.titleValue,
      text: this.textValue || this.titleValue,
      url: this.urlValue
    }
  }

  async share(event) {
    event.preventDefault()

    const mobile = window.matchMedia("(pointer: coarse)").matches
    if (mobile && navigator.share) {
      try {
        await navigator.share(this.shareData)
        return
      } catch (error) {
        if (error.name === "AbortError") return
      }
    }

    await this.copyFallback()
  }

  async copyFallback() {
    try {
      if (!navigator.clipboard?.writeText) throw new Error("Clipboard unavailable")

      await navigator.clipboard.writeText(this.urlValue)
      this.flashLabel(this.copiedLabelValue)
    } catch (_error) {
      this.flashLabel(this.failedLabelValue)
    }
  }

  flashLabel(label) {
    this.labelTarget.textContent = label
    this.element.setAttribute("aria-label", label)
    clearTimeout(this.resetTimer)
    this.resetTimer = setTimeout(() => {
      this.labelTarget.textContent = this.defaultLabel
      this.element.setAttribute("aria-label", this.defaultLabel)
    }, 2000)
  }
}
