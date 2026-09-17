import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "bean", "grinder", "context", "empty", "history", "latest", "selectedBean", "source", "inherited", "summary", "rows", "pending", "grindSetting", "applySetting" ]
  static values = { useSettingTemplate: String, noHistory: String, noGrinder: String, preGround: String }

  connect() { this.updateReminder() }
  beanChanged() { this.updateReminder() }
  grinderChanged() { this.updateReminder() }
  grindSettingChanged() { this.updateSettingAction() }

  updateReminder() {
    const grinder = this.grinderTargets.find((input) => input.checked)
    const bean = this.beanTargets.find((input) => input.checked)
    this.contextTarget.textContent = grinder?.dataset.grinderName || this.noGrinderValue
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
      this.renderBars(this.history.settings)
    } else {
      this.rowsTarget.replaceChildren()
    }
    this.updateSettingAction()
  }

  renderBars(settings) {
    const maximum = Math.max(...settings.map((entry) => entry.count), 1)
    const rows = settings.map(({ setting, count }) => {
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
      return row
    })
    this.rowsTarget.replaceChildren(...rows)
  }

  get canCopy() {
    return Boolean(this.history && this.hasGrindSettingTarget && !this.grindSettingTarget.disabled &&
      !this.grindSettingTarget.closest("[hidden]") && this.grindSettingTarget.type !== "hidden")
  }

  updateSettingAction() {
    const differs = this.canCopy && this.normalizedSetting(this.history.setting) !== this.normalizedSetting(this.grindSettingTarget.value)
    this.pendingTarget.hidden = !differs
    if (!this.hasApplySettingTarget) return
    this.applySettingTarget.hidden = !differs
    if (differs) this.applySettingTarget.textContent = this.useSettingTemplateValue.replace("%{value}", this.history.setting)
  }

  applySetting() {
    if (!this.canCopy) return
    this.grindSettingTarget.value = this.history.setting
    this.grindSettingTarget.dispatchEvent(new Event("input", { bubbles: true }))
    this.updateSettingAction()
  }

  normalizedSetting(value) { return value.trim().toLowerCase() }
}
