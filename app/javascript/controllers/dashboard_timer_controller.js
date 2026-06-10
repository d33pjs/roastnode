import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { sinceAt: Number }
  static targets = [ "value" ]

  connect() {
    this.update()
    this.interval = setInterval(() => this.update(), 1000)
  }

  disconnect() {
    clearInterval(this.interval)
  }

  update() {
    if (!this.hasSinceAtValue || !this.hasValueTarget) return

    const elapsedSeconds = Math.max(0, Math.floor((Date.now() / 1000) - this.sinceAtValue))
    this.valueTarget.textContent = this.formatDuration(elapsedSeconds)
  }

  formatDuration(totalSeconds) {
    const days = Math.floor(totalSeconds / 86400)
    let remaining = totalSeconds % 86400
    const hours = Math.floor(remaining / 3600)
    remaining = remaining % 3600
    const minutes = Math.floor(remaining / 60)
    const seconds = remaining % 60

    const parts = []
    if (days > 0) parts.push(`${days}d`)
    if (hours > 0 || parts.length > 0) parts.push(`${hours}h`)
    if (minutes > 0 || parts.length > 0) parts.push(`${minutes}m`)
    parts.push(`${seconds}s`)

    return parts.join(" ")
  }
}
