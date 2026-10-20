import assert from "node:assert/strict"
import { readFileSync } from "node:fs"
import test from "node:test"
import vm from "node:vm"
const stateSource = readFileSync(new URL("../../app/javascript/controllers/brew_session_state.js", import.meta.url), "utf8")
const state = await import(`data:text/javascript;base64,${Buffer.from(stateSource).toString("base64")}`)
const source = readFileSync(new URL("../../app/javascript/controllers/brew_session_controller.js", import.meta.url), "utf8")
 .replace('import { Controller } from "@hotwired/stimulus"', 'class Controller {}')
 .replace(/import \{.+\} from "controllers\/brew_session_state"/, 'const {applyFields, serializeFields, restoreSession, samePreparation, uniqueFormIds, nextCoffeeFields, localLogTime, coffeeIdentity} = state')
 .replace('export default class', 'globalThis.Session = class')
const key = "9eabfc89-0059-40d3-a0ed-8be74d7c8ee1"
function setup(extra = {}) {
 const storage = new Map()
 const sandbox = {state, crypto: {randomUUID: () => key}, AbortController, setTimeout, clearTimeout, Uint8Array, localStorage: {setItem: (k,v) => storage.set(k,v), removeItem: (k) => storage.delete(k)},
  document: {querySelector: () => ({content: 'csrf'})}, window: {Turbo: {visit(url) {sandbox.visited = url}}}, FormData: class {constructor(form) {this.form = form; this.values = {}} set(k,v) {this.values[k] = v}}, ...extra}
 vm.runInNewContext(source, sandbox)
 const c = new sandbox.Session()
 const fields = [{name: 'brew[grind_setting]', type: 'text', value: '1/2,50', disabled: false}, {name: 'brew[bean_weight_grams]', type: 'text', value: '18,50', disabled: false}]
 const form = {elements: fields, action: '/brews', setAttribute() {}, removeAttribute() {}, querySelector: () => ({dataset: {grindState: 'whole_bean'}}), remove() {this.removed = true}}
 const entry = {id: key, number: 1, stage: 'prepare', scroll: 0, form, busy: false}
 Object.assign(c, {entries: [entry], activeId: key, connected: true, nextNumber: 2, storageKeyValue: 'drafts', grinderUsesUrlValue: '/grinder_uses', labelsValue: {failed: 'Failed', timeout: 'Timeout', authentication: 'Sign in', preparation_changed: 'Confirm again', confirmation_required: 'Confirm grinding'}})
 c.preparation = () => ({bean_id: '1', grinder_id: '2', method: 'espresso', grind_setting: fields[0].value})
 c.render = () => {}; c.applyHouseholdHistory = (data) => {c.household = data.last_uses}
 return {c, entry, storage, sandbox, fields, event: {target: form, preventDefault() {}, stopImmediatePropagation() {}}}
}
test('confirmation key is persisted before first fetch and retries keep the exact key', async () => {
 const {c, entry, storage} = setup()
 let tries = 0
 c.request = async (_url, options) => {
  const payload = JSON.parse(options.body)
  assert.equal(payload.grinder_use.confirmation_key, key)
  assert.equal(JSON.parse(storage.get('drafts')).drafts[0].confirmation.key, key)
  if (++tries === 1) throw new Error('Offline')
  return {use: {id: 12}, last_uses: {'2': {setting: '1/2,50'}}}
 }
 assert.equal(await c.confirmEntry(entry), false)
 assert.equal(entry.stage, 'prepare'); assert.equal(entry.error, 'Offline'); assert.equal(entry.confirmation.key, key)
 assert.equal(await c.confirmEntry(entry), true)
 assert.equal(entry.stage, 'extract'); assert.equal(entry.confirmation.id, 12)
})
test('save errors retain exact fields and UUID while submitting controls are disabled', async () => {
 const {c, entry, storage, fields, event} = setup()
 c.request = async (_url, options) => {
  assert.equal(options.body.values.client_draft_key, key)
  assert.equal(fields[0].disabled, true)
  throw new Error('Invalid dose')
 }
 await c.submit(event)
 assert.equal(entry.error, 'Invalid dose'); assert.equal(fields[0].disabled, false)
 assert.equal(JSON.parse(storage.get('drafts')).drafts[0].fields['brew[grind_setting]'], '1/2,50')
 assert.equal(JSON.parse(storage.get('drafts')).drafts[0].fields['brew[bean_weight_grams]'], '18,50')
 assert.equal(entry.id, key); assert.equal(entry.form.removed, undefined)
})
test('save acknowledgement removes only the saved coffee and keeps the other confirmation', async () => {
 const {c, entry, event, storage} = setup()
 const remaining = {...entry, id: 'ca9b3e99-5313-49b5-ade6-f01350c54315', number: 2, confirmation: {id: 22, key, context: c.preparation()}}
 c.entries.push(remaining)
 c.request = async () => ({url: '/brews/41'})
 await c.submit(event)
 assert.equal(c.entries.length, 1); assert.equal(c.entries[0].id, remaining.id)
 assert.equal(c.entries[0].confirmation.id, 22); assert.equal(c.activeId, remaining.id)
 assert.equal(JSON.parse(storage.get('drafts')).drafts.length, 1)
})
test('changing exact preparation invalidates confirmation and blocks a stale save', async () => {
 const {c, entry, fields, event} = setup()
 entry.confirmation = {id: 12, key, context: c.preparation()}
 entry.form.contains = () => true
 c.renderCoffees = () => {}; c.renderConfirmation = () => {}
 fields[0].value = '1/3,0'
 c.changed({target: fields[0]})
 assert.equal(entry.confirmation, null); assert.equal(entry.confirmationChanged, true)
 c.request = () => {throw new Error('must not save')}
 await c.submit(event)
 assert.equal(entry.error, 'Confirm again')
})
test('no-grinder and pre-ground preparations advance without a physical-use request', async () => {
 for (const mode of ['no_grinder', 'pre_ground']) {
  const {c, entry} = setup()
  const context = c.preparation()
  if (mode === 'no_grinder') c.preparation = () => ({...context, grinder_id: ''})
  else entry.form.querySelector = () => ({dataset: {grindState: 'pre_ground'}})
  c.request = () => {throw new Error('must not request')}
  assert.equal(await c.confirmEntry(entry), true); assert.equal(entry.stage, 'extract')
 }
})
test('request uses no-store and same-origin; auth redirects and timeout remain visible', async () => {
 let abort
 const {c} = setup({setTimeout(callback, milliseconds) {assert.equal(milliseconds, 5000); abort = callback; return 1}, clearTimeout() {}, fetch: async (_url, options) => {
  assert.equal(options.cache, 'no-store'); assert.equal(options.credentials, 'same-origin'); assert.equal(options.headers['X-CSRF-Token'], 'csrf')
  return {redirected: true, status: 200}
 }})
 await assert.rejects(c.request('/brews'), /Sign in/)
 const timed = setup({setTimeout(callback) {abort = callback; return 1}, clearTimeout() {}, fetch: (_url, {signal}) => new Promise((_resolve, reject) => signal.addEventListener('abort', () => reject(Object.assign(new Error('abort'), {name: 'AbortError'}))))})
 const pending = timed.c.request('/brews'); abort(); await assert.rejects(pending, /Timeout/)
})

test('save does not bypass a confirmation whose response was lost', async () => {
 const {c, entry, event} = setup()
 entry.confirmation = {id: null, key, context: c.preparation()}
 let requests = 0
 c.request = async () => { requests++; return {url: '/brews/1'} }
 await c.submit(event)
 assert.equal(requests, 0); assert.equal(entry.error, 'Confirm again')
})

test('new parallel whole-bean coffees require an explicit grinding confirmation from every stage', async () => {
 const {c, entry, event} = setup()
 entry.requiresConfirmation = true
 entry.stage = 'taste'
 let requests = 0
 c.request = async () => { requests++; return {url: '/brews/1'} }
 await c.submit(event)
 assert.equal(requests, 0)
 assert.equal(entry.error, 'Confirm grinding')
})
test('confirmed parallel saves send their persisted requirement and confirmation id', async () => {
 const {c, entry, event} = setup()
 entry.requiresConfirmation = true
 entry.confirmation = {id: 12, key, context: c.preparation()}
 c.request = async (_url, {body}) => {
  assert.equal(body.values.grinder_confirmation_required, '1')
  assert.equal(body.values.grinder_use_id, 12)
  return {url: '/brews/1'}
 }
 await c.submit(event)
 assert.equal(entry.form.removed, true)
})

function deferred() {
 let resolve, reject
 const promise = new Promise((success, failure) => {resolve = success; reject = failure})
 return {promise, resolve, reject}
}
function addingSetup() {
 const scenario = setup({queueMicrotask})
 const {c, entry, fields, sandbox} = scenario
 for (const [name, value] of [['bean_id', 'selected-bean'], ['grinder_id', 'selected-grinder'], ['machine_id', 'selected-machine']]) {
  fields.push({name: `brew[${name}]`, type: 'radio', checked: true, value, disabled: false})
 }
 const save = {type: 'submit', disabled: false}
 fields.push(save)
 const discard = {disabled: false}
 c.element = {querySelector: () => discard}
 c.addTarget = {disabled: false}
 c.historyUrlValue = '/brews/grinder_history'
 c.timeZoneValue = 'UTC'
 c.confirmEntry = async () => true
 c.uuid = () => '70616435-a277-4dbf-91de-95917cd654f4'
 c.synchronize = () => {}
 c.selectEntry = (id) => {c.activeId = id}
 c.cloneForm = () => {
  const elements = ['bean_id', 'grinder_id', 'machine_id', 'grind_setting'].map((name) => ({name: `brew[${name}]`, value: `template-${name}`, type: 'text'}))
  return {elements, querySelector(selector) {return elements.find((field) => selector.includes(`name="${field.name}"`)) || null}}
 }
 c.mount = (form, draft) => {
  state.applyFields(form.elements, draft.fields)
  const next = {...draft, form}
  c.entries.push(next)
  return next
 }
 c.preparation = (item) => Object.fromEntries(['bean_id', 'grinder_id', 'grind_setting'].map((name) => [name, item.form.elements.find((field) => field.name === `brew[${name}]`)?.value || '']))
 const history = deferred()
 const historyStarted = deferred()
 const saved = deferred()
 let saveRequests = 0
 c.request = (url) => {
  if (url === c.historyUrlValue) {historyStarted.resolve(); return history.promise}
  saveRequests++
  return saved.promise
 }
 sandbox.window.confirm = () => {throw new Error('Discard must be blocked while adding')}
 return {...scenario, save, discard, history, historyStarted, saved, saveRequests: () => saveRequests}
}

test('adding holds the source setup intact while a save is attempted during household refresh', async () => {
 const {c, fields, save, discard, history, historyStarted, saved, event, saveRequests} = addingSetup()
 const pendingAdd = c.add()
 await historyStarted.promise
 const pendingSave = c.submit(event)
 assert.equal(saveRequests(), 0)
 assert.equal(save.disabled, true); assert.equal(discard.disabled, true)
 assert.equal(fields.find((field) => field.name === 'brew[bean_id]').disabled, false)
 history.resolve({last_uses: {'selected-grinder': {setting: 'fresh 1/3,0'}}})
 saved.resolve({url: '/brews/5'})
 await Promise.all([pendingAdd, pendingSave])
 assert.equal(c.entries.length, 2)
 const next = c.entries[1]
 assert.equal(next.fields['brew[bean_id]'], 'selected-bean')
 assert.equal(next.fields['brew[grinder_id]'], 'selected-grinder')
 assert.equal(next.fields['brew[machine_id]'], 'selected-machine')
 assert.equal(next.form.querySelector('[name="brew[grind_setting]"]').value, 'fresh 1/3,0')
 assert.equal(save.disabled, false); assert.equal(discard.disabled, false)
})

test('adding blocks discard and uses the clicked setup snapshot when source inputs change', async () => {
 const {c, entry, fields, history, historyStarted} = addingSetup()
 const pendingAdd = c.add()
 await historyStarted.promise
 c.discard()
 assert.equal(c.entries[0], entry)
 fields.find((field) => field.name === 'brew[bean_id]').value = 'edited-bean'
 history.resolve({last_uses: {}})
 await pendingAdd
 assert.equal(c.entries[1].fields['brew[bean_id]'], 'selected-bean')
 assert.equal(fields.find((field) => field.name === 'brew[bean_id]').value, 'edited-bean')
})

test('late add history never mounts a coffee after its source has been removed', async () => {
 const {c, history, historyStarted, save, discard} = addingSetup()
 const pendingAdd = c.add()
 await historyStarted.promise
 c.entries = []
 c.activeId = null
 history.resolve({last_uses: {}})
 await assert.doesNotReject(pendingAdd)
 assert.equal(c.entries.length, 0)
 assert.equal(c.adding, false); assert.equal(save.disabled, false); assert.equal(discard.disabled, false)
})

test('failed add history is harmless when no active source remains', async () => {
 const {c, history, historyStarted} = addingSetup()
 const pendingAdd = c.add()
 await historyStarted.promise
 c.entries = []
 c.activeId = null
 history.reject(new Error('Offline'))
 await assert.doesNotReject(pendingAdd)
 assert.equal(c.adding, false)
})
