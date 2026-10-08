import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "bean", "grinder", "panel", "lastUse", "context", "empty", "history", "latest", "selectedBean", "source", "inherited", "summary", "rows", "pending", "grindSetting", "applySetting", "fieldReminder", "fieldDescription", "sort", "noRatings" ]
  static values = { lastUses: Object, useSettingTemplate: String, noHistory: String, noGrinder: String, preGround: String, unknownSetting: String, matches: String, mismatch: String, refreshUrl: String, stale: String }

  connect() {
    this.connected = true
    this.sharedStateFresh = true
    this.refreshSequence = this.refreshSequence || 0
    this.updateReminder()
    if (this.hasGrindSettingTarget) {
      this.resizeObserver = new ResizeObserver(() => this.updateFieldReminder())
      this.resizeObserver.observe(this.grindSettingTarget)
    }
    this.refreshHandler = () => this.refreshHistory()
    window.addEventListener("focus", this.refreshHandler)
    document.addEventListener("visibilitychange", this.refreshHandler)
    this.refreshInterval = setInterval(this.refreshHandler, 15000)
    this.refreshHistory()
  }
  disconnect() {
    this.connected = false
    this.refreshSequence++
    this.refreshRequest?.abort()
    clearInterval(this.refreshInterval)
    window.removeEventListener("focus", this.refreshHandler)
    document.removeEventListener("visibilitychange", this.refreshHandler)
    this.resizeObserver?.disconnect()
  }
  beanChanged() { this.updateReminder() }
  grinderChanged() { this.updateReminder() }
  grindSettingChanged() { this.updateSettingState() }
  sortChanged() { this.renderSettings() }

  async refreshHistory() {
    if (!this.connected || document.hidden || !this.refreshUrlValue) return
    const sequence = this.refreshSequence = (this.refreshSequence || 0) + 1
    this.refreshRequest?.abort()
    const request = this.refreshRequest = new AbortController()
    const timeout = setTimeout(() => {
      if (this.connected && sequence === this.refreshSequence) {
        this.sharedStateFresh = false
        this.updateSettingState()
      }
      request.abort()
    }, 5000)
    try {
      const response = await fetch(this.refreshUrlValue, {
        headers: { Accept: "application/json" }, credentials: "same-origin", cache: "no-store", signal: request.signal
      })
      if (!response.ok) throw new Error("Household history unavailable")
      const data = await response.json()
      if (!this.connected || sequence !== this.refreshSequence || request.signal.aborted) return
      let changed = this.sharedStateFresh === false || JSON.stringify(this.lastUsesValue) !== JSON.stringify(data.last_uses)
      for (const bean of this.beanTargets) {
        const histories = JSON.stringify(data.histories[bean.value] || {})
        if (bean.dataset.grinderHistories !== histories) {
          bean.dataset.grinderHistories = histories
          changed = true
        }
      }
      this.lastUsesValue = data.last_uses
      this.sharedStateFresh = true
      if (changed) this.updateReminder()
    } catch (error) {
      if (!this.connected || sequence !== this.refreshSequence || error.name === "AbortError") return
      this.sharedStateFresh = false
      this.updateSettingState()
    } finally {
      clearTimeout(timeout)
    }
  }

  updateReminder() {
    const grinder = this.grinderTargets.find((input) => input.checked)
    const bean = this.beanTargets.find((input) => input.checked)
    this.contextTarget.textContent = grinder?.dataset.grinderName || ""
    this.contextTarget.hidden = !grinder?.value
    this.history = null
    if (bean?.dataset.grindState === "pre_ground") {
      this.emptyTarget.textContent = this.preGroundValue
    } else if (!grinder?.value) {
      this.emptyTarget.textContent = this.noGrinderValue
    } else {
      const histories = JSON.parse(bean?.dataset.grinderHistories || "{}")
      this.history = histories[grinder.value]
      this.emptyTarget.textContent = this.noHistoryValue
    }
    this.historyTarget.hidden = !this.history
    this.emptyTarget.hidden = Boolean(this.history)
    if (this.history) {
      this.selectedBeanTarget.textContent = this.history.bean
      this.latestTarget.textContent = this.history.setting
      this.sourceTarget.textContent = this.history.source
      this.inheritedTarget.hidden = !this.history.inherited
      this.summaryTarget.textContent = this.history.summary
      this.renderSettings()
    } else {
      this.rowsTarget.replaceChildren()
    }
    this.lastUse = this.lastUsesValue[grinder?.value]
    this.lastUseTarget.textContent = this.lastUse?.label || this.unknownSettingValue
    this.lastUseTarget.parentElement.hidden = !grinder?.value || bean?.dataset.grindState === "pre_ground"
    this.grinderRelevant = Boolean(grinder?.value && bean && bean.dataset.grindState !== "pre_ground")
    this.updateSettingState()
  }

  updateSettingState() {
    const inputSetting = this.hasVisibleSettingInput ? this.grindSettingTarget.value : this.lastUse?.setting
    const fresh = this.sharedStateFresh !== false
    const matches = Boolean(fresh && this.history && this.normalizedSetting(inputSetting) === this.normalizedSetting(this.history.setting))
    this.panelTarget.dataset.settingMatch = this.grinderRelevant ? String(matches) : ""
    this.pendingTarget.hidden = !this.grinderRelevant
    this.pendingTarget.textContent = !fresh ? this.staleValue : matches ? this.matchesValue : this.mismatchValue
    this.physicalCheck = Boolean(this.grinderRelevant && (!fresh || !this.history || !this.lastUse?.setting?.trim() ||
      this.normalizedSetting(this.history.setting) !== this.normalizedSetting(this.lastUse.setting) ||
      this.normalizedSetting(inputSetting) !== this.normalizedSetting(this.lastUse.setting)))
    this.panelTarget.dataset.adjustmentNeeded = String(this.physicalCheck)
    this.updateFieldReminder()
    this.updateSettingAction()
  }

  updateFieldReminder() {
    if (!this.hasFieldReminderTarget || !this.hasGrindSettingTarget) return
    this.grindSettingTarget.dataset.physicalCheck = String(this.physicalCheck)
    if (this.hasFieldDescriptionTarget) this.fieldDescriptionTarget.hidden = !this.physicalCheck
    this.fieldReminderTarget.hidden = !this.physicalCheck
    if (this.physicalCheck) {
      this.fieldReminderTarget.hidden = this.settingTextWidth() + this.fieldReminderTarget.offsetWidth + 36 > this.grindSettingTarget.clientWidth
    }
  }

  settingTextWidth() {
    const context = document.createElement("canvas").getContext("2d")
    context.font = getComputedStyle(this.grindSettingTarget).font
    return context.measureText(this.grindSettingTarget.value).width
  }

  renderSettings() {
    const mode = this.hasSortTarget ? this.sortTarget.value : "recent"
    const settings = mode === "best" ? this.history.best_settings : mode === "recent" ? this.history.recent_settings : this.history.settings
    if (this.hasNoRatingsTarget) this.noRatingsTarget.hidden = mode !== "best" || Boolean(settings?.length)
    this.renderBars(settings || this.history.settings)
  }

  renderBars(settings) {
    const maximum = Math.max(...settings.map((entry) => entry.count), 1)
    const rows = settings.map(({ setting, count, rating_label, last_used }) => {
      const row = document.createElement("li")
      row.className = "grid grid-cols-[minmax(3rem,auto)_1fr_auto] items-center gap-3 text-sm"
      const label = document.createElement("span")
      label.className = "max-w-32 break-words font-bold text-rn-ink"
      label.textContent = setting
      const track = document.createElement("span")
      track.className = "h-2 overflow-hidden rounded bg-[var(--rn-surface-muted)]"
      track.setAttribute("aria-hidden", "true")
      const bar = document.createElement("span")
      bar.className = "block h-full rounded bg-[var(--rn-accent-strong)]"
      bar.style.width = `${count / maximum * 100}%`
      track.append(bar)
      const total = document.createElement("span")
      total.className = "tabular-nums text-rn-muted"
      total.textContent = String(count)
      row.append(label, track, total)
      if (last_used || rating_label) {
        const details = document.createElement("span")
        details.className = "col-span-3 -mt-1 break-words text-xs text-rn-muted"
        details.textContent = [rating_label, last_used].filter(Boolean).join(" · ")
        row.append(details)
      }
      return row
    })
    this.rowsTarget.replaceChildren(...rows)
  }

  get canCopy() {
    return Boolean(this.history && this.hasVisibleSettingInput)
  }

  get hasVisibleSettingInput() {
    return Boolean(this.hasGrindSettingTarget && !this.grindSettingTarget.disabled &&
      !this.grindSettingTarget.closest("[hidden]") && this.grindSettingTarget.type !== "hidden")
  }

  updateSettingAction() {
    const differs = this.canCopy && this.normalizedSetting(this.history.setting) !== this.normalizedSetting(this.grindSettingTarget.value)
    if (!this.hasApplySettingTarget) return
    this.applySettingTarget.hidden = !differs
    if (differs) this.applySettingTarget.textContent = this.useSettingTemplateValue.replace("%{value}", this.history.setting)
  }

  applySetting() {
    if (!this.canCopy) return
    this.grindSettingTarget.value = this.history.setting
    this.grindSettingTarget.dispatchEvent(new Event("input", { bubbles: true }))
    this.updateSettingState()
  }

  normalizedSetting(value) { return (value || "").trim().toLowerCase() }
}
