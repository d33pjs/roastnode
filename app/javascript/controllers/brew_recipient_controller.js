import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "selection", "guest", "name" ]

  nameChanged() {
    if (this.nameTarget.value.trim() !== "") this.guestTarget.checked = true
  }

  selectionChanged(event) {
    if (event.target.value !== "guest") this.nameTarget.value = ""
  }
}
