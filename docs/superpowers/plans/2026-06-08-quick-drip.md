# Quick Drip Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Quick Drip as Roastnode's first non-espresso brew method with method tabs, spoon-estimated inventory, brewer equipment, method-aware cards/history/analytics, exports, docs, and demo data.

**Architecture:** Keep `Brew#bean_weight_grams` as canonical consumed coffee grams and add typed Quick Drip fields plus source metadata. Add `brewer` as a third equipment kind, add per-user enabled method and spoon calibration preferences, and make the existing brew form/card surfaces dispatch by `Brew#method` instead of forking controllers. Public sharing, Quick Drip recipes, and Beanconqueror Quick Drip mapping stay out of v1.

**Tech Stack:** Rails 8.1, Active Record/PostgreSQL migrations, Hotwire/Turbo server-rendered ERB, Stimulus draft recovery, Minitest, Active Storage, Tailwind CSS.

---

## Scope Check

This plan implements one integrated product slice: Quick Drip private logging. It touches several Rails layers because brew method affects validation, inventory, UI, cards, analytics, exports, and docs. Public sharing, recipes, Beanconqueror Quick Drip import, water calibration, and professional filter methods are explicitly excluded so this remains one shippable feature.

## File Structure

- Modify `db/migrate/20260608150000_add_quick_drip_logging.rb` and `db/schema.rb`: add typed columns and indexes.
- Modify `app/models/brew.rb`: method enum, equipment associations, Quick Drip validations, inventory source calculation, retention scoping, correction behavior.
- Modify `app/models/bean.rb`: grind state constants/validation/default/duplication.
- Modify `app/models/equipment.rb`: `brewer` kind and history nullification.
- Modify `app/models/preparation_tool.rb`: Quick Drip method support/scope.
- Modify `app/models/user.rb`: enabled methods and grams-per-spoon preferences.
- Modify `app/controllers/brews_controller.rb`: method selection, defaulting, repeat, param whitelisting, method-specific tool/equipment loading.
- Modify `app/controllers/equipment_controller.rb`: kind preselection for Add Brewer.
- Modify `app/controllers/profiles_controller.rb`: permit new user preferences and normalize decimals.
- Modify `app/views/brews/_form.html.erb`: dispatch to method-specific partials and render method tabs.
- Create `app/views/brews/_method_tabs.html.erb`, `_espresso_form_fields.html.erb`, `_quick_drip_form_fields.html.erb`, `_quick_drip_hero_card.html.erb`.
- Modify `app/views/brews/_hero_card.html.erb`, `_compact_card.html.erb`, `show.html.erb`, `index.html.erb`, and dashboard surfaces to render method-aware facts.
- Modify `app/helpers/brews_helper.rb`: method labels, Quick Drip formatting, estimate display, taste labels, related brewer photos.
- Modify `app/services/workspace_statistics.rb`, `bean_statistics.rb`, `equipment_statistics.rb`, `grinder_setting_suggestion.rb`, and `open_bean_cockpit.rb` for method-aware analytics/default surfaces.
- Modify `app/services/workspace_export_builder.rb`, `workspace_csv_export_builder.rb`, `instance_readable_export_builder.rb`, `instance_backup_restorer.rb`.
- Modify `app/services/demo_data_seeder.rb`.
- Modify `config/locales/en.yml`.
- Modify docs listed in the design spec after implementation.
- Add/modify tests under `test/models`, `test/controllers`, `test/helpers`, `test/services`, fixtures, and docs checks.

---

### Task 1: Schema, Fixtures, And Core Model Constants

**Files:**
- Create: `db/migrate/20260608150000_add_quick_drip_logging.rb`
- Modify: `db/schema.rb`
- Modify: `app/models/brew.rb`
- Modify: `app/models/bean.rb`
- Modify: `app/models/equipment.rb`
- Modify: `app/models/preparation_tool.rb`
- Modify: `app/models/user.rb`
- Modify: `test/fixtures/equipment.yml`
- Modify: `test/fixtures/preparation_tools.yml`
- Modify: `test/fixtures/beans.yml`
- Test: `test/models/user_test.rb`
- Test: `test/models/bean_test.rb`
- Test: `test/models/equipment_test.rb`
- Test: `test/models/preparation_tool_test.rb`

- [ ] **Step 1: Write failing preference/model tests**

Add these tests to the matching model test files.

```ruby
# test/models/user_test.rb
test "enabled brew methods default to espresso and quick drip and require one method" do
  user = User.new(email_address: "methods@example.com", password: "secret123")

  assert_equal %w[espresso quick_drip], user.enabled_brew_methods

  user.enabled_brew_methods = [ "quick_drip", "unsupported", "", "quick_drip" ]
  assert_equal %w[quick_drip], user.enabled_brew_methods
  assert_predicate user, :valid?

  user.enabled_brew_methods = []
  assert_not_predicate user, :valid?
  assert_includes user.errors[:enabled_brew_methods], "must include at least one method"
end

test "grams per coffee spoon accepts blank or positive decimal values" do
  user = users(:one)

  user.grams_per_coffee_spoon = nil
  assert_predicate user, :valid?

  user.grams_per_coffee_spoon = 4.5
  assert_predicate user, :valid?

  user.grams_per_coffee_spoon = 0
  assert_not_predicate user, :valid?
end
```

```ruby
# test/models/bean_test.rb
test "grind state defaults to whole bean and supports pre ground" do
  bean = workspaces(:household).beans.new(
    name: "Ground filter",
    bag_size_grams: 250,
    remaining_grams: 250
  )

  assert_equal "whole_bean", bean.grind_state
  assert_predicate bean, :valid?

  bean.grind_state = "pre_ground"
  assert_predicate bean, :valid?

  bean.grind_state = "powder_cloud"
  assert_not_predicate bean, :valid?
end
```

```ruby
# test/models/equipment_test.rb
test "equipment supports brewer kind" do
  brewer = workspaces(:household).equipment.new(name: "Moccamaster", kind: "brewer")

  assert_predicate brewer, :valid?
  assert_predicate brewer, :brewer?
end
```

```ruby
# test/models/preparation_tool_test.rb
test "preparation tools support quick drip method" do
  tool = workspaces(:household).preparation_tools.new(name: "Paper filter", brew_method: "quick_drip")

  assert_predicate tool, :valid?
  tool.save!
  assert_includes workspaces(:household).preparation_tools.quick_drip, tool
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
bin/rails test test/models/user_test.rb test/models/bean_test.rb test/models/equipment_test.rb test/models/preparation_tool_test.rb
```

Expected: FAIL with missing columns/methods such as `enabled_brew_methods`, `grams_per_coffee_spoon`, `grind_state`, `brewer?`, and `quick_drip`.

- [ ] **Step 3: Add migration**

Create `db/migrate/20260608150000_add_quick_drip_logging.rb`:

```ruby
class AddQuickDripLogging < ActiveRecord::Migration[8.1]
  def change
    add_reference :brews, :brewer, foreign_key: { to_table: :equipment }, index: true
    add_column :brews, :machine_cups, :decimal, precision: 8, scale: 2
    add_column :brews, :coffee_spoons, :decimal, precision: 8, scale: 2
    add_column :brews, :grams_per_coffee_spoon, :decimal, precision: 8, scale: 2
    add_column :brews, :coffee_amount_source, :string, default: "measured", null: false

    add_column :beans, :grind_state, :string, default: "whole_bean", null: false

    add_column :users, :enabled_brew_methods, :jsonb, default: %w[espresso quick_drip], null: false
    add_column :users, :grams_per_coffee_spoon, :decimal, precision: 6, scale: 2
  end
end
```

- [ ] **Step 4: Run migration**

Run:

```bash
bin/rails db:migrate
```

Expected: migration succeeds and `db/schema.rb` includes the new columns.

- [ ] **Step 5: Add model constants and validations**

In `app/models/brew.rb`, update enums/associations:

```ruby
TYPICAL_GRAMS_PER_COFFEE_SPOON = BigDecimal("5")

enum :method, {
  espresso: "espresso",
  quick_drip: "quick_drip"
}

BREW_METHODS = %w[espresso quick_drip].freeze

enum :coffee_amount_source, {
  measured: "measured",
  estimated_spoons: "estimated_spoons"
}, prefix: :coffee_amount

belongs_to :brewer, class_name: "Equipment", optional: true
```

In `app/models/bean.rb`, add:

```ruby
GRIND_STATES = %w[whole_bean pre_ground].freeze

validates :grind_state, inclusion: { in: GRIND_STATES }

def pre_ground?
  grind_state == "pre_ground"
end
```

Include `grind_state:` in `duplicate_attributes`.

In `app/models/equipment.rb`, update the enum and associations:

```ruby
enum :kind, {
  grinder: "grinder",
  machine: "machine",
  brewer: "brewer"
}

has_many :brewer_brews, class_name: "Brew", foreign_key: :brewer_id, dependent: :nullify, inverse_of: :brewer
```

Update `destroy_with_history!`:

```ruby
grinder_brews.update_all(grinder_id: nil)
machine_brews.update_all(machine_id: nil)
brewer_brews.update_all(brewer_id: nil)
destroy!
```

In `app/models/preparation_tool.rb`, add:

```ruby
BREW_METHODS = %w[espresso quick_drip].freeze

scope :quick_drip, -> { where(brew_method: "quick_drip") }

validates :brew_method, inclusion: { in: BREW_METHODS }
```

In `app/models/user.rb`, add:

```ruby
ENABLED_BREW_METHODS = Brew::BREW_METHODS.freeze

validates :grams_per_coffee_spoon, numericality: { greater_than: 0 }, allow_nil: true
validate :enabled_brew_methods_supported

def enabled_brew_methods
  values = Array(self[:enabled_brew_methods]).presence || %w[espresso quick_drip]
  values & ENABLED_BREW_METHODS
end

def enabled_brew_methods=(values)
  self[:enabled_brew_methods] = Array(values).compact_blank.uniq & ENABLED_BREW_METHODS
end

private
  def enabled_brew_methods_supported
    errors.add(:enabled_brew_methods, "must include at least one method") if enabled_brew_methods.empty?
  end
```

- [ ] **Step 6: Update fixtures**

Add to `test/fixtures/equipment.yml`:

```yaml
household_brewer:
  workspace: household
  name: Moccamaster
  kind: brewer
  model: KBG Select
  notes: Main Quick Drip brewer.
```

Add to `test/fixtures/preparation_tools.yml`:

```yaml
paper_filter:
  workspace: household
  name: Paper filter
  brew_method: quick_drip
  active: true
  position: 40
  notes: Size 4 paper filter.
```

Add `grind_state: whole_bean` to existing bean fixtures and set one fixture to `pre_ground` if useful for Quick Drip controller tests.

- [ ] **Step 7: Run model tests**

Run:

```bash
bin/rails test test/models/user_test.rb test/models/bean_test.rb test/models/equipment_test.rb test/models/preparation_tool_test.rb
```

Expected: PASS.

- [ ] **Step 8: Commit**

Run:

```bash
git add db/migrate/20260608150000_add_quick_drip_logging.rb db/schema.rb app/models/brew.rb app/models/bean.rb app/models/equipment.rb app/models/preparation_tool.rb app/models/user.rb test/fixtures/equipment.yml test/fixtures/preparation_tools.yml test/fixtures/beans.yml test/models/user_test.rb test/models/bean_test.rb test/models/equipment_test.rb test/models/preparation_tool_test.rb
git commit -m "feat: add quick drip model foundations"
```

---

### Task 2: Brew Model Inventory And Method Validation

**Files:**
- Modify: `app/models/brew.rb`
- Test: `test/models/brew_test.rb`

- [ ] **Step 1: Write failing Brew model tests**

Add these tests to `test/models/brew_test.rb`:

```ruby
test "quick drip with spoons estimates consumed grams and records adjustment" do
  user = users(:one)
  user.update!(grams_per_coffee_spoon: 4.5)
  bean = beans(:second_open_household)

  brew = workspaces(:household).brews.create!(
    user:,
    method: "quick_drip",
    bean:,
    brewer: equipment(:household_brewer),
    machine_cups: 6,
    coffee_spoons: 5.5,
    taste_balance: "neutral"
  )

  assert_equal 24.75.to_d, brew.bean_weight_grams
  assert_equal 4.5.to_d, brew.grams_per_coffee_spoon
  assert_predicate brew, :coffee_amount_estimated_spoons?
  assert_equal(-24.75.to_d, brew.inventory_adjustment.delta_grams)
  assert_equal 196.25.to_d, bean.reload.remaining_grams
end

test "quick drip uses five gram fallback when user spoon preference is blank" do
  user = users(:one)
  user.update!(grams_per_coffee_spoon: nil)

  brew = workspaces(:household).brews.create!(
    user:,
    method: "quick_drip",
    bean: beans(:second_open_household),
    brewer: equipment(:household_brewer),
    machine_cups: 4,
    coffee_spoons: 6
  )

  assert_equal 30.to_d, brew.bean_weight_grams
  assert_equal 5.to_d, brew.grams_per_coffee_spoon
  assert_predicate brew, :coffee_amount_estimated_spoons?
end

test "quick drip measured grams override spoon estimate" do
  brew = workspaces(:household).brews.create!(
    user: users(:one),
    method: "quick_drip",
    bean: beans(:second_open_household),
    brewer: equipment(:household_brewer),
    machine_cups: 6,
    coffee_spoons: 6,
    grams_per_coffee_spoon: 5,
    bean_weight_grams: 28
  )

  assert_equal 28.to_d, brew.bean_weight_grams
  assert_predicate brew, :coffee_amount_measured?
end

test "quick drip requires brewer machine cups and a coffee amount source" do
  brew = workspaces(:household).brews.new(
    user: users(:one),
    method: "quick_drip",
    bean: beans(:second_open_household)
  )

  assert_not brew.valid?
  assert_includes brew.errors[:brewer], "must be selected"
  assert_includes brew.errors[:machine_cups], "must be greater than 0"
  assert_includes brew.errors[:base], "Quick Drip requires coffee spoons or measured ground coffee"
end

test "quick drip rejects espresso machine as brewer and espresso rejects brewer" do
  quick_drip = workspaces(:household).brews.new(
    user: users(:one),
    method: "quick_drip",
    bean: beans(:second_open_household),
    brewer: equipment(:household_machine),
    machine_cups: 6,
    coffee_spoons: 6
  )
  assert_not quick_drip.valid?
  assert_includes quick_drip.errors[:brewer], "must be a brewer"

  espresso = workspaces(:household).brews.new(
    user: users(:one),
    method: "espresso",
    bean: beans(:second_open_household),
    brewer: equipment(:household_brewer),
    bean_weight_grams: 18
  )
  assert_not espresso.valid?
  assert_includes espresso.errors[:brewer], "is only used for Quick Drip"
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
bin/rails test test/models/brew_test.rb
```

Expected: FAIL because Quick Drip inventory calculation and validations do not exist yet.

- [ ] **Step 3: Implement Brew calculation and validations**

In `app/models/brew.rb`, add callbacks before existing retention calculation:

```ruby
before_validation :set_defaults
before_validation :set_quick_drip_consumed_grams
before_validation :set_retention_marker
```

Add validations:

```ruby
validates :machine_cups, numericality: { greater_than: 0 }, allow_nil: true
validates :coffee_spoons, :grams_per_coffee_spoon, numericality: { greater_than: 0 }, allow_nil: true
validate :quick_drip_required_fields
validate :method_specific_equipment
```

Add private methods:

```ruby
def set_quick_drip_consumed_grams
  return unless quick_drip?

  if bean_weight_grams.present?
    self.coffee_amount_source = "measured"
    self.grams_per_coffee_spoon = spoon_grams_for_snapshot if coffee_spoons.present? && grams_per_coffee_spoon.blank?
    return
  end

  return if coffee_spoons.blank?

  spoon_grams = spoon_grams_for_snapshot
  self.grams_per_coffee_spoon = spoon_grams
  self.bean_weight_grams = (coffee_spoons.to_d * spoon_grams).round(2)
  self.coffee_amount_source = "estimated_spoons"
end

def spoon_grams_for_snapshot
  grams_per_coffee_spoon.presence || user&.grams_per_coffee_spoon.presence || TYPICAL_GRAMS_PER_COFFEE_SPOON
end

def calculated_retention_marker
  return "unknown" unless espresso?
  return "unknown" if bean_weight_grams.blank? || ground_weight_grams.blank?

  delta = ground_weight_grams - bean_weight_grams
  return "exchange" if delta > RETENTION_TOLERANCE_GRAMS
  return "retention" if delta < -RETENTION_TOLERANCE_GRAMS

  "normal"
end

def quick_drip_required_fields
  return unless quick_drip?

  errors.add(:brewer, "must be selected") if brewer.blank?
  errors.add(:machine_cups, "must be greater than 0") if machine_cups.blank? || machine_cups.to_d <= 0
  if bean_weight_grams.blank? && coffee_spoons.blank?
    errors.add(:base, "Quick Drip requires coffee spoons or measured ground coffee")
  end
end

def method_specific_equipment
  if quick_drip?
    errors.add(:brewer, "must be a brewer") if brewer.present? && !brewer.brewer?
    errors.add(:machine, "is only used for espresso") if machine.present?
  elsif espresso?
    errors.add(:brewer, "is only used for Quick Drip") if brewer.present?
  end
end
```

Fold `brewer` into workspace checking:

```ruby
[ grinder, machine, brewer ].compact.each do |item|
  errors.add(:base, "#{item.name} must belong to the workspace") if item.workspace_id != workspace_id
end
```

- [ ] **Step 4: Run model tests**

Run:

```bash
bin/rails test test/models/brew_test.rb
```

Expected: PASS.

- [ ] **Step 5: Commit**

Run:

```bash
git add app/models/brew.rb test/models/brew_test.rb
git commit -m "feat: estimate quick drip inventory"
```

---

### Task 3: Profile Preferences And Equipment/Tool Setup UI

**Files:**
- Modify: `app/controllers/profiles_controller.rb`
- Modify: `app/views/profiles/edit.html.erb`
- Modify: `app/controllers/equipment_controller.rb`
- Modify: `app/views/equipment/_form.html.erb`
- Modify: `app/views/preparation_tools/_form.html.erb`
- Modify: `config/locales/en.yml`
- Test: `test/controllers/profiles_controller_test.rb`
- Test: `test/controllers/equipment_controller_test.rb`
- Test: `test/controllers/preparation_tools_controller_test.rb`

- [ ] **Step 1: Write failing controller tests**

Add to `test/controllers/profiles_controller_test.rb`:

```ruby
test "profile renders and saves quick drip preferences" do
  sign_in_as(users(:one))

  get edit_profile_path

  assert_response :success
  assert_select "input[type=checkbox][name=?][value=?]", "user[enabled_brew_methods][]", "quick_drip"
  assert_select "input[type=text][name=?][inputmode=decimal]", "user[grams_per_coffee_spoon]"

  patch profile_path, params: {
    user: {
      display_name: "Jens",
      default_landing_screen: "log_espresso",
      enabled_brew_methods: [ "", "quick_drip" ],
      grams_per_coffee_spoon: "4,5"
    }
  }

  assert_redirected_to root_path
  users(:one).reload
  assert_equal %w[quick_drip], users(:one).enabled_brew_methods
  assert_equal 4.5.to_d, users(:one).grams_per_coffee_spoon
end

test "profile rejects disabling all brew methods" do
  sign_in_as(users(:one))

  patch profile_path, params: {
    user: {
      enabled_brew_methods: [ "" ],
      grams_per_coffee_spoon: "5"
    }
  }

  assert_response :unprocessable_entity
  assert_select ".text-red-800", text: /Enabled brew methods must include at least one method/
end
```

Add to `test/controllers/equipment_controller_test.rb`:

```ruby
test "new equipment can preselect brewer kind" do
  sign_in_as(users(:one))

  get new_equipment_path(kind: "brewer")

  assert_response :success
  assert_select "select[name=?] option[value=brewer][selected]", "equipment[kind]"
end
```

Add to `test/controllers/preparation_tools_controller_test.rb`:

```ruby
test "preparation tool form offers quick drip method" do
  sign_in_as(users(:one))

  get new_preparation_tool_path

  assert_response :success
  assert_select "select[name=?] option[value=quick_drip]", "preparation_tool[brew_method]"
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
bin/rails test test/controllers/profiles_controller_test.rb test/controllers/equipment_controller_test.rb test/controllers/preparation_tools_controller_test.rb
```

Expected: FAIL because forms and permitted params do not include the new fields/methods.

- [ ] **Step 3: Implement profile params and decimal parsing**

In `app/controllers/profiles_controller.rb`, add `:grams_per_coffee_spoon` to decimal normalization and permit `enabled_brew_methods: []`:

```ruby
def profile_params
  attributes = params.require(:user).permit(
    :display_name,
    :default_landing_screen,
    :theme,
    :number_format,
    :time_format,
    :default_brew_focus_field,
    :grams_per_coffee_spoon,
    :avatar,
    :public_banner,
    enabled_brew_methods: [],
    hidden_brew_field_names: []
  )

  normalize_decimal_attributes(attributes, :grams_per_coffee_spoon)
end
```

- [ ] **Step 4: Implement Profile form UI**

In `app/views/profiles/edit.html.erb`, render an error box near the top of the form:

```erb
<% if @user.errors.any? %>
  <div class="rounded-2xl border border-red-200 bg-red-50 p-4 text-sm font-bold text-red-800">
    <%= @user.errors.full_messages.to_sentence %>
  </div>
<% end %>
```

Add brew method checkboxes before hidden espresso fields:

```erb
<fieldset>
  <legend class="block text-sm font-medium text-stone-700"><%= t(".enabled_brew_methods_title") %></legend>
  <p class="mt-1 text-sm text-stone-600"><%= t(".enabled_brew_methods_help") %></p>
  <%= hidden_field_tag "user[enabled_brew_methods][]", "" %>
  <div class="mt-2 grid gap-2 sm:grid-cols-2">
    <% Brew::BREW_METHODS.each do |method| %>
      <label for="user_enabled_brew_method_<%= method %>" class="flex items-center gap-2 rounded-md border border-stone-200 px-3 py-2 text-sm text-stone-800">
        <%= check_box_tag "user[enabled_brew_methods][]",
          method,
          @user.enabled_brew_methods.include?(method),
          id: "user_enabled_brew_method_#{method}",
          class: "rounded border-stone-300 text-stone-950" %>
        <span><%= t("brews.methods.#{method}") %></span>
      </label>
    <% end %>
  </div>
</fieldset>

<div>
  <%= form.label :grams_per_coffee_spoon, t(".grams_per_coffee_spoon"), class: "block text-sm font-medium text-stone-700" %>
  <%= form.text_field :grams_per_coffee_spoon, inputmode: "decimal", class: "mt-1 w-full rounded-md border border-stone-300 px-3 py-2 text-stone-950 shadow-sm focus:border-stone-900 focus:outline-none" %>
  <p class="mt-1 text-sm text-stone-600"><%= t(".grams_per_coffee_spoon_help") %></p>
</div>
```

- [ ] **Step 5: Implement Brewer preselection and tool method options**

In `app/controllers/equipment_controller.rb`:

```ruby
def new
  @equipment = current_workspace.equipment.new(kind: params[:kind].presence_in(Equipment.kinds.keys) || "grinder")
  prepare_record_links(@equipment)
end
```

In `app/views/preparation_tools/_form.html.erb`, change method select to:

```erb
<%= form.select :brew_method,
  PreparationTool::BREW_METHODS.map { |method| [ t("brews.methods.#{method}"), method ] },
  {},
  class: input_class %>
```

- [ ] **Step 6: Add locale strings**

In `config/locales/en.yml`, add:

```yaml
brews:
  methods:
    espresso: "Espresso"
    quick_drip: "Quick Drip"
profiles:
  edit:
    enabled_brew_methods_title: "Enabled brew methods"
    enabled_brew_methods_help: "Controls which tabs appear on your Log screen. Historical brews stay visible."
    grams_per_coffee_spoon: "Grams per coffee spoon"
    grams_per_coffee_spoon_help: "Used to estimate Quick Drip inventory when you log spoons instead of grams. Default: 5g."
```

Also change the existing landing screen label for `log_espresso` to "Log".

- [ ] **Step 7: Run preference/setup tests**

Run:

```bash
bin/rails test test/controllers/profiles_controller_test.rb test/controllers/equipment_controller_test.rb test/controllers/preparation_tools_controller_test.rb
```

Expected: PASS.

- [ ] **Step 8: Commit**

Run:

```bash
git add app/controllers/profiles_controller.rb app/views/profiles/edit.html.erb app/controllers/equipment_controller.rb app/views/preparation_tools/_form.html.erb config/locales/en.yml test/controllers/profiles_controller_test.rb test/controllers/equipment_controller_test.rb test/controllers/preparation_tools_controller_test.rb
git commit -m "feat: add quick drip profile preferences"
```

---

### Task 4: Method-Aware Log Screen And Quick Drip Create Flow

**Files:**
- Modify: `app/controllers/brews_controller.rb`
- Modify: `app/views/brews/new.html.erb`
- Modify: `app/views/brews/edit.html.erb`
- Modify: `app/views/brews/_form.html.erb`
- Create: `app/views/brews/_method_tabs.html.erb`
- Create: `app/views/brews/_espresso_form_fields.html.erb`
- Create: `app/views/brews/_quick_drip_form_fields.html.erb`
- Modify: `config/locales/en.yml`
- Test: `test/controllers/brews_controller_test.rb`

- [ ] **Step 1: Write failing Log screen tests**

Add to `test/controllers/brews_controller_test.rb`:

```ruby
test "new renders stable method tabs and defaults to last enabled method" do
  user = users(:one)
  sign_in_as(user)

  get new_brew_path(method: "quick_drip")

  assert_response :success
  assert_select "a[href=?]", new_brew_path(method: "espresso"), text: "Espresso"
  assert_select "a[href=?][aria-current=page]", new_brew_path(method: "quick_drip"), text: "Quick Drip"
end

test "disabled method tab is hidden but history remains visible" do
  users(:one).update!(enabled_brew_methods: %w[espresso])
  sign_in_as(users(:one))

  get new_brew_path(method: "quick_drip")

  assert_response :success
  assert_select "a[href=?]", new_brew_path(method: "quick_drip"), count: 0
  assert_select "a[href=?][aria-current=page]", new_brew_path(method: "espresso")

  get brew_path(brews(:morning_espresso))
  assert_response :success
end

test "quick drip new redirects to add brewer when no brewer exists" do
  workspaces(:household).equipment.brewer.destroy_all
  sign_in_as(users(:one))

  get new_brew_path(method: "quick_drip")

  assert_redirected_to new_equipment_path(kind: "brewer")
  assert_equal I18n.t("brews.new.needs_brewer"), flash[:alert]
end

test "quick drip new renders batch fields and quick drip tools" do
  sign_in_as(users(:one))

  get new_brew_path(method: "quick_drip")

  assert_response :success
  assert_select "input[name=?][autofocus]", "brew[machine_cups]"
  assert_select "input[type=text][inputmode=decimal][name=?]", "brew[machine_cups]"
  assert_select "input[type=text][inputmode=decimal][name=?]", "brew[coffee_spoons]"
  assert_select "input[type=text][inputmode=decimal][name=?]", "brew[bean_weight_grams]"
  assert_select "input[type=text][inputmode=decimal][name=?]", "brew[beverage_grams]"
  assert_select "input[type=radio][name=?][value=?][checked]", "brew[brewer_id]", equipment(:household_brewer).id.to_s
  assert_select "input[type=checkbox][name=?][value=?]", "brew[preparation_tool_ids][]", preparation_tools(:paper_filter).id.to_s
  assert_select "input[type=checkbox][name=?][value=?]", "brew[preparation_tool_ids][]", preparation_tools(:wdt).id.to_s, count: 0
  assert_select "input[name=?]", "brew[brew_temperature_celsius]", count: 0
  assert_select "input[name=?]", "brew[preinfusion_seconds]", count: 0
  assert_select "input[name=?]", "brew[first_drip_seconds]", count: 0
  assert_select "input[name=?]", "brew[channeling]", count: 0
end

test "member can create spoon estimated quick drip brew with comma decimals" do
  user = users(:one)
  user.update!(grams_per_coffee_spoon: 4.5)
  sign_in_as(user)
  bean = beans(:second_open_household)

  assert_difference -> { workspaces(:household).brews.quick_drip.count }, 1 do
    post brews_path, params: {
      brew: {
        method: "quick_drip",
        bean_id: bean.id,
        brewer_id: equipment(:household_brewer).id,
        machine_cups: "6,5",
        coffee_spoons: "5,5",
        beverage_grams: "900,0",
        total_time_seconds: "320",
        taste_balance: "neutral",
        rating: "4",
        preparation_tool_ids: [ preparation_tools(:paper_filter).id, preparation_tools(:wdt).id ]
      }
    }
  end

  brew = workspaces(:household).brews.order(:created_at).last
  assert_redirected_to brew_path(brew)
  assert_equal 6.5.to_d, brew.machine_cups
  assert_equal 5.5.to_d, brew.coffee_spoons
  assert_equal 24.75.to_d, brew.bean_weight_grams
  assert_equal "estimated_spoons", brew.coffee_amount_source
  assert_equal [ "Paper filter" ], brew.brew_preparation_tools.order(:position).pluck(:tool_name)
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
bin/rails test test/controllers/brews_controller_test.rb
```

Expected: FAIL because method tabs, Quick Drip form, params, and create handling are missing.

- [ ] **Step 3: Refactor form partial without behavior change**

Move the current body inside `form_with` from `app/views/brews/_form.html.erb` into `app/views/brews/_espresso_form_fields.html.erb`. Keep the existing locals:

```erb
<%= render "brews/espresso_form_fields",
  form:,
  brew:,
  autofocus_field:,
  hidden_brew_fields:,
  hide_brew_field: %>
```

Run:

```bash
bin/rails test test/controllers/brews_controller_test.rb
```

Expected: existing espresso tests still PASS or fail only on new Quick Drip tests.

- [ ] **Step 4: Add method tabs partial**

Create `app/views/brews/_method_tabs.html.erb`:

```erb
<nav data-testid="brew-method-tabs" class="flex gap-2 overflow-x-auto rounded-2xl border border-rn-line bg-rn-surface p-1">
  <% Current.user.enabled_brew_methods.each do |method| %>
    <% active = method == selected_method %>
    <%= link_to t("brews.methods.#{method}"),
      new_brew_path(method: method),
      aria: (active ? { current: "page" } : {}),
      class: [
        "whitespace-nowrap rounded-xl px-4 py-2 text-sm font-extrabold",
        active ? "bg-rn-ink text-white" : "text-rn-muted hover:bg-[var(--rn-surface-muted)]"
      ].join(" ") %>
  <% end %>
</nav>
```

Render it above the form in `app/views/brews/new.html.erb`.

- [ ] **Step 5: Add controller method selection and option loading**

In `app/controllers/brews_controller.rb`, add:

```ruby
before_action :set_selected_method, only: %i[new create]

def set_selected_method
  requested = params[:method].presence || params.dig(:brew, :method).presence
  @selected_method = requested.presence_in(Current.user.enabled_brew_methods) || default_log_method
end

def default_log_method
  last_method = current_workspace.brews.where(user: Current.user, method: Current.user.enabled_brew_methods).order(occurred_at: :desc, created_at: :desc).pick(:method)
  last_method.presence || Current.user.enabled_brew_methods.first
end
```

Update `new` to pass method into defaults:

```ruby
default_attributes = default_brew_attributes(method: @selected_method)
@brew = current_workspace.brews.new(default_attributes.merge(method: @selected_method))
```

Split option loading:

```ruby
def load_form_options(selected_bean: nil, selected_grinder: nil, selected_machine: nil, selected_brewer: nil)
  @beans = current_workspace.beans.open.includes(:primary_photo_record, photos_attachments: :blob).to_a
  @beans << selected_bean if selected_bean && @beans.exclude?(selected_bean)
  sort_beans_for_method!
  @grinders = equipment_options(kind: :grinder, selected_equipment: selected_grinder)
  @machines = equipment_options(kind: :machine, selected_equipment: selected_machine)
  @brewers = equipment_options(kind: :brewer, selected_equipment: selected_brewer)
  @preparation_tools = current_workspace.preparation_tools.active.where(brew_method: @selected_method).ordered.includes(:primary_photo_record, photos_attachments: :blob)
end
```

Add a `sort_beans_for_method!` helper that puts filter/omni first for Quick Drip and preserves existing opened-date order for espresso.

- [ ] **Step 6: Add Quick Drip form partial**

Create `app/views/brews/_quick_drip_form_fields.html.erb` with sections matching the design. Include these field names:

```erb
<%= form.hidden_field :method, value: "quick_drip" %>

<section data-testid="brew-form-section" data-section="bean">...</section>

<section data-testid="brew-form-section" data-section="batch">
  <%= form.text_field :machine_cups, inputmode: "decimal", autofocus: true, ... %>
  <%= form.text_field :coffee_spoons, inputmode: "decimal", ... %>
  <%= form.text_field :bean_weight_grams, inputmode: "decimal", ... %>
  <%= form.text_field :beverage_grams, inputmode: "decimal", ... %>
  <%= form.number_field :total_time_seconds, inputmode: "numeric", ... %>
</section>

<section data-testid="brew-form-section" data-section="setup">
  brewer radio buttons named `brew[brewer_id]`
  optional grinder radio buttons named `brew[grinder_id]`
  grind setting text input named `brew[grind_setting]`
  Quick Drip preparation tool checkboxes
</section>
```

Use the same image-backed selector pattern as the espresso form. Do not render temperature, preinfusion, first drip, or channeling.

- [ ] **Step 7: Permit Quick Drip params and decimals**

Add to `DECIMAL_BREW_FIELDS`:

```ruby
machine_cups
coffee_spoons
grams_per_coffee_spoon
```

Permit:

```ruby
:method,
:brewer_id,
:machine_cups,
:coffee_spoons,
:grams_per_coffee_spoon,
```

Keep `bean_weight_grams` as the optional Ground coffee field.

- [ ] **Step 8: Implement Quick Drip defaults and redirects**

Add Quick Drip default helpers in `BrewsController`:

```ruby
def default_brew_attributes(method:)
  return repeat_brew_attributes(@repeat_source_brew) if @repeat_source_brew
  return default_quick_drip_attributes if method == "quick_drip"

  default_espresso_attributes
end

def default_quick_drip_attributes
  last_brew = last_brew_for_defaults(method: "quick_drip")
  bean = default_quick_drip_bean(last_brew)
  return { bean: nil } unless bean
  return { bean:, brewer: nil } if @brewers.empty?

  @selected_preparation_tools = default_preparation_tools(last_brew, method: "quick_drip")
  {
    bean:,
    brewer: default_brewer(last_brew),
    grinder: bean.pre_ground? ? nil : default_equipment(last_brew&.grinder),
    occurred_at: Time.current,
    machine_cups: last_brew&.machine_cups,
    coffee_spoons: last_brew&.coffee_spoons,
    grind_setting: last_brew&.grind_setting
  }
end
```

If default attributes have no bean, redirect to `new_bean_path`. If selected method is Quick Drip and no active brewer exists, redirect to `new_equipment_path(kind: "brewer")` with `brews.new.needs_brewer`.

- [ ] **Step 9: Method-specific draft keys**

Change `brew_draft_storage_key` to:

```ruby
"roastnode:brew:new:#{@selected_method}:#{current_workspace.id}:#{Current.user.id}"
```

Keep repeat key but include source brew id as today. Add method if useful:

```ruby
"roastnode:brew:repeat:#{source_brew.method}:#{current_workspace.id}:#{Current.user.id}:#{source_brew.id}"
```

- [ ] **Step 10: Run controller tests**

Run:

```bash
bin/rails test test/controllers/brews_controller_test.rb
```

Expected: PASS.

- [ ] **Step 11: Commit**

Run:

```bash
git add app/controllers/brews_controller.rb app/views/brews/new.html.erb app/views/brews/edit.html.erb app/views/brews/_form.html.erb app/views/brews/_method_tabs.html.erb app/views/brews/_espresso_form_fields.html.erb app/views/brews/_quick_drip_form_fields.html.erb config/locales/en.yml test/controllers/brews_controller_test.rb
git commit -m "feat: add quick drip log form"
```

---

### Task 5: Method-Aware Repeat, Edit, Taste, And Detail Views

**Files:**
- Modify: `app/controllers/brews_controller.rb`
- Modify: `app/views/brews/show.html.erb`
- Modify: `app/views/brews/_taste_balance_choices.html.erb`
- Modify: `app/helpers/brews_helper.rb`
- Modify: `config/locales/en.yml`
- Test: `test/controllers/brews_controller_test.rb`
- Test: `test/helpers/brews_helper_test.rb`

- [ ] **Step 1: Write failing tests**

Add to `test/controllers/brews_controller_test.rb`:

```ruby
test "quick drip repeat copies method target fields and keeps subjective fields fresh" do
  source = workspaces(:household).brews.create!(
    user: users(:one),
    method: "quick_drip",
    bean: beans(:second_open_household),
    brewer: equipment(:household_brewer),
    grinder: equipment(:household_grinder),
    machine_cups: 6,
    coffee_spoons: 6,
    bean_weight_grams: 31,
    beverage_grams: 900,
    total_time_seconds: 320,
    grind_setting: "filter 8",
    taste_balance: "bitter",
    rating: 5,
    notes: "Do not copy."
  )
  source.snapshot_preparation_tools!([ preparation_tools(:paper_filter) ])
  sign_in_as(users(:one))

  get new_brew_path(repeat_brew_id: source.id)

  assert_response :success
  assert_select "input[type=hidden][name=?][value=?]", "brew[method]", "quick_drip"
  assert_select "input[name=?][value=?]", "brew[machine_cups]", "6.0"
  assert_select "input[name=?][value=?]", "brew[coffee_spoons]", "6.0"
  assert_select "input[name=?][value=?]", "brew[bean_weight_grams]", "31.0"
  assert_select "input[name=?][value=?]", "brew[beverage_grams]", "900.0"
  assert_select "input[name=?][value=?]", "brew[total_time_seconds]", "320"
  assert_select "input[name=?][value=?]", "brew[grind_setting]", "filter 8"
  assert_select "input[type=checkbox][name=?][value=?][checked]", "brew[preparation_tool_ids][]", preparation_tools(:paper_filter).id.to_s
  assert_select "input[type=radio][name=?][value=?][checked]", "brew[taste_balance]", "bitter", count: 0
  assert_select "input[type=radio][name=?][value=?][checked]", "brew[rating]", "5", count: 0
  assert_select "textarea[name=?]", "brew[notes]", text: ""
end

test "quick drip detail shows estimate calculation and brewer" do
  brew = workspaces(:household).brews.create!(
    user: users(:one),
    method: "quick_drip",
    bean: beans(:second_open_household),
    brewer: equipment(:household_brewer),
    machine_cups: 6,
    coffee_spoons: 6,
    grams_per_coffee_spoon: 5,
    taste_balance: "sour"
  )
  sign_in_as(users(:one))

  get brew_path(brew)

  assert_response :success
  assert_select "[data-testid=brew-detail-brewer] a[href=?]", equipment_path(equipment(:household_brewer)), text: "Moccamaster"
  assert_select "[data-testid=brew-detail-machine-cups]", "6"
  assert_select "[data-testid=brew-detail-estimate]", "6 spoons x 5g = ~30g"
  assert_select "[data-testid=brew-detail-taste]", "Weak"
end
```

Add helper tests in `test/helpers/brews_helper_test.rb`:

```ruby
test "quick drip estimate display uses tilde for spoon estimates" do
  brew = brews(:morning_espresso)
  brew.method = "quick_drip"
  brew.bean_weight_grams = 30
  brew.coffee_amount_source = "estimated_spoons"

  assert_equal "~30g", quick_drip_consumed_grams(brew)
end

test "quick drip taste labels use weak balanced harsh" do
  assert_equal "Weak", brew_taste_label("sour", method: "quick_drip")
  assert_equal "Balanced", brew_taste_label("neutral", method: "quick_drip")
  assert_equal "Harsh", brew_taste_label("bitter", method: "quick_drip")
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
bin/rails test test/controllers/brews_controller_test.rb test/helpers/brews_helper_test.rb
```

Expected: FAIL due missing method-aware repeat/detail helpers.

- [ ] **Step 3: Implement repeat dispatch**

In `BrewsController#repeat_brew_attributes`, dispatch by source method:

```ruby
def repeat_brew_attributes(source_brew)
  return repeat_quick_drip_attributes(source_brew) if source_brew.quick_drip?

  repeat_espresso_attributes(source_brew)
end
```

Add Quick Drip copy method:

```ruby
def repeat_quick_drip_attributes(source_brew)
  bean = repeat_brew_bean(source_brew.bean)
  return { bean: nil } unless bean

  @selected_method = "quick_drip"
  @selected_preparation_tools = default_preparation_tools(source_brew, method: "quick_drip")
  {
    method: "quick_drip",
    bean:,
    occurred_at: Time.current,
    brewer: default_equipment(source_brew.brewer),
    grinder: default_equipment(source_brew.grinder),
    machine_cups: source_brew.machine_cups,
    coffee_spoons: source_brew.coffee_spoons,
    bean_weight_grams: source_brew.bean_weight_grams,
    beverage_grams: source_brew.beverage_grams,
    total_time_seconds: source_brew.total_time_seconds,
    grind_setting: source_brew.grind_setting
  }
end
```

- [ ] **Step 4: Add helper formatting**

In `app/helpers/brews_helper.rb`, add:

```ruby
def quick_drip_consumed_grams(brew)
  grams = brew_card_grams(brew.bean_weight_grams)
  brew.coffee_amount_estimated_spoons? ? "~#{grams}" : grams
end

def quick_drip_estimate_calculation(brew)
  return unless brew.coffee_spoons.present? && brew.grams_per_coffee_spoon.present?

  t(
    "brews.show.quick_drip_estimate",
    spoons: profile_number(brew.coffee_spoons, precision: 2),
    grams_per_spoon: profile_grams(brew.grams_per_coffee_spoon),
    grams: quick_drip_consumed_grams(brew)
  )
end

def brew_taste_label(value, method: "espresso")
  return t("brews.show.unknown") if value.blank? || value == "unknown"

  if method == "quick_drip"
    t("brews.taste.quick_drip.#{value}", default: value.humanize)
  else
    value.humanize
  end
end
```

- [ ] **Step 5: Make taste choices method-aware**

Update `_taste_balance_choices.html.erb` to accept `method:` local:

```erb
<% method = local_assigns.fetch(:method, form.object.method || "espresso") %>
<% values = method == "quick_drip" ? %w[unknown sour neutral bitter] : Brew.taste_balances.keys %>
```

Use `brew_taste_label(value, method:)` for labels.

- [ ] **Step 6: Render Quick Drip detail fields**

In `app/views/brews/show.html.erb`, branch inside the details definition list:

```erb
<% if @brew.quick_drip? %>
  <dt class="text-xs font-bold uppercase text-stone-500"><%= t(".brewer") %></dt>
  <dd data-testid="brew-detail-brewer" class="mt-1 text-sm font-semibold text-stone-950">
    <%= link_to @brew.brewer.name, equipment_path(@brew.brewer), class: "text-stone-950 underline decoration-stone-300 underline-offset-2 hover:decoration-stone-950" %>
  </dd>
  <dt class="text-xs font-bold uppercase text-stone-500"><%= t(".machine_cups") %></dt>
  <dd data-testid="brew-detail-machine-cups" class="mt-1 text-sm font-semibold text-stone-950"><%= profile_number(@brew.machine_cups, precision: 2) %></dd>
  <% if quick_drip_estimate_calculation(@brew).present? %>
    <dt class="text-xs font-bold uppercase text-stone-500"><%= t(".coffee_estimate") %></dt>
    <dd data-testid="brew-detail-estimate" class="mt-1 text-sm font-semibold text-stone-950"><%= quick_drip_estimate_calculation(@brew) %></dd>
  <% end %>
<% else %>
  existing espresso detail fields
<% end %>
```

- [ ] **Step 7: Run tests**

Run:

```bash
bin/rails test test/controllers/brews_controller_test.rb test/helpers/brews_helper_test.rb
```

Expected: PASS.

- [ ] **Step 8: Commit**

Run:

```bash
git add app/controllers/brews_controller.rb app/views/brews/show.html.erb app/views/brews/_taste_balance_choices.html.erb app/helpers/brews_helper.rb config/locales/en.yml test/controllers/brews_controller_test.rb test/helpers/brews_helper_test.rb
git commit -m "feat: make brew detail method aware"
```

---

### Task 6: Quick Drip Hero Card, Compact Cards, Dashboard, And Public Sharing Deferral

**Files:**
- Modify: `app/views/brews/_hero_card.html.erb`
- Create: `app/views/brews/_espresso_hero_card.html.erb`
- Create: `app/views/brews/_quick_drip_hero_card.html.erb`
- Modify: `app/views/brews/_compact_card.html.erb`
- Modify: `app/views/brews/index.html.erb`
- Modify: `app/views/home/index.html.erb`
- Modify: `app/controllers/public_brew_shares_controller.rb`
- Modify: `config/locales/en.yml`
- Test: `test/controllers/brews_controller_test.rb`
- Test: `test/controllers/home_controller_test.rb`
- Test: `test/controllers/public_brew_shares_controller_test.rb`

- [ ] **Step 1: Write failing card/dashboard tests**

Add to `test/controllers/brews_controller_test.rb`:

```ruby
test "quick drip hero card renders metric first batch facts without espresso chart" do
  brew = workspaces(:household).brews.create!(
    user: users(:one),
    method: "quick_drip",
    bean: beans(:second_open_household),
    brewer: equipment(:household_brewer),
    machine_cups: 6,
    coffee_spoons: 6,
    grams_per_coffee_spoon: 5,
    taste_balance: "neutral",
    rating: 4,
    total_time_seconds: 320
  )
  sign_in_as(users(:one))

  get brew_path(brew)

  assert_response :success
  assert_select "[data-testid=brew-hero-card][data-method=quick_drip]"
  assert_select "[data-testid=brew-method]", "Quick Drip"
  assert_select "[data-testid=quick-drip-machine-cups]", "6"
  assert_select "[data-testid=quick-drip-coffee]", "6 spoons"
  assert_select "[data-testid=quick-drip-consumed]", "~30g"
  assert_select "[data-testid=quick-drip-duration]", "320s"
  assert_select "[data-testid=brew-chart-grid]", count: 0
  assert_select "[data-testid=brew-retention-card]", count: 0
end

test "compact brew card is method aware for quick drip" do
  brew = workspaces(:household).brews.create!(
    user: users(:one),
    method: "quick_drip",
    bean: beans(:second_open_household),
    brewer: equipment(:household_brewer),
    machine_cups: 6,
    coffee_spoons: 6
  )
  sign_in_as(users(:one))

  get brews_path

  assert_response :success
  assert_select "[data-testid=brew-compact-card][data-method=quick_drip]", text: /Quick Drip/
  assert_select "[data-testid=brew-compact-card][data-method=quick_drip]", text: /6 cups/
  assert_select "[data-testid=brew-compact-card][data-method=quick_drip]", text: /Moccamaster/
end
```

Add to `test/controllers/public_brew_shares_controller_test.rb`:

```ruby
test "quick drip public sharing is not exposed in v1" do
  brew = workspaces(:household).brews.create!(
    user: users(:one),
    method: "quick_drip",
    bean: beans(:second_open_household),
    brewer: equipment(:household_brewer),
    machine_cups: 6,
    coffee_spoons: 6
  )
  sign_in_as(users(:one))

  get brew_path(brew)

  assert_response :success
  assert_select "a[href=?]", new_brew_public_brew_share_path(brew), count: 0
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
bin/rails test test/controllers/brews_controller_test.rb test/controllers/home_controller_test.rb test/controllers/public_brew_shares_controller_test.rb
```

Expected: FAIL because card rendering and share deferral are missing.

- [ ] **Step 3: Split espresso card and add dispatcher**

Move current `app/views/brews/_hero_card.html.erb` contents to `app/views/brews/_espresso_hero_card.html.erb`.

Replace `app/views/brews/_hero_card.html.erb` with:

```erb
<% if brew.quick_drip? %>
  <%= render "brews/quick_drip_hero_card", brew:, card_class:, compact:, chart_id: %>
<% else %>
  <%= render "brews/espresso_hero_card", brew:, card_class:, compact:, chart_id: %>
<% end %>
```

- [ ] **Step 4: Add Quick Drip hero card**

Create `app/views/brews/_quick_drip_hero_card.html.erb` using the existing card classes. Include these data test IDs:

```erb
<article data-testid="brew-hero-card" data-method="quick_drip" class="relative overflow-hidden rounded-lg bg-stone-950 text-stone-50 shadow-sm <%= card_class %>">
  <div class="bg-stone-950 p-5">
    <div data-testid="brew-card-header" class="flex flex-nowrap items-center gap-1 overflow-hidden sm:gap-2">
      <span data-testid="brew-timestamp" class="..."><%= brew_card_timestamp(brew) %></span>
      <span data-testid="brew-method" class="..."><%= t("brews.methods.quick_drip") %></span>
      ...
    </div>
    <div data-testid="brew-metrics" class="mt-4 grid grid-cols-2 gap-2 sm:grid-cols-4">
      <div><p><%= t("brews.show.machine_cups") %></p><p data-testid="quick-drip-machine-cups"><%= profile_number(brew.machine_cups, precision: 2) %></p></div>
      <div><p><%= t("brews.show.coffee") %></p><p data-testid="quick-drip-coffee"><%= quick_drip_coffee_amount_label(brew) %></p></div>
      <div><p><%= t("brews.show.consumed") %></p><p data-testid="quick-drip-consumed"><%= quick_drip_consumed_grams(brew) %></p></div>
      <div><p><%= t("brews.show.time") %></p><p data-testid="quick-drip-duration"><%= brew_card_seconds(brew.total_time_seconds) %></p></div>
    </div>
  </div>
  <div class="bg-stone-900 px-5 py-3">
    brewer/grinder/tool pills
  </div>
</article>
```

- [ ] **Step 5: Add compact card method branches**

In `app/views/brews/_compact_card.html.erb`, add `data-method="<%= brew.method %>"` and branch metric labels:

```erb
<% if brew.quick_drip? %>
  <p><%= t("brews.methods.quick_drip") %></p>
  <p><%= t("brews.compact.quick_drip_summary", cups: profile_number(brew.machine_cups, precision: 2), coffee: quick_drip_consumed_grams(brew)) %></p>
  <p><%= t("brews.show.brewer") %>: <%= brew.brewer&.name || t("brews.show.unknown") %></p>
<% else %>
  existing espresso compact metrics
<% end %>
```

- [ ] **Step 6: Hide public share actions for Quick Drip**

In `app/views/brews/show.html.erb`, wrap public share action links:

```erb
<% if @brew.espresso? %>
  existing public share action
<% end %>
```

In `PublicBrewSharesController`, add an espresso guard for `new`, `create`, `edit`, and `update`:

```ruby
return redirect_to @brew, alert: t("public_brew_shares.unsupported_method") unless @brew.espresso?
```

- [ ] **Step 7: Run card/dashboard/share tests**

Run:

```bash
bin/rails test test/controllers/brews_controller_test.rb test/controllers/home_controller_test.rb test/controllers/public_brew_shares_controller_test.rb
```

Expected: PASS.

- [ ] **Step 8: Commit**

Run:

```bash
git add app/views/brews/_hero_card.html.erb app/views/brews/_espresso_hero_card.html.erb app/views/brews/_quick_drip_hero_card.html.erb app/views/brews/_compact_card.html.erb app/views/brews/index.html.erb app/views/home/index.html.erb app/controllers/public_brew_shares_controller.rb config/locales/en.yml test/controllers/brews_controller_test.rb test/controllers/home_controller_test.rb test/controllers/public_brew_shares_controller_test.rb
git commit -m "feat: render quick drip brew cards"
```

---

### Task 7: Analytics, Equipment Statistics, And Espresso-Specific Exclusions

**Files:**
- Modify: `app/services/workspace_statistics.rb`
- Modify: `app/services/bean_statistics.rb`
- Modify: `app/services/equipment_statistics.rb`
- Modify: `app/services/grinder_setting_suggestion.rb`
- Modify: `app/views/equipment/show.html.erb`
- Modify: `config/locales/en.yml`
- Test: `test/services/workspace_statistics_test.rb`
- Test: `test/services/bean_statistics_test.rb`
- Test: `test/services/equipment_statistics_test.rb`
- Test: `test/services/grinder_setting_suggestion_test.rb`

- [ ] **Step 1: Write failing analytics tests**

Add representative tests:

```ruby
# test/services/workspace_statistics_test.rb
test "includes quick drip in shared totals but excludes from espresso-specific channeling rate" do
  workspaces(:household).brews.create!(
    user: users(:one),
    method: "quick_drip",
    bean: beans(:second_open_household),
    brewer: equipment(:household_brewer),
    machine_cups: 6,
    coffee_spoons: 6,
    occurred_at: Time.zone.local(2026, 5, 26, 9, 0, 0)
  )

  stats = WorkspaceStatistics.new(
    workspace: workspaces(:household),
    start_date: Date.new(2026, 5, 26),
    end_date: Date.new(2026, 5, 26)
  ).call

  assert_equal 2, stats[:totals][:total_brews]
  assert_equal 48.to_d, stats[:totals][:total_bean_weight_grams]
end
```

```ruby
# test/services/equipment_statistics_test.rb
test "builds brewer usage analytics from quick drip brews" do
  brewer = equipment(:household_brewer)
  brew = workspaces(:household).brews.create!(
    user: users(:one),
    method: "quick_drip",
    bean: beans(:second_open_household),
    brewer:,
    machine_cups: 6,
    coffee_spoons: 6,
    rating: 4
  )

  statistics = EquipmentStatistics.new(equipment: brewer).call

  assert_equal 1, statistics[:totals][:brew_count]
  assert_equal 30.to_d, statistics[:totals][:total_bean_weight_grams]
  assert_equal 4.to_d, statistics[:averages][:rating]
  assert_equal [ brew ], statistics[:recent_brews]
end
```

```ruby
# test/services/grinder_setting_suggestion_test.rb
test "ignores quick drip brews for grinder tendency" do
  bean = beans(:second_open_household)
  workspaces(:household).brews.create!(
    user: users(:one),
    method: "quick_drip",
    bean:,
    brewer: equipment(:household_brewer),
    grinder: equipment(:household_grinder),
    machine_cups: 6,
    coffee_spoons: 6,
    grind_setting: "filter 8"
  )

  assert_empty GrinderSettingSuggestion.new(bean:).call
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
bin/rails test test/services/workspace_statistics_test.rb test/services/bean_statistics_test.rb test/services/equipment_statistics_test.rb test/services/grinder_setting_suggestion_test.rb
```

Expected: FAIL where services assume only grinder/machine or include Quick Drip in espresso-only calculations.

- [ ] **Step 3: Update statistics scopes**

In `WorkspaceStatistics#brews`, include `:brewer`:

```ruby
.includes(:bean, :grinder, :machine, :brewer)
```

Add method distributions if useful:

```ruby
method: count_by_present_value(brews, :method)
```

Keep total consumed grams as `brews.sum(&:bean_weight_grams)`.

- [ ] **Step 4: Update EquipmentStatistics for brewer**

Replace `brews_scope` with:

```ruby
def brews_scope
  return equipment.grinder_brews if equipment.grinder?
  return equipment.machine_brews if equipment.machine?

  equipment.brewer_brews
end
```

Update service event types:

```ruby
def service_event_types
  return %w[grinder_cleaning grinder_deep_cleaning burr_change] if equipment.grinder?
  return %w[machine_descaling machine_backflush] if equipment.machine?

  %w[brewer_cleaning brewer_descaling filter_change]
end
```

- [ ] **Step 5: Add brewer event types**

In `EquipmentEvent.event_type` enum:

```ruby
brewer_cleaning: "brewer_cleaning",
brewer_descaling: "brewer_descaling",
filter_change: "filter_change",
```

Update locale event labels wherever event type names are rendered.

- [ ] **Step 6: Exclude Quick Drip from grinder tendency**

In `GrinderSettingSuggestion`, scope candidate brews to espresso:

```ruby
bean.brews.espresso.includes(:grinder).order(:occurred_at, :created_at).first
```

and:

```ruby
calibration_brew.workspace.brews.espresso
```

- [ ] **Step 7: Run analytics tests**

Run:

```bash
bin/rails test test/services/workspace_statistics_test.rb test/services/bean_statistics_test.rb test/services/equipment_statistics_test.rb test/services/grinder_setting_suggestion_test.rb
```

Expected: PASS.

- [ ] **Step 8: Commit**

Run:

```bash
git add app/services/workspace_statistics.rb app/services/bean_statistics.rb app/services/equipment_statistics.rb app/services/grinder_setting_suggestion.rb app/models/equipment_event.rb app/views/equipment/show.html.erb config/locales/en.yml test/services/workspace_statistics_test.rb test/services/bean_statistics_test.rb test/services/equipment_statistics_test.rb test/services/grinder_setting_suggestion_test.rb
git commit -m "feat: add quick drip analytics support"
```

---

### Task 8: Exports, Backups, Restore, Demo Data, And Beanconqueror Deferral

**Files:**
- Modify: `app/services/workspace_export_builder.rb`
- Modify: `app/services/workspace_csv_export_builder.rb`
- Modify: `app/services/instance_readable_export_builder.rb`
- Modify: `app/services/instance_backup_restorer.rb`
- Modify: `app/services/demo_data_seeder.rb`
- Modify: `docs/demo-data.md`
- Test: `test/services/workspace_export_builder_test.rb`
- Test: `test/services/workspace_csv_export_builder_test.rb`
- Test: backup/export tests present in the repo
- Test: `test/services/demo_data_seeder_test.rb` if present, otherwise add it

- [ ] **Step 1: Write failing export tests**

Add to `test/services/workspace_export_builder_test.rb`:

```ruby
test "exports quick drip fields and bean grind state" do
  beans(:second_open_household).update!(grind_state: "pre_ground")
  brew = workspaces(:household).brews.create!(
    user: users(:one),
    method: "quick_drip",
    bean: beans(:second_open_household),
    brewer: equipment(:household_brewer),
    machine_cups: 6,
    coffee_spoons: 6
  )

  payload = WorkspaceExportBuilder.new(workspaces(:household), generated_at: Time.current).call

  bean_payload = payload[:beans].find { |row| row[:id] == beans(:second_open_household).id }
  assert_equal "pre_ground", bean_payload[:grind_state]

  brew_payload = payload[:brews].find { |row| row[:id] == brew.id }
  assert_equal equipment(:household_brewer).id, brew_payload[:brewer_id]
  assert_equal "6.0", brew_payload[:machine_cups]
  assert_equal "6.0", brew_payload[:coffee_spoons]
  assert_equal "5.0", brew_payload[:grams_per_coffee_spoon]
  assert_equal "estimated_spoons", brew_payload[:coffee_amount_source]
end
```

Add to `test/services/workspace_csv_export_builder_test.rb`:

```ruby
test "exports quick drip csv columns" do
  brew = workspaces(:household).brews.create!(
    user: users(:one),
    method: "quick_drip",
    bean: beans(:second_open_household),
    brewer: equipment(:household_brewer),
    machine_cups: 6,
    coffee_spoons: 6
  )

  rows = CSV.parse(WorkspaceCsvExportBuilder.new(workspaces(:household)).brews_csv, headers: true)
  exported = rows.find { |row| row.fetch("id").to_i == brew.id }

  assert_equal "quick_drip", exported.fetch("method")
  assert_equal equipment(:household_brewer).id.to_s, exported.fetch("brewer_id")
  assert_equal "Moccamaster", exported.fetch("brewer_name")
  assert_equal "6.0", exported.fetch("machine_cups")
  assert_equal "6.0", exported.fetch("coffee_spoons")
  assert_equal "estimated_spoons", exported.fetch("coffee_amount_source")
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
bin/rails test test/services/workspace_export_builder_test.rb test/services/workspace_csv_export_builder_test.rb
```

Expected: FAIL because export payloads do not include Quick Drip fields.

- [ ] **Step 3: Update JSON export**

In `WorkspaceExportBuilder#beans_payload`, add:

```ruby
grind_state: bean.grind_state,
```

In `WorkspaceExportBuilder#brews_payload`, add:

```ruby
brewer_id: brew.brewer_id,
machine_cups: decimal(brew.machine_cups),
coffee_spoons: decimal(brew.coffee_spoons),
grams_per_coffee_spoon: decimal(brew.grams_per_coffee_spoon),
coffee_amount_source: brew.coffee_amount_source,
```

In `InstanceReadableExportBuilder#users_payload`, add:

```ruby
enabled_brew_methods: user.enabled_brew_methods,
grams_per_coffee_spoon: decimal(user.grams_per_coffee_spoon),
```

Add a private `decimal` helper to `InstanceReadableExportBuilder`:

```ruby
def decimal(value)
  value&.to_s("F")
end
```

- [ ] **Step 4: Update restore**

In `InstanceBackupRestorer#restore_users`, add:

```ruby
enabled_brew_methods: row["enabled_brew_methods"].presence || %w[espresso quick_drip],
grams_per_coffee_spoon: row["grams_per_coffee_spoon"],
```

In `restore_beans`, add:

```ruby
grind_state: row["grind_state"].presence || "whole_bean",
```

In `restore_brews`, add:

```ruby
brewer: optional_lookup(@equipment_map, row["brewer_id"]),
machine_cups: row["machine_cups"],
coffee_spoons: row["coffee_spoons"],
grams_per_coffee_spoon: row["grams_per_coffee_spoon"],
coffee_amount_source: row["coffee_amount_source"] || "measured",
```

- [ ] **Step 5: Update CSV columns**

Add `grind_state` to `BEAN_COLUMNS`.

Add these to `BREW_COLUMNS` after `machine_name`:

```ruby
brewer_id brewer_name
```

Add after `beverage_grams`:

```ruby
machine_cups coffee_spoons grams_per_coffee_spoon coffee_amount_source
```

Handle `brewer_name` and decimal fields in `brew_value`.

- [ ] **Step 6: Add demo data**

In `DemoDataSeeder`, add:

```ruby
filter_ground: find_or_create_bean!(
  name: "Demo Ground Filter",
  roaster_name: "Roastnode Samples",
  origin: "Brazil",
  process: "natural",
  roast_type: "filter",
  grind_state: "pre_ground",
  bag_size_grams: 500,
  remaining_grams: 500,
  opened_on: Date.new(2026, 5, 23),
  notes: "Seeded demo Quick Drip coffee."
)
```

Add equipment:

```ruby
brewer: find_or_create_equipment!("Demo Quick Drip Brewer", "brewer", "Thermos drip")
```

Add preparation tool:

```ruby
paper_filter: find_or_create_preparation_tool!("Demo Paper Filter", brew_method: "quick_drip")
```

Update `find_or_create_preparation_tool!` to accept `brew_method: "espresso"`.

Add a Quick Drip brew:

```ruby
create_quick_drip_once!(
  occurred_at: Time.zone.local(2026, 5, 27, 8, 0, 0),
  bean: beans.fetch(:filter_ground),
  machine_cups: 6,
  coffee_spoons: 6,
  beverage_grams: 900,
  total_time_seconds: 360,
  taste_balance: "neutral",
  rating: 4,
  notes: "Seeded fast thermos batch.",
  tools: [ preparation_tools.fetch(:paper_filter) ]
)
```

Implement `create_quick_drip_once!` analogous to `create_brew_once!` with `method: "quick_drip"`, `brewer: equipment.fetch(:brewer)`, and no espresso machine fields.

- [ ] **Step 7: Run export/demo tests**

Run:

```bash
bin/rails test test/services/workspace_export_builder_test.rb test/services/workspace_csv_export_builder_test.rb test/services/demo_data_seeder_test.rb
```

If `test/services/demo_data_seeder_test.rb` does not exist, run:

```bash
bin/rails runner 'DemoDataSeeder.new.call; puts Workspace.find_by!(name: DemoDataSeeder::WORKSPACE_NAME).brews.quick_drip.count'
```

Expected: tests PASS, or runner prints a positive Quick Drip count.

- [ ] **Step 8: Commit**

Run:

```bash
git add app/services/workspace_export_builder.rb app/services/workspace_csv_export_builder.rb app/services/instance_readable_export_builder.rb app/services/instance_backup_restorer.rb app/services/demo_data_seeder.rb docs/demo-data.md test/services/workspace_export_builder_test.rb test/services/workspace_csv_export_builder_test.rb
git add test/services/demo_data_seeder_test.rb
git commit -m "feat: export quick drip data"
```

If `test/services/demo_data_seeder_test.rb` was not created in this task, omit that second `git add` command.

---

### Task 9: Durable Docs, Final Regression, And Local Server

**Files:**
- Modify: `docs/README.md`
- Modify: `docs/status.md`
- Modify: `docs/coffee-core.md`
- Modify: `docs/brew-form-preferences.md`
- Modify: `docs/brew-draft-recovery.md`
- Modify: `docs/brew-card.md`
- Modify: `docs/preparation-tools.md`
- Modify: `docs/equipment-lifecycle.md`
- Modify: `docs/equipment-events.md`
- Modify: `docs/statistics.md`
- Modify: `docs/workspace-export.md`
- Modify: `docs/demo-data.md`
- Modify: `AGENTS.md` only if the implementation adds new agent-critical rules.

- [ ] **Step 1: Update docs with v1 scope**

Add Quick Drip to `docs/coffee-core.md`:

```md
## Quick Drip Logging

Quick Drip is the first non-espresso brew method. It is a private daily logging flow for automatic drip-style filter coffee.

Quick Drip requires an open bean, a Brewer, Machine cups, and either Coffee spoons or measured Ground coffee. Spoon-only logs estimate consumed coffee using the user's Grams per coffee spoon preference, falling back to 5g per spoon.

Quick Drip omits espresso-only fields such as temperature, preinfusion, first drip, and channeling. Quick Drip recipes, public Quick Drip sharing, Beanconqueror Quick Drip import, and brewer cup calibration are deferred.
```

Update `docs/brew-card.md` with:

```md
Quick Drip Hero Cards reuse the private Hero Brew Card family but render method-specific batch metrics instead of the espresso extraction chart. Estimated consumed coffee uses a leading `~`.
```

Update `docs/brew-form-preferences.md` with:

```md
Enabled brew methods and Grams per coffee spoon live in Profile. Espresso hidden-field and focus preferences do not apply to Quick Drip v1.
```

Update the other docs listed above with the same facts in their local context.

- [ ] **Step 2: Run doc/status checks**

Run:

```bash
rg "Quick Drip|quick_drip|Brewer|Grams per coffee spoon" docs AGENTS.md CONTEXT.md
```

Expected: new durable docs mention the feature and deferrals in the relevant files.

- [ ] **Step 3: Run targeted test suite**

Run:

```bash
bin/rails test test/models/brew_test.rb test/models/bean_test.rb test/models/equipment_test.rb test/models/user_test.rb test/controllers/brews_controller_test.rb test/controllers/profiles_controller_test.rb test/controllers/equipment_controller_test.rb test/controllers/preparation_tools_controller_test.rb test/services/workspace_statistics_test.rb test/services/bean_statistics_test.rb test/services/equipment_statistics_test.rb test/services/workspace_export_builder_test.rb test/services/workspace_csv_export_builder_test.rb
```

Expected: PASS.

- [ ] **Step 4: Run full test suite**

Run:

```bash
bin/rails test
```

Expected: PASS.

- [ ] **Step 5: Run security check**

Run:

```bash
bin/brakeman
```

Expected: no new high-confidence warnings.

- [ ] **Step 6: Start local development server**

Run:

```bash
bin/dev --host 0.0.0.0
```

Expected: server starts on the configured local web port, preferably `3001`, binds to all interfaces, and is reachable on the network DNS setup documented for this project.

- [ ] **Step 7: Browser smoke check**

Use Browser/in-app browser against the local server:

1. Sign in.
2. Open Log.
3. Switch to Quick Drip.
4. Log a spoon-estimated Quick Drip brew.
5. Confirm the Hero Card shows Quick Drip metrics and estimated grams.
6. Confirm the bean remaining amount changed by the estimated grams.

Expected: workflow completes without layout overlap or missing media errors.

Stop the local server after the smoke check unless the user asks to keep it running.

- [ ] **Step 8: Commit docs and final polish**

Run:

```bash
git add docs/README.md docs/status.md docs/coffee-core.md docs/brew-form-preferences.md docs/brew-draft-recovery.md docs/brew-card.md docs/preparation-tools.md docs/equipment-lifecycle.md docs/equipment-events.md docs/statistics.md docs/workspace-export.md docs/demo-data.md AGENTS.md
git commit -m "docs: document quick drip logging"
```

- [ ] **Step 9: Final status**

Run:

```bash
git status --short
```

Expected: clean working tree.
