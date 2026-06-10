# Dashboard Metrics Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the approved dashboard timer, mixed coffee metrics, stock/open inventory metrics, rough spend metrics, and last-4-week trend sparklines.

**Architecture:** Move dashboard aggregation into a dedicated `DashboardMetrics` service that returns plain hashes for the view. Keep `HomeController` responsible for loading existing hero/activity data. Render the metric cards with small ERB partials/helpers, and use a Stimulus controller only for the live "since last coffee" timer.

**Tech Stack:** Rails 8.1, Active Record, ERB, Tailwind utility classes, Stimulus, Minitest.

---

## File Map

- Create `app/services/dashboard_metrics.rb`: workspace-scoped dashboard aggregation, rough cost calculation, last-4-week comparison labels, and sparkline values.
- Create `test/services/dashboard_metrics_test.rb`: service tests for counts, costs, inventory, workspace isolation, and comparison labels.
- Modify `app/controllers/home_controller.rb`: load `@dashboard_metrics` and remove inline status-card queries.
- Modify `app/views/workspaces/show.html.erb`: place the timer first, keep existing hero cards unwrapped, and render the new metric grid.
- Modify `app/helpers/workspaces_helper.rb`: duration formatting and SVG sparkline point generation.
- Modify `config/locales/en.yml`: dashboard labels for the timer and metric cards.
- Create `app/javascript/controllers/dashboard_timer_controller.js`: live elapsed-time rendering.
- Create `test/assets/dashboard_timer_controller_test.rb`: source-level coverage for the Stimulus timer behavior.
- Modify `test/controllers/home_controller_test.rb`: rendered dashboard assertions for ordering, labels, hero preservation, trend text, and workspace isolation.
- Update `docs/status.md` and `docs/coffee-core.md`: document the dashboard metric enhancement.

## Task 1: Dashboard Metrics Service

**Files:**
- Create: `app/services/dashboard_metrics.rb`
- Test: `test/services/dashboard_metrics_test.rb`

- [ ] **Step 1: Write failing service tests**

Add tests that set `travel_to Time.zone.local(2026, 6, 10, 12, 0, 0)`, create workspace-local and other-workspace brews/external coffees, and assert:

```ruby
metrics = DashboardMetrics.new(workspace:, now: Time.current).call
assert_equal 2, metrics[:counts][:coffees_today]
assert_equal 3, metrics[:counts][:coffees_this_week]
assert_equal 1, metrics[:counts][:brews_today]
assert_equal 1, metrics[:counts][:brews_this_week]
assert_equal 530, metrics[:spend][:today_cents]
assert_equal 830, metrics[:spend][:week_cents]
assert_equal external_today.occurred_at.to_i, metrics[:last_coffee_at].to_i
```

Add inventory assertions:

```ruby
assert_equal 1, metrics[:inventory][:stock_bag_count]
assert_equal 500.to_d, metrics[:inventory][:stock_grams]
assert_equal 370.to_d, metrics[:inventory][:open_grams]
```

Add comparison assertions:

```ruby
comparison = metrics[:comparisons][:coffees_today]
assert_equal "+100% over last 4 weeks", comparison[:label]
assert_equal "up", comparison[:direction]
assert_equal [1, 2, 3, 4, 5], comparison[:values]
```

- [ ] **Step 2: Run tests and confirm RED**

Run: `bin/rails test test/services/dashboard_metrics_test.rb`

Expected: failure because `DashboardMetrics` is not defined.

- [ ] **Step 3: Implement `DashboardMetrics`**

Implement a plain Ruby service with:

```ruby
DashboardMetrics.new(workspace:, now: Time.current).call
```

The returned hash must include `:counts`, `:inventory`, `:spend`, `:last_coffee_at`, and `:comparisons`.

Comparison labels are exactly:

- `+N% over last 4 weeks`
- `-N% over last 4 weeks`
- `same as last 4 weeks`
- `new over last 4 weeks`

- [ ] **Step 4: Run tests and confirm GREEN**

Run: `bin/rails test test/services/dashboard_metrics_test.rb`

Expected: all service tests pass.

## Task 2: Dashboard Rendering And Helpers

**Files:**
- Modify: `app/controllers/home_controller.rb`
- Modify: `app/views/workspaces/show.html.erb`
- Modify: `app/helpers/workspaces_helper.rb`
- Modify: `config/locales/en.yml`
- Test: `test/controllers/home_controller_test.rb`

- [ ] **Step 1: Write failing controller/view tests**

Add assertions that the timer appears before latest hero headings, metric labels render, trend labels include `over last 4 weeks`, and the existing hero card sections remain direct dashboard sections:

```ruby
assert_appears_before "dashboard-last-coffee-timer", "dashboard-latest-coffee-card"
assert_select "[data-testid=dashboard-latest-coffee-card]"
assert_select "[data-testid=dashboard-latest-best-brew-card]"
assert_select "[data-testid=dashboard-metric-coffees-today]"
assert_select "[data-testid=dashboard-metric-spent-this-week]", text: /over last 4 weeks/
```

- [ ] **Step 2: Run tests and confirm RED**

Run: `bin/rails test test/controllers/home_controller_test.rb`

Expected: failures for missing timer and new metric test ids.

- [ ] **Step 3: Wire controller, helpers, translations, and ERB**

Load `@dashboard_metrics = DashboardMetrics.new(workspace: current_workspace).call`.

Render:

- `dashboard-last-coffee-timer` before the hero section
- existing hero section without adding another card container
- metric cards for coffees, brews, bean stock, open grams, and spend
- sparklines for the six comparison-backed cards

- [ ] **Step 4: Run controller tests and confirm GREEN**

Run: `bin/rails test test/controllers/home_controller_test.rb`

Expected: all dashboard controller tests pass.

## Task 3: Live Timer Stimulus Controller

**Files:**
- Create: `app/javascript/controllers/dashboard_timer_controller.js`
- Test: `test/assets/dashboard_timer_controller_test.rb`

- [ ] **Step 1: Write failing source-level Stimulus test**

Assert the controller has a timestamp value, a value target, `setInterval`, `clearInterval`, and second-level formatting:

```ruby
assert_includes source, "static values = { sinceAt: Number }"
assert_includes source, "static targets = [ \"value\" ]"
assert_includes source, "setInterval"
assert_includes source, "clearInterval"
assert_includes source, "1000"
assert_includes source, "formatDuration"
```

- [ ] **Step 2: Run tests and confirm RED**

Run: `bin/rails test test/assets/dashboard_timer_controller_test.rb`

Expected: failure because the file does not exist.

- [ ] **Step 3: Implement controller**

Create a Stimulus controller that updates the visible elapsed duration every second and clears the interval on disconnect.

- [ ] **Step 4: Run asset test and confirm GREEN**

Run: `bin/rails test test/assets/dashboard_timer_controller_test.rb`

Expected: the asset test passes.

## Task 4: Docs And Final Verification

**Files:**
- Modify: `docs/status.md`
- Modify: `docs/coffee-core.md`

- [ ] **Step 1: Update docs**

Add one sentence to each doc describing the dashboard live timer, mixed coffee metric cards, stock/open inventory split, rough spend, and last-4-week trend sparklines.

- [ ] **Step 2: Run focused tests**

Run: `bin/rails test test/services/dashboard_metrics_test.rb test/controllers/home_controller_test.rb test/assets/dashboard_timer_controller_test.rb`

Expected: all focused tests pass.

- [ ] **Step 3: Run broader relevant tests**

Run: `bin/rails test test/services/workspace_statistics_test.rb test/controllers/statistics_controller_test.rb`

Expected: existing statistics behavior still passes.

- [ ] **Step 4: Start local server and visually inspect**

Run: `bin/dev`.

Open the dashboard in the in-app browser. Check normal desktop, wide desktop, and mobile viewport widths. Verify that the timer does not look awkward on wide monitors, hero cards are not wrapped inside another card container, metric text is readable, and sparklines render.

- [ ] **Step 5: Commit**

Commit the implementation with:

```bash
git add app/services/dashboard_metrics.rb test/services/dashboard_metrics_test.rb app/controllers/home_controller.rb app/views/workspaces/show.html.erb app/helpers/workspaces_helper.rb config/locales/en.yml app/javascript/controllers/dashboard_timer_controller.js test/assets/dashboard_timer_controller_test.rb test/controllers/home_controller_test.rb docs/status.md docs/coffee-core.md docs/superpowers/plans/2026-06-10-dashboard-metrics.md
git commit -m "Add dashboard coffee metrics"
```
