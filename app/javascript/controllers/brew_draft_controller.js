import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "notice" ]
  static values = { storageKey: String }

  connect() {
    // Espresso sessions own both drafts, submission acknowledgements and recovery.
    this.sessionManaged = Boolean(this.element.closest('[data-controller~="brew-session"]'))
    if (this.sessionManaged) return
    this.defaultFields = this.serializeFields(this.restorableFields)
    this.inputHandler = () => this.persist()
    this.submitHandler = (event) => { if (event.detail?.success) this.clear() }

    this.element.addEventListener("input", this.inputHandler)
    this.element.addEventListener("change", this.inputHandler)
    this.element.addEventListener("turbo:submit-end", this.submitHandler)

    this.restore()
  }

  disconnect() {
    if (this.sessionManaged) return
    this.element.removeEventListener("input", this.inputHandler)
    this.element.removeEventListener("change", this.inputHandler)
    this.element.removeEventListener("turbo:submit-end", this.submitHandler)
  }

  discard() {
    if (this.sessionManaged) return
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

  serializeFields(controls = this.storableFields) {
    const fields = {}

    for (const field of controls) {
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

    this.notifyMachineSelectionChanged()
    this.notifyBeanSelectionChanged()
  }

  notifyMachineSelectionChanged() {
    const selectedMachine = this.element.querySelector('input[type="radio"][name="brew[machine_id]"]:checked')
    selectedMachine?.dispatchEvent(new Event("change", { bubbles: true }))
  }

  notifyBeanSelectionChanged() {
    const selectedBean = this.element.querySelector('input[type="radio"][name="brew[bean_id]"]:checked')
    selectedBean?.dispatchEvent(new Event("change", { bubbles: true }))
  }

  showNotice() {
    if (this.hasNoticeTarget) this.noticeTarget.classList.remove("hidden")
  }

  hideNotice() {
    if (this.hasNoticeTarget) this.noticeTarget.classList.add("hidden")
  }

  get groupedFields() {
    return this.restorableFields.reduce((groups, field) => {
      groups[field.name] ||= []
      groups[field.name].push(field)
      return groups
    }, {})
  }

  get storableFields() {
    return this.restorableFields.filter((field) => !field.disabled)
  }

  get restorableFields() {
    return Array.from(this.element.elements).filter((field) => {
      if (!field.name) return false
      if (field.type === "file") return false
      return ![ "button", "hidden", "reset", "submit" ].includes(field.type)
    })
  }
}
