# Roaster Suggestions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add search-while-type roaster suggestions to the bean form, matching existing active-workspace roaster names by substring.

**Architecture:** A collection endpoint on `BeansController` returns JSON suggestions from `current_workspace.beans`. The bean form wires the roaster input to a small Stimulus controller that fetches suggestions as the user types and fills the existing free-text field when an option is chosen. Tests cover the Rails contract, workspace isolation, rendered Stimulus wiring, and the controller source.

**Tech Stack:** Rails 8.1, Hotwire Turbo, Stimulus, Minitest, PostgreSQL `ILIKE`.

---

### Task 1: Roaster Suggestions Endpoint

**Files:**
- Modify: `config/routes.rb`
- Modify: `app/controllers/beans_controller.rb`
- Test: `test/controllers/beans_controller_test.rb`

- [ ] **Step 1: Write the failing endpoint tests**

Add these tests near the other `BeansControllerTest` form/action tests:

```ruby
test "roaster suggestions match substring across active workspace bean history" do
  sign_in_as(users(:one))
  workspace = workspaces(:household)
  workspace.beans.create!(
    name: "Wildbad Espresso",
    roaster_name: "Kaffeemanufaktur Bad Wildbad",
    bag_size_grams: 250,
    remaining_grams: 0,
    opened_on: Date.new(2026, 4, 1),
    archived_at: Time.current
  )

  get roaster_suggestions_beans_path, params: { q: "bad" }, as: :json

  assert_response :success
  suggestions = JSON.parse(response.body).fetch("suggestions")
  assert_includes suggestions, "Kaffeemanufaktur Bad Wildbad"
end

test "roaster suggestions stay scoped to active workspace and skip blanks" do
  sign_in_as(users(:one))
  workspaces(:household).beans.create!(
    name: "Blank Roaster Bag",
    roaster_name: "",
    bag_size_grams: 250,
    remaining_grams: 250,
    opened_on: Date.current
  )
  workspaces(:other_household).beans.create!(
    name: "Outside Bad Bag",
    roaster_name: "Bad Outside Roaster",
    bag_size_grams: 250,
    remaining_grams: 250,
    opened_on: Date.current
  )

  get roaster_suggestions_beans_path, params: { q: "bad" }, as: :json

  assert_response :success
  suggestions = JSON.parse(response.body).fetch("suggestions")
  assert_not_includes suggestions, "Bad Outside Roaster"
  assert_not_includes suggestions, ""
end

test "blank roaster suggestion query returns no suggestions" do
  sign_in_as(users(:one))

  get roaster_suggestions_beans_path, params: { q: " " }, as: :json

  assert_response :success
  assert_equal [], JSON.parse(response.body).fetch("suggestions")
end
```

- [ ] **Step 2: Run endpoint tests to verify they fail**

Run:

```bash
bin/rails test test/controllers/beans_controller_test.rb
```

Expected: FAIL because `roaster_suggestions_beans_path` is not defined.

- [ ] **Step 3: Add the collection route**

Change `config/routes.rb` inside `resources :beans` to include:

```ruby
resources :beans, only: %i[index new create show edit update destroy] do
  get :roaster_suggestions, on: :collection
  patch :finish, on: :member
  patch :close, on: :member
  patch :reopen, on: :member
  post :duplicate, on: :member
  resources :inventory_adjustments, only: %i[new create]
end
```

- [ ] **Step 4: Add the controller action**

Update `app/controllers/beans_controller.rb`:

```ruby
before_action :authorize_workspace_write!, only: %i[new create edit update finish close reopen duplicate destroy roaster_suggestions]
```

Add the action near `new`:

```ruby
def roaster_suggestions
  query = params[:q].to_s.strip
  suggestions = roaster_name_suggestions_for(query)

  render json: { suggestions: suggestions }
end
```

Add the private helper:

```ruby
def roaster_name_suggestions_for(query)
  return [] if query.blank?

  current_workspace.beans
    .where.not(roaster_name: [ nil, "" ])
    .where("roaster_name ILIKE ?", "%#{Bean.sanitize_sql_like(query)}%")
    .pluck(:roaster_name)
    .map { |name| name.to_s.strip }
    .reject(&:blank?)
    .uniq { |name| name.downcase }
    .sort_by(&:downcase)
    .first(8)
end
```

- [ ] **Step 5: Run endpoint tests to verify they pass**

Run:

```bash
bin/rails test test/controllers/beans_controller_test.rb
```

Expected: PASS.

- [ ] **Step 6: Commit endpoint work**

Run:

```bash
git add config/routes.rb app/controllers/beans_controller.rb test/controllers/beans_controller_test.rb
git commit -m "Add roaster suggestion endpoint"
```

### Task 2: Bean Form Autocomplete UI

**Files:**
- Modify: `app/views/beans/_form.html.erb`
- Create: `app/javascript/controllers/roaster_suggestions_controller.js`
- Test: `test/controllers/beans_controller_test.rb`
- Test: `test/assets/roaster_suggestions_controller_test.rb`

- [ ] **Step 1: Write failing form and asset tests**

Extend the existing `"new includes photo upload"` test in `test/controllers/beans_controller_test.rb` with:

```ruby
assert_select "[data-controller=roaster-suggestions][data-roaster-suggestions-url-value=?]", roaster_suggestions_beans_path(format: :json)
assert_select "input[name=?][data-roaster-suggestions-target=input][data-action*=?]", "bean[roaster_name]", "input->roaster-suggestions#search"
assert_select "[data-roaster-suggestions-target=list]"
```

Create `test/assets/roaster_suggestions_controller_test.rb`:

```ruby
require "test_helper"

class RoasterSuggestionsControllerTest < ActiveSupport::TestCase
  test "roaster suggestions controller fetches and applies suggestions" do
    controller = Rails.root.join("app/javascript/controllers/roaster_suggestions_controller.js")
    source = controller.read

    assert_includes source, "static targets = [ \"input\", \"list\" ]"
    assert_includes source, "static values = { url: String }"
    assert_includes source, "encodeURIComponent(query)"
    assert_includes source, "fetch(`${this.urlValue}?q=${encodeURIComponent(query)}`"
    assert_includes source, "data.suggestions || []"
    assert_includes source, "button.dataset.roasterName = name"
    assert_includes source, "this.inputTarget.value = event.currentTarget.dataset.roasterName"
    assert_includes source, "this.inputTarget.focus()"
  end
end
```

- [ ] **Step 2: Run UI tests to verify they fail**

Run:

```bash
bin/rails test test/controllers/beans_controller_test.rb test/assets/roaster_suggestions_controller_test.rb
```

Expected: FAIL because the rendered form has no roaster suggestions wiring and the new controller file does not exist.

- [ ] **Step 3: Wire the form**

In `app/views/beans/_form.html.erb`, replace the roaster text field block with:

```erb
<div data-controller="roaster-suggestions" data-roaster-suggestions-url-value="<%= roaster_suggestions_beans_path(format: :json) %>" class="relative">
  <%= form.label :roaster_name, t("beans.form.roaster"), class: label_class %>
  <%= form.text_field :roaster_name,
    autocomplete: "off",
    class: input_class,
    data: {
      roaster_suggestions_target: "input",
      action: "input->roaster-suggestions#search focus->roaster-suggestions#search blur->roaster-suggestions#blur"
    } %>
  <div data-roaster-suggestions-target="list" class="hidden absolute z-20 mt-2 max-h-56 w-full overflow-auto rounded-2xl border border-rn-line bg-rn-surface p-1 shadow-lg" role="listbox"></div>
</div>
```

- [ ] **Step 4: Add the Stimulus controller**

Create `app/javascript/controllers/roaster_suggestions_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "input", "list" ]
  static values = { url: String }

  connect() {
    this.abortController = null
    this.searchTimeout = null
  }

  disconnect() {
    this.abortController?.abort()
    clearTimeout(this.searchTimeout)
  }

  search() {
    const query = this.inputTarget.value.trim()

    clearTimeout(this.searchTimeout)
    if (query.length === 0) {
      this.clear()
      return
    }

    this.searchTimeout = setTimeout(() => this.fetchSuggestions(query), 150)
  }

  blur() {
    setTimeout(() => this.clear(), 100)
  }

  async fetchSuggestions(query) {
    this.abortController?.abort()
    this.abortController = new AbortController()

    const response = await fetch(`${this.urlValue}?q=${encodeURIComponent(query)}`, {
      headers: { Accept: "application/json" },
      signal: this.abortController.signal
    })

    if (!response.ok) return

    const data = await response.json()
    this.render(data.suggestions || [])
  }

  render(suggestions) {
    this.listTarget.innerHTML = ""

    if (suggestions.length === 0) {
      this.clear()
      return
    }

    suggestions.forEach((name) => {
      const button = document.createElement("button")
      button.type = "button"
      button.dataset.roasterName = name
      button.className = "block w-full rounded-xl px-3 py-2 text-left text-sm font-extrabold text-rn-ink hover:bg-[var(--rn-surface-muted)]"
      button.textContent = name
      button.addEventListener("mousedown", (event) => event.preventDefault())
      button.addEventListener("click", (event) => this.choose(event))
      this.listTarget.appendChild(button)
    })

    this.listTarget.classList.remove("hidden")
  }

  choose(event) {
    this.inputTarget.value = event.currentTarget.dataset.roasterName
    this.clear()
    this.inputTarget.focus()
  }

  clear() {
    this.listTarget.innerHTML = ""
    this.listTarget.classList.add("hidden")
  }
}
```

- [ ] **Step 5: Run UI tests to verify they pass**

Run:

```bash
bin/rails test test/controllers/beans_controller_test.rb test/assets/roaster_suggestions_controller_test.rb
```

Expected: PASS.

- [ ] **Step 6: Commit UI work**

Run:

```bash
git add app/views/beans/_form.html.erb app/javascript/controllers/roaster_suggestions_controller.js test/controllers/beans_controller_test.rb test/assets/roaster_suggestions_controller_test.rb
git commit -m "Add roaster autocomplete to bean form"
```

### Task 3: Documentation and Verification

**Files:**
- Modify: `docs/coffee-core.md`
- Modify: `docs/status.md`

- [ ] **Step 1: Update coffee docs**

In `docs/coffee-core.md`, add this bullet under `Included Now`:

```markdown
- Search-while-type roaster suggestions on bean entry, sourced from existing active-workspace bean history.
```

- [ ] **Step 2: Update status**

In `docs/status.md`, update the `Beans:` bullet to include:

```markdown
search-while-type roaster suggestions from existing workspace bean history
```

- [ ] **Step 3: Run focused tests**

Run:

```bash
bin/rails test test/controllers/beans_controller_test.rb test/assets/roaster_suggestions_controller_test.rb
```

Expected: PASS.

- [ ] **Step 4: Run broader test checks**

Run:

```bash
bin/rails test test/assets
bin/rails test test/controllers/beans_controller_test.rb
```

Expected: PASS.

- [ ] **Step 5: Start local server for browser verification**

Run:

```bash
bin/dev
```

Expected: Rails starts on host port `3001`, reachable from the local network.

- [ ] **Step 6: Verify in Browser**

Open `http://localhost:3001/beans/new`, sign in if needed, type `bad` into the Roaster field after a workspace bean with roaster `Kaffeemanufaktur Bad Wildbad` exists, and confirm the suggestion appears and fills the field when clicked.

- [ ] **Step 7: Commit docs**

Run:

```bash
git add docs/coffee-core.md docs/status.md
git commit -m "Document roaster suggestions"
```
