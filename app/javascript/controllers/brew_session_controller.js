import { Controller } from "@hotwired/stimulus"
import { applyFields, serializeFields, restoreSession, samePreparation, uniqueFormIds, nextCoffeeFields, localLogTime, coffeeIdentity } from "controllers/brew_session_state"

export default class extends Controller {
  static targets = ["toolbar", "coffees", "forms", "template", "add", "notice", "error", "stage", "continue", "confirmation", "photos", "actions", "addHelp"]
  static values = { storageKey: String, grinderUsesUrl: String, historyUrl: String, timeZone: String, labels: Object }

  connect() {
    this.entries = []
    this.connected = true
    const initialForm = this.formsTarget.querySelector("form")
    this.templateTarget.content.replaceChildren(initialForm.cloneNode(true))
    const restored = this.read()
    this.nextNumber = restored?.nextNumber || 2
    if (restored) {
      restored.drafts.forEach((draft, index) => this.mount(index === 0 ? initialForm : this.cloneForm(draft.id), draft))
      this.activeId = restored.activeId
      this.noticeTarget.hidden = false
    } else {
      const id = this.uuid()
      this.mount(initialForm, {id, number: 1, stage: "all", scroll: 0})
      this.activeId = id
    }
    this.inputHandler = (event) => this.changed(event)
    this.submitHandler = (event) => this.submit(event)
    this.pageHideHandler = () => { if (this.activeEntry) { this.activeEntry.scroll = window.scrollY; this.persist() } }
    this.element.addEventListener("input", this.inputHandler)
    this.element.addEventListener("change", this.inputHandler)
    this.element.addEventListener("submit", this.submitHandler, true)
    window.addEventListener("pagehide", this.pageHideHandler)
    this.toolbarTarget.hidden = false
    this.actionsTarget.hidden = false
    this.element.querySelector("[data-brew-session-discard]").hidden = false
    this.render()
    // Child Stimulus controllers must be connected before restored machine/bean events.
    queueMicrotask(() => {
      this.entries.forEach((entry) => this.synchronize(entry.form))
      if (restored && this.connected) window.scrollTo({top: this.activeEntry.scroll || 0, behavior: "instant"})
    })
  }

  disconnect() {
    this.connected = false
    this.element.removeEventListener("input", this.inputHandler)
    this.element.removeEventListener("change", this.inputHandler)
    this.element.removeEventListener("submit", this.submitHandler, true)
    window.removeEventListener("pagehide", this.pageHideHandler)
  }

  uuid() {
    if (crypto.randomUUID) return crypto.randomUUID()
    const bytes = crypto.getRandomValues(new Uint8Array(16))
    bytes[6] = (bytes[6] & 15) | 64
    bytes[8] = (bytes[8] & 63) | 128
    const hex = Array.from(bytes, (byte) => byte.toString(16).padStart(2, "0")).join("")
    return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`
  }

  mount(form, draft) {
    if (draft.fields) applyFields(form.elements, draft.fields)
    form.dataset.draftId = draft.id
    form.noValidate = true // The server validates all stages and keeps the complete form on error.
    const entry = {requiresConfirmation: false, ...draft, form, error: "", busy: false}
    this.entries.push(entry)
    return entry
  }

  cloneForm(id) {
    const form = this.templateTarget.content.querySelector("form").cloneNode(true)
    uniqueFormIds(form, id)
    this.formsTarget.append(form)
    return form
  }

  synchronize(form) {
    this.synchronizing = true
    for (const name of ["machine_id", "bean_id", "recipient_selection"]) {
      form.querySelector(`input[name="brew[${name}]"]:checked`)?.dispatchEvent(new Event("change", {bubbles: true}))
    }
    this.synchronizing = false
  }

  get activeEntry() { return this.entries.find((entry) => entry.id === this.activeId) }

  preparation(entry) {
    const value = (name) => {
      const controls = Array.from(entry.form.elements).filter((field) => field.name === `brew[${name}]`)
      return controls.find((field) => field.type !== "radio" || field.checked)?.value || ""
    }
    return {bean_id: value("bean_id"), grinder_id: value("grinder_id"), method: "espresso", grind_setting: value("grind_setting")}
  }

  changed(event) {
    if (this.synchronizing) return
    const entry = this.entries.find((item) => item.form.contains(event.target))
    if (!entry) return
    if (entry.confirmation && !samePreparation(entry.confirmation.context, this.preparation(entry))) {
      entry.confirmation = null
      entry.confirmationChanged = true
    }
    if (event.target.type === "file") entry.hadPhotos = Array.from(entry.form.querySelectorAll('input[type="file"]')).some((input) => input.files.length > 0)
    this.persist()
    this.renderCoffees()
    this.renderConfirmation()
  }

  select(event) { this.selectEntry(event.currentTarget.dataset.draftId) }

  selectEntry(id) {
    if (this.activeEntry) this.activeEntry.scroll = window.scrollY
    this.activeId = id
    this.render()
    this.persist()
    window.scrollTo({top: this.activeEntry.scroll || 0, behavior: "instant"})
  }

  coffeeKeydown(event) {
    if (!["ArrowLeft", "ArrowRight", "Home", "End"].includes(event.key)) return
    event.preventDefault()
    const index = this.entries.findIndex((entry) => entry.id === this.activeId)
    const next = event.key === "Home" ? 0 : event.key === "End" ? this.entries.length - 1 : (index + (event.key === "ArrowRight" ? 1 : -1) + this.entries.length) % this.entries.length
    this.selectEntry(this.entries[next].id)
    this.coffeesTarget.querySelector(`[data-draft-id="${this.activeId}"]`).focus()
  }

  changeStage(event) {
    this.activeEntry.stage = event.currentTarget.dataset.stage
    this.render()
    this.persist()
  }

  async add() {
    const source = this.activeEntry
    if (!source || source.busy || this.entries.length >= 2 || this.adding) return
    const setupFields = nextCoffeeFields(serializeFields(source.form.elements))
    const lockedControls = [
      ...Array.from(source.form.elements).filter((field) => field.type === "submit"),
      this.element.querySelector("[data-brew-session-discard]")
    ].filter((control) => control && !control.disabled)
    this.adding = true
    this.addTarget.disabled = true
    lockedControls.forEach((control) => { control.disabled = true })
    try {
      // Opening the next coffee explicitly confirms this preparation first.
      if (!await this.confirmEntry(source, false)) return
      if (!this.connected || !this.entries.includes(source) || source.form.isConnected === false) return
      source.busy = true
      this.render()
      // Get the physical household reference, never copy another coffee's input.
      const data = await this.request(this.historyUrlValue)
      if (!this.connected || !this.entries.includes(source) || source.form.isConnected === false) return
      this.applyHouseholdHistory(data)
      const id = this.uuid()
      const entry = this.mount(this.cloneForm(id), {id, number: this.nextNumber++, stage: "prepare", scroll: 0, fields: setupFields, requiresConfirmation: true})
      const logTime = entry.form.querySelector('[name="brew[occurred_at]"]')
      if (logTime) logTime.value = localLogTime(new Date(), this.timeZoneValue)
      const grinderId = this.preparation(entry).grinder_id
      const setting = entry.form.querySelector('[name="brew[grind_setting]"]')
      if (setting) setting.value = data.last_uses?.[grinderId]?.setting || ""
      this.applyHouseholdHistory(data)
      this.selectEntry(id)
      queueMicrotask(() => this.synchronize(entry.form))
    } catch (error) {
      if (this.entries.includes(source)) source.error = error.message
    } finally {
      source.busy = false
      this.adding = false
      this.addTarget.disabled = false
      lockedControls.forEach((control) => { control.disabled = false })
      if (this.connected) this.render()
    }
  }

  async confirmPreparation() { return this.confirmEntry(this.activeEntry) }

  async confirmEntry(entry, advance = true) {
    if (entry.busy) return false
    const context = this.preparation(entry)
    const bean = entry.form.querySelector('input[name="brew[bean_id]"]:checked')
    if (!context.grinder_id || bean?.dataset.grindState === "pre_ground") {
      entry.confirmation = null
      entry.confirmationChanged = false
      if (advance) entry.stage = "extract"
      this.persist()
      this.render()
      return true
    }
    if (entry.confirmation?.id && samePreparation(entry.confirmation.context, context)) {
      entry.confirmationChanged = false
      if (advance) entry.stage = "extract"
      this.persist()
      this.render()
      return true
    }
    const confirmation = entry.confirmation ||= {key: this.uuid(), context, id: null}
    this.persist() // Persist the retry key before the request can reach the server.
    entry.busy = true
    entry.error = ""
    this.render()
    try {
      const data = await this.request(this.grinderUsesUrlValue, {
        method: "POST", headers: {"Content-Type": "application/json"},
        body: JSON.stringify({grinder_use: {...context, confirmation_key: confirmation.key}})
      })
      if (!this.connected) return
      this.applyHouseholdHistory(data)
      if (entry.confirmation !== confirmation || !samePreparation(context, this.preparation(entry))) return
      confirmation.id = data.use.id
      entry.confirmationChanged = false
      if (advance) entry.stage = "extract"
      return true
    } catch (error) { entry.error = error.message; return false }
    finally {
      entry.busy = false
      this.persist()
      this.render()
    }
  }

  async submit(event) {
    const entry = this.entries.find((item) => item.form === event.target)
    if (!entry) return
    event.preventDefault()
    event.stopImmediatePropagation()
    if (entry.busy || this.adding) return
    if (this.needsConfirmation(entry)) {
      entry.error = this.labelsValue.confirmation_required
      this.render()
      return
    }
    if (entry.confirmationChanged || (entry.confirmation && (!entry.confirmation.id || !samePreparation(entry.confirmation.context, this.preparation(entry))))) {
      entry.error = this.labelsValue.preparation_changed
      this.render()
      return
    }
    entry.submittingFields = serializeFields(entry.form.elements)
    const data = new FormData(entry.form)
    data.set("client_draft_key", entry.id)
    if (entry.requiresConfirmation) data.set("grinder_confirmation_required", "1")
    if (entry.confirmation?.id) data.set("grinder_use_id", entry.confirmation.id)
    this.persist()
    entry.busy = true
    entry.error = ""
    const enabledControls = Array.from(entry.form.elements).filter((field) => !field.disabled)
    enabledControls.forEach((field) => { field.disabled = true })
    entry.form.setAttribute("aria-busy", "true")
    this.render()
    try {
      const response = await this.request(entry.form.action, {method: "POST", body: data})
      if (!this.connected) return
      if (typeof response.url !== "string" || !/^\/brews\/\d+$/.test(response.url)) throw new Error(this.labelsValue.failed)
      this.entries = this.entries.filter((item) => item !== entry)
      entry.form.remove()
      if (this.entries.length) {
        if (this.activeId === entry.id) this.activeId = this.entries[0].id
        this.persist()
        this.render()
      } else {
        this.clear()
        if (window.Turbo) window.Turbo.visit(response.url)
        else window.location.assign(response.url)
      }
    } catch (error) {
      entry.error = error.message
      this.persist()
      this.render()
    } finally {
      entry.busy = false
      enabledControls.forEach((field) => { field.disabled = false })
      entry.form.removeAttribute("aria-busy")
      delete entry.submittingFields
      if (this.entries.length) { this.persist(); this.render() }
    }
  }

  async request(url, options = {}) {
    const request = new AbortController()
    const timeout = setTimeout(() => request.abort(), 5000)
    try {
      const response = await fetch(url, {
        ...options, headers: {Accept: "application/json", "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content || "", ...options.headers},
        credentials: "same-origin", cache: "no-store", signal: request.signal
      })
      if (response.redirected || response.status === 401 || response.status === 403) throw new Error(this.labelsValue.authentication)
      if (!response.headers.get("Content-Type")?.includes("application/json")) throw new Error(this.labelsValue.failed)
      const data = await response.json()
      if (!response.ok) throw new Error(Array.isArray(data.errors) ? data.errors.map(String).join(" ") : this.labelsValue.failed)
      return data
    } catch (error) {
      if (error.name === "AbortError") throw new Error(this.labelsValue.timeout)
      if (error instanceof TypeError) throw new Error(this.labelsValue.failed)
      throw error
    } finally { clearTimeout(timeout) }
  }

  applyHouseholdHistory(data) {
    for (const entry of this.entries) {
      if (data.last_uses) entry.form.setAttribute("data-brew-grinder-reminder-last-uses-value", JSON.stringify(data.last_uses))
      if (data.histories) entry.form.querySelectorAll('[data-brew-grinder-reminder-target~="bean"]').forEach((bean) => {
        bean.dataset.grinderHistories = JSON.stringify(data.histories[bean.value] || {})
      })
      const reminder = this.application.getControllerForElementAndIdentifier(entry.form, "brew-grinder-reminder")
      if (reminder) {
        // Invalidate an older in-flight refresh before installing this newer reference.
        reminder.refreshSequence++
        reminder.refreshRequest?.abort()
        if (data.last_uses) reminder.lastUsesValue = data.last_uses
        reminder.sharedStateFresh = true
        reminder.updateReminder()
      }
    }
  }

  renderCoffees() {
    // Keep buttons mounted: replacing them during a field's blur/change loses the click.
    for (const button of this.coffeesTarget.children) {
      if (!this.entries.some((entry) => entry.id === button.dataset.draftId)) button.remove()
    }
    for (const entry of this.entries) {
      let button = this.coffeesTarget.querySelector(`[data-draft-id="${entry.id}"]`)
      if (!button) {
        button = document.createElement("button")
        button.type = "button"
        button.dataset.draftId = entry.id
        button.dataset.testid = "brew-session-coffee"
        button.dataset.action = "click->brew-session#select keydown->brew-session#coffeeKeydown"
        button.className = "min-h-14 min-w-0 rounded-2xl border px-3 py-2 text-left focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-[var(--rn-accent-strong)]"
        const title = document.createElement("span")
        title.className = "flex min-w-0 items-center gap-2"
        const coffee = document.createElement("span")
        coffee.className = "shrink-0 text-sm font-extrabold"
        const recipient = document.createElement("span")
        recipient.className = "min-w-0 flex-1 truncate text-right text-xs font-semibold opacity-90"
        title.append(coffee, recipient)
        const detail = document.createElement("span")
        detail.className = "block truncate text-xs font-semibold opacity-90"
        button.append(title, detail)
        this.coffeesTarget.append(button)
      }
      button.style.background = entry.id === this.activeId ? "var(--rn-coffee)" : "var(--rn-surface)"
      button.style.color = entry.id === this.activeId ? "var(--rn-canvas)" : "var(--rn-ink)"
      button.style.borderColor = entry.id === this.activeId ? "var(--rn-coffee)" : "var(--rn-line)"
      button.setAttribute("aria-pressed", String(entry.id === this.activeId))
      const bean = entry.form.querySelector('input[name="brew[bean_id]"]:checked')
      const selection = entry.form.querySelector('input[name="brew[recipient_selection]"]:checked')
      const identity = coffeeIdentity({number: entry.number, template: this.labelsValue.coffee,
        bean: bean?.dataset.beanLabel || this.labelsValue.choose_bean,
        selection: selection?.value, recipientLabel: selection?.dataset.recipientLabel,
        recipientName: entry.form.querySelector('[name="brew[recipient_name]"]')?.value})
      const coffeeLabel = button.firstElementChild.firstElementChild
      const recipientLabel = button.firstElementChild.lastElementChild
      if (coffeeLabel.textContent !== identity.coffee) coffeeLabel.textContent = identity.coffee
      if (recipientLabel.textContent !== identity.recipient) recipientLabel.textContent = identity.recipient
      if (button.lastElementChild.textContent !== identity.bean) button.lastElementChild.textContent = identity.bean
      button.title = identity.accessible
      button.setAttribute("aria-label", identity.accessible)
    }
  }

  render() {
    const active = this.activeEntry
    if (!active) return
    this.entries.forEach((entry) => {
      entry.form.hidden = entry !== active
      for (const section of entry.form.children) {
        const name = section.dataset.section || (section.dataset.testid === "record-links-fields" ? "links" : null)
        if (!name) continue
        const stage = ["bean", "dose", "setup"].includes(name) ? "prepare" : name === "extraction" ? "extract" : "taste"
        section.hidden = entry.stage !== "all" && entry.stage !== stage
      }
    })
    this.stageTargets.forEach((button) => {
      const selected = button.dataset.stage === active.stage
      button.setAttribute("aria-pressed", String(selected))
      button.style.background = selected ? "var(--rn-surface-muted)" : "transparent"
    })
    this.addTarget.hidden = this.entries.length >= 2
    this.addHelpTarget.hidden = this.entries.length >= 2
    this.continueTarget.disabled = active.busy
    this.continueTarget.hidden = !["prepare", "all"].includes(active.stage) && !active.confirmationChanged && !(active.confirmation && !active.confirmation.id) && !this.needsConfirmation(active)
    this.continueTarget.textContent = active.busy ? this.labelsValue.working : this.labelsValue.continue
    this.errorTarget.textContent = active.error || ""
    this.errorTarget.hidden = !active.error
    this.photosTarget.hidden = !active.hadPhotos || Array.from(active.form.querySelectorAll('input[type="file"]')).some((input) => input.files.length)
    this.renderCoffees()
    this.renderConfirmation()
  }

  needsConfirmation(entry) {
    const context = this.preparation(entry)
    const bean = entry.form.querySelector('input[name="brew[bean_id]"]:checked')
    return Boolean(entry.requiresConfirmation && context.grinder_id && bean?.dataset.grindState !== "pre_ground" && !entry.confirmation?.id)
  }

  renderConfirmation() {
    const active = this.activeEntry
    if (!active) return
    this.confirmationTarget.hidden = !active.confirmation?.id && !active.confirmationChanged && !this.needsConfirmation(active)
    this.confirmationTarget.textContent = active.confirmationChanged ? this.labelsValue.preparation_changed : this.needsConfirmation(active) ? this.labelsValue.confirmation_required : this.labelsValue.confirmed
  }

  discard() {
    const entry = this.activeEntry
    if (this.adding || !entry || entry.busy || !window.confirm(this.labelsValue.discard_confirm)) return
    if (this.entries.length === 1) {
      const id = this.uuid()
      entry.form.reset()
      this.entries = []
      this.mount(entry.form, {id, number: this.nextNumber++, stage: "all", scroll: 0})
      this.synchronize(entry.form)
    } else {
      this.entries = this.entries.filter((item) => item !== entry)
      entry.form.remove()
    }
    this.activeId = this.entries[0].id
    this.noticeTarget.hidden = true
    this.persist()
    this.render()
  }

  persist() {
    const payload = {version: 2, savedAt: new Date().toISOString(), activeId: this.activeId, nextNumber: this.nextNumber,
      drafts: this.entries.map(({id, number, stage, scroll, form, confirmation, hadPhotos, confirmationChanged, requiresConfirmation, submittingFields}) => ({
        id, number, stage, scroll, confirmation, hadPhotos, confirmationChanged, requiresConfirmation, fields: submittingFields || serializeFields(form.elements)
      }))}
    try { localStorage.setItem(this.storageKeyValue, JSON.stringify(payload)) } catch { /* Keep in-memory forms usable when browser storage is unavailable. */ }
  }

  read() {
    try { return restoreSession(JSON.parse(localStorage.getItem(this.storageKeyValue)), () => this.uuid()) } catch { return null }
  }

  clear() {
    try { localStorage.removeItem(this.storageKeyValue) } catch { /* Save acknowledgement still succeeds without browser storage. */ }
  }
}
