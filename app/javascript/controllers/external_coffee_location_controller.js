import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "latitude", "longitude", "status" ]

  capture() {
    if (!navigator.geolocation) {
      this.statusTarget.textContent = this.element.dataset.unsupportedMessage
      return
    }

    this.statusTarget.textContent = this.element.dataset.pendingMessage
    navigator.geolocation.getCurrentPosition(
      (position) => this.setPosition(position),
      () => this.statusTarget.textContent = this.element.dataset.deniedMessage,
      { enableHighAccuracy: true, timeout: 10000, maximumAge: 60000 }
    )
  }

  setPosition(position) {
    this.latitudeTarget.value = position.coords.latitude.toFixed(6)
    this.longitudeTarget.value = position.coords.longitude.toFixed(6)
    this.statusTarget.textContent = this.element.dataset.capturedMessage
  }
}
