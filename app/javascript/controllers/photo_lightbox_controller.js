import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "dialog", "image" ]
  static values = { sources: Array }

  connect() {
    this.currentIndex = 0
    this.touchStartX = null
  }

  open(event) {
    const source = event.currentTarget.dataset.fullSrc
    if (!source) return

    this.currentIndex = Number.isInteger(event.params.index) ? event.params.index : this.sourcesValue.indexOf(source)
    if (this.currentIndex < 0) this.currentIndex = 0

    this.showSource(source)
    this.dialogTarget.classList.remove("hidden")
    this.dialogTarget.setAttribute("aria-hidden", "false")
    document.documentElement.classList.add("overflow-hidden")
  }

  next() {
    this.move(1)
  }

  previous() {
    this.move(-1)
  }

  close() {
    this.dialogTarget.classList.add("hidden")
    this.dialogTarget.setAttribute("aria-hidden", "true")
    this.imageTarget.removeAttribute("src")
    document.documentElement.classList.remove("overflow-hidden")
  }

  closeFromKeyboard(event) {
    if (event.key === "Escape") this.close()
    if (event.key === "ArrowRight") this.next()
    if (event.key === "ArrowLeft") this.previous()
  }

  touchStart(event) {
    this.touchStartX = event.changedTouches[0]?.clientX
  }

  touchEnd(event) {
    if (this.touchStartX === null) return

    const touchEndX = event.changedTouches[0]?.clientX
    const delta = touchEndX - this.touchStartX
    this.touchStartX = null

    if (Math.abs(delta) < 40) return

    delta < 0 ? this.next() : this.previous()
  }

  move(direction) {
    if (this.dialogTarget.classList.contains("hidden")) return
    if (this.sourcesValue.length < 2) return

    this.currentIndex = (this.currentIndex + direction + this.sourcesValue.length) % this.sourcesValue.length
    this.showSource(this.sourcesValue[this.currentIndex])
  }

  showSource(source) {
    this.imageTarget.src = source
  }
}
