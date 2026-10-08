import assert from "node:assert/strict"
import { readFileSync } from "node:fs"
import test from "node:test"
import vm from "node:vm"
const source = readFileSync(new URL("../../app/javascript/controllers/brew_grinder_reminder_controller.js", import.meta.url), "utf8").replace('import { Controller } from "@hotwired/stimulus"', 'class Controller {}').replace('export default class', 'globalThis.Reminder = class')
function setup() {
  const sandbox = { Event: class { constructor(type) { this.type = type } } }
  vm.runInNewContext(source, sandbox)
  const c = new sandbox.Reminder()
  const history = { setting: '7', bean: 'Selected coffee', source: 'Coffee · today', inherited: false, summary: '4 brews · 1 bag', settings: [{setting: '8', count: 3}, {setting: '7', count: 1}] }
  Object.assign(c, { beanTargets: [{checked: true, dataset: {grindState: 'whole_bean', grinderHistories: JSON.stringify({'1': history})}}], grinderTargets: [{checked: true, value: '1', dataset: {grinderName: 'Grinder A'}}], hasGrindSettingTarget: true, hasApplySettingTarget: true, grindSettingTarget: {value: '12', disabled: false, closest: () => null, dispatchEvent(e) { this.event = e }}, applySettingTarget: {}, pendingTarget: {}, contextTarget: {}, emptyTarget: {}, historyTarget: {}, latestTarget: {}, selectedBeanTarget: {}, sourceTarget: {}, inheritedTarget: {}, summaryTarget: {}, rowsTarget: {replaceChildren() {}}, useSettingTemplateValue: 'Use %{value}', noHistoryValue: 'No history', noGrinderValue: 'Choose grinder', preGroundValue: 'Pre-ground' })
  c.renderBars = (settings) => { c.rendered = settings }
  Object.assign(c, { panelTarget: {dataset: {}}, lastUseTarget: {parentElement: {}}, lastUsesValue: {'1': {setting: '12', label: 'Other coffee · 12'}}, unknownSettingValue: 'Unknown setting' })
  Object.assign(c, { hasFieldReminderTarget: true, fieldReminderTarget: { offsetWidth: 150 }, hasFieldDescriptionTarget: true, fieldDescriptionTarget: {}, hasSortTarget: true, sortTarget: {value: 'recent'}, matchesValue: 'Setting matches', mismatchValue: 'Check grinder setting' })
  c.grindSettingTarget.dataset = {}
  c.grindSettingTarget.clientWidth = 320
  c.settingTextWidth = () => c.grindSettingTarget.value.length * 8
  return c
}
test('bean and grinder switches never write input; history survives matching and copying', () => {
 const c = setup(); c.updateReminder(); assert.equal(c.latestTarget.textContent, '7'); assert.equal(c.grindSettingTarget.value, '12'); assert.equal(c.pendingTarget.hidden, false)
 c.applySetting(); assert.equal(c.grindSettingTarget.value, '7'); assert.equal(c.grindSettingTarget.event.type, 'input'); assert.equal(c.applySettingTarget.hidden, true); assert.equal(c.historyTarget.hidden, false); assert.equal(c.rendered.length, 2)
 c.grinderTargets[0].value = '2'; c.updateReminder(); assert.equal(c.historyTarget.hidden, true); assert.equal(c.emptyTarget.textContent, 'No history'); assert.equal(c.grindSettingTarget.value, '7')
})
test('pre-ground, absent grinder, hidden and disabled fields cannot copy', () => {
 for (const condition of ['pre_ground', 'no_grinder', 'disabled', 'hidden']) {
  const c = setup()
  if(condition === 'pre_ground') c.beanTargets[0].dataset.grindState = 'pre_ground'
  if(condition === 'no_grinder') c.grinderTargets[0].value = ''
  if(condition === 'disabled') c.grindSettingTarget.disabled = true
  if(condition === 'hidden') c.grindSettingTarget.closest = () => ({})
  c.updateReminder(); c.applySetting(); assert.equal(c.grindSettingTarget.value, '12'); assert.equal(c.applySettingTarget.hidden, true)
 }
})

test('no grinder gives a single instruction without duplicate context text', () => {
 const c = setup(); c.grinderTargets[0].checked = false; c.updateReminder()
 assert.equal(c.contextTarget.hidden, true)
 assert.equal(c.contextTarget.textContent, '')
 assert.equal(c.emptyTarget.textContent, 'Choose grinder')
})

test('physical reminder stays red after copying while the matching panel turns green', () => {
 const c = setup(); c.updateReminder(); c.applySetting()
 assert.equal(c.panelTarget.dataset.settingMatch, 'true')
 assert.equal(c.pendingTarget.textContent, 'Setting matches')
 assert.equal(c.fieldReminderTarget.hidden, false)
 assert.equal(c.panelTarget.dataset.adjustmentNeeded, 'true')
 assert.equal(c.lastUseTarget.textContent, 'Other coffee · 12')
 c.updateReminder()
 assert.equal(c.pendingTarget.hidden, false)
})

test('matching last grinder use clears the warning regardless of the selected bag', () => {
 const c = setup(); c.lastUsesValue['1'].setting = ' 7 '; c.updateReminder()
 assert.equal(c.panelTarget.dataset.settingMatch, 'false')
 assert.equal(c.panelTarget.dataset.adjustmentNeeded, 'true')
 assert.equal(c.applySettingTarget.hidden, false)
 c.grindSettingTarget.value = ' 7 '; c.grindSettingChanged()
 assert.equal(c.panelTarget.dataset.settingMatch, 'true')
 assert.equal(c.fieldReminderTarget.hidden, true)
})

test('typing updates panel match independently of saved grinder values', () => {
 const c = setup(); c.updateReminder()
 assert.equal(c.panelTarget.dataset.settingMatch, 'false')
 c.grindSettingTarget.value = ' 7 '; c.grindSettingChanged()
 assert.equal(c.panelTarget.dataset.settingMatch, 'true')
 assert.equal(c.fieldReminderTarget.hidden, false)
 c.grindSettingTarget.value = ''; c.grindSettingChanged()
 assert.equal(c.panelTarget.dataset.settingMatch, 'false')
})

test('long input hides the overlay while keeping its red outline and accessible reminder', () => {
 const c = setup(); c.updateReminder()
 assert.equal(c.fieldReminderTarget.hidden, false)
 c.grindSettingTarget.value = 'a very long grinder setting that needs the whole input'; c.grindSettingChanged()
 assert.equal(c.fieldReminderTarget.hidden, true)
 assert.equal(c.grindSettingTarget.dataset.physicalCheck, 'true')
 assert.equal(c.fieldDescriptionTarget.hidden, false)
})

test('setting sort modes keep latest reference and input unchanged', () => {
 const c = setup(); c.updateReminder()
 c.history.recent_settings = [{setting: 'latest', count: 1}]
 c.history.best_settings = [{setting: 'best', average_rating: 5, rating_count: 2}]
 c.sortTarget.value = 'best'; c.sortChanged()
 assert.equal(c.rendered[0].setting, 'best')
 assert.equal(c.latestTarget.textContent, '7')
 assert.equal(c.grindSettingTarget.value, '12')
})

test('unknown coffee or grinder settings require a check even with hidden grind fields', () => {
 for (const condition of ['no_history', 'blank_last_use', 'no_last_use', 'hidden_input']) {
  const c = setup()
  if (condition === 'no_history') c.beanTargets[0].dataset.grinderHistories = '{}'
  if (condition === 'blank_last_use') c.lastUsesValue['1'].setting = ''
  if (condition === 'no_last_use') c.lastUsesValue = {}
  if (condition === 'hidden_input') c.hasGrindSettingTarget = false
  c.updateReminder()
  assert.equal(c.pendingTarget.hidden, false, condition)
 }
})

test('pre-ground and absent grinders clear the physical adjustment warning', () => {
 for (const condition of ['pre_ground', 'no_grinder']) {
  const c = setup(); c.updateReminder()
  if (condition === 'pre_ground') c.beanTargets[0].dataset.grindState = 'pre_ground'
  if (condition === 'no_grinder') c.grinderTargets[0].checked = false
  c.updateReminder()
  assert.equal(c.pendingTarget.hidden, true)
  assert.equal(c.panelTarget.dataset.adjustmentNeeded, 'false')
 }
})

test('hidden grind input keeps the household physical mismatch visible in the panel', () => {
 const c = setup(); c.hasGrindSettingTarget = false; c.hasFieldReminderTarget = false; c.updateReminder()
 assert.equal(c.panelTarget.dataset.settingMatch, 'false')
 assert.equal(c.pendingTarget.textContent, 'Check grinder setting')
})
