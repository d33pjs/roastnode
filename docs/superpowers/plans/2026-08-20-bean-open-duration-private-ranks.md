# Bean Open Duration and Private Ranks Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use exodos-dev:subagent-driven-development (recommended) or exodos-dev:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stop bean open age at the correct lifecycle boundary and show the existing workspace comparison ranks in the private Bean Analytics rating and channeling cards.

**Architecture:** Introduce a domain-named `BeanOpenDuration` calculator shared by private statistics and public snapshots. Generalize the public-only ranker to `BeanComparisonRanker`, return its live result from `BeanStatistics`, and move the existing badge markup into a shared partial used by both private and public pages. Public pages continue to read curated snapshot data; private pages calculate ranks live.

**Tech Stack:** Ruby 3.3.12, Rails 8.1.3.1, Active Record, ERB, Tailwind CSS, Minitest, PostgreSQL 17.11

## Global Constraints

- Work directly on `main`; do not create a branch or worktree.
- Preserve unrelated user changes and inspect `git status --short` before each commit.
- Use red-green TDD: run each stated red test before adding its production implementation, then rerun it green.
- Run Rails tests with `POSTGRES_PORT=55433` and `PARALLEL_WORKERS=1` so the existing Roastnode database and serial test assumptions are preserved.
- Treat `Workspace` as the ownership boundary. Ranking queries must remain scoped to `bean.workspace_id`.
- Preserve the public snapshot boundary: public pages render stored `PublicBeanShare#snapshot` rank/count data and never query live peer data.
- Never expose peer bean identities, raw values, IDs, or links in comparison badges.
- Do not add a migration, a used-up timestamp, a stored private rank, or a workspace rankings page.
- Keep the local development server running in tmux session `roastnode-dev` on port 3001 after the user-facing work is complete.

---

## Task 1: Add one lifecycle-aware open-duration calculator

**Files:**

- Create: `app/services/bean_open_duration.rb`
- Create: `test/services/bean_open_duration_test.rb`
- Modify: `app/services/bean_statistics.rb`
- Modify: `test/services/bean_statistics_test.rb`
- Modify: `app/services/public_bean_share_snapshot_builder.rb`
- Modify: `test/services/public_bean_share_snapshot_builder_test.rb`

### Step 1: Write the calculator tests

- [ ] Create `test/services/bean_open_duration_test.rb` with a small `build_bean` helper and these exact lifecycle cases:

```ruby
require "test_helper"

class BeanOpenDurationTest < ActiveSupport::TestCase
  test "open bag runs through today" do
    bean = build_bean(opened_on: Date.new(2026, 5, 10))

    assert_equal 16, BeanOpenDuration.new(
      bean:,
      latest_brew_at: Time.zone.local(2026, 5, 20, 9),
      today: Date.new(2026, 5, 26)
    ).call
  end

  test "finished bag stops at finished date" do
    bean = build_bean(
      opened_on: Date.new(2026, 5, 10),
      finished_at: Time.zone.local(2026, 5, 23, 9)
    )

    assert_equal 13, BeanOpenDuration.new(bean:, today: Date.new(2026, 6, 1)).call
  end

  test "archived bag stops at archived date" do
    bean = build_bean(
      opened_on: Date.new(2026, 5, 10),
      archived_at: Time.zone.local(2026, 5, 21, 9)
    )

    assert_equal 11, BeanOpenDuration.new(bean:, today: Date.new(2026, 6, 1)).call
  end

  test "used up bag stops at latest brew date" do
    bean = build_bean(opened_on: Date.new(2026, 5, 10), remaining_grams: 0)

    assert_equal 12, BeanOpenDuration.new(
      bean:,
      latest_brew_at: Time.zone.local(2026, 5, 22, 9),
      today: Date.new(2026, 6, 1)
    ).call
  end

  test "used up bag without a brew falls back to today" do
    bean = build_bean(opened_on: Date.new(2026, 5, 10), remaining_grams: 0)

    assert_equal 22, BeanOpenDuration.new(bean:, today: Date.new(2026, 6, 1)).call
  end

  test "stock bag has no open duration" do
    assert_nil BeanOpenDuration.new(bean: build_bean(opened_on: nil), today: Date.new(2026, 6, 1)).call
  end

  test "terminal date before opening clamps to zero" do
    bean = build_bean(
      opened_on: Date.new(2026, 5, 10),
      archived_at: Time.zone.local(2026, 5, 8, 9)
    )

    assert_equal 0, BeanOpenDuration.new(bean:, today: Date.new(2026, 6, 1)).call
  end

  private
    def build_bean(opened_on:, remaining_grams: 100, finished_at: nil, archived_at: nil)
      Bean.new(
        name: "Duration bean",
        bag_size_grams: 250,
        remaining_grams:,
        opened_on:,
        finished_at:,
        archived_at:
      )
    end
end
```

### Step 2: Run the calculator test red

- [ ] Run:

```bash
env POSTGRES_PORT=55433 PARALLEL_WORKERS=1 bin/rails test test/services/bean_open_duration_test.rb
```

Expected: failure with `NameError: uninitialized constant BeanOpenDuration`.

### Step 3: Implement the shared calculator

- [ ] Create `app/services/bean_open_duration.rb`:

```ruby
class BeanOpenDuration
  def initialize(bean:, latest_brew_at: nil, today: Date.current)
    @bean = bean
    @latest_brew_at = latest_brew_at
    @today = today.to_date
  end

  def call
    return if bean.opened_on.blank? || bean.stock?

    [ (end_date - bean.opened_on).to_i, 0 ].max
  end

  private
    attr_reader :bean, :latest_brew_at, :today

    def end_date
      case bean.bag_status
      when "finished"
        bean.finished_at.to_date
      when "archived"
        bean.archived_at.to_date
      when "used_up"
        latest_brew_at&.to_date || today
      else
        today
      end
    end
end
```

This intentionally ignores `latest_brew_at` for an open bean. It uses the supplied date only for the used-up state, whose model currently has no terminal timestamp.

### Step 4: Run the calculator test green

- [ ] Rerun the Step 2 command.

Expected: 7 runs, 7 assertions, 0 failures, 0 errors.

### Step 5: Write private statistics integration regressions

- [ ] In `test/services/bean_statistics_test.rb`, add a test that travels beyond a finished bean's end date and asserts both the existing finished duration and the analytics open age stop at 13 days:

```ruby
test "stops open age when a bag is finished" do
  travel_to Time.zone.local(2026, 6, 1, 12) do
    bean = workspaces(:household).beans.create!(
      name: "Finished open age",
      bag_size_grams: 250,
      remaining_grams: 14,
      opened_on: Date.new(2026, 5, 10),
      finished_at: Time.zone.local(2026, 5, 23, 9)
    )

    statistics = BeanStatistics.new(bean:).call

    assert_equal 13, statistics[:totals][:open_age_days]
    assert_equal 13, statistics[:totals][:finished_open_days]
  end
end
```

- [ ] Add a used-up integration test proving the cutoff uses the latest all-time brew, not `Date.current`:

```ruby
test "stops used up open age at the latest brew" do
  travel_to Time.zone.local(2026, 6, 1, 12) do
    bean = workspaces(:household).beans.create!(
      name: "Used up open age",
      bag_size_grams: 250,
      remaining_grams: 0,
      opened_on: Date.new(2026, 5, 10)
    )
    create_brew(
      bean:,
      grinder: equipment(:household_grinder),
      machine: equipment(:household_machine),
      grind_setting: "10",
      occurred_at: Time.zone.local(2026, 5, 22, 9, 30)
    )

    assert_equal 12, BeanStatistics.new(bean:).call[:totals][:open_age_days]
  end
end
```

- [ ] Extend the existing `create_brew` helper to accept `occurred_at:` with its present May 24 timestamp as the default, and pass that keyword into `workspace.brews.create!`.

### Step 6: Run the private integration tests red

- [ ] Run:

```bash
env POSTGRES_PORT=55433 PARALLEL_WORKERS=1 bin/rails test test/services/bean_statistics_test.rb
```

Expected: the finished test receives 22 instead of 13 and the used-up test receives 22 instead of 12.

### Step 7: Route private statistics through the calculator

- [ ] Replace `BeanStatistics#open_age_days` with:

```ruby
def open_age_days
  BeanOpenDuration.new(
    bean:,
    latest_brew_at: bean.brews.maximum(:occurred_at)
  ).call
end
```

Use `bean.brews.maximum(:occurred_at)`, not the filtered `brews` array, so lifecycle age remains an all-time bag fact if date filtering is reintroduced.

### Step 8: Run the private integration tests green

- [ ] Rerun the Step 6 command.

Expected: all `BeanStatisticsTest` cases pass.

### Step 9: Write public snapshot regressions

- [ ] In `test/services/public_bean_share_snapshot_builder_test.rb`, add one test for an open bag whose most recent brew predates today and one for an archived bag whose archived date predates today. Use `travel_to`, build snapshots through the existing test helper, and assert:

```ruby
assert_equal 16, snapshot.dig("stats", "open_duration_days")
```

for an open bean from May 10 observed May 26, even when its latest brew was May 20; and:

```ruby
assert_equal 11, snapshot.dig("stats", "open_duration_days")
```

for a bean opened May 10 and archived May 21, observed June 1.

### Step 10: Run the public snapshot regressions red

- [ ] Run:

```bash
env POSTGRES_PORT=55433 PARALLEL_WORKERS=1 bin/rails test test/services/public_bean_share_snapshot_builder_test.rb
```

Expected: the open-bean assertion reports the latest-brew duration rather than 16. The archived case may already pass and protects the shared integration.

### Step 11: Route public snapshots through the calculator

- [ ] Replace `PublicBeanShareSnapshotBuilder#open_duration_days` with:

```ruby
def open_duration_days
  BeanOpenDuration.new(
    bean:,
    latest_brew_at: brews.filter_map(&:occurred_at).max
  ).call
end
```

Keep `terminal_at` because the timeline payload still uses it.

### Step 12: Verify and commit Task 1

- [ ] Run:

```bash
env POSTGRES_PORT=55433 PARALLEL_WORKERS=1 bin/rails test test/services/bean_open_duration_test.rb test/services/bean_statistics_test.rb test/services/public_bean_share_snapshot_builder_test.rb
bin/rubocop app/services/bean_open_duration.rb app/services/bean_statistics.rb app/services/public_bean_share_snapshot_builder.rb test/services/bean_open_duration_test.rb test/services/bean_statistics_test.rb test/services/public_bean_share_snapshot_builder_test.rb
git diff --check
git status --short
```

Expected: all focused tests pass, RuboCop reports no offenses, the diff check is empty, and status contains only Task 1 files.

- [ ] Commit:

```bash
git add app/services/bean_open_duration.rb app/services/bean_statistics.rb app/services/public_bean_share_snapshot_builder.rb test/services/bean_open_duration_test.rb test/services/bean_statistics_test.rb test/services/public_bean_share_snapshot_builder_test.rb
git commit -m "Correct bean open duration lifecycle"
```

---

## Task 2: Generalize the ranker and expose live comparisons from BeanStatistics

**Files:**

- Create: `app/services/bean_comparison_ranker.rb`
- Delete: `app/services/public_bean_comparison_ranker.rb`
- Create: `test/services/bean_comparison_ranker_test.rb`
- Delete: `test/services/public_bean_comparison_ranker_test.rb`
- Modify: `app/services/bean_statistics.rb`
- Modify: `test/services/bean_statistics_test.rb`
- Modify: `app/services/public_bean_share_snapshot_builder.rb`
- Modify: `test/services/public_bean_share_snapshot_builder_test.rb`

### Step 1: Rename the ranker test and make its contract domain-named

- [ ] Move `test/services/public_bean_comparison_ranker_test.rb` to `test/services/bean_comparison_ranker_test.rb` with `git mv`.
- [ ] Rename `PublicBeanComparisonRankerTest` to `BeanComparisonRankerTest`.
- [ ] Replace all `PublicBeanComparisonRanker.new` calls with `BeanComparisonRanker.new`.
- [ ] Keep every existing assertion for one-decimal rating ties, whole-percent channeling ties, the two-bean minimum, Quick Drip exclusion, and workspace isolation unchanged.

### Step 2: Run the renamed ranker test red

- [ ] Run:

```bash
env POSTGRES_PORT=55433 PARALLEL_WORKERS=1 bin/rails test test/services/bean_comparison_ranker_test.rb
```

Expected: failure with `NameError: uninitialized constant BeanComparisonRanker`.

### Step 3: Rename the service without changing ranking behavior

- [ ] Move `app/services/public_bean_comparison_ranker.rb` to `app/services/bean_comparison_ranker.rb` with `git mv`.
- [ ] Rename only the class declaration to:

```ruby
class BeanComparisonRanker
```

- [ ] Preserve the existing `workspace_brews` projection exactly:

```ruby
Brew
  .where(workspace_id: bean.workspace_id)
  .select(:bean_id, :method, :rating, :channeling)
  .to_a
```

### Step 4: Update public snapshot construction and run ranker/snapshot tests green

- [ ] In `PublicBeanShareSnapshotBuilder#call`, change:

```ruby
"comparisons" => BeanComparisonRanker.new(bean:).call,
```

- [ ] Run:

```bash
env POSTGRES_PORT=55433 PARALLEL_WORKERS=1 bin/rails test test/services/bean_comparison_ranker_test.rb test/services/public_bean_share_snapshot_builder_test.rb
```

Expected: all tests pass.

### Step 5: Write the private statistics comparison test

- [ ] In `test/services/bean_statistics_test.rb`, add a focused test that creates a current bean and a peer in one new workspace, gives the current bean rating 5 with no channeling and the peer rating 4 with channeling, then asserts:

```ruby
assert_equal(
  { "rank" => 1, "eligible_count" => 2 },
  statistics.dig(:comparisons, "average_rating")
)
assert_equal(
  { "rank" => 1, "eligible_count" => 2 },
  statistics.dig(:comparisons, "channeling")
)
```

Use this setup before the assertions so the eligible pool is exactly two beans and is independent of household fixtures:

```ruby
workspace = Workspace.create!(name: "Private rankings", kind: "household", default_currency: "EUR")
Membership.create!(workspace:, user: users(:one), role: "owner")
current = workspace.beans.create!(
  name: "Current ranked bean",
  bag_size_grams: 250,
  remaining_grams: 200,
  grind_state: "whole_bean",
  opened_on: Date.current
)
peer = workspace.beans.create!(
  name: "Peer ranked bean",
  bag_size_grams: 250,
  remaining_grams: 200,
  grind_state: "whole_bean",
  opened_on: Date.current
)
create_ranked_brew(bean: current, rating: 5, channeling: false)
create_ranked_brew(bean: peer, rating: 4, channeling: true)

statistics = BeanStatistics.new(bean: current).call
```

Add this private helper next to the existing `create_brew` helper:

```ruby
def create_ranked_brew(bean:, rating:, channeling:)
  bean.workspace.brews.create!(
    user: users(:one),
    bean:,
    grinder: bean.workspace.equipment.create!(name: "Ranking grinder", kind: "grinder"),
    machine: bean.workspace.equipment.create!(name: "Ranking machine", kind: "machine"),
    bean_weight_grams: 18,
    ground_weight_grams: 18,
    dose_grams: 18,
    beverage_grams: 42,
    method: "espresso",
    rating:,
    channeling:
  )
end
```

### Step 6: Run the private comparison test red

- [ ] Run:

```bash
env POSTGRES_PORT=55433 PARALLEL_WORKERS=1 bin/rails test test/services/bean_statistics_test.rb
```

Expected: both comparison assertions fail because `statistics[:comparisons]` is absent.

### Step 7: Add comparisons to BeanStatistics

- [ ] Add `comparisons:` to `BeanStatistics#call`:

```ruby
def call
  {
    totals:,
    averages:,
    rates:,
    comparisons:,
    distributions:,
    best_brews:,
    recent_brews:
  }
end
```

- [ ] Add the private method:

```ruby
def comparisons
  @comparisons ||= BeanComparisonRanker.new(bean:).call
end
```

Do not derive comparisons from the possibly filtered private statistics arrays. The shared ranker owns the approved all-time, workspace-wide pool.

### Step 8: Verify and commit Task 2

- [ ] Run:

```bash
env POSTGRES_PORT=55433 PARALLEL_WORKERS=1 bin/rails test test/services/bean_comparison_ranker_test.rb test/services/bean_statistics_test.rb test/services/public_bean_share_snapshot_builder_test.rb test/services/public_bean_share_refresher_test.rb
bin/rubocop app/services/bean_comparison_ranker.rb app/services/bean_statistics.rb app/services/public_bean_share_snapshot_builder.rb test/services/bean_comparison_ranker_test.rb test/services/bean_statistics_test.rb test/services/public_bean_share_snapshot_builder_test.rb
git diff --check
git status --short
```

Expected: focused tests pass, RuboCop reports no offenses, and no reference to `PublicBeanComparisonRanker` remains outside historical design/plan documents.

- [ ] Confirm the production/test code search:

```bash
rg -n "PublicBeanComparisonRanker" app test
```

Expected: no output.

- [ ] Commit:

```bash
git add app/services/bean_comparison_ranker.rb app/services/bean_statistics.rb app/services/public_bean_share_snapshot_builder.rb test/services/bean_comparison_ranker_test.rb test/services/bean_statistics_test.rb test/services/public_bean_share_snapshot_builder_test.rb app/services/public_bean_comparison_ranker.rb test/services/public_bean_comparison_ranker_test.rb
git commit -m "Share bean comparison ranking"
```

---

## Task 3: Share the badge component and render ranks in private Bean Analytics

**Files:**

- Create: `app/views/shared/_bean_comparison_badge.html.erb`
- Delete: `app/views/public_bean_pages/_comparison_badge.html.erb`
- Modify: `app/views/public_bean_pages/show.html.erb`
- Modify: `app/views/beans/show.html.erb`
- Modify: `config/locales/en.yml`
- Modify: `test/controllers/beans_controller_test.rb`
- Modify: `test/controllers/public_bean_pages_controller_test.rb`

### Step 1: Write private badge rendering assertions

- [ ] Extend `test "show renders bean analytics"` in `test/controllers/beans_controller_test.rb`. Before the request, calculate the exact expected live comparisons:

```ruby
comparisons = BeanComparisonRanker.new(bean:).call
rating_comparison = comparisons.fetch("average_rating")
channeling_comparison = comparisons.fetch("channeling")
```

- [ ] After the request, assert both shared badge instances use private test IDs and the exact localized accessible copy:

```ruby
assert_select(
  "[data-testid=bean-average-rating-comparison-badge][aria-label=?]",
  I18n.t(
    "shared.bean_comparison_rank",
    rank: rating_comparison.fetch("rank"),
    count: rating_comparison.fetch("eligible_count")
  )
)
assert_select(
  "[data-testid=bean-channeling-comparison-badge][aria-label=?]",
  I18n.t(
    "shared.bean_comparison_rank",
    rank: channeling_comparison.fetch("rank"),
    count: channeling_comparison.fetch("eligible_count")
  )
)
```

- [ ] Add a separate controller test using `beans(:second_open_household)`, which has no brews and therefore cannot have a current rating or channeling value. Sign in as `users(:one)`, request that bean, assert success, then assert:

```ruby
assert_select "[data-testid^=bean-][data-testid$='-comparison-badge']", count: 0
```

### Step 2: Run the private controller tests red

- [ ] Run:

```bash
env POSTGRES_PORT=55433 PARALLEL_WORKERS=1 bin/rails test test/controllers/beans_controller_test.rb
```

Expected: the new badge selectors match zero elements.

### Step 3: Move the badge markup to a shared partial

- [ ] Move `app/views/public_bean_pages/_comparison_badge.html.erb` to `app/views/shared/_bean_comparison_badge.html.erb` with `git mv`.
- [ ] Preserve the existing class map and SVG paths exactly.
- [ ] Change the translation and test ID lines to:

```erb
<% copy = t("shared.bean_comparison_rank", rank:, count:) %>
```

and:

```erb
data-testid="<%= testid_prefix %>-<%= metric %>-comparison-badge"
```

The partial interface is therefore `comparison:`, `metric:`, and `testid_prefix:`. It still renders nothing when `comparison.blank?`.

### Step 4: Move the comparison translation to shared scope

- [ ] In `config/locales/en.yml`, add:

```yaml
shared:
  bean_comparison_rank: "TOP %{rank} OF %{count} BEANS"
```

Place the key inside the existing top-level `shared` mapping. Remove `public_bean_pages.show.comparison_rank` after both callers use the shared key.

### Step 5: Point the public page at the shared partial

- [ ] Replace both public renders with:

```erb
<%= render "shared/bean_comparison_badge", comparison: comparisons["average_rating"], metric: "average-rating", testid_prefix: "public-bean" %>
```

and:

```erb
<%= render "shared/bean_comparison_badge", comparison: comparisons["channeling"], metric: "channeling", testid_prefix: "public-bean" %>
```

Existing public selectors and visual treatments must remain unchanged.

### Step 6: Render badges in the private analytics cards

- [ ] In the Average Rating card in `app/views/beans/show.html.erb`, immediately after the numeric value paragraph, add:

```erb
<%= render "shared/bean_comparison_badge",
  comparison: @bean_statistics[:comparisons]["average_rating"],
  metric: "average-rating",
  testid_prefix: "bean" %>
```

- [ ] In the Channeling card, immediately after `bean-channeling-count`, add:

```erb
<%= render "shared/bean_comparison_badge",
  comparison: @bean_statistics[:comparisons]["channeling"],
  metric: "channeling",
  testid_prefix: "bean" %>
```

The badge belongs inside each existing card and below its current value/context. Do not add a new row or rankings section.

### Step 7: Verify podium and neutral behavior on both surfaces

- [ ] Keep the existing public controller assertions for rank 1 trophy, ranks 2/3 medal, and rank 4 with no SVG.
- [ ] Update any test translation lookup from `public_bean_pages.show.comparison_rank` to `shared.bean_comparison_rank`.
- [ ] Run:

```bash
env POSTGRES_PORT=55433 PARALLEL_WORKERS=1 bin/rails test test/controllers/beans_controller_test.rb test/controllers/public_bean_pages_controller_test.rb
```

Expected: both controller files pass, proving the private badges render and public markup remains compatible.

### Step 8: Verify and commit Task 3

- [ ] Run:

```bash
env POSTGRES_PORT=55433 PARALLEL_WORKERS=1 bin/rails test test/services/bean_comparison_ranker_test.rb test/services/bean_statistics_test.rb test/controllers/beans_controller_test.rb test/controllers/public_bean_pages_controller_test.rb
bin/rubocop app/services/bean_comparison_ranker.rb app/services/bean_statistics.rb test/services/bean_comparison_ranker_test.rb test/services/bean_statistics_test.rb test/controllers/beans_controller_test.rb test/controllers/public_bean_pages_controller_test.rb
git diff --check
git status --short
```

Expected: all focused tests pass, RuboCop reports no offenses, and status contains only Task 3 files.

- [ ] Commit:

```bash
git add app/views/shared/_bean_comparison_badge.html.erb app/views/public_bean_pages/show.html.erb app/views/beans/show.html.erb config/locales/en.yml test/controllers/beans_controller_test.rb test/controllers/public_bean_pages_controller_test.rb app/views/public_bean_pages/_comparison_badge.html.erb
git commit -m "Show comparison ranks in bean analytics"
```

---

## Task 4: Document, audit, and visually verify the completed behavior

**Files:**

- Modify: `docs/bean-analytics.md`
- Modify: `docs/public-bean-sharing.md`
- Modify: `docs/status.md`

### Step 1: Update durable product documentation

- [ ] Update `docs/bean-analytics.md` to state:

  - open bags count through today;
  - finished and archived bags stop on their respective lifecycle date;
  - used-up bags stop on their latest brew date, falling back to today only when no brew exists;
  - stock bags have no open duration and negative durations clamp to zero;
  - Average Rating and Channeling cards show live workspace comparison badges using the public badge contract;
  - rankings include all non-deleted beans in the workspace, require two eligible beans, use displayed precision and competition ties, and reveal only rank/count.

- [ ] Update `docs/public-bean-sharing.md` to record that snapshot open duration uses the shared lifecycle calculator while public comparisons remain curated snapshot values rather than live queries.
- [ ] Add a concise completed entry to `docs/status.md` describing corrected terminal open age and private analytics badges.

### Step 2: Run the complete focused regression set

- [ ] Run:

```bash
env POSTGRES_PORT=55433 PARALLEL_WORKERS=1 bin/rails test test/services/bean_open_duration_test.rb test/services/bean_comparison_ranker_test.rb test/services/bean_statistics_test.rb test/services/public_bean_share_snapshot_builder_test.rb test/services/public_bean_share_refresher_test.rb test/controllers/beans_controller_test.rb test/controllers/public_bean_pages_controller_test.rb
```

Expected: 0 failures and 0 errors.

### Step 3: Run static checks and the full serial test suite

- [ ] Run:

```bash
bin/rubocop
env POSTGRES_PORT=55433 PARALLEL_WORKERS=1 bin/rails test
git diff --check
```

Expected: all Ruby files pass RuboCop; the full Rails suite has 0 failures and 0 errors; the diff check produces no output.

### Step 4: Start or confirm the local development server

- [ ] Inspect the session and current listener:

```bash
tmux ls
lsof -nP -iTCP:3001 -sTCP:LISTEN
```

- [ ] If `roastnode-dev` is absent or no process listens on port 3001, start it with the repository's documented tmux workflow and `bin/dev`. Do not terminate a healthy existing session.
- [ ] Confirm both addresses respond:

```bash
curl -I http://127.0.0.1:3001
curl -I http://miniknubbel.internal:3001
```

Expected: an HTTP response from both loopback and the network DNS name.

### Step 5: Complete desktop and mobile visual checks

- [ ] In the in-app browser, sign in and inspect a private bean with eligible rating and channeling peers at desktop width. Confirm:

  - the open-age value matches its lifecycle state;
  - both rank badges sit inside their respective Analytics cards below the existing values;
  - long `TOP N OF C BEANS` copy stays within the card;
  - gold/silver/bronze icon treatments and neutral rank 4+ treatment match the public page.

- [ ] Repeat the private page at mobile width. Confirm the Analytics cards stack without horizontal overflow and badges remain readable.
- [ ] Open an existing public bean share at desktop and mobile widths. Confirm the shared partial preserved its prior badge appearance and the public page performs no live peer disclosure.
- [ ] If visual inspection finds a layout defect, add a controller/view regression where practical, apply the smallest correction, and rerun Tasks 4 Steps 2–3.

### Step 6: Review privacy, query shape, and stale references

- [ ] Confirm no public controller or public view invokes the live ranker:

```bash
rg -n "BeanComparisonRanker" app/controllers app/views/public_bean_pages
```

Expected: no output.

- [ ] Confirm the obsolete production/test names and partial path are gone:

```bash
rg -n "PublicBeanComparisonRanker|public_bean_pages/comparison_badge|render \"comparison_badge\"" app test
```

Expected: no output.

- [ ] Inspect the ranker diff and confirm its only data projection remains `bean_id`, `method`, `rating`, and `channeling`, scoped by `workspace_id`.

### Step 7: Commit documentation and final adjustments

- [ ] Inspect status and commit only the planned documentation plus any verified visual correction:

```bash
git status --short
git diff --check
git add docs/bean-analytics.md docs/public-bean-sharing.md docs/status.md
git commit -m "Document bean duration and analytics ranks"
```

### Step 8: Final completion evidence

- [ ] Run one final clean-state check:

```bash
git status --short
git log -4 --oneline
```

Expected: the working tree is clean and the four task commits are visible.

- [ ] Report to the user:

  - the exact lifecycle cutoff behavior now implemented;
  - that private Bean Analytics displays the same rank badges as public shares;
  - focused/full test and RuboCop results;
  - desktop/mobile visual verification results;
  - the reachable local URL `http://miniknubbel.internal:3001`.
