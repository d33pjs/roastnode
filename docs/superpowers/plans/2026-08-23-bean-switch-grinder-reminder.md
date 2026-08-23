# Bean-Switch Grinder Reminder Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use exodos-dev:subagent-driven-development (recommended) or exodos-dev:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add compact remaining-inventory and last-used context to Brew Log bean choices, plus a live warning when changing beans requires a different grinder reference.

**Architecture:** A workspace- and method-scoped query/presenter selects the operator-first previous brew and each open bean's best usable rated grinder reference. A shared bean-selector partial renders both Espresso and Quick Drip choices, while a focused Stimulus controller compares opaque, server-normalized keys and reveals a compact pre-rendered warning without changing form values.

**Tech Stack:** Rails 8.1, Ruby 3.3, Active Record, ERB, I18n, Hotwire Stimulus, Tailwind CSS, Minitest.

## Global Constraints

- Treat `Workspace` as the ownership and authorization boundary.
- Compare Espresso only with Espresso and Quick Drip only with Quick Drip.
- Use the operator's most recent method-specific brew, falling back to the workspace's most recent brew only when that operator has no matching workspace history.
- Define a bean's best reference as its highest-rated usable brew for the method, then newest `occurred_at`, then newest `created_at`.
- Show the warning only for a different bean whose reference differs or is unavailable; do not warn when another bean has the same grinder and normalized setting.
- Normalize comparison settings by trimming surrounding whitespace and comparing case-insensitively; do not convert grinder notations or decimal formats.
- Never overwrite grinder or grind-setting inputs.
- Do not add red X marks to beans that were not last used.
- Keep edit forms free of the switch reminder; this slice affects new, repeat, recipe-guided, and failed-create Brew Log rendering.
- Do not add a database migration or persist reminder state.

## File Structure

- Create `app/services/brew_grinder_reminder.rb`: query and value objects for previous/best method-specific grinder references.
- Create `test/services/brew_grinder_reminder_test.rb`: selection, scoping, tie-break, normalization, and unavailable-reference coverage.
- Create `app/views/brews/_bean_selector.html.erb`: shared compact bean-choice UI and pre-rendered warning.
- Modify `app/controllers/brews_controller.rb`: load reminder data only for new/create form flows.
- Modify `app/helpers/brews_helper.rb`: format a private grinder reference for display.
- Modify `app/views/brews/_espresso_form_fields.html.erb`: render the shared selector.
- Modify `app/views/brews/_quick_drip_form_fields.html.erb`: render the shared selector.
- Modify `config/locales/en.yml`: add concise bean inventory and reminder copy.
- Modify `test/controllers/brews_controller_test.rb`: verify rendered metadata, marker uniqueness, private reference payload, and selected-bean preservation.
- Create `app/javascript/controllers/brew_grinder_reminder_controller.js`: reveal/hide the warning on initial connect and bean change.
- Create `test/assets/brew_grinder_reminder_controller_test.rb`: enforce the JavaScript behavior contract used by the rendered form.
- Modify `docs/coffee-core.md` and `docs/status.md`: record the completed Brew Log helper.

---

### Task 1: Workspace-scoped grinder reference query

**Files:**
- Create: `app/services/brew_grinder_reminder.rb`
- Create: `test/services/brew_grinder_reminder_test.rb`

**Interfaces:**
- Consumes: `Workspace#brews`, `User#brews`, `Brew#method`, `Brew#rating`, `Brew#bean`, `Brew#grinder`, and an array of form-available `Bean` records.
- Produces: `BrewGrinderReminder.new(workspace:, user:, method:, beans:).call -> BrewGrinderReminder::Result`.
- Produces: `Result#last_bean_id -> Integer?`, `Result#previous -> Reference?`, and `Result#best_for(bean) -> Reference?`.
- Produces: `Reference#comparison_key -> String?`, an opaque JSON array of grinder ID and normalized setting.

- [ ] **Step 1: Write failing service tests**

Create `test/services/brew_grinder_reminder_test.rb`:

```ruby
require "test_helper"

class BrewGrinderReminderTest < ActiveSupport::TestCase
  test "uses operator history before newer workspace history and stays method scoped" do
    workspace = workspaces(:household)
    operator = users(:one)
    bean = beans(:open_household)
    other_bean = beans(:second_open_household)
    grinder = equipment(:household_grinder)
    brews(:morning_espresso).update!(user: users(:two), occurred_at: 3.days.ago)
    operator_brew = create_espresso(
      workspace:, user: operator, bean:, grinder:, setting: "1/1,75",
      rating: 3, occurred_at: 2.days.ago
    )
    create_espresso(
      workspace:, user: users(:two), bean: other_bean, grinder:, setting: "1/2,00",
      rating: 5, occurred_at: 1.hour.ago
    )
    workspace.brews.create!(
      user: operator,
      bean: other_bean,
      brewer: equipment(:household_brewer),
      grinder:,
      method: "quick_drip",
      occurred_at: 1.minute.ago,
      machine_cups: 4,
      bean_weight_grams: 1,
      grind_setting: "filter 8",
      rating: 5
    )

    result = BrewGrinderReminder.new(
      workspace:, user: operator, method: "espresso", beans: [ bean, other_bean ]
    ).call

    assert_equal operator_brew.bean_id, result.last_bean_id
    assert_equal operator_brew, result.previous.brew
  end

  test "falls back to the workspace and never reads another workspace" do
    workspace = workspaces(:household)
    operator = users(:two)
    bean = beans(:open_household)
    local = create_espresso(
      workspace:, user: users(:one), bean:, grinder: equipment(:household_grinder),
      setting: "12", rating: 4, occurred_at: 2.hours.ago
    )
    create_espresso(
      workspace: workspaces(:other_household), user: operator,
      bean: beans(:other_workspace_open), grinder: equipment(:other_workspace_grinder),
      setting: "secret", rating: 5, occurred_at: 1.minute.ago
    )

    result = BrewGrinderReminder.new(
      workspace:, user: operator, method: "espresso", beans: [ bean ]
    ).call

    assert_equal local, result.previous.brew
    assert_equal bean.id, result.last_bean_id
    assert_not_includes result.previous.display_parts, "secret"
  end

  test "chooses the highest-rated usable bean reference and breaks ties by recency" do
    workspace = workspaces(:household)
    bean = beans(:second_open_household)
    grinder = equipment(:household_grinder)
    create_espresso(
      workspace:, user: users(:one), bean:, grinder:, setting: "old five",
      rating: 5, occurred_at: 2.days.ago
    )
    chosen = create_espresso(
      workspace:, user: users(:one), bean:, grinder:, setting: "new five",
      rating: 5, occurred_at: 1.day.ago
    )
    create_espresso(
      workspace:, user: users(:one), bean:, grinder:, setting: "recent four",
      rating: 4, occurred_at: 1.minute.ago
    )
    create_espresso(
      workspace:, user: users(:one), bean:, grinder: nil, setting: " ",
      rating: 5, occurred_at: Time.current
    )

    result = BrewGrinderReminder.new(
      workspace:, user: users(:one), method: "espresso", beans: [ bean ]
    ).call

    assert_equal chosen, result.best_for(bean).brew
  end

  test "normalizes reference keys and omits beans without usable rated references" do
    workspace = workspaces(:household)
    grinder = equipment(:household_grinder)
    first = create_espresso(
      workspace:, user: users(:one), bean: beans(:open_household), grinder:,
      setting: "  Dial A  ", rating: 5, occurred_at: 2.minutes.ago
    )
    create_espresso(
      workspace:, user: users(:one), bean: beans(:second_open_household),
      grinder: nil, setting: nil, rating: 5, occurred_at: 1.minute.ago
    )

    result = BrewGrinderReminder.new(
      workspace:, user: users(:one), method: "espresso",
      beans: [ beans(:open_household), beans(:second_open_household) ]
    ).call

    assert_equal [ grinder.id.to_s, "dial a" ].to_json, result.best_for(first.bean).comparison_key
    assert_nil result.best_for(beans(:second_open_household))
  end

  private
    def create_espresso(workspace:, user:, bean:, grinder:, setting:, rating:, occurred_at:)
      workspace.brews.create!(
        user:,
        bean:,
        grinder:,
        machine: workspace.equipment.machine.first,
        method: "espresso",
        occurred_at:,
        bean_weight_grams: 1,
        grind_setting: setting,
        rating:
      )
    end
end
```

- [ ] **Step 2: Run the service test and verify the red state**

Run:

```bash
bin/rails test test/services/brew_grinder_reminder_test.rb
```

Expected: ERROR with `uninitialized constant BrewGrinderReminder`.

- [ ] **Step 3: Implement the minimal query and value objects**

Create `app/services/brew_grinder_reminder.rb`:

```ruby
class BrewGrinderReminder
  Reference = Data.define(:brew) do
    delegate :bean, :grinder, :grind_setting, to: :brew

    def usable?
      grinder.present? || grind_setting.present?
    end

    def comparison_key
      return unless usable?

      [ grinder&.id&.to_s, grind_setting.to_s.strip.downcase.presence ].to_json
    end

    def display_parts
      [ bean.display_name, grinder&.name, grind_setting.to_s.strip.presence ].compact
    end
  end

  Result = Data.define(:last_bean_id, :previous, :best_by_bean_id) do
    def best_for(bean)
      best_by_bean_id[bean.id]
    end
  end

  def initialize(workspace:, user:, method:, beans:)
    @workspace = workspace
    @user = user
    @method = method
    @beans = beans
  end

  def call
    last_brew = previous_brew
    previous = reference_for(last_brew)
    previous = nil unless previous&.usable?

    Result.new(
      last_bean_id: last_brew&.bean_id,
      previous:,
      best_by_bean_id: best_references
    )
  end

  private
    attr_reader :workspace, :user, :method, :beans

    def previous_brew
      ordered(workspace.brews.where(user:, method:)).first ||
        ordered(workspace.brews.where(method:)).first
    end

    def best_references
      workspace.brews
        .where(method:, bean_id: beans.map(&:id))
        .where.not(rating: nil)
        .includes(:bean, :grinder)
        .group_by(&:bean_id)
        .transform_values { |brews| best_reference(brews) }
        .compact
    end

    def best_reference(brews)
      brews
        .filter_map do |brew|
          reference = reference_for(brew)
          [ brew, reference ] if reference.usable?
        end
        .max_by do |brew, _reference|
          [ brew.rating, brew.occurred_at || Time.zone.at(0), brew.created_at || Time.zone.at(0) ]
        end
        &.last
    end

    def ordered(scope)
      scope.includes(:bean, :grinder).order(occurred_at: :desc, created_at: :desc)
    end

    def reference_for(brew)
      Reference.new(brew:) if brew
    end
end
```

- [ ] **Step 4: Run the service test and verify green**

Run:

```bash
bin/rails test test/services/brew_grinder_reminder_test.rb
```

Expected: 4 tests, 0 failures, 0 errors.

- [ ] **Step 5: Run style checks for the new Ruby files**

Run:

```bash
bin/rubocop app/services/brew_grinder_reminder.rb test/services/brew_grinder_reminder_test.rb
```

Expected: 2 files inspected, no offenses detected.

- [ ] **Step 6: Commit the query boundary**

```bash
git add app/services/brew_grinder_reminder.rb test/services/brew_grinder_reminder_test.rb
git commit -m "Add brew grinder reminder references"
```

---

### Task 2: Shared bean selector and server-rendered reminder data

**Files:**
- Create: `app/views/brews/_bean_selector.html.erb`
- Modify: `app/controllers/brews_controller.rb`
- Modify: `app/helpers/brews_helper.rb`
- Modify: `app/views/brews/_espresso_form_fields.html.erb`
- Modify: `app/views/brews/_quick_drip_form_fields.html.erb`
- Modify: `config/locales/en.yml`
- Modify: `test/controllers/brews_controller_test.rb`

**Interfaces:**
- Consumes: `BrewGrinderReminder::Result#last_bean_id`, `#previous`, and `#best_for(bean)` from Task 1.
- Produces: radios targeted by `brew-grinder-reminder`, each with `data-grinder-reference-key` and `data-grinder-reference-label`.
- Produces: a hidden notice targeted as `notice` and `selectedReference` for Task 3.

- [ ] **Step 1: Add failing controller rendering tests**

Add these tests near the existing new-form tests in `test/controllers/brews_controller_test.rb`:

```ruby
test "new shows remaining percentage and marks only the method-specific last bean" do
  sign_in_as(users(:one))

  get new_brew_path(method: "espresso")

  assert_response :success
  assert_select "[data-testid=?]", "brew-bean-option-meta-#{beans(:open_household).id}", text: /150(?:\.0)? g left.*60% left/
  assert_select "[data-testid=?]", "brew-bean-last-used-#{beans(:open_household).id}", text: /Last used/, count: 1
  assert_select "[data-testid=?]", "brew-bean-last-used-#{beans(:second_open_household).id}", count: 0
end

test "new renders private best-reference data without changing grind defaults" do
  grinder = equipment(:household_grinder)
  selected_bean = beans(:second_open_household)
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
  brews(:morning_espresso).update!(occurred_at: 1.minute.ago, grind_setting: "1/1,75")
  sign_in_as(users(:one))

  get new_brew_path(method: "espresso")

  assert_response :success
  section = Nokogiri::HTML(response.body).at_css("[data-controller='brew-grinder-reminder']")
  selected_input = section.at_css("input[value='#{selected_bean.id}']")
  assert_equal [ grinder.id.to_s, "1/1,50" ].to_json, selected_input["data-grinder-reference-key"]
  assert_includes selected_input["data-grinder-reference-label"], selected_bean.display_name
  assert_includes selected_input["data-grinder-reference-label"], "1/1,50"
  assert_select "input[name=?][value=?]", "brew[grind_setting]", "1/1,75"
end

test "repeat brew keeps its bean selection while last-used marker describes actual history" do
  source = workspaces(:household).brews.create!(
    user: users(:one),
    bean: beans(:second_open_household),
    grinder: equipment(:household_grinder),
    machine: equipment(:household_machine),
    method: "espresso",
    occurred_at: 2.days.ago,
    bean_weight_grams: 1,
    grind_setting: "1/1,50",
    rating: 5
  )
  brews(:morning_espresso).update!(occurred_at: 1.minute.ago)
  sign_in_as(users(:one))

  get new_brew_path(repeat_brew_id: source.id)

  assert_response :success
  assert_select "input[name=?][value=?][checked]", "brew[bean_id]", source.bean_id.to_s
  assert_select "[data-testid=?]", "brew-bean-last-used-#{brews(:morning_espresso).bean_id}", count: 1
end

test "failed create preserves the selected bean and actual last-used marker" do
  last_brew = brews(:morning_espresso)
  selected_bean = beans(:second_open_household)
  sign_in_as(users(:one))

  post brews_path, params: {
    brew: {
      method: "espresso",
      bean_id: selected_bean.id,
      grinder_id: equipment(:household_grinder).id,
      machine_id: equipment(:household_machine).id,
      bean_weight_grams: ""
    }
  }

  assert_response :unprocessable_entity
  assert_select "input[name=?][value=?][checked]", "brew[bean_id]", selected_bean.id.to_s
  assert_select "[data-testid=?]", "brew-bean-last-used-#{last_brew.bean_id}", count: 1
end
```

- [ ] **Step 2: Run the focused controller tests and verify red**

Run:

```bash
bin/rails test test/controllers/brews_controller_test.rb -n '/new shows remaining percentage|new renders private best-reference|repeat brew keeps its bean selection|failed create preserves the selected bean/'
```

Expected: FAIL because the metadata, marker, controller data, and shared reminder section do not exist.

- [ ] **Step 3: Load reminder data in new/create flows**

In `BrewsController#new`, place `load_grinder_reminder` immediately after `load_form_options`. In `BrewsController#create`, place it immediately after the existing `load_form_options(...)` call. Add this private method near the other form-loading methods:

```ruby
def load_grinder_reminder
  @grinder_reminder = BrewGrinderReminder.new(
    workspace: current_workspace,
    user: Current.user,
    method: @selected_method,
    beans: @beans
  ).call
end
```

Do not call it from `edit` or `update`.

- [ ] **Step 4: Add the reference display helper**

Add to `app/helpers/brews_helper.rb` before its private section:

```ruby
def brew_grinder_reference_label(reference)
  reference.display_parts.join(" · ")
end
```

- [ ] **Step 5: Add concise localized copy**

Add these keys under `brews.form` in `config/locales/en.yml`:

```yaml
      best_for_selected_bean: "Best for selected bean"
      check_grinder_settings: "Check grinder settings"
      last_used: "Last used"
      no_rated_grinder_reference: "No rated grinder reference yet"
      previous_brew: "Previous brew"
      remaining: "%{grams} left"
      remaining_percent: "%{percent}% left"
```

- [ ] **Step 6: Create the shared bean-selector partial**

Create `app/views/brews/_bean_selector.html.erb`:

```erb
<% reminder = local_assigns.fetch(:grinder_reminder, nil) %>
<% previous = reminder&.previous %>

<section
  data-testid="brew-form-section"
  data-section="bean"
  <% if previous %>
    data-controller="brew-grinder-reminder"
    data-brew-grinder-reminder-last-bean-id-value="<%= reminder.last_bean_id %>"
    data-brew-grinder-reminder-previous-reference-key-value="<%= previous&.comparison_key %>"
    data-brew-grinder-reminder-unavailable-value="<%= t("brews.form.no_rated_grinder_reference") %>"
  <% end %>
  class="rounded-3xl border border-rn-line bg-rn-surface p-4 shadow-sm sm:p-5">
  <h2 class="text-sm font-extrabold uppercase tracking-[0.08em] text-rn-muted"><%= t("brews.form.sections.bean") %></h2>
  <div class="mt-3 grid gap-3">
    <% @beans.each do |bean| %>
      <% reference = reminder&.best_for(bean) %>
      <% radio_data = if previous
        {
          brew_grinder_reminder_target: "bean",
          action: "change->brew-grinder-reminder#beanChanged",
          grinder_reference_key: reference&.comparison_key,
          grinder_reference_label: reference ? brew_grinder_reference_label(reference) : nil
        }.compact
      else
        {}
      end %>
      <label for="brew_bean_id_<%= bean.id %>" class="grid cursor-pointer grid-cols-[3.5rem_1fr_auto] items-center gap-3 rounded-2xl border border-rn-line bg-[var(--rn-canvas)] p-3 hover:bg-[var(--rn-surface-muted)]">
        <%= render "shared/record_photo_thumb",
          record: bean,
          testid: "brew-bean-option-photo",
          class_name: "h-14 w-14 shrink-0 rounded-2xl object-contain ring-1 ring-stone-200" %>
        <span class="min-w-0">
          <span class="block truncate font-extrabold text-rn-ink"><%= bean.display_name_for_collection(@beans) %></span>
          <span data-testid="brew-bean-option-meta-<%= bean.id %>" class="mt-1 flex flex-wrap items-center gap-x-1.5 text-sm font-semibold text-rn-muted">
            <span><%= t("brews.form.remaining", grams: profile_grams(bean.remaining_grams)) %></span>
            <span aria-hidden="true">·</span>
            <span><%= t("brews.form.remaining_percent", percent: bean.remaining_percent) %></span>
            <% if reminder&.last_bean_id == bean.id %>
              <span aria-hidden="true">·</span>
              <span data-testid="brew-bean-last-used-<%= bean.id %>" class="font-extrabold text-green-700">✓ <%= t("brews.form.last_used") %></span>
            <% end %>
          </span>
        </span>
        <%= form.radio_button :bean_id, bean.id,
          data: radio_data,
          class: "h-5 w-5 border-rn-line text-[var(--rn-accent-strong)]" %>
      </label>
    <% end %>
  </div>

  <% if reminder && previous %>
    <div
      hidden
      role="alert"
      data-testid="brew-grinder-reminder"
      data-brew-grinder-reminder-target="notice"
      class="mt-3 rounded-2xl border border-red-300 bg-red-50 px-3 py-2.5 text-sm text-red-900">
      <p class="font-extrabold"><%= t("brews.form.check_grinder_settings") %></p>
      <p class="mt-1"><span class="font-bold"><%= t("brews.form.previous_brew") %></span> — <%= brew_grinder_reference_label(previous) %></p>
      <p><span class="font-bold"><%= t("brews.form.best_for_selected_bean") %></span> — <span data-brew-grinder-reminder-target="selectedReference"></span></p>
    </div>
  <% end %>
</section>
```

- [ ] **Step 7: Replace both duplicated bean sections with the shared partial**

In `app/views/brews/_espresso_form_fields.html.erb` and `app/views/brews/_quick_drip_form_fields.html.erb`, replace the full first `<section data-section="bean">...</section>` block with:

```erb
<%= render "brews/bean_selector", form:, grinder_reminder: @grinder_reminder %>
```

- [ ] **Step 8: Run controller and helper coverage**

Run:

```bash
bin/rails test test/controllers/brews_controller_test.rb test/helpers/brews_helper_test.rb
```

Expected: 0 failures, 0 errors.

- [ ] **Step 9: Commit the server-rendered interface**

```bash
git add app/controllers/brews_controller.rb app/helpers/brews_helper.rb app/views/brews/_bean_selector.html.erb app/views/brews/_espresso_form_fields.html.erb app/views/brews/_quick_drip_form_fields.html.erb config/locales/en.yml test/controllers/brews_controller_test.rb
git commit -m "Show bean switch grinder context"
```

---

### Task 3: Live grinder reminder behavior

**Files:**
- Create: `app/javascript/controllers/brew_grinder_reminder_controller.js`
- Create: `test/assets/brew_grinder_reminder_controller_test.rb`

**Interfaces:**
- Consumes: `bean`, `notice`, and `selectedReference` targets from Task 2.
- Consumes: `lastBeanId`, `previousReferenceKey`, and `unavailable` Stimulus values from Task 2.
- Consumes: each selected radio's `data-grinder-reference-key` and `data-grinder-reference-label`.
- Produces: an initial and change-driven `hidden` state for the existing notice; changes no form input values.

- [ ] **Step 1: Add the failing JavaScript behavior contract test**

Create `test/assets/brew_grinder_reminder_controller_test.rb`:

```ruby
require "test_helper"

class BrewGrinderReminderControllerTest < ActiveSupport::TestCase
  test "updates on connect and bean changes without mutating brew inputs" do
    source = Rails.root.join("app/javascript/controllers/brew_grinder_reminder_controller.js").read

    assert_includes source, 'static targets = [ "bean", "notice", "selectedReference" ]'
    assert_includes source, "connect()"
    assert_includes source, "beanChanged()"
    assert_includes source, "this.updateReminder()"
    assert_includes source, "bean.checked"
    assert_includes source, "selected.value === this.lastBeanIdValue"
    assert_includes source, "selected.dataset.grinderReferenceKey"
    assert_includes source, "selectedKey !== this.previousReferenceKeyValue"
    assert_includes source, "this.noticeTarget.hidden = !needsCheck"
    assert_includes source, "this.selectedReferenceTarget.textContent"
    assert_not_includes source, "innerHTML"
    assert_not_includes source, "grind_setting"
    assert_not_includes source, "grinder_id"
  end
end
```

- [ ] **Step 2: Run the asset test and verify red**

Run:

```bash
bin/rails test test/assets/brew_grinder_reminder_controller_test.rb
```

Expected: ERROR because `brew_grinder_reminder_controller.js` does not exist.

- [ ] **Step 3: Implement the focused Stimulus controller**

Create `app/javascript/controllers/brew_grinder_reminder_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "bean", "notice", "selectedReference" ]
  static values = {
    lastBeanId: String,
    previousReferenceKey: String,
    unavailable: String
  }

  connect() {
    this.updateReminder()
  }

  beanChanged() {
    this.updateReminder()
  }

  updateReminder() {
    const selected = this.beanTargets.find((bean) => bean.checked)
    const selectedKey = selected?.dataset.grinderReferenceKey || ""
    const sameBean = selected?.value === this.lastBeanIdValue
    const needsCheck = Boolean(
      selected &&
      !sameBean &&
      this.previousReferenceKeyValue &&
      (!selectedKey || selectedKey !== this.previousReferenceKeyValue)
    )

    this.noticeTarget.hidden = !needsCheck
    if (!needsCheck) return

    this.selectedReferenceTarget.textContent =
      selected.dataset.grinderReferenceLabel || this.unavailableValue
  }
}
```

- [ ] **Step 4: Run asset and form tests and verify green**

Run:

```bash
bin/rails test test/assets/brew_grinder_reminder_controller_test.rb test/controllers/brews_controller_test.rb
```

Expected: 0 failures, 0 errors.

- [ ] **Step 5: Commit the interaction**

```bash
git add app/javascript/controllers/brew_grinder_reminder_controller.js test/assets/brew_grinder_reminder_controller_test.rb
git commit -m "Add live grinder switch reminder"
```

---

### Task 4: Product documentation, regression verification, and visual QA

**Files:**
- Modify: `docs/coffee-core.md`
- Modify: `docs/status.md`

**Interfaces:**
- Consumes: completed server rendering and Stimulus behavior from Tasks 1-3.
- Produces: durable product documentation and fresh verification evidence.

- [ ] **Step 1: Update the coffee workflow documentation**

Add this paragraph to the Espresso/Quick Drip logging area in `docs/coffee-core.md`:

```markdown
The new Brew Log keeps multi-bean operation visible at the top of the form. Every open bean choice shows remaining grams and rounded percentage, and the operator's last method-specific bean is marked with a green `Last used` check. Selecting another bean reveals a compact `Check grinder settings` warning only when its highest-rated method-specific grinder reference differs from the previous brew, or when no rated reference is available. The helper never changes grinder or grind-setting inputs.
```

- [ ] **Step 2: Update the status ledger**

Extend the existing Espresso/Quick Drip logging bullets in `docs/status.md` with this sentence:

```markdown
Brew Log bean choices now show grams and percentage remaining, identify the operator's method-specific last-used bean, and reveal a compact grinder-check reminder when another bean's best saved reference differs or is unavailable.
```

- [ ] **Step 3: Run focused feature verification**

Run:

```bash
bin/rails test test/services/brew_grinder_reminder_test.rb test/assets/brew_grinder_reminder_controller_test.rb test/controllers/brews_controller_test.rb test/helpers/brews_helper_test.rb
```

Expected: 0 failures, 0 errors.

- [ ] **Step 4: Run the full Rails test suite**

Run:

```bash
bin/rails test
```

Expected: 0 failures, 0 errors.

- [ ] **Step 5: Run repository quality and security checks**

Run:

```bash
bin/rubocop
bin/brakeman --no-pager
git diff --check
```

Expected: RuboCop reports no offenses, Brakeman reports no warnings, and `git diff --check` exits 0 without output.

- [ ] **Step 6: Start the user-checkable development server in tmux**

Confirm whether `roastnode-dev` exists with `tmux ls`. If it exists, send Ctrl-C through tmux and wait for the processes to stop. Start a fresh detached session from the repository root:

```bash
tmux new-session -d -s roastnode-dev -c /Users/d33pjs/Documents/developing/roastnode 'bin/dev'
```

Confirm the server is reachable at `http://localhost:3001` and that `.env` retains `BINDING=0.0.0.0` plus the configured `ROASTNODE_DEV_HOSTS` for LAN/DNS access.

- [ ] **Step 7: Perform visual and interaction QA**

Sign in to the local development app, open `/brews/new?method=espresso`, and verify at mobile and desktop widths:

- Every bean row remains compact and shows grams plus percentage.
- Exactly one green `Last used` label is visible.
- The warning is hidden for the last-used bean.
- Selecting a bean with a different reference shows both concise reference lines.
- Selecting a bean with the same reference hides the warning.
- Selecting a bean without a rated usable reference shows `No rated grinder reference yet`.
- The existing grind-setting and grinder inputs do not change when bean selection changes.
- Quick Drip uses only Quick Drip history.

- [ ] **Step 8: Review the final diff against the approved design**

Run:

```bash
git status --short
git diff --stat HEAD
git diff HEAD -- app/services/brew_grinder_reminder.rb app/controllers/brews_controller.rb app/helpers/brews_helper.rb app/views/brews app/javascript/controllers/brew_grinder_reminder_controller.js config/locales/en.yml docs/coffee-core.md docs/status.md
```

Check every global constraint at the top of this plan and confirm no unrelated user changes are included.

- [ ] **Step 9: Commit documentation and final adjustments**

```bash
git add docs/coffee-core.md docs/status.md
git commit -m "Document grinder switch guidance"
```

- [ ] **Step 10: Report the result with fresh evidence**

Report the implemented UI behavior, exact test/lint/security results, commit IDs, and the local URL. Mention any visual-QA limitation plainly instead of implying it was checked.
