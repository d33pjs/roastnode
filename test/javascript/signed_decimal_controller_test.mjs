import assert from "node:assert/strict"
import { readFileSync } from "node:fs"
import test from "node:test"
import vm from "node:vm"

const source = readFileSync(new URL("../../app/javascript/controllers/signed_decimal_controller.js", import.meta.url), "utf8")
  .replace('import { Controller } from "@hotwired/stimulus"', 'class Controller {}')
  .replace("export default class", "globalThis.SignedDecimal = class")

test("switching weighing modes hides and disables the unused amount and focuses the active amount", () => {
  const sandbox = {}
  vm.runInNewContext(source, sandbox)
  const controller = new sandbox.SignedDecimal()
  const targetInput = { disabled: false, focus() { this.focused = true } }
  const deltaInput = { disabled: false, focus() { this.focused = true } }
  Object.assign(controller, { hasModeTarget: true, modeTarget: { value: "set_remaining" },
    targetFieldsTarget: { querySelectorAll: () => [targetInput] }, deltaFieldsTarget: { querySelectorAll: () => [deltaInput] } })
  controller.connect()
  assert.equal(controller.deltaFieldsTarget.hidden, true)
  assert.equal(deltaInput.disabled, true)
  assert.equal(targetInput.disabled, false)
  controller.modeTarget.value = "delta"
  controller.updateMode()
  assert.equal(controller.targetFieldsTarget.hidden, true)
  assert.equal(targetInput.disabled, true)
  assert.equal(deltaInput.disabled, false)
  assert.equal(deltaInput.focused, true)
})

test("legacy signed amount inputs without mode targets still connect", () => {
  const sandbox = {}
  vm.runInNewContext(source, sandbox)
  const controller = new sandbox.SignedDecimal()
  controller.hasModeTarget = false
  assert.doesNotThrow(() => controller.connect())
})
