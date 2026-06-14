# Mobile Actions And Timezones Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove bean processing from private Hero Brew Cards, make detail-page navigation/actions icon-first without hidden mobile scrolling, and add per-user timezone handling for timestamp display and `datetime-local` forms.

**Architecture:** Keep the UI change view/helper-level: a shared Material-style icon helper, icon-only shared back link, and a reusable detail action partial for bean/brew detail actions. Timezone behavior belongs to `User` plus an `around_action` in `ApplicationController`, so normal Rails parsing and rendering use the active user's IANA zone while UTC storage stays unchanged.

**Tech Stack:** Rails 8.1, Hotwire/Turbo server-rendered ERB, Tailwind CSS, Minitest integration/helper/model tests, PostgreSQL datetime columns.

---

### Task 1: Private Hero Card Descriptor

**Files:**
- Modify: `app/helpers/brews_helper.rb`
- Modify: `test/controllers/brews_controller_test.rb`
- Modify: `docs/brew-card.md`

- [ ] **Step 1: Write the failing descriptor assertion**

Add to the private Hero Card controller tests near existing Hero Card assertions:

```ruby
test "show omits bean processing from private hero card descriptor" do
  sign_in_as(users(:one))
  brew = brews(:morning_espresso)
  brew.bean.update!(origin: "Colombia", process: "Washed", roast_level: "Light")

  get brew_path(brew)

  assert_response :success
  assert_select "[data-testid=brew-title-block]", text: /Colombia/
  assert_select "[data-testid=brew-title-block]", text: /Light/
  assert_select "[data-testid=brew-title-block]", text: /Washed/, count: 0
end
```

- [ ] **Step 2: Run the failing test**

Run: `bin/rails test test/controllers/brews_controller_test.rb -n "test_show_omits_bean_processing_from_private_hero_card_descriptor"`

Expected: FAIL because the descriptor currently includes `Washed`.

- [ ] **Step 3: Implement the helper change**

Change `brew_card_bean_descriptor` to:

```ruby
def brew_card_bean_descriptor(bean)
  [ bean.origin, bean.roast_level ].compact_blank.join(" · ")
end
```

- [ ] **Step 4: Verify the test passes**

Run: `bin/rails test test/controllers/brews_controller_test.rb -n "test_show_omits_bean_processing_from_private_hero_card_descriptor"`

Expected: PASS.

- [ ] **Step 5: Update docs**

Update `docs/brew-card.md` so the bean descriptor bullet says `origin/roast-level` and no longer says `process`.

### Task 2: Back Link Icon Helper

**Files:**
- Modify: `app/helpers/application_helper.rb`
- Modify: `app/views/shared/_back_link.html.erb`
- Modify: back-link assertions in controller tests that currently expect visible text
- Modify: `docs/navigation.md`

- [ ] **Step 1: Write failing shared back-link assertions**

Update representative assertions to require accessible labels without visible label text:

```ruby
assert_select "a[data-testid=back-link][href=?][aria-label=?][title=?]",
  beans_path,
  I18n.t("beans.show.back"),
  I18n.t("beans.show.back")
assert_select "a[data-testid=back-link] .material-symbol", "arrow_back"
assert_select "a[data-testid=back-link]", text: /Back to beans/, count: 0
```

Apply the same pattern to one brew detail test that uses `prefer_referrer: false`.

- [ ] **Step 2: Run the failing tests**

Run: `bin/rails test test/controllers/beans_controller_test.rb -n "test_show_renders_bean_detail" test/controllers/brews_controller_test.rb -n "test_show_renders_private_brew_detail"`

Expected: FAIL because the back link still renders visible text and no `material-symbol` span.

- [ ] **Step 3: Add a reusable icon helper**

Add this helper to `ApplicationHelper`:

```ruby
def material_symbol(name, classes: "material-symbol")
  tag.span(name, aria: { hidden: true }, class: classes)
end
```

- [ ] **Step 4: Make shared back link icon-only**

Change `_back_link.html.erb` to set `aria-label` and `title` on the `link_to`, render `material_symbol("arrow_back")`, and remove visible label text.

- [ ] **Step 5: Verify back-link tests**

Run the same two focused controller tests.

Expected: PASS.

- [ ] **Step 6: Update docs**

Update `docs/navigation.md` to say shared back links are icon-only controls with accessible labels and referrer-safe routing.

### Task 3: Bean And Brew Detail Action Controls

**Files:**
- Create: `app/views/shared/_detail_actions.html.erb`
- Modify: `app/views/beans/show.html.erb`
- Modify: `app/views/brews/show.html.erb`
- Modify: `test/controllers/beans_controller_test.rb`
- Modify: `test/controllers/brews_controller_test.rb`

- [ ] **Step 1: Write failing action-area tests**

For bean detail actions, assert no horizontal scrolling and require the hybrid action UI:

```ruby
assert_select "[data-testid=bean-detail-actions]"
actions = Nokogiri::HTML(response.body).at_css("[data-testid='bean-detail-actions']")
assert_not_includes actions["class"].to_s, "overflow-x-auto"
assert_select "[data-testid=bean-detail-actions] .material-symbol", minimum: 1
assert_select "[data-testid=bean-detail-actions-more]"
assert_select "[data-testid=bean-detail-actions-menu] a[href=?]", edit_bean_path(bean), text: I18n.t("beans.show.edit")
assert_select "[data-testid=bean-detail-actions-menu] a[href=?]", new_bean_inventory_adjustment_path(bean), text: I18n.t("beans.show.adjust_inventory")
```

For brew detail actions, assert the same non-scroll/menu behavior and that Edit remains reachable:

```ruby
actions = Nokogiri::HTML(response.body).at_css("[data-testid='brew-detail-actions']")
assert_not_includes actions["class"].to_s, "overflow-x-auto"
assert_select "[data-testid=brew-detail-actions] .material-symbol", minimum: 1
assert_select "[data-testid=brew-detail-actions-more]"
assert_select "[data-testid=brew-detail-actions-menu] a[href=?]", edit_brew_path(brew), text: I18n.t("brews.show.edit")
```

- [ ] **Step 2: Run the failing action tests**

Run: `bin/rails test test/controllers/beans_controller_test.rb -n "test_show_exposes_public_share_and_management_actions_in_order" test/controllers/brews_controller_test.rb -n "test_show_keeps_edit_actions_out_of_danger_zone"`

Expected: FAIL because the current action strips scroll horizontally and do not render the shared menu.

- [ ] **Step 3: Create the shared action partial**

Create `_detail_actions.html.erb` accepting `testid:`, `actions:`, and `primary_index: 0`. Each action hash has:

```ruby
{
  label: "...",
  icon: "edit",
  kind: :link,
  path: edit_brew_path(@brew),
  method: nil,
  testid: "brew-edit-link-1",
  primary: false
}
```

The partial renders:

- a mobile row with the primary action as an icon button and a `more_vert` `<details>` menu for remaining actions when more than two actions exist;
- a direct icon strip for one or two actions on mobile;
- a desktop direct icon strip for all actions;
- text labels inside menu items;
- `aria-label` and `title` on all icon buttons.

- [ ] **Step 4: Replace bean detail action strip**

Build `bean_actions` in `app/views/beans/show.html.erb` with the existing action order and route/test IDs. Use icons:

```ruby
rebuy: "shopping_bag"
native share: "ios_share"
share publicly: "public"
duplicate: "content_copy"
open bag: "inventory"
reopen: "restart_alt"
finish: "check_circle"
adjust inventory: "scale"
edit: "edit"
```

Render `shared/detail_actions` instead of the scrollable `div`.

- [ ] **Step 5: Replace brew detail action strip**

Build `brew_actions` in `app/views/brews/show.html.erb` with icons:

```ruby
native share: "ios_share"
share publicly: "public"
save as recipe: "bookmark_add"
repeat: "refresh"
edit: "edit"
```

Render `shared/detail_actions` instead of the scrollable `div`.

- [ ] **Step 6: Verify action tests**

Run the same focused bean and brew action tests.

Expected: PASS.

### Task 4: Per-User Timezone Support

**Files:**
- Create: `db/migrate/20260614120000_add_time_zone_to_users.rb`
- Modify: `app/models/user.rb`
- Modify: `app/controllers/application_controller.rb`
- Modify: `app/controllers/profiles_controller.rb`
- Modify: `app/views/profiles/edit.html.erb`
- Modify: `test/models/user_test.rb`
- Modify: `test/controllers/profiles_controller_test.rb`
- Modify: `test/controllers/brews_controller_test.rb`
- Modify: `test/controllers/external_coffees_controller_test.rb`
- Modify: `docs/formatting.md`

- [ ] **Step 1: Write failing model/profile tests**

Add to `UserTest`:

```ruby
test "timezone preference is constrained to IANA zones" do
  user = users(:one)

  user.time_zone = "Europe/Berlin"
  assert_predicate user, :valid?

  user.time_zone = "Mars/Olympus"
  assert_not_predicate user, :valid?
end
```

Add to `ProfilesControllerTest` edit/update assertions:

```ruby
assert_select "select[name=?]", "user[time_zone]"
```

and after update:

```ruby
assert_equal "Europe/Berlin", user.time_zone
```

- [ ] **Step 2: Write failing datetime behavior tests**

Add a brew edit/display test:

```ruby
test "datetime fields render and submit in user timezone" do
  user = users(:one)
  user.update!(time_zone: "Europe/Berlin")
  sign_in_as(user)
  brew = brews(:morning_espresso)
  brew.update!(occurred_at: Time.utc(2026, 6, 14, 8, 15, 28))

  get edit_brew_path(brew)

  assert_response :success
  assert_select "input[name=?][value=?]", "brew[occurred_at]", "2026-06-14T10:15:28"

  patch brew_path(brew), params: {
    brew: {
      bean_id: brew.bean.id,
      grinder_id: brew.grinder.id,
      machine_id: brew.machine.id,
      occurred_at: "2026-06-14T10:45:28",
      bean_weight_grams: brew.bean_weight_grams.to_s,
      ground_weight_grams: brew.ground_weight_grams.to_s,
      dose_grams: brew.dose_grams.to_s,
      beverage_grams: brew.beverage_grams.to_s,
      total_time_seconds: brew.total_time_seconds.to_s,
      taste_balance: brew.taste_balance
    }
  }

  assert_redirected_to brew_path(brew)
  assert_equal Time.utc(2026, 6, 14, 8, 45, 28), brew.reload.occurred_at
end
```

Add the same edit-field rendering assertion for external coffee edit.

- [ ] **Step 3: Run failing timezone tests**

Run: `bin/rails test test/models/user_test.rb test/controllers/profiles_controller_test.rb test/controllers/brews_controller_test.rb -n "test_datetime_fields_render_and_submit_in_user_timezone"`

Expected: FAIL because `time_zone` does not exist and request zone wrapping is missing.

- [ ] **Step 4: Add migration and model validation**

Migration:

```ruby
class AddTimeZoneToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :time_zone, :string, null: false, default: "Europe/Berlin"
  end
end
```

Model:

```ruby
validates :time_zone, presence: true, inclusion: { in: ActiveSupport::TimeZone.all.map(&:tzinfo).map(&:name) }
```

- [ ] **Step 5: Wrap request timezone**

Add to `ApplicationController`:

```ruby
around_action :use_current_user_time_zone

def use_current_user_time_zone(&block)
  zone_name = Current.user&.time_zone
  zone = zone_name.presence && ActiveSupport::TimeZone[zone_name]

  if zone
    Time.use_zone(zone, &block)
  else
    yield
  end
end
```

- [ ] **Step 6: Add profile form/params**

Permit `:time_zone` in `ProfilesController`, and add a select:

```erb
<%= form.select :time_zone,
  ActiveSupport::TimeZone.all.map { |zone| [ zone.to_s, zone.tzinfo.name ] },
  {},
  class: "mt-1 w-full rounded-md border border-stone-300 px-3 py-2 text-stone-950 shadow-sm focus:border-stone-900 focus:outline-none" %>
```

- [ ] **Step 7: Run migration and focused tests**

Run: `bin/rails db:migrate`

Run: `bin/rails test test/models/user_test.rb test/controllers/profiles_controller_test.rb test/controllers/brews_controller_test.rb test/controllers/external_coffees_controller_test.rb`

Expected: PASS.

- [ ] **Step 8: Update docs**

Update `docs/formatting.md` with the timezone preference behavior.

### Task 5: Final Verification And Server

**Files:**
- Modify: `docs/status.md` if needed by final implemented behavior.

- [ ] **Step 1: Run targeted full test set**

Run:

```bash
bin/rails test test/controllers/brews_controller_test.rb test/controllers/beans_controller_test.rb test/controllers/profiles_controller_test.rb test/controllers/external_coffees_controller_test.rb test/models/user_test.rb
```

Expected: PASS.

- [ ] **Step 2: Inspect git diff**

Run: `git diff --stat`

Expected: only files in this plan changed.

- [ ] **Step 3: Start dev server**

Run: `bin/dev`

Expected: Rails dev server starts on the configured local port, reachable for user review.
