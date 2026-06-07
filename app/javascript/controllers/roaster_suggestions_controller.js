import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "input", "list" ]
  static values = { url: String }

  connect() {
    this.abortController = null
    this.searchTimeout = null
  }

  disconnect() {
    this.abortController?.abort()
    clearTimeout(this.searchTimeout)
  }

  search() {
    const query = this.inputTarget.value.trim()

    clearTimeout(this.searchTimeout)
    if (query.length === 0) {
      this.clear()
      return
    }

    this.searchTimeout = setTimeout(() => this.fetchSuggestions(query), 150)
  }

  blur() {
    setTimeout(() => this.clear(), 100)
  }

  async fetchSuggestions(query) {
    this.abortController?.abort()
    this.abortController = new AbortController()

    try {
      const response = await fetch(`${this.urlValue}?q=${encodeURIComponent(query)}`, {
        headers: { Accept: "application/json" },
        signal: this.abortController.signal
      })

      if (!response.ok) return

      const data = await response.json()
      this.render(data.suggestions || [])
    } catch (error) {
      if (error.name === "AbortError") return

      throw error
    }
  }

  render(suggestions) {
    this.listTarget.innerHTML = ""

    if (suggestions.length === 0) {
      this.clear()
      return
    }

    suggestions.forEach((name) => {
      const button = document.createElement("button")
      button.type = "button"
      button.dataset.roasterName = name
      button.className = "block w-full rounded-xl px-3 py-2 text-left text-sm font-extrabold text-rn-ink hover:bg-[var(--rn-surface-muted)]"
      button.textContent = name
      button.addEventListener("mousedown", (event) => event.preventDefault())
      button.addEventListener("click", (event) => this.choose(event))
      this.listTarget.appendChild(button)
    })

    this.listTarget.classList.remove("hidden")
  }

  choose(event) {
    this.inputTarget.value = event.currentTarget.dataset.roasterName
    this.clear()
    this.inputTarget.focus()
  }

  clear() {
    this.listTarget.innerHTML = ""
    this.listTarget.classList.add("hidden")
  }
}
