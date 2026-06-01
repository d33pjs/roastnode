# Brew And Activity History Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add paginated all-time brew history and activity history pages for the active workspace, with dashboard and statistics entry points.

**Architecture:** Add a small reusable `HistoryPaginator` for limit-plus-one pagination, a `WorkspaceActivityFeed` service for combining dashboard activity families, and server-rendered Rails views for `brews#index` and `activity#index`. Keep all data access scoped through `current_workspace`; reuse existing brew card helpers and `brews/_hero_card` for hero view.

**Tech Stack:** Rails 8.1, Hotwire-compatible server-rendered ERB, Tailwind utility classes, Minitest integration/model tests, PostgreSQL-backed Active Record.

---

## File Structure

- Create `app/models/history_paginator.rb`: reusable page normalization and limit-plus-one pagination for relations and arrays.
- Create `test/models/history_paginator_test.rb`: unit coverage for page fallback, next/previous links, relation pagination, and array pagination.
- Create `app/services/workspace_activity_feed.rb`: returns sorted all-time activity records for one workspace.
- Create `test/services/workspace_activity_feed_test.rb`: service-level scoping and sort coverage.
- Modify `config/routes.rb`: add `brews#index` and `GET /activity`.
- Modify `app/controllers/brews_controller.rb`: add read-only `index`.
- Create `app/controllers/activity_controller.rb`: read-only activity index.
- Create `app/views/brews/index.html.erb`: brew history page, view toggle, pagination.
- Create `app/views/brews/_compact_card.html.erb`: compact brew history card.
- Create `app/views/activity/index.html.erb`: all-activity card history page.
- Create `app/views/shared/_history_pagination.html.erb`: previous/next pagination controls.
- Modify `app/views/workspaces/show.html.erb`: dashboard `View all` links.
- Modify `app/views/statistics/index.html.erb`: all-brews page button and total-brews card link.
- Modify `config/locales/en.yml`: labels for history pages, toggles, links, and pagination.
- Modify `test/controllers/brews_controller_test.rb`: brew history integration coverage.
- Create `test/controllers/activity_controller_test.rb`: activity history integration coverage.
- Modify `test/controllers/home_controller_test.rb`: dashboard link coverage.
- Modify `test/controllers/statistics_controller_test.rb`: statistics link coverage.
- Modify `docs/coffee-core.md`, `docs/navigation.md`, and `docs/statistics.md`: durable product documentation updates.

---

### Task 1: Add Reusable History Pagination

**Files:**
- Create: `app/models/history_paginator.rb`
- Create: `test/models/history_paginator_test.rb`

- [ ] **Step 1: Write the failing paginator tests**

Create `test/models/history_paginator_test.rb`:

```ruby
require "test_helper"

class HistoryPaginatorTest < ActiveSupport::TestCase
  test "normalizes invalid pages to page one" do
    paginator = HistoryPaginator.new([ 1, 2, 3 ], page: "bad", per_page: 2)

    assert_equal 1, paginator.page
    assert_equal [ 1, 2 ], paginator.records
    assert_nil paginator.previous_page
    assert_equal 2, paginator.next_page
  end

  test "paginates arrays with previous and next state" do
    paginator = HistoryPaginator.new([ 1, 2, 3, 4, 5 ], page: 2, per_page: 2)

    assert_equal 2, paginator.page
    assert_equal [ 3, 4 ], paginator.records
    assert_equal 1, paginator.previous_page
    assert_equal 3, paginator.next_page
  end

  test "paginates active record relations without loading unrelated pages" do
    workspace = workspaces(:household)
    relation = workspace.brews.order(occurred_at: :desc, created_at: :desc)

    paginator = HistoryPaginator.new(relation, page: 1, per_page: 1)

    assert_equal [ brews(:morning_espresso) ], paginator.records
    assert_nil paginator.previous_page
    assert_nil paginator.next_page
  end
end
```

- [ ] **Step 2: Run the paginator tests and verify they fail**

Run:

```bash
bin/rails test test/models/history_paginator_test.rb
```

Expected: fail with `uninitialized constant HistoryPaginator`.

- [ ] **Step 3: Implement the paginator**

Create `app/models/history_paginator.rb`:

```ruby
class HistoryPaginator
  DEFAULT_PER_PAGE = 20

  attr_reader :page, :per_page, :records

  def initialize(scope, page:, per_page: DEFAULT_PER_PAGE)
    @scope = scope
    @page = normalize_page(page)
    @per_page = per_page
    @records = load_records
  end

  def previous_page
    page - 1 if page > 1
  end

  def next_page
    page + 1 if @has_next_page
  end

  def any?
    records.any?
  end

  private
    attr_reader :scope

    def normalize_page(value)
      Integer(value)
    rescue ArgumentError, TypeError
      1
    else
      value.to_i.positive? ? value.to_i : 1
    end

    def load_records
      items = if relation_scope?
        scope.offset(offset).limit(per_page + 1).to_a
      else
        scope.to_a.slice(offset, per_page + 1) || []
      end

      @has_next_page = items.size > per_page
      items.first(per_page)
    end

    def relation_scope?
      scope.respond_to?(:offset) && scope.respond_to?(:limit)
    end

    def offset
      (page - 1) * per_page
    end
end
```

- [ ] **Step 4: Run paginator tests and verify they pass**

Run:

```bash
bin/rails test test/models/history_paginator_test.rb
```

Expected: 3 runs, 0 failures, 0 errors.

- [ ] **Step 5: Commit the paginator**

```bash
git add app/models/history_paginator.rb test/models/history_paginator_test.rb
git commit -m "feat: add history paginator"
```

---

### Task 2: Add Workspace Activity Feed Service

**Files:**
- Create: `app/services/workspace_activity_feed.rb`
- Create: `test/services/workspace_activity_feed_test.rb`

- [ ] **Step 1: Write failing service tests**

Create `test/services/workspace_activity_feed_test.rb`:

```ruby
require "test_helper"

class WorkspaceActivityFeedTest < ActiveSupport::TestCase
  test "returns workspace activity sorted newest first" do
    workspace = workspaces(:household)
    adjustment = workspace.inventory_adjustments.create!(
      bean: beans(:open_household),
      user: users(:one),
      delta_grams: 12.5,
      reason: "manual",
      note: "Found extra beans.",
      occurred_at: Time.zone.local(2026, 6, 1, 9, 30, 0)
    )
    brews(:morning_espresso).update!(occurred_at: Time.zone.local(2026, 6, 1, 8, 0, 0))
    equipment_events(:grinder_cleaning).update!(occurred_at: Time.zone.local(2026, 6, 1, 7, 0, 0))

    records = WorkspaceActivityFeed.new(workspace).records

    assert_equal [ adjustment, brews(:morning_espresso), equipment_events(:grinder_cleaning) ], records.first(3)
  end

  test "does not include other workspace activity" do
    records = WorkspaceActivityFeed.new(workspaces(:household)).records

    assert_includes records, brews(:morning_espresso)
    assert_includes records, equipment_events(:grinder_cleaning)
    assert_not_includes records, brews(:other_workspace_brew)
    assert_not_includes records, equipment_events(:other_workspace_event)
  end
end
```

- [ ] **Step 2: Run the service tests and verify they fail**

Run:

```bash
bin/rails test test/services/workspace_activity_feed_test.rb
```

Expected: fail with `uninitialized constant WorkspaceActivityFeed`.

- [ ] **Step 3: Implement the activity feed**

Create `app/services/workspace_activity_feed.rb`:

```ruby
class WorkspaceActivityFeed
  def initialize(workspace)
    @workspace = workspace
  end

  def records
    @records ||= (brews + manual_adjustments + equipment_events).sort_by do |record|
      [ record.occurred_at || Time.zone.at(0), record.created_at || Time.zone.at(0) ]
    end.reverse
  end

  private
    attr_reader :workspace

    def brews
      workspace.brews.includes(:bean, :user).to_a
    end

    def manual_adjustments
      workspace.inventory_adjustments.manual.includes(:bean, :user).to_a
    end

    def equipment_events
      workspace.equipment_events.includes(:equipment, :user).to_a
    end
end
```

- [ ] **Step 4: Run service tests and verify they pass**

Run:

```bash
bin/rails test test/services/workspace_activity_feed_test.rb
```

Expected: 2 runs, 0 failures, 0 errors.

- [ ] **Step 5: Commit the service**

```bash
git add app/services/workspace_activity_feed.rb test/services/workspace_activity_feed_test.rb
git commit -m "feat: add workspace activity feed"
```

---

### Task 3: Add Brew History Page

**Files:**
- Modify: `config/routes.rb`
- Modify: `app/controllers/brews_controller.rb`
- Create: `app/views/brews/index.html.erb`
- Create: `app/views/brews/_compact_card.html.erb`
- Create: `app/views/shared/_history_pagination.html.erb`
- Modify: `config/locales/en.yml`
- Modify: `test/controllers/brews_controller_test.rb`

- [ ] **Step 1: Write failing brew history tests**

Append these tests to `test/controllers/brews_controller_test.rb`:

```ruby
  test "index shows workspace brews newest first in compact view by default" do
    older = brews(:morning_espresso)
    older.update!(occurred_at: Time.zone.local(2026, 5, 30, 8, 0, 0))
    newest = workspaces(:household).brews.create!(
      user: users(:one),
      bean: beans(:second_open_household),
      grinder: equipment(:household_grinder),
      machine: equipment(:household_machine),
      occurred_at: Time.zone.local(2026, 6, 1, 9, 0, 0),
      bean_weight_grams: 19,
      dose_grams: 18.5,
      beverage_grams: 46,
      total_time_seconds: 30,
      grind_setting: "13",
      taste_balance: "neutral",
      rating: 5
    )

    sign_in_as(users(:one))
    get brews_path

    assert_response :success
    assert_select "h1", I18n.t("brews.index.title")
    assert_select "[data-testid=brew-history-compact-card]", count: 2
    assert_select "[data-testid=brew-history-hero-card]", count: 0
    assert_select "a[href=?]", brew_path(newest), text: /#{newest.bean.name}/
    assert_select "a[href=?]", brew_path(older), text: /#{older.bean.name}/
    assert_select "a[href=?]", brew_path(brews(:other_workspace_brew)), count: 0
    assert_appears_before newest.bean.name, older.bean.name
  end

  test "index can render hero cards" do
    sign_in_as(users(:one))

    get brews_path, params: { view: "hero" }

    assert_response :success
    assert_select "[data-testid=brew-history-hero-card]", count: 1
    assert_select "[data-testid=brew-history-compact-card]", count: 0
    assert_select "[data-testid=brew-history-hero-card] a[href=?]", brew_path(brews(:morning_espresso))
  end

  test "index paginates brews and preserves selected view" do
    workspace = workspaces(:household)
    21.times do |index|
      workspace.brews.create!(
        user: users(:one),
        bean: beans(:second_open_household),
        occurred_at: Time.zone.local(2026, 6, 1, 12, 0, 0) - index.minutes,
        bean_weight_grams: 18,
        dose_grams: 18,
        beverage_grams: 45
      )
    end
    sign_in_as(users(:one))

    get brews_path, params: { view: "hero" }

    assert_response :success
    assert_select "[data-testid=history-next-page][href=?]", brews_path(view: "hero", page: 2)

    get brews_path, params: { view: "hero", page: 2 }

    assert_response :success
    assert_select "[data-testid=history-previous-page][href=?]", brews_path(view: "hero", page: 1)
  end

  test "viewer can read brew history" do
    memberships(:member).update!(role: "viewer")
    user = users(:two)
    user.update!(active_workspace: workspaces(:household))
    sign_in_as(user)

    get brews_path

    assert_response :success
    assert_select "h1", I18n.t("brews.index.title")
  end
```

- [ ] **Step 2: Run brew history tests and verify they fail**

Run:

```bash
bin/rails test test/controllers/brews_controller_test.rb
```

Expected: failures for missing `index` route/action and missing view.

- [ ] **Step 3: Add the route and controller action**

In `config/routes.rb`, change:

```ruby
  resources :brews, only: %i[new create show edit update destroy] do
```

to:

```ruby
  resources :brews, only: %i[index new create show edit update destroy] do
```

In `app/controllers/brews_controller.rb`, add `index` before `show`:

```ruby
  def index
    @brew_history_view = params[:view] == "hero" ? "hero" : "compact"
    brews = current_workspace
      .brews
      .includes(:bean, :user, :grinder, :machine, brew_preparation_tools: :preparation_tool)
      .order(occurred_at: :desc, created_at: :desc)
    @brew_history = HistoryPaginator.new(brews, page: params[:page])
  end
```

- [ ] **Step 4: Add locale keys**

Add under `brews:` in `config/locales/en.yml`:

```yaml
    index:
      back: "Back to dashboard"
      compact_view: "Compact"
      empty: "No brews yet."
      hero_view: "Hero cards"
      next_page: "Next"
      previous_page: "Previous"
      title: "Brews"
```

Add under `shared:` in `config/locales/en.yml`:

```yaml
    history_pagination:
      next: "Next"
      previous: "Previous"
```

- [ ] **Step 5: Add the shared pagination partial**

Create `app/views/shared/_history_pagination.html.erb`:

```erb
<% preserved_params = local_assigns.fetch(:params, {}) %>
<% if paginator.previous_page || paginator.next_page %>
  <nav class="mt-6 flex items-center justify-between gap-3" aria-label="Pagination">
    <% if paginator.previous_page %>
      <%= link_to t("shared.history_pagination.previous"),
        url_for(preserved_params.merge(page: paginator.previous_page)),
        data: { testid: "history-previous-page" },
        class: "rounded-lg border border-rn-line bg-rn-surface px-4 py-2 text-sm font-extrabold text-rn-ink hover:bg-[var(--rn-surface-muted)]" %>
    <% else %>
      <span></span>
    <% end %>

    <% if paginator.next_page %>
      <%= link_to t("shared.history_pagination.next"),
        url_for(preserved_params.merge(page: paginator.next_page)),
        data: { testid: "history-next-page" },
        class: "ml-auto rounded-lg bg-[var(--rn-accent-strong)] px-4 py-2 text-sm font-extrabold text-[#f8faf6] hover:opacity-90" %>
    <% end %>
  </nav>
<% end %>
```

- [ ] **Step 6: Add the compact brew card partial**

Create `app/views/brews/_compact_card.html.erb`:

```erb
<%= link_to brew_path(brew),
  data: { testid: "brew-history-compact-card" },
  class: "block rounded-2xl border border-rn-line bg-rn-surface p-4 shadow-sm hover:bg-[var(--rn-surface-muted)]" do %>
  <div class="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
    <div class="min-w-0">
      <p class="text-xs font-extrabold uppercase tracking-[0.08em] text-rn-muted"><%= profile_timestamp(brew.occurred_at) %></p>
      <h2 class="mt-1 truncate text-xl font-black text-rn-ink"><%= brew.bean.name %></h2>
      <p class="mt-1 truncate text-sm font-bold text-rn-ink"><%= brew.bean.roaster_name.presence || t("beans.index.unknown") %></p>
      <p class="mt-2 text-sm font-semibold text-rn-muted"><%= t("brews.show.logged_by") %>: <%= brew.user.display_label %></p>
    </div>
    <div class="grid grid-cols-2 gap-2 text-sm sm:min-w-60">
      <div class="rounded-xl border border-rn-line bg-rn-canvas p-3">
        <p class="text-xs font-extrabold uppercase tracking-[0.08em] text-rn-muted"><%= t("brews.show.dose") %></p>
        <p class="mt-1 font-black text-rn-ink"><%= brew_card_grams(brew.dose_grams) %></p>
      </div>
      <div class="rounded-xl border border-rn-line bg-rn-canvas p-3">
        <p class="text-xs font-extrabold uppercase tracking-[0.08em] text-rn-muted"><%= t("brews.show.ratio") %></p>
        <p class="mt-1 font-black text-rn-ink"><%= brew_card_ratio(brew) %></p>
      </div>
      <div class="rounded-xl border border-rn-line bg-rn-canvas p-3">
        <p class="text-xs font-extrabold uppercase tracking-[0.08em] text-rn-muted"><%= t("brews.show.grind_setting") %></p>
        <p class="mt-1 font-black text-rn-ink"><%= brew.grind_setting.presence || t("brews.show.unknown") %></p>
      </div>
      <div class="rounded-xl border border-rn-line bg-rn-canvas p-3">
        <p class="text-xs font-extrabold uppercase tracking-[0.08em] text-rn-muted"><%= t("brews.show.rating") %></p>
        <p class="mt-1 font-black text-rn-ink"><%= brew.rating.presence || t("brews.show.unknown") %></p>
      </div>
    </div>
  </div>
  <div class="mt-3 flex flex-wrap gap-2 text-xs font-extrabold uppercase tracking-[0.08em] text-rn-muted">
    <span><%= brew.grinder&.name || t("brews.show.unknown") %></span>
    <span><%= brew.machine&.name || t("brews.show.unknown") %></span>
    <span><%= brew.taste_balance.humanize %></span>
  </div>
<% end %>
```

- [ ] **Step 7: Add the brew index view**

Create `app/views/brews/index.html.erb`:

```erb
<main class="rn-page">
  <%= render "brews/hero_card_styles" if @brew_history_view == "hero" %>

  <section class="rn-shell max-w-6xl py-6 sm:px-6 lg:py-10">
    <header class="border-b border-rn-line pb-6">
      <%= render "shared/back_link", label: t(".back"), path: dashboard_path %>
      <div class="mt-4 flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <p class="text-sm font-extrabold uppercase tracking-[0.08em] text-rn-muted"><%= current_workspace.name %></p>
          <h1 class="mt-2 text-4xl font-black text-rn-ink"><%= t(".title") %></h1>
        </div>
        <div class="flex flex-wrap gap-2">
          <%= link_to t(".compact_view"),
            brews_path(view: "compact"),
            aria: { current: @brew_history_view == "compact" ? "page" : nil },
            class: [
              "rounded-lg border px-3 py-2 text-sm font-extrabold",
              @brew_history_view == "compact" ? "border-rn-line bg-[var(--rn-accent-strong)] text-[#f8faf6]" : "border-rn-line bg-rn-surface text-rn-ink hover:bg-[var(--rn-surface-muted)]"
            ] %>
          <%= link_to t(".hero_view"),
            brews_path(view: "hero"),
            aria: { current: @brew_history_view == "hero" ? "page" : nil },
            class: [
              "rounded-lg border px-3 py-2 text-sm font-extrabold",
              @brew_history_view == "hero" ? "border-rn-line bg-[var(--rn-accent-strong)] text-[#f8faf6]" : "border-rn-line bg-rn-surface text-rn-ink hover:bg-[var(--rn-surface-muted)]"
            ] %>
        </div>
      </div>
    </header>

    <% if @brew_history.any? %>
      <div class="mt-8 grid gap-4">
        <% @brew_history.records.each do |brew| %>
          <% if @brew_history_view == "hero" %>
            <div data-testid="brew-history-hero-card">
              <%= link_to brew_path(brew), class: "block" do %>
                <%= render "brews/hero_card", brew:, compact: true, chart_id: "brew-history-shot-fill-#{brew.id}" %>
              <% end %>
            </div>
          <% else %>
            <%= render "brews/compact_card", brew: %>
          <% end %>
        <% end %>
      </div>
      <%= render "shared/history_pagination", paginator: @brew_history, params: request.query_parameters.except("page") %>
    <% else %>
      <p class="mt-8 rounded-2xl border border-rn-line bg-rn-surface p-5 text-sm font-semibold text-rn-ink"><%= t(".empty") %></p>
    <% end %>
  </section>
</main>
```

- [ ] **Step 8: Run brew history tests and fix only failures in this scope**

Run:

```bash
bin/rails test test/controllers/brews_controller_test.rb
```

Expected: all `BrewsControllerTest` tests pass.

- [ ] **Step 9: Commit brew history**

```bash
git add config/routes.rb app/controllers/brews_controller.rb app/views/brews/index.html.erb app/views/brews/_compact_card.html.erb app/views/shared/_history_pagination.html.erb config/locales/en.yml test/controllers/brews_controller_test.rb
git commit -m "feat: add brew history"
```

---

### Task 4: Add Activity History Page

**Files:**
- Modify: `config/routes.rb`
- Create: `app/controllers/activity_controller.rb`
- Create: `app/views/activity/index.html.erb`
- Modify: `config/locales/en.yml`
- Create: `test/controllers/activity_controller_test.rb`

- [ ] **Step 1: Write failing activity controller tests**

Create `test/controllers/activity_controller_test.rb`:

```ruby
require "test_helper"

class ActivityControllerTest < ActionDispatch::IntegrationTest
  test "index shows workspace activity newest first" do
    workspace = workspaces(:household)
    adjustment = workspace.inventory_adjustments.create!(
      bean: beans(:open_household),
      user: users(:one),
      delta_grams: 12.5,
      reason: "manual",
      note: "Found extra beans.",
      occurred_at: Time.zone.local(2026, 6, 1, 10, 0, 0)
    )
    brews(:morning_espresso).update!(occurred_at: Time.zone.local(2026, 6, 1, 9, 0, 0))
    equipment_events(:grinder_cleaning).update!(occurred_at: Time.zone.local(2026, 6, 1, 8, 0, 0))
    sign_in_as(users(:one))

    get activity_path

    assert_response :success
    assert_select "h1", I18n.t("activity.index.title")
    assert_select "[data-testid=activity-card]", minimum: 3
    assert_select "a[href=?]", brew_path(brews(:morning_espresso)), text: /#{beans(:open_household).name}/
    assert_select "a[href=?]", equipment_event_path(equipment_events(:grinder_cleaning)), text: /Grinder cleaning/
    assert_select "p", text: I18n.t("activity.index.adjustment", amount: "12,5", bean: adjustment.bean.name)
    assert_select "a[href=?]", brew_path(brews(:other_workspace_brew)), count: 0
    assert_appears_before "12,5", beans(:open_household).name
    assert_appears_before beans(:open_household).name, "Grinder cleaning"
  end

  test "index paginates activity" do
    workspace = workspaces(:household)
    21.times do |index|
      workspace.inventory_adjustments.create!(
        bean: beans(:open_household),
        user: users(:one),
        delta_grams: index + 1,
        reason: "manual",
        note: "Correction #{index}",
        occurred_at: Time.zone.local(2026, 6, 1, 12, 0, 0) - index.minutes
      )
    end
    sign_in_as(users(:one))

    get activity_path

    assert_response :success
    assert_select "[data-testid=history-next-page][href=?]", activity_path(page: 2)

    get activity_path, params: { page: 2 }

    assert_response :success
    assert_select "[data-testid=history-previous-page][href=?]", activity_path(page: 1)
  end

  test "viewer can read activity history" do
    memberships(:member).update!(role: "viewer")
    user = users(:two)
    user.update!(active_workspace: workspaces(:household))
    sign_in_as(user)

    get activity_path

    assert_response :success
    assert_select "h1", I18n.t("activity.index.title")
  end

  private
    def assert_appears_before(first, second)
      first_index = response.body.index(first)
      second_index = response.body.index(second)

      assert first_index, "Expected #{first.inspect} to appear in response body"
      assert second_index, "Expected #{second.inspect} to appear in response body"
      assert first_index < second_index, "Expected #{first.inspect} to appear before #{second.inspect}"
    end
end
```

- [ ] **Step 2: Run activity tests and verify they fail**

Run:

```bash
bin/rails test test/controllers/activity_controller_test.rb
```

Expected: fail with missing `activity_path` route/controller.

- [ ] **Step 3: Add route and controller**

In `config/routes.rb`, add near the dashboard route:

```ruby
  get "activity" => "activity#index", as: :activity
```

Create `app/controllers/activity_controller.rb`:

```ruby
class ActivityController < ApplicationController
  def index
    @activity = HistoryPaginator.new(WorkspaceActivityFeed.new(current_workspace).records, page: params[:page])
  end
end
```

- [ ] **Step 4: Add activity locale keys**

Add this top-level key to `config/locales/en.yml`:

```yaml
  activity:
    index:
      adjustment: "%{amount} g inventory adjustment for %{bean}"
      back: "Back to dashboard"
      brew: "Espresso with %{bean}"
      empty: "No activity yet."
      equipment_event: "%{event} for %{equipment}"
      inventory_type: "Inventory"
      brew_type: "Brew"
      equipment_type: "Equipment"
      title: "Activity"
```

- [ ] **Step 5: Add activity index view**

Create `app/views/activity/index.html.erb`:

```erb
<main class="rn-page">
  <section class="rn-shell max-w-6xl py-6 sm:px-6 lg:py-10">
    <header class="border-b border-rn-line pb-6">
      <%= render "shared/back_link", label: t(".back"), path: dashboard_path %>
      <p class="mt-4 text-sm font-extrabold uppercase tracking-[0.08em] text-rn-muted"><%= current_workspace.name %></p>
      <h1 class="mt-2 text-4xl font-black text-rn-ink"><%= t(".title") %></h1>
    </header>

    <% if @activity.any? %>
      <div class="mt-8 overflow-hidden rounded-2xl border border-rn-line bg-rn-surface shadow-sm">
        <% @activity.records.each do |activity| %>
          <% if activity.is_a?(Brew) %>
            <%= link_to brew_path(activity), data: { testid: "activity-card" }, class: "block border-b border-rn-line p-4 last:border-b-0 hover:bg-[var(--rn-surface-muted)]" do %>
              <p class="font-extrabold text-rn-ink"><%= t(".brew", bean: activity.bean.name) %></p>
              <p class="mt-1 text-sm font-semibold text-rn-ink"><%= profile_timestamp(activity.occurred_at) %> · <%= t(".brew_type") %> · <%= activity.user.display_label %></p>
            <% end %>
          <% elsif activity.is_a?(EquipmentEvent) %>
            <%= link_to equipment_event_path(activity), data: { testid: "activity-card" }, class: "block border-b border-rn-line p-4 last:border-b-0 hover:bg-[var(--rn-surface-muted)]" do %>
              <p class="font-extrabold text-rn-ink"><%= t(".equipment_event", event: activity.event_type_summary, equipment: activity.equipment.map(&:name).to_sentence) %></p>
              <p class="mt-1 text-sm font-semibold text-rn-ink"><%= profile_timestamp(activity.occurred_at) %> · <%= t(".equipment_type") %> · <%= activity.user.display_label %></p>
            <% end %>
          <% else %>
            <div data-testid="activity-card" class="border-b border-rn-line p-4 last:border-b-0">
              <p class="font-extrabold text-rn-ink"><%= t(".adjustment", bean: activity.bean.name, amount: profile_number(activity.delta_grams, precision: 1)) %></p>
              <p class="mt-1 text-sm font-semibold text-rn-ink"><%= profile_timestamp(activity.occurred_at) %> · <%= t(".inventory_type") %> · <%= activity.user.display_label %></p>
            </div>
          <% end %>
        <% end %>
      </div>
      <%= render "shared/history_pagination", paginator: @activity, params: request.query_parameters.except("page") %>
    <% else %>
      <p class="mt-8 rounded-2xl border border-rn-line bg-rn-surface p-5 text-sm font-semibold text-rn-ink"><%= t(".empty") %></p>
    <% end %>
  </section>
</main>
```

- [ ] **Step 6: Run activity tests and verify they pass**

Run:

```bash
bin/rails test test/controllers/activity_controller_test.rb
```

Expected: 3 runs, 0 failures, 0 errors.

- [ ] **Step 7: Commit activity history**

```bash
git add config/routes.rb app/controllers/activity_controller.rb app/views/activity/index.html.erb config/locales/en.yml test/controllers/activity_controller_test.rb
git commit -m "feat: add activity history"
```

---

### Task 5: Add Dashboard And Statistics Entry Points

**Files:**
- Modify: `app/views/workspaces/show.html.erb`
- Modify: `app/views/statistics/index.html.erb`
- Modify: `config/locales/en.yml`
- Modify: `test/controllers/home_controller_test.rb`
- Modify: `test/controllers/statistics_controller_test.rb`

- [ ] **Step 1: Write failing dashboard link assertions**

In `test/controllers/home_controller_test.rb`, extend `test "workspace dashboard shows latest and latest best hero cards"` with:

```ruby
    assert_select "[data-testid=dashboard-latest-brew-heading] a[href=?]", brews_path, text: I18n.t("workspaces.show.view_all")
```

In `test/controllers/home_controller_test.rb`, extend `test "workspace dashboard shows overview and recent activity without duplicate command strips"` with:

```ruby
    assert_select "[data-testid=dashboard-recent-activity-heading] a[href=?]", activity_path, text: I18n.t("workspaces.show.view_all")
```

- [ ] **Step 2: Write failing statistics link assertions**

In `test/controllers/statistics_controller_test.rb`, extend `test "workspace member sees scoped statistics"` with:

```ruby
    assert_select "a[data-testid=statistics-all-brews-button][href=?]", brews_path, text: I18n.t("statistics.index.all_brews")
    assert_select "[data-testid=statistics-total-brews-card] a[href=?]", brews_path, text: I18n.t("statistics.index.view_all")
```

- [ ] **Step 3: Run link tests and verify they fail**

Run:

```bash
bin/rails test test/controllers/home_controller_test.rb test/controllers/statistics_controller_test.rb
```

Expected: failures for missing dashboard and statistics links.

- [ ] **Step 4: Add locale keys**

Under `statistics.index` in `config/locales/en.yml`, add:

```yaml
      all_brews: "All brews"
      view_all: "View all"
```

- [ ] **Step 5: Add dashboard links**

In `app/views/workspaces/show.html.erb`, replace the latest brew heading:

```erb
            <h2 class="mb-3 text-xl font-black text-rn-ink"><%= t(".hero.latest") %></h2>
```

with:

```erb
            <div data-testid="dashboard-latest-brew-heading" class="mb-3 flex items-center justify-between gap-4">
              <h2 class="text-xl font-black text-rn-ink"><%= t(".hero.latest") %></h2>
              <%= link_to t(".view_all"), brews_path, class: "text-sm font-bold text-rn-ink hover:underline" %>
            </div>
```

Replace the recent activity heading:

```erb
        <h2 class="mb-4 text-xl font-black text-rn-ink"><%= t(".recent_activity") %></h2>
```

with:

```erb
        <div data-testid="dashboard-recent-activity-heading" class="mb-4 flex items-center justify-between gap-4">
          <h2 class="text-xl font-black text-rn-ink"><%= t(".recent_activity") %></h2>
          <%= link_to t(".view_all"), activity_path, class: "text-sm font-bold text-rn-ink hover:underline" %>
        </div>
```

- [ ] **Step 6: Add statistics links**

In `app/views/statistics/index.html.erb`, inside the header after the `<h1>` line, add:

```erb
      <div class="mt-4">
        <%= link_to t(".all_brews"),
          brews_path,
          data: { testid: "statistics-all-brews-button" },
          class: "inline-flex rounded-lg bg-stone-950 px-4 py-2 text-sm font-semibold text-white shadow-sm hover:bg-stone-800" %>
      </div>
```

In the total brews card, replace:

```erb
      <div class="rounded-lg border border-stone-200 bg-white p-5 shadow-sm">
        <p class="text-sm font-semibold uppercase text-stone-600"><%= t(".total_brews") %></p>
        <p data-testid="total-brews" class="mt-2 text-3xl font-bold text-stone-950"><%= @statistics[:totals][:total_brews] %></p>
      </div>
```

with:

```erb
      <div data-testid="statistics-total-brews-card" class="rounded-lg border border-stone-200 bg-white p-5 shadow-sm">
        <div class="flex items-start justify-between gap-3">
          <p class="text-sm font-semibold uppercase text-stone-700"><%= t(".total_brews") %></p>
          <%= link_to t(".view_all"), brews_path, class: "text-sm font-semibold text-stone-950 underline decoration-stone-300 underline-offset-2 hover:decoration-stone-950" %>
        </div>
        <p data-testid="total-brews" class="mt-2 text-3xl font-bold text-stone-950"><%= @statistics[:totals][:total_brews] %></p>
      </div>
```

- [ ] **Step 7: Run dashboard and statistics tests**

Run:

```bash
bin/rails test test/controllers/home_controller_test.rb test/controllers/statistics_controller_test.rb
```

Expected: all tests pass.

- [ ] **Step 8: Commit entry points**

```bash
git add app/views/workspaces/show.html.erb app/views/statistics/index.html.erb config/locales/en.yml test/controllers/home_controller_test.rb test/controllers/statistics_controller_test.rb
git commit -m "feat: link brew and activity history"
```

---

### Task 6: Update Durable Docs And Verify

**Files:**
- Modify: `docs/coffee-core.md`
- Modify: `docs/navigation.md`
- Modify: `docs/statistics.md`

- [ ] **Step 1: Update coffee-core docs**

In `docs/coffee-core.md`, under `Included Now`, add:

```markdown
- Paginated all-time brew history with compact-card and hero-card views.
- Paginated all-time workspace activity history for brews, manual inventory adjustments, and equipment events.
```

- [ ] **Step 2: Update navigation docs**

In `docs/navigation.md`, under `Included Now`, add:

```markdown
- Dashboard `View all` links open all-time brew history from Latest brew and all-time activity history from Recent activity.
- Brew history is available at `/brews`, defaults to compact cards, and can switch to hero cards while preserving pagination.
- Activity history is available at `/activity` and uses dashboard-style activity cards.
```

- [ ] **Step 3: Update statistics docs**

In `docs/statistics.md`, under `Included Now`, add:

```markdown
- Statistics links to all-time brew history through a page-level all-brews button and the total-brews card.
```

Under `Date Range Rules`, add:

```markdown
- Links from statistics to brew history do not preserve the selected analytics date range; they always open all-time brew history.
```

- [ ] **Step 4: Run focused test suite**

Run:

```bash
bin/rails test test/models/history_paginator_test.rb test/services/workspace_activity_feed_test.rb test/controllers/brews_controller_test.rb test/controllers/activity_controller_test.rb test/controllers/home_controller_test.rb test/controllers/statistics_controller_test.rb
```

Expected: all focused tests pass with 0 failures and 0 errors.

- [ ] **Step 5: Run full test suite**

Run:

```bash
bin/rails test
```

Expected: full suite passes with 0 failures and 0 errors.

- [ ] **Step 6: Start the development server for user review**

Run:

```bash
bin/rails server -p 3001 -b 0.0.0.0
```

Expected: server starts on port 3001. If port 3001 is already occupied, use another available port and report it.

- [ ] **Step 7: Commit docs and final verification state**

```bash
git add docs/coffee-core.md docs/navigation.md docs/statistics.md
git commit -m "docs: document brew and activity history"
```

---

## Self-Review Notes

- Spec coverage: brew history, activity history, all-time default, compact default, hero option, dashboard links, statistics links, pagination, scoping, viewer access, contrast, and docs are covered by tasks.
- Placeholder scan: no unfinished-marker or deferred-work instructions remain.
- Type consistency: `HistoryPaginator#records`, `#previous_page`, `#next_page`, and `#any?` are used consistently by controller and views; `WorkspaceActivityFeed#records` is the single activity service API.
