import assert from "node:assert/strict"
import { readFileSync } from "node:fs"
import test from "node:test"
import vm from "node:vm"
const source = readFileSync(new URL("../../app/javascript/controllers/coffee_history_choice_controller.js", import.meta.url), "utf8").replace('import { Controller } from "@hotwired/stimulus"', 'class Controller {}').replace('export default class', 'globalThis.Choice = class')
function harness() {
 const requests = [], timers = []
 const sandbox = { URLSearchParams, AbortController, setTimeout: fn => timers.push(fn), clearTimeout: () => {}, document: {createElement: () => ({dataset: {}})}, fetch: () => new Promise(resolve => requests.push(resolve)) }
 vm.runInNewContext(source, sandbox)
 const c = new sandbox.Choice()
 const chosen = {value: '7', selected: true, dataset: {suggestion: 'true'}, remove() {throw Error('Explicit choice lost')} }
 Object.assign(c, { sequence: 0, nameTarget: {value: 'Coffee'}, roasterTarget: {value: 'Roaster'}, choiceTarget: { options: [{value: '', dataset: {}}, chosen], append(o) {this.options.push(o)} }, statusTarget: {}, urlValue: '/suggestions', bagsValue: '%{count} bags', loadingValue: 'loading', emptyValue: 'empty', availableValue: 'available', failedValue: 'failed' })
 return {c, requests, timers}
}
test('invalidates in-flight responses immediately, including during debounce; never auto-selects', async () => {
 const {c, requests} = harness()
 const first = c.fetchSuggestions(0)
 c.nameTarget.value = 'New coffee'; c.search()
 requests[0]({ok:true, json:async()=>({suggestions:[{id:3,label:'Stale'}]})}); await first
 assert.equal(c.choiceTarget.options.length, 2); assert.equal(c.statusTarget.textContent, 'loading')
 const second = c.fetchSuggestions(1)
 requests[1]({ok:true,json:async()=>({suggestions:[{id:4,label:'<script>Literal coffee</script>',bag_count:2}]})}); await second
 assert.equal(c.choiceTarget.options[2].textContent, '<script>Literal coffee</script> · 2 bags'); assert.equal(c.choiceTarget.options[2].selected, undefined); assert.equal(c.choiceTarget.options[1].selected, true)
})
test('failure and blank identity retain selected shared history', async () => {
 const {c, requests} = harness(); const result = c.fetchSuggestions(0)
 requests[0]({ok:false}); await result; assert.equal(c.statusTarget.textContent, 'failed')
 c.nameTarget.value = ' '; c.search(); assert.equal(c.statusTarget.textContent, 'empty'); assert.equal(c.choiceTarget.options[1].selected, true)
})

test('reconnect restarts the same identity and cannot accept pre-disconnect responses', async () => {
 const {c, requests} = harness()
 c.connect()
 const oldSequence = c.sequence
 const old = c.fetchSuggestions(oldSequence)
 c.disconnect(); c.connect()
 assert.ok(c.sequence > oldSequence)
 const current = c.fetchSuggestions(c.sequence)
 requests[1]({ok:true,json:async()=>({suggestions:[{id:4,label:'Current',bag_count:2}]})}); await current
 requests[0]({ok:true,json:async()=>({suggestions:[{id:5,label:'Stale',bag_count:3}]})}); await old
 assert.equal(c.choiceTarget.options.at(-1).textContent, 'Current · 2 bags')
 const sequence = c.sequence
 c.search()
 assert.equal(c.sequence, sequence, 'native blur change must not invalidate an unchanged menu')
})
