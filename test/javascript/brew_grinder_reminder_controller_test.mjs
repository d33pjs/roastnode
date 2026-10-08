import assert from "node:assert/strict"
import { readFileSync } from "node:fs"
import test from "node:test"
import vm from "node:vm"
const source = readFileSync(new URL("../../app/javascript/controllers/brew_grinder_reminder_controller.js", import.meta.url), "utf8").replace('import { Controller } from "@hotwired/stimulus"', 'class Controller {}').replace('export default class', 'globalThis.Reminder = class')
function setup(overrides = {}) {
  const sandbox = { Event: class { constructor(type) { this.type = type } }, document: {hidden: false, removeEventListener() {}}, window: {removeEventListener() {}}, AbortController, setTimeout, clearTimeout, clearInterval, fetch: (...args) => c.fetch(...args), ...overrides }
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
  c.connected = true
  c.sharedStateFresh = true
  c.refreshUrlValue = '/brews/grinder_history?method=espresso'
  c.staleValue = 'Check household grinder history'
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

test('live household refresh turns an old matching phone input red without overwriting it', async () => {
 const c = setup()
 const initial = JSON.parse(c.beanTargets[0].dataset.grinderHistories)
 initial['1'].setting = '1/1,00'
 c.beanTargets[0].value = 'coffee'
 c.beanTargets[0].dataset.grinderHistories = JSON.stringify(initial)
 c.lastUsesValue['1'].setting = '1/1,00'
 c.grindSettingTarget.value = '1/1,00'; c.updateReminder()
 assert.equal(c.panelTarget.dataset.settingMatch, 'true')
 c.fetch = async (_url, options) => {
   assert.equal(options.cache, 'no-store')
   return { ok: true, json: async () => ({histories: {coffee: {'1': {...initial['1'], setting: '1/3,0'}}}, last_uses: {'1': {setting: '1/3,0', label: 'Household coffee · 1/3,0'}}}) }
 }
 await c.refreshHistory()
 assert.equal(c.grindSettingTarget.value, '1/1,00')
 assert.equal(c.latestTarget.textContent, '1/3,0')
 assert.equal(c.lastUseTarget.textContent, 'Household coffee · 1/3,0')
 assert.equal(c.panelTarget.dataset.settingMatch, 'false')
 assert.equal(c.fieldReminderTarget.hidden, false)
})

test('failed refresh cannot show an all-clear and recovers without changing the input', async () => {
 const c = setup(); c.lastUsesValue['1'].setting = '7'; c.grindSettingTarget.value = '7'; c.updateReminder()
 c.beanTargets[0].value = 'coffee'
 c.fetch = async () => { throw new Error('offline') }
 await c.refreshHistory()
 assert.equal(c.panelTarget.dataset.settingMatch, 'false')
 assert.equal(c.pendingTarget.textContent, 'Check household grinder history')
 assert.equal(c.grindSettingTarget.dataset.physicalCheck, 'true')
 const history = JSON.parse(c.beanTargets[0].dataset.grinderHistories)
 c.fetch = async () => ({ok: true, json: async () => ({histories: {coffee: history}, last_uses: c.lastUsesValue})})
 await c.refreshHistory()
 assert.equal(c.panelTarget.dataset.settingMatch, 'true')
 assert.equal(c.grindSettingTarget.value, '7')
})

test('a response from an older refresh cannot undo a newer household warning', async () => {
 const c = setup(); c.beanTargets[0].value = 'coffee'; c.grindSettingTarget.value = '7'; c.updateReminder()
 const history = JSON.parse(c.beanTargets[0].dataset.grinderHistories)
 let resolveOld
 c.fetch = () => new Promise((resolve) => { resolveOld = resolve })
 const old = c.refreshHistory()
 c.fetch = async () => ({ok: true, json: async () => ({histories: {coffee: {'1': {...history['1'], setting: 'new'}}}, last_uses: {'1': {setting: 'new'}}})})
 await c.refreshHistory()
 resolveOld({ok: true, json: async () => ({histories: {coffee: history}, last_uses: {'1': {setting: '7'}}})})
 await old
 assert.equal(c.latestTarget.textContent, 'new')
 assert.equal(c.panelTarget.dataset.settingMatch, 'false')
})

test('five-second timeout removes green reassurance and retains the entered setting', async () => {
 let expire
 const c = setup({setTimeout(callback, milliseconds) { assert.equal(milliseconds, 5000); expire = callback; return 1 }, clearTimeout() {}})
 c.lastUsesValue['1'].setting = '7'; c.grindSettingTarget.value = '7'; c.updateReminder()
 c.fetch = (_url, {signal}) => new Promise((_resolve, reject) => {
   signal.addEventListener('abort', () => reject(Object.assign(new Error('timeout'), {name: 'AbortError'})))
 })
 const pending = c.refreshHistory(); expire(); await pending
 assert.equal(c.pendingTarget.textContent, 'Check household grinder history')
 assert.equal(c.panelTarget.dataset.settingMatch, 'false')
 assert.equal(c.grindSettingTarget.value, '7')
})

test('disconnected controller ignores a late household response', async () => {
 const c = setup(); c.updateReminder()
 let complete
 c.fetch = () => new Promise((resolve) => { complete = resolve })
 const pending = c.refreshHistory(); c.disconnect()
 complete({ok: true, json: async () => ({histories: {}, last_uses: {}})})
 await pending
 assert.equal(c.lastUsesValue['1'].setting, '12')
 assert.equal(c.latestTarget.textContent, '7')
})

test('focus and fifteen-second polling refresh only while the page is visible', async () => {
 const handlers = {}
 const doc = {hidden: true, addEventListener(name, callback) { handlers[name] = callback }, removeEventListener() {}}
 let interval, requests = 0
 const c = setup({document: doc, window: {addEventListener(name, callback) {handlers[name] = callback}, removeEventListener() {}}, ResizeObserver: class {observe() {} disconnect() {}}, setInterval(callback, milliseconds) { assert.equal(milliseconds, 15000); interval = callback; return 1 }})
 c.beanTargets[0].value = 'coffee'
 const history = JSON.parse(c.beanTargets[0].dataset.grinderHistories)
 c.fetch = async () => { requests++; return {ok: true, json: async () => ({histories: {coffee: history}, last_uses: c.lastUsesValue})} }
 c.connect(); await interval(); assert.equal(requests, 0)
 doc.hidden = false; await handlers.visibilitychange(); assert.equal(requests, 1)
 await handlers.focus(); assert.equal(requests, 2)
 await interval(); assert.equal(requests, 3)
 doc.hidden = true; await interval(); assert.equal(requests, 3)
 c.disconnect()
})

test('unchanged household history leaves the live region untouched', async () => {
 const c = setup(); c.beanTargets[0].value = 'coffee'; c.updateReminder()
 const history = JSON.parse(c.beanTargets[0].dataset.grinderHistories)
 let redraws = 0
 c.updateReminder = () => { redraws++ }
 c.fetch = async () => ({ok: true, json: async () => ({histories: {coffee: history}, last_uses: c.lastUsesValue})})
 await c.refreshHistory()
 assert.equal(redraws, 0)
})
