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

  async share(event) {
    event.preventDefault()

    const shareData = {
      title: this.titleValue,
      text: this.textValue || this.titleValue,
      url: this.urlValue
    }

    if (navigator.share) {
      try {
        await navigator.share(shareData)
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
    clearTimeout(this.resetTimer)
    this.resetTimer = setTimeout(() => {
      this.labelTarget.textContent = this.defaultLabel
    }, 2000)
  }
}
