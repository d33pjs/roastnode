import assert from "node:assert/strict"
import { readFileSync } from "node:fs"
import test from "node:test"
const source = readFileSync(new URL("../../app/javascript/controllers/brew_session_state.js", import.meta.url), "utf8")
const state = await import(`data:text/javascript;base64,${Buffer.from(source).toString("base64")}`)
const uuid = "d8aa831e-c4cc-4ed9-8cc0-c80c13455d50"
const second = "9119ea83-029e-48bf-9327-e746c00831fe"
const control = (name, value, type = "text", extra = {}) => ({ name, value, type, ...extra })

test("serializes only expected editable controls, retaining exact text and checkbox lists", () => {
 const fields = state.serializeFields([
  control("brew[grind_setting]", "1/2,50"), control("brew[bean_weight_grams]", "18,50"),
  control("brew[preparation_tool_ids][]", "3", "checkbox", { checked: true }),
  control("brew[preparation_tool_ids][]", "4", "checkbox", { checked: false }),
  control("brew[bean_id]", "7", "radio", { checked: true }), control("brew[bean_id]", "8", "radio", { checked: false }),
  control("authenticity_token", "secret"), control("brew[recipe_id]", "4", "hidden"),
  control("brew[photos][]", "private.png", "file"), control("brew[notes]", "ignored", "text", {disabled: true}),
  control("brew[raw_media_url]", "private"), control("brew[record_links_attributes][0][url]", "https://coffee.example")
 ])
 assert.deepEqual(fields, {"brew[grind_setting]": "1/2,50", "brew[bean_weight_grams]": "18,50", "brew[preparation_tool_ids][]": ["3"], "brew[bean_id]": "7", "brew[record_links_attributes][0][url]": "https://coffee.example"})
})
test("migrates a legacy single draft and sanitizes untrusted restored fields", () => {
 const result = state.restoreSession({version: 1, fields: {"brew[grind_setting]": "1/2,50", authenticity_token: "secret"}}, () => uuid)
 assert.equal(result.drafts.length, 1); assert.equal(result.drafts[0].id, uuid)
 assert.deepEqual(result.drafts[0].fields, {"brew[grind_setting]": "1/2,50"})
 assert.equal(result.drafts[0].stage, "all")
})
test("restores two isolated drafts and selection, limiting active coffees to two", () => {
 const result = state.restoreSession({version: 2, activeId: second, nextNumber: 4, drafts: [
  {id: uuid, number: 1, stage: "taste", fields: {"brew[notes]": "first"}, hadPhotos: true},
  {id: second, number: 3, stage: "extract", fields: {"brew[notes]": "second"}},
  {id: "bad", number: 4, fields: {}}
 ]}, () => uuid)
 assert.equal(result.drafts.length, 2); assert.equal(result.activeId, second)
 assert.equal(result.drafts[0].fields["brew[notes]"], "first")
 assert.equal(result.drafts[1].fields["brew[notes]"], "second")
 assert.equal(result.nextNumber, 4); assert.equal(result.drafts[0].hadPhotos, true)
})
test("confirmation compares exact strings and clears when preparation changes", () => {
 const context = {bean_id: "1", grinder_id: "2", method: "espresso", grind_setting: "1/2,50"}
 assert.equal(state.samePreparation(context, {...context}), true)
 for (const changed of [{grind_setting: "1/2.50"}, {bean_id: "3"}, {grinder_id: "4"}]) {
  assert.equal(state.samePreparation(context, {...context, ...changed}), false)
 }
})
test("draft removal preserves other identity, metadata and rolling numbering", () => {
 const result = state.removeDraft({drafts: [{id: uuid, number: 1}, {id: second, number: 2}], activeId: uuid, nextNumber: 3}, uuid)
 assert.equal(result.drafts.length, 1); assert.equal(result.activeId, second); assert.equal(result.nextNumber, 3)
 assert.equal(result.drafts[0].number, 2)
})

test("new coffee carries curated setup but clears doses, extraction, recipients and notes", () => {
 const fields = state.nextCoffeeFields({"brew[bean_id]": "7", "brew[grinder_id]": "9", "brew[machine_id]": "11", "brew[preparation_tool_ids][]": ["3"], "brew[brew_temperature_celsius]": "93,5", "brew[preinfusion_seconds]": "4", "brew[bean_weight_grams]": "18,50", "brew[beverage_grams]": "40", "brew[recipient_name]": "Guest", "brew[notes]": "old", "brew[grind_setting]": "stale"})
 assert.equal(fields["brew[bean_id]"], "7"); assert.equal(fields["brew[grinder_id]"], "9")
 assert.deepEqual(fields["brew[preparation_tool_ids][]"], ["3"])
 assert.equal(fields["brew[bean_weight_grams]"], ""); assert.equal(fields["brew[beverage_grams]"], "")
 assert.equal(fields["brew[recipient_selection]"], "self"); assert.equal(fields["brew[recipient_name]"], "")
 assert.equal(fields["brew[grind_setting]"], undefined)
})
test("new log timestamps use the application timezone rather than the browser timezone", () => {
 assert.equal(state.localLogTime(new Date("2026-10-20T20:00:02Z"), "Europe/Berlin"), "2026-10-20T22:00:02")
 assert.equal(state.localLogTime(new Date("2026-10-20T20:00:02Z"), "UTC"), "2026-10-20T20:00:02")
})

test("coffee identity retains selected household-member and guest recipients independently of long beans", () => {
 const bean = "An exceptionally long coffee identity that needs truncation"
 const member = state.coffeeIdentity({number: 2, template: "Coffee %{number}", bean, selection: "member:7", recipientLabel: "A household member with a long display label", recipientName: ""})
 assert.equal(member.recipient, "A household member with a long display label")
 assert.equal(member.bean, bean)
 assert.match(member.accessible, /Coffee 2.*long coffee.*household member/)
 const guest = state.coffeeIdentity({number: 1, template: "Coffee %{number}", bean, selection: "guest", recipientLabel: "Guest", recipientName: "A visiting friend with a very long name"})
 assert.equal(guest.recipient, "A visiting friend with a very long name")
 assert.match(guest.accessible, /long coffee.*visiting friend/)
})
