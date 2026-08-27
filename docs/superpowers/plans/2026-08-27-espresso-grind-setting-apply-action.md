# Espresso Grind-Setting Apply Action Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use exodos-dev:subagent-driven-development (recommended) or exodos-dev:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an Espresso-only button beside the Grind setting field that explicitly copies the selected bean's saved best-reference setting when it differs from the current input.

**Architecture:** Keep `BrewGrinderReminder` as the server-side source of the selected bean's best method-specific reference. Move the existing Stimulus controller boundary from the bean section to the whole Brew form so it can coordinate bean radios, the warning, and the Espresso grind-setting field; render the raw saved setting as private radio data and perform all comparison and copying locally without changing the grinder selection.

**Tech Stack:** Rails 8.1 views and integration tests, Hotwire Stimulus, Tailwind CSS, Capybara system tests, Minitest.

## Global Constraints

- The apply action is Espresso-only; Quick Drip's existing informational reminder stays unchanged.
- Use the same best rated, method-specific reference already selected by `BrewGrinderReminder`.
- Show the action only when the saved setting is nonblank and differs from the current input after trimming and case-folding.
- Copy the exact saved text only after an explicit click.
- Never change the selected grinder.
- Dispatch a bubbling `input` event after applying so browser-local draft persistence records the value.
- Do not render the action when the user's Grind setting field is hidden.
- Treat arbitrary grinder-setting strings as text; never render them through `innerHTML`.

---

## File Structure

- Modify `app/views/brews/_form.html.erb`: make the Brew form the `brew-grinder-reminder` controller boundary and provide its translated values.
- Modify `app/views/brews/_bean_selector.html.erb`: keep bean/reference targets inside the form boundary and add each best reference's raw grind-setting data.
- Modify `app/views/brews/_espresso_form_fields.html.erb`: render the Espresso-only grind-setting target and compact apply button.
- Modify `app/javascript/controllers/brew_grinder_reminder_controller.js`: compare the selected saved setting with the current input, show/hide the button, and apply on click.
- Modify `config/locales/en.yml`: add the `Use %{value}` action copy.
- Modify `test/controllers/brews_controller_test.rb`: prove the server-rendered controller/data/markup contract and Espresso-only scope.
- Modify `test/assets/brew_grinder_reminder_controller_test.rb`: lock the controller's safe target/event contract.
- Modify `test/system/brew_draft_grinder_reminder_test.rb`: prove live visibility, manual edits, explicit copying, grinder preservation, and draft persistence.
- Modify `docs/coffee-core.md` and `docs/status.md`: document the explicit Espresso-only apply behavior.

---

### Task 1: Render the Espresso apply-action contract

**Files:**
- Modify: `test/controllers/brews_controller_test.rb`
- Modify: `app/views/brews/_form.html.erb`
- Modify: `app/views/brews/_bean_selector.html.erb`
- Modify: `app/views/brews/_espresso_form_fields.html.erb`
- Modify: `config/locales/en.yml`

**Interfaces:**
- Consumes: `@grinder_reminder`, a `BrewGrinderReminder::Result`; `Reference#grind_setting`; `hidden_brew_fields` through `hide_brew_field`.
- Produces: a form-level `brew-grinder-reminder` controller; bean radio `data-grind-setting`; `grindSetting` and `applySetting` targets; `useSettingTemplate` value containing `Use %{value}`.

- [ ] **Step 1: Write failing integration assertions for the form contract**

Extend `test "new renders private best-reference data without changing grind defaults"` in `test/controllers/brews_controller_test.rb` so the relevant assertions read:

```ruby
document = Nokogiri::HTML(response.body)
form = document.at_css("form[data-controller~='brew-grinder-reminder']")
assert form
assert_equal selected_bean.id.to_s,
  form.at_css("input[value='#{selected_bean.id}']")["value"]
assert_equal "Use %{value}",
  form["data-brew-grinder-reminder-use-setting-template-value"]

selected_input = form.at_css("input[value='#{selected_bean.id}']")
assert_equal [ grinder.id.to_s, "1/1,50" ].to_json,
  selected_input["data-grinder-reference-key"]
assert_equal "1/1,50", selected_input["data-grind-setting"]
assert_includes selected_input["data-grinder-reference-label"], selected_bean.display_name
assert_includes selected_input["data-grinder-reference-label"], "1/1,50"

grind_input = form.at_css("input[name='brew[grind_setting]']")
assert_equal "grindSetting", grind_input["data-brew-grinder-reminder-target"]
assert_includes grind_input["data-action"],
  "input->brew-grinder-reminder#grindSettingChanged"

apply_button = form.at_css("[data-testid='brew-grind-setting-apply']")
assert_equal "button", apply_button["type"]
assert apply_button.key?("hidden")
assert_equal "applySetting", apply_button["data-brew-grinder-reminder-target"]
assert_includes apply_button["data-action"],
  "brew-grinder-reminder#applySetting"

notice = form.at_css("[data-testid='brew-grinder-reminder']")
```

Add a focused scope test:

```ruby
test "grind setting apply action is Espresso-only and respects hidden fields" do
  sign_in_as(users(:one))

  get new_brew_path(method: "quick_drip")

  assert_response :success
  assert_select "[data-testid=brew-grind-setting-apply]", count: 0

  users(:one).update!(hidden_brew_field_names: %w[grind_setting])
  get new_brew_path(method: "espresso")

  assert_response :success
  assert_select "input[name=?]", "brew[grind_setting]", count: 0
  assert_select "[data-testid=brew-grind-setting-apply]", count: 0
end
```

- [ ] **Step 2: Run the focused integration tests and verify RED**

Run:

```bash
bin/rails test test/controllers/brews_controller_test.rb -n "/new renders private best-reference data|grind setting apply action/"
```

Expected: FAIL because the Stimulus boundary is still on the bean section, `data-grind-setting` and `useSettingTemplate` are absent, and no apply button is rendered.

- [ ] **Step 3: Move the controller boundary to the form**

In `app/views/brews/_form.html.erb`, append the controller and values after the existing controller setup and before `form_with`:

```erb
<% if @grinder_reminder&.previous %>
  <% form_data[:controller] = [form_data[:controller], "brew-grinder-reminder"].compact.join(" ") %>
  <% form_data[:brew_grinder_reminder_last_bean_id_value] = @grinder_reminder.last_bean_id %>
  <% form_data[:brew_grinder_reminder_previous_reference_key_value] = @grinder_reminder.previous.comparison_key %>
  <% form_data[:brew_grinder_reminder_unavailable_value] = t("brews.form.no_rated_grinder_reference") %>
  <% form_data[:brew_grinder_reminder_use_setting_template_value] = t("brews.form.use_grind_setting", value: "%{value}") %>
<% end %>
```

In `app/views/brews/_bean_selector.html.erb`, remove the section's `data-controller` and four controller value attributes. Keep the section start as:

```erb
<section
  data-testid="brew-form-section"
  data-section="bean"
  class="rounded-3xl border border-rn-line bg-rn-surface p-4 shadow-sm sm:p-5">
```

Add the raw saved setting to `radio_data` without changing the existing comparison key or label:

```erb
grinder_reference_key: reference&.comparison_key,
grinder_reference_label: reference ? brew_grinder_reference_label(reference) : nil,
grind_setting: reference&.grind_setting.presence
```

- [ ] **Step 4: Render the Espresso-only field target and button**

In `app/views/brews/_espresso_form_fields.html.erb`, replace the visible Grind setting block with:

```erb
<% unless hide_brew_field.call(:grind_setting) %>
  <div>
    <%= form.label :grind_setting, t("brews.form.grind_setting"), class: "block text-sm font-bold text-rn-muted" %>
    <div class="mt-1 flex items-center gap-2">
      <%= form.text_field :grind_setting,
        autofocus: autofocus_field == "grind_setting",
        data: {
          brew_grinder_reminder_target: "grindSetting",
          action: "input->brew-grinder-reminder#grindSettingChanged"
        },
        class: "min-w-0 flex-1 rounded-2xl border border-rn-line bg-[var(--rn-canvas)] px-3 py-3 text-rn-ink shadow-sm focus:border-[var(--rn-accent-strong)] focus:outline-none" %>
      <button
        hidden
        type="button"
        data-testid="brew-grind-setting-apply"
        data-brew-grinder-reminder-target="applySetting"
        data-action="brew-grinder-reminder#applySetting"
        class="shrink-0 rounded-full border border-rn-line bg-rn-surface px-3 py-2 text-sm font-extrabold text-rn-ink hover:bg-[var(--rn-surface-muted)]">
        <%= t("brews.form.use_grind_setting", value: "") %>
      </button>
    </div>
  </div>
<% end %>
```

Under `brews.form` in `config/locales/en.yml`, add:

```yaml
use_grind_setting: "Use %{value}"
```

- [ ] **Step 5: Run the focused integration tests and verify GREEN**

Run:

```bash
bin/rails test test/controllers/brews_controller_test.rb -n "/new renders private best-reference data|grind setting apply action/"
```

Expected: 2 runs, 0 failures, 0 errors.

- [ ] **Step 6: Commit the rendered contract**

```bash
git add app/views/brews/_form.html.erb app/views/brews/_bean_selector.html.erb app/views/brews/_espresso_form_fields.html.erb config/locales/en.yml test/controllers/brews_controller_test.rb
git commit -m "Render espresso grind setting apply action"
```

---

### Task 2: Implement and prove live apply behavior

**Files:**
- Modify: `test/system/brew_draft_grinder_reminder_test.rb`
- Modify: `test/assets/brew_grinder_reminder_controller_test.rb`
- Modify: `app/javascript/controllers/brew_grinder_reminder_controller.js`

**Interfaces:**
- Consumes: `bean` targets with `data-grind-setting`; optional `grindSetting` and `applySetting` targets; `useSettingTemplateValue` containing `%{value}`.
- Produces: `grindSettingChanged()`, `applySetting()`, `updateSettingAction()`, `selectedBean`, `selectedGrindSetting`, and `normalizedSetting(value)`.

- [ ] **Step 1: Write the failing browser behavior test**

Add this test to `test/system/brew_draft_grinder_reminder_test.rb`:

```ruby
test "Espresso can apply a differing selected-bean grind setting explicitly" do
  selected_bean = beans(:second_open_household)
  grinder = equipment(:household_grinder)
  workspaces(:household).brews.create!(
    user: users(:one),
    bean: selected_bean,
    grinder:,
    machine: equipment(:household_machine),
    method: "espresso",
    occurred_at: 1.day.ago,
    bean_weight_grams: 1,
    grind_setting: "1/1,50",
    rating: 5
  )
  brews(:morning_espresso).update!(occurred_at: 1.minute.ago, grind_setting: "1/1,75", rating: 5)
  sign_in_through_browser

  visit new_brew_path(method: "espresso")
  wait_for_stimulus("brew-grinder-reminder")

  grind_input = find('input[name="brew[grind_setting]"]')
  grinder_id = find('input[name="brew[grinder_id]"]:checked').value
  storage_key = find("form[data-brew-draft-storage-key-value]")["data-brew-draft-storage-key-value"]

  assert_equal "1/1,75", grind_input.value
  assert_no_selector "[data-testid=brew-grind-setting-apply]:not([hidden])"

  find("#brew_bean_id_#{selected_bean.id}").click

  assert_selector "[data-testid=brew-grind-setting-apply]:not([hidden])", text: "Use 1/1,50"

  fill_in "Grind setting", with: " 1/1,50 "
  assert_no_selector "[data-testid=brew-grind-setting-apply]:not([hidden])"

  fill_in "Grind setting", with: "manual 9"
  assert_selector "[data-testid=brew-grind-setting-apply]:not([hidden])", text: "Use 1/1,50"
  find("[data-testid=brew-grind-setting-apply]").click

  assert_equal "1/1,50", grind_input.value
  assert_no_selector "[data-testid=brew-grind-setting-apply]:not([hidden])"
  assert_equal grinder_id, find('input[name="brew[grinder_id]"]:checked').value
  assert_equal "1/1,50",
    evaluate_script("JSON.parse(localStorage.getItem(arguments[0])).fields['brew[grind_setting]']", storage_key)
end
```

- [ ] **Step 2: Strengthen the controller safety contract**

In `test/assets/brew_grinder_reminder_controller_test.rb`, replace the old target assertion and the assertion excluding `grind_setting` with:

```ruby
assert_includes source,
  'static targets = [ "bean", "notice", "selectedReference", "grindSetting", "applySetting" ]'
assert_includes source, "grindSettingChanged()"
assert_includes source, "applySetting()"
assert_includes source, "this.grindSettingTarget.value = setting"
assert_includes source, 'new Event("input", { bubbles: true })'
assert_includes source, "this.applySettingTarget.hidden = !differs"
assert_includes source, 'replace("%{value}", setting.trim())'
assert_includes source, "trim().toLowerCase()"
assert_not_includes source, "innerHTML"
assert_not_includes source, "grinder_id"
```

- [ ] **Step 3: Run both behavior tests and verify RED**

Run:

```bash
bin/rails test test/assets/brew_grinder_reminder_controller_test.rb test/system/brew_draft_grinder_reminder_test.rb
```

Expected: FAIL because the controller does not yet declare the setting targets or implement visibility and copying.

- [ ] **Step 4: Implement the minimal Stimulus behavior**

Replace `app/javascript/controllers/brew_grinder_reminder_controller.js` with:

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "bean", "notice", "selectedReference", "grindSetting", "applySetting" ]
  static values = {
    lastBeanId: String,
    previousReferenceKey: String,
    unavailable: String,
    useSettingTemplate: String
  }

  connect() {
    this.updateReminder()
  }

  beanChanged() {
    this.updateReminder()
  }

  grindSettingChanged() {
    this.updateSettingAction()
  }

  applySetting() {
    const setting = this.selectedGrindSetting
    if (!setting || !this.hasGrindSettingTarget) return

    this.grindSettingTarget.value = setting
    this.grindSettingTarget.dispatchEvent(new Event("input", { bubbles: true }))
    this.updateSettingAction()
  }

  updateReminder() {
    const selected = this.selectedBean
    const selectedKey = (selected && selected.dataset.grinderReferenceKey) || ""
    const sameBean = selected && selected.value === this.lastBeanIdValue
    const needsCheck = Boolean(
      selected &&
      !sameBean &&
      this.previousReferenceKeyValue &&
      (!selectedKey || selectedKey !== this.previousReferenceKeyValue)
    )

    this.noticeTarget.hidden = !needsCheck
    this.updateSettingAction()
    if (!needsCheck) return

    this.selectedReferenceTarget.textContent =
      selected.dataset.grinderReferenceLabel || this.unavailableValue
  }

  updateSettingAction() {
    if (!this.hasGrindSettingTarget || !this.hasApplySettingTarget) return

    const setting = this.selectedGrindSetting
    const differs = Boolean(
      setting &&
      this.normalizedSetting(setting) !== this.normalizedSetting(this.grindSettingTarget.value)
    )

    this.applySettingTarget.hidden = !differs
    if (!differs) return

    this.applySettingTarget.textContent =
      this.useSettingTemplateValue.replace("%{value}", setting.trim())
  }

  normalizedSetting(value) {
    return value.trim().toLowerCase()
  }

  get selectedBean() {
    return this.beanTargets.find((bean) => bean.checked)
  }

  get selectedGrindSetting() {
    const setting = this.selectedBean?.dataset.grindSetting || ""
    return setting.trim() ? setting : ""
  }
}
```

- [ ] **Step 5: Run both behavior tests and verify GREEN**

Run:

```bash
bin/rails test test/assets/brew_grinder_reminder_controller_test.rb test/system/brew_draft_grinder_reminder_test.rb
```

Expected: all runs pass with 0 failures and 0 errors.

- [ ] **Step 6: Run the focused reminder regression suite**

Run:

```bash
bin/rails test test/services/brew_grinder_reminder_test.rb test/controllers/brews_controller_test.rb test/assets/brew_grinder_reminder_controller_test.rb test/system/brew_draft_grinder_reminder_test.rb
```

Expected: 0 failures and 0 errors; existing warning, history selection, hidden-field, and draft behavior remain intact.

- [ ] **Step 7: Commit live behavior**

```bash
git add app/javascript/controllers/brew_grinder_reminder_controller.js test/assets/brew_grinder_reminder_controller_test.rb test/system/brew_draft_grinder_reminder_test.rb
git commit -m "Apply selected bean grind setting explicitly"
```

---

### Task 3: Document and verify the finished feature

**Files:**
- Modify: `docs/coffee-core.md`
- Modify: `docs/status.md`

**Interfaces:**
- Consumes: the verified Espresso-only apply behavior from Tasks 1 and 2.
- Produces: durable product documentation that distinguishes automatic non-mutation from an explicit operator action.

- [ ] **Step 1: Update coffee workflow documentation**

In `docs/coffee-core.md`, replace the end of the bean-switch paragraph:

```markdown
The helper never changes grinder or grind-setting inputs.
```

with:

```markdown
The helper never changes the grinder or Grind setting automatically. On Espresso logs only, when the selected bean has a saved best-reference Grind setting that differs from the current input, a compact action beside the field lets the operator copy that exact value explicitly. Quick Drip remains informational only.
```

- [ ] **Step 2: Update the compact status ledger**

In the Espresso logging bullet in `docs/status.md`, add this sentence after the current last-brew-default description:

```markdown
When an Espresso bean switch exposes a differing saved best-reference Grind setting, a compact field action can copy that exact text explicitly without changing the selected grinder; matching or unavailable settings show no action.
```

- [ ] **Step 3: Run formatting and focused verification**

Run:

```bash
git diff --check
bin/rails test test/services/brew_grinder_reminder_test.rb test/controllers/brews_controller_test.rb test/assets/brew_grinder_reminder_controller_test.rb test/system/brew_draft_grinder_reminder_test.rb
```

Expected: `git diff --check` prints nothing; tests finish with 0 failures and 0 errors.

- [ ] **Step 4: Run the full Rails test suite and static checks**

Run:

```bash
bin/rails test
bin/rubocop
bin/brakeman --no-pager
```

Expected: Rails tests finish with 0 failures and 0 errors; RuboCop reports no offenses; Brakeman reports no warnings.

- [ ] **Step 5: Commit documentation**

```bash
git add docs/coffee-core.md docs/status.md
git commit -m "Document espresso grind setting apply action"
```

- [ ] **Step 6: Start the local development server for user review**

Check for the repository's named tmux session:

```bash
tmux has-session -t roastnode-dev
```

If it exists, restart `bin/dev` inside it:

```bash
tmux send-keys -t roastnode-dev C-c
tmux send-keys -t roastnode-dev "cd /Users/d33pjs/Documents/developing/roastnode && bin/dev" Enter
```

If it does not exist, create it detached from the repository root:

```bash
tmux new-session -d -s roastnode-dev "cd /Users/d33pjs/Documents/developing/roastnode && bin/dev"
```

Confirm the server responds and obtain the machine's DNS name:

```bash
curl -I http://localhost:3001
hostname
```

Expected: HTTP 200 or 302 from port 3001. Report `http://<hostname>:3001` so another network client can open it.
