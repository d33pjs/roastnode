import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "notice" ]
  static values = { storageKey: String }

  connect() {
    this.defaultFields = this.serializeFields()
    this.inputHandler = () => this.persist()
    this.submitHandler = () => this.clear()

    this.element.addEventListener("input", this.inputHandler)
    this.element.addEventListener("change", this.inputHandler)
    this.element.addEventListener("submit", this.submitHandler)

    this.restore()
  }

  disconnect() {
    this.element.removeEventListener("input", this.inputHandler)
    this.element.removeEventListener("change", this.inputHandler)
    this.element.removeEventListener("submit", this.submitHandler)
  }

  discard() {
    this.applyFields(this.defaultFields)
    this.clear()
    this.hideNotice()
  }

  persist() {
    const payload = {
      version: 1,
      savedAt: new Date().toISOString(),
      fields: this.serializeFields()
    }

    try {
      localStorage.setItem(this.storageKeyValue, JSON.stringify(payload))
    } catch {
      this.hideNotice()
    }
  }

  restore() {
    const payload = this.read()
    if (!payload?.fields) return

    this.applyFields(payload.fields)
    this.showNotice()
  }

  clear() {
    try {
      localStorage.removeItem(this.storageKeyValue)
    } catch {
      this.hideNotice()
    }
  }

  read() {
    try {
      return JSON.parse(localStorage.getItem(this.storageKeyValue))
    } catch {
      return null
    }
  }

  serializeFields() {
    const fields = {}

    for (const field of this.storableFields) {
      if (field.type === "checkbox") {
        fields[field.name] ||= []
        if (field.checked) fields[field.name].push(field.value)
      } else if (field.type === "radio") {
        if (field.checked) fields[field.name] = field.value
      } else {
        fields[field.name] = field.value
      }
    }

    return fields
  }

  applyFields(fields) {
    for (const [name, controls] of Object.entries(this.groupedFields)) {
      if (!(name in fields)) continue

      for (const field of controls) {
        const value = fields[name]

        if (field.type === "checkbox") {
          field.checked = Array.isArray(value) && value.includes(field.value)
        } else if (field.type === "radio") {
          field.checked = value === field.value
        } else {
          field.value = value
        }
      }
    }
  }

  showNotice() {
    if (this.hasNoticeTarget) this.noticeTarget.classList.remove("hidden")
  }

  hideNotice() {
    if (this.hasNoticeTarget) this.noticeTarget.classList.add("hidden")
  }

  get groupedFields() {
    return this.storableFields.reduce((groups, field) => {
      groups[field.name] ||= []
      groups[field.name].push(field)
      return groups
    }, {})
  }

  get storableFields() {
    return Array.from(this.element.elements).filter((field) => {
      if (!field.name || field.disabled) return false
      if (field.type === "file") return false
      return ![ "button", "hidden", "reset", "submit" ].includes(field.type)
    })
  }
}
