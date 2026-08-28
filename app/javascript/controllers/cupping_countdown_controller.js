import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { deadline: Number }
  static targets = [ "value", "form", "expired" ]

  connect() {
    this.update()
    this.interval = setInterval(() => this.update(), 1000)
  }

  disconnect() {
    clearInterval(this.interval)
  }

  update() {
    if (!this.hasDeadlineValue || !this.hasValueTarget) return

    const remainingMilliseconds = Math.max(0, this.deadlineValue - Date.now())
    const remainingSeconds = Math.ceil(remainingMilliseconds / 1000)
    this.valueTarget.textContent = this.formatDuration(remainingSeconds)

    if (remainingMilliseconds === 0) this.expire()
  }

  formatDuration(totalSeconds) {
    const hours = Math.floor(totalSeconds / 3600)
    const minutes = Math.floor((totalSeconds % 3600) / 60)
    const seconds = totalSeconds % 60

    return [ hours, minutes, seconds ].map((part) => part.toString().padStart(2, "0")).join(":")
  }

  expire() {
    clearInterval(this.interval)
    this.valueTarget.textContent = "00:00:00"
    if (this.hasFormTarget) this.formTarget.hidden = true
    if (this.hasExpiredTarget) this.expiredTarget.hidden = false
  }
}
