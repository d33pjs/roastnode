// Browser drafts contain editable brew fields only, never tokens, hidden context or media.
const fieldNames = new Set([
  "bean_id", "bean_weight_grams", "ground_weight_grams", "dose_grams", "beverage_grams", "grind_setting",
  "grinder_id", "machine_id", "brew_temperature_celsius", "preinfusion_seconds", "low_flow_start_seconds",
  "first_drip_seconds", "total_time_seconds", "channeling", "flow_control_used", "taste_balance", "rating",
  "recipient_selection", "recipient_name", "cup_style", "notes", "public_note", "occurred_at"
].map((name) => `brew[${name}]`))
export const validUUID = (value) => typeof value === "string" && /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value)
export const expectedField = (name) => fieldNames.has(name) || name === "brew[preparation_tool_ids][]" || /^brew\[record_links_attributes\]\[\d+\]\[(label|url|kind|visibility)\]$/.test(name)
export function editableControls(controls) {
  return Array.from(controls).filter((field) => expectedField(field.name) && !["hidden", "file", "button", "submit", "reset"].includes(field.type))
}
export function serializeFields(controls) {
  const fields = {}
  for (const field of editableControls(controls).filter((field) => !field.disabled)) {
    if (field.type === "checkbox") {
      fields[field.name] ||= []
      if (field.checked) fields[field.name].push(field.value)
    } else if (field.type !== "radio" || field.checked) fields[field.name] = field.value
  }
  return fields
}
export function applyFields(controls, fields) {
  for (const field of editableControls(controls)) {
    if (!Object.hasOwn(fields, field.name)) continue
    const value = fields[field.name]
    if (field.type === "checkbox") field.checked = Array.isArray(value) && value.includes(field.value)
    else if (field.type === "radio") field.checked = value === field.value
    else if (typeof value === "string") field.value = value
  }
}
function safeFields(fields) {
  return Object.fromEntries(Object.entries(fields || {}).filter(([name, value]) => expectedField(name) &&
    (typeof value === "string" || (Array.isArray(value) && value.every((item) => typeof item === "string")))))
}
export function samePreparation(left, right) {
  return Boolean(left && right && ["bean_id", "grinder_id", "method", "grind_setting"].every((name) => left[name] === right[name]))
}
export function restoreSession(payload, uuid) {
  if (!payload || typeof payload !== "object") return null
  if (payload.version === 1 && payload.fields) {
    const id = uuid()
    return {version: 2, activeId: id, nextNumber: 2, drafts: [{id, number: 1, stage: "all", scroll: 0, fields: safeFields(payload.fields)}]}
  }
  if (payload.version !== 2 || !Array.isArray(payload.drafts)) return null
  const seen = new Set()
  const drafts = payload.drafts.filter((draft) => validUUID(draft?.id) && !seen.has(draft.id) && seen.add(draft.id)).slice(0, 2).map((draft, index) => ({
    id: draft.id, number: Number.isSafeInteger(draft.number) && draft.number > 0 ? draft.number : index + 1,
    stage: ["prepare", "extract", "taste", "all"].includes(draft.stage) ? draft.stage : "all",
    scroll: Number.isFinite(draft.scroll) ? Math.max(0, draft.scroll) : 0,
    requiresConfirmation: typeof draft.requiresConfirmation === "boolean" ? draft.requiresConfirmation : draft.number > 1,
    fields: safeFields(draft.fields), hadPhotos: draft.hadPhotos === true, confirmationChanged: draft.confirmationChanged === true,
    confirmation: validUUID(draft.confirmation?.key) && draft.confirmation.context && typeof draft.confirmation.context === "object" ? {
      key: draft.confirmation.key,
      id: typeof draft.confirmation.id === "number" || /^\d+$/.test(draft.confirmation.id) ? draft.confirmation.id : null,
      context: Object.fromEntries(["bean_id", "grinder_id", "method", "grind_setting"].map((key) => [key, String(draft.confirmation.context[key] ?? "")]))
    } : null
  }))
  if (!drafts.length) return null
  return {version: 2, drafts, activeId: drafts.some((draft) => draft.id === payload.activeId) ? payload.activeId : drafts[0].id,
    nextNumber: Math.max(Number.isSafeInteger(payload.nextNumber) ? payload.nextNumber : 1, ...drafts.map((draft) => draft.number + 1))}
}
export function removeDraft(session, id) {
  const drafts = session.drafts.filter((draft) => draft.id !== id)
  return {...session, drafts, activeId: drafts.some((draft) => draft.id === session.activeId) ? session.activeId : drafts[0]?.id || null}
}
export function uniqueFormIds(form, suffix) {
  const references = new Map()
  for (const element of [form, ...form.querySelectorAll("[id]")].filter((element) => element.id)) {
    const oldId = element.id
    element.id = `${oldId}-${suffix}`
    references.set(oldId, element.id)
  }
  for (const element of form.querySelectorAll("[for], [list], [aria-describedby], [aria-labelledby], [aria-controls]")) {
    for (const attribute of ["for", "list", "aria-describedby", "aria-labelledby", "aria-controls"]) {
      if (!element.hasAttribute(attribute)) continue
      element.setAttribute(attribute, element.getAttribute(attribute).split(/\s+/).map((id) => references.get(id) || id).join(" "))
    }
  }
  form.querySelectorAll("[autofocus]").forEach((field) => field.removeAttribute("autofocus"))
}

export function nextCoffeeFields(current) {
  const carried = ["bean_id", "grinder_id", "machine_id", "brew_temperature_celsius", "preinfusion_seconds", "low_flow_start_seconds"].map((name) => `brew[${name}]`)
  carried.push("brew[preparation_tool_ids][]")
  const fields = Object.fromEntries(carried.filter((name) => Object.hasOwn(current, name)).map((name) => [name, current[name]]))
  for (const name of ["bean_weight_grams", "ground_weight_grams", "dose_grams", "beverage_grams", "total_time_seconds", "first_drip_seconds", "notes", "public_note", "recipient_name", "cup_style", "rating"]) fields[`brew[${name}]`] = ""
  fields["brew[recipient_selection]"] = "self"
  fields["brew[taste_balance]"] = "unknown"
  fields["brew[channeling]"] = []
  fields["brew[flow_control_used]"] = []
  return fields
}
export function localLogTime(date, timeZone) {
  const parts = Object.fromEntries(new Intl.DateTimeFormat("en-CA", {timeZone, year: "numeric", month: "2-digit", day: "2-digit", hour: "2-digit", minute: "2-digit", second: "2-digit", hourCycle: "h23"}).formatToParts(date).map(({type, value}) => [type, value]))
  return `${parts.year}-${parts.month}-${parts.day}T${parts.hour}:${parts.minute}:${parts.second}`
}

export function coffeeIdentity({number, template, bean, selection, recipientLabel, recipientName}) {
  const coffee = template.replace("%{number}", number)
  const recipient = selection === "guest" && recipientName?.trim() ? recipientName.trim() : recipientLabel || ""
  return {coffee, bean, recipient, accessible: [coffee, bean, recipient].filter(Boolean).join(" · ")}
}
