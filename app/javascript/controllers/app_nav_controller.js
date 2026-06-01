import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "menu" ]

  closeFromOutside(event) {
    if (this.element.contains(event.target)) return

    this.closeMenus()
  }

  closeOtherMenus(event) {
    if (!event.target.open) return

    this.closeMenusExcept(event.target)
  }

  closeFromKeyboard(event) {
    if (event.key !== "Escape") return

    this.closeMenus()
  }

  closeMenus() {
    this.closeMenusExcept(null)
  }

  closeMenusExcept(activeMenu) {
    for (const menu of this.menuTargets) {
      if (menu === activeMenu) continue

      menu.open = false
    }
  }
}
