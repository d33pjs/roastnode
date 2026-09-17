import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "name", "roaster", "choice", "status" ]
  static values = { url: String, beanId: String, loading: String, empty: String, failed: String, available: String, bags: String }

  connect() { this.sequence = this.sequence || 0; this.identity = null; this.search() }
  disconnect() { this.sequence++; clearTimeout(this.timer); this.request?.abort() }

  search() {
    const identity = JSON.stringify([ this.nameTarget.value.trim(), this.roasterTarget.value.trim() ])
    if (identity === this.identity) return
    this.identity = identity
    const sequence = ++this.sequence
    clearTimeout(this.timer)
    this.request?.abort()
    this.clearSuggestions()
    if (!this.nameTarget.value.trim() || !this.roasterTarget.value.trim()) {
      this.statusTarget.textContent = this.emptyValue
      return
    }
    this.statusTarget.textContent = this.loadingValue
    this.timer = setTimeout(() => this.fetchSuggestions(sequence), 200)
  }

  clearSuggestions() {
    // Preserve explicit choices, including those redisplayed after validation errors.
    Array.from(this.choiceTarget.options).forEach((option) => {
      if (option.dataset.suggestion && !option.selected) option.remove()
    })
  }

  async fetchSuggestions(sequence) {
    this.request = new AbortController()
    const query = new URLSearchParams({ name: this.nameTarget.value, roaster_name: this.roasterTarget.value })
    if (this.beanIdValue) query.set("bean_id", this.beanIdValue)
    try {
      const response = await fetch(`${this.urlValue}?${query}`, { headers: { Accept: "application/json" }, signal: this.request.signal })
      if (!response.ok) throw new Error("Suggestion lookup failed")
      const data = await response.json()
      if (sequence !== this.sequence) return
      this.clearSuggestions()
      for (const suggestion of data.suggestions) {
        if (Array.from(this.choiceTarget.options).some((option) => option.value === String(suggestion.id))) continue
        const option = document.createElement("option")
        option.value = String(suggestion.id)
        option.textContent = `${suggestion.label} · ${this.bagsValue.replace("%{count}", suggestion.bag_count)}`
        option.dataset.suggestion = "true"
        this.choiceTarget.append(option)
      }
      this.statusTarget.textContent = data.suggestions.length ? this.availableValue : this.emptyValue
    } catch (error) {
      if (sequence !== this.sequence || error.name === "AbortError") return
      this.statusTarget.textContent = this.failedValue
    }
  }
}
