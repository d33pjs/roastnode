# Public Bean Comparison Badges Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use exodos-dev:subagent-driven-development (recommended) or exodos-dev:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add privacy-safe workspace ranking badges for public bean rating and channeling, and move public bean Links below the taste profile.

**Architecture:** A new `PublicBeanComparisonRanker` aggregates display-equivalent values for beans in one workspace and returns only rank/count pairs. `PublicBeanShareSnapshotBuilder` persists those pairs in the curated snapshot, while workspace-wide bean/brew refresh propagation keeps them current. The public view renders a small snapshot-only badge partial and uses a single-column Details flow.

**Tech Stack:** Rails 8.1, Active Record, Minitest, ERB, Tailwind CSS, existing public bean snapshot/media architecture.

## Global Constraints

- Rank only current beans in the shared bean's workspace.
- One rated brew qualifies for rating; one espresso brew qualifies for channeling.
- Rating is rounded to one decimal before higher-is-better ranking.
- Channeling is rounded to an integer percentage before lower-is-better ranking.
- Ties use standard competition ranking.
- Suppress a badge when the shared bean lacks the metric or fewer than two beans qualify.
- Store only rank and eligible count in public snapshots; never expose competing bean identities, IDs, values, or lifecycle data.
- Render TOP 1/2/3 with distinctive inline icons and gold/silver/bronze treatment; later ranks are neutral and text-only.
- Preserve existing public-share access, media, and external-link security behavior.

---

### Task 1: Workspace Bean Comparison Ranker

**Files:**
- Create: `app/services/public_bean_comparison_ranker.rb`
- Create: `test/services/public_bean_comparison_ranker_test.rb`

**Interfaces:**
- Consumes: `PublicBeanComparisonRanker.new(bean: Bean)` where the bean is persisted and belongs to a workspace.
- Produces: `#call -> Hash<String, Hash<String, Integer>>`, with optional `average_rating` and `channeling` entries containing `rank` and `eligible_count`.

- [ ] **Step 1: Write failing rating tests**

Create `test/services/public_bean_comparison_ranker_test.rb` with focused tests and local record helpers:

```ruby
require "test_helper"

class PublicBeanComparisonRankerTest < ActiveSupport::TestCase
  test "ranks rounded average rating higher first with competition ties" do
    workspace = create_workspace("Ranking")
    first = create_bean(workspace:, name: "First")
    tied = create_bean(workspace:, name: "Tied")
    third = create_bean(workspace:, name: "Third")

    create_brew(first, rating: 5, channeling: false)
    create_brew(tied, rating: 5, channeling: true)
    create_brew(third, rating: 4, channeling: false)

    assert_equal({ "rank" => 1, "eligible_count" => 3 }, comparison(first, "average_rating"))
    assert_equal({ "rank" => 1, "eligible_count" => 3 }, comparison(tied, "average_rating"))
    assert_equal({ "rank" => 3, "eligible_count" => 3 }, comparison(third, "average_rating"))
  end

  test "ties ratings at the displayed one decimal precision" do
    workspace = create_workspace("Rounded ranking")
    first = create_bean(workspace:, name: "Rounded first")
    second = create_bean(workspace:, name: "Rounded second")

    [ 4, 5 ].each { |rating| create_brew(first, rating:, channeling: false) }
    ([ 5 ] * 9 + [ 4 ] * 11).each { |rating| create_brew(second, rating:, channeling: false) }

    assert_equal "4.5", public_average(first)
    assert_equal "4.5", public_average(second)
    assert_equal({ "rank" => 1, "eligible_count" => 2 }, comparison(first, "average_rating"))
    assert_equal({ "rank" => 1, "eligible_count" => 2 }, comparison(second, "average_rating"))
  end

  test "omits rating comparison until two beans have rated brews" do
    bean = create_bean(workspace: create_workspace("Single ranking"), name: "Only rated")
    create_brew(bean, rating: 5, channeling: false)

    assert_nil PublicBeanComparisonRanker.new(bean:).call["average_rating"]
  end

  private
    def create_workspace(name)
      Workspace.create!(name:, kind: "household", default_currency: "EUR")
    end

    def comparison(bean, metric)
      PublicBeanComparisonRanker.new(bean:).call.fetch(metric)
    end

    def public_average(bean)
      ratings = bean.brews.where.not(rating: nil).pluck(:rating)
      (ratings.sum.to_d / ratings.size).round(1).to_s("F")
    end

    def create_bean(workspace:, name:)
      workspace.beans.create!(
        name:,
        roaster_name: "Comparison Roaster",
        bag_size_grams: 250,
        remaining_grams: 250,
        grind_state: "whole_bean",
        opened_on: Date.current
      )
    end

    def create_brew(bean, rating:, channeling:, method: "espresso")
      bean.workspace.brews.create!(
        user: users(:one),
        bean:,
        method:,
        bean_weight_grams: 1,
        rating:,
        channeling:
      )
    end
end
```

- [ ] **Step 2: Run the rating tests and verify RED**

Run: `bin/rails test test/services/public_bean_comparison_ranker_test.rb`

Expected: ERROR with `uninitialized constant PublicBeanComparisonRanker`, proving the new service is absent.

- [ ] **Step 3: Implement rating ranking minimally**

Create `app/services/public_bean_comparison_ranker.rb` with the public interface, workspace-scoped brew projection, one-decimal rating aggregation, and `comparison_for` helper:

```ruby
class PublicBeanComparisonRanker
  def initialize(bean:)
    @bean = bean
  end

  def call
    {
      "average_rating" => comparison_for(average_ratings, higher_is_better: true)
    }.compact
  end

  private
    attr_reader :bean

    def average_ratings
      grouped_brews.filter_map do |bean_id, brews|
        ratings = brews.filter_map(&:rating)
        next if ratings.empty?

        [ bean_id, (ratings.sum.to_d / ratings.size).round(1) ]
      end.to_h
    end

    def grouped_brews
      @grouped_brews ||= workspace_brews.group_by(&:bean_id)
    end

    def workspace_brews
      @workspace_brews ||= Brew
        .where(workspace_id: bean.workspace_id)
        .select(:bean_id, :method, :rating, :channeling)
        .to_a
    end

    def comparison_for(values, higher_is_better:)
      current_value = values[bean.id]
      return if current_value.nil? || values.size < 2

      better_count = values.values.count do |value|
        higher_is_better ? value > current_value : value < current_value
      end

      { "rank" => better_count + 1, "eligible_count" => values.size }
    end
end
```

- [ ] **Step 4: Run rating tests and verify GREEN**

Run: `bin/rails test test/services/public_bean_comparison_ranker_test.rb`

Expected: all rating tests PASS.

- [ ] **Step 5: Add failing channeling and workspace-isolation tests**

Before `private`, add:

```ruby
test "ranks rounded channeling lower first with competition ties" do
  workspace = create_workspace("Channeling ranking")
  zero = create_bean(workspace:, name: "Zero")
  tied_zero = create_bean(workspace:, name: "Tied zero")
  channeled = create_bean(workspace:, name: "Channeled")

  create_brew(zero, rating: nil, channeling: false)
  create_brew(tied_zero, rating: nil, channeling: false)
  create_brew(channeled, rating: nil, channeling: true)

  assert_equal({ "rank" => 1, "eligible_count" => 3 }, comparison(zero, "channeling"))
  assert_equal({ "rank" => 1, "eligible_count" => 3 }, comparison(tied_zero, "channeling"))
  assert_equal({ "rank" => 3, "eligible_count" => 3 }, comparison(channeled, "channeling"))
end

test "excludes Quick Drip and other workspaces from channeling comparison" do
  workspace = create_workspace("Isolated ranking")
  current = create_bean(workspace:, name: "Current")
  peer = create_bean(workspace:, name: "Peer")
  quick_drip_only = create_bean(workspace:, name: "Quick Drip only")
  create_brew(current, rating: nil, channeling: true)
  create_brew(peer, rating: nil, channeling: false)
  create_brew(quick_drip_only, rating: 5, channeling: nil, method: "quick_drip")

  other_workspace = create_workspace("Other ranking")
  other = create_bean(workspace: other_workspace, name: "Other")
  create_brew(other, rating: 5, channeling: false)

  assert_equal({ "rank" => 2, "eligible_count" => 2 }, comparison(current, "channeling"))
  assert_nil PublicBeanComparisonRanker.new(bean: quick_drip_only).call["channeling"]
end
```

Replace the `create_brew` helper with a method that supplies Quick Drip's required brewer/cup fields when needed:

```ruby
def create_brew(bean, rating:, channeling:, method: "espresso")
  attributes = {
    user: users(:one),
    bean:,
    method:,
    bean_weight_grams: 1,
    rating:,
    channeling:
  }
  if method == "quick_drip"
    attributes[:brewer] = bean.workspace.equipment.create!(name: "Ranking Brewer", kind: "brewer")
    attributes[:machine_cups] = 1
  end

  bean.workspace.brews.create!(attributes)
end
```

- [ ] **Step 6: Run channeling tests and verify RED**

Run: `bin/rails test test/services/public_bean_comparison_ranker_test.rb`

Expected: FAIL because `call` has no `channeling` entry.

- [ ] **Step 7: Implement channeling ranking minimally**

Extend `#call` and add:

```ruby
def call
  {
    "average_rating" => comparison_for(average_ratings, higher_is_better: true),
    "channeling" => comparison_for(channeling_percentages, higher_is_better: false)
  }.compact
end

def channeling_percentages
  grouped_brews.filter_map do |bean_id, brews|
    espresso_brews = brews.select(&:espresso?)
    next if espresso_brews.empty?

    percentage = ((espresso_brews.count(&:channeling?).to_d / espresso_brews.size) * 100).round
    [ bean_id, percentage ]
  end.to_h
end
```

- [ ] **Step 8: Run service tests and commit**

Run: `bin/rails test test/services/public_bean_comparison_ranker_test.rb`

Expected: all tests PASS.

Commit:

```bash
git add app/services/public_bean_comparison_ranker.rb test/services/public_bean_comparison_ranker_test.rb
git commit -m "Add workspace bean comparison rankings"
```

### Task 2: Snapshot Integration and Workspace Refresh Propagation

**Files:**
- Modify: `app/services/public_bean_share_snapshot_builder.rb`
- Modify: `app/services/public_bean_share_refresher.rb`
- Modify: `test/services/public_bean_share_snapshot_builder_test.rb`
- Modify: `test/services/public_bean_share_refresher_test.rb`

**Interfaces:**
- Consumes: `PublicBeanComparisonRanker.new(bean:).call` from Task 1.
- Produces: snapshot key `comparisons`; `PublicBeanShareRefresher.shares_for(Bean|Brew)` returns all bean shares in the record's workspace.

- [ ] **Step 1: Write a failing snapshot privacy test**

Add a test that uses `beans(:open_household)` and `beans(:second_open_household)`, creates a rated/channeled espresso brew for the second bean, builds the first bean's snapshot, and asserts:

```ruby
assert_equal({ "rank" => 2, "eligible_count" => 2 }, snapshot.dig("comparisons", "average_rating"))
assert_equal({ "rank" => 1, "eligible_count" => 2 }, snapshot.dig("comparisons", "channeling"))
assert_not_includes snapshot.to_json, beans(:second_open_household).name
assert_no_internal_ids(snapshot)
```

- [ ] **Step 2: Run the snapshot test and verify RED**

Run: `bin/rails test test/services/public_bean_share_snapshot_builder_test.rb`

Expected: FAIL because `snapshot["comparisons"]` is absent.

- [ ] **Step 3: Add comparisons to the snapshot**

In `PublicBeanShareSnapshotBuilder#call`, insert:

```ruby
"comparisons" => PublicBeanComparisonRanker.new(bean:).call,
```

Keep it beside `stats` so public aggregate data remains grouped.

- [ ] **Step 4: Run snapshot tests and verify GREEN**

Run: `bin/rails test test/services/public_bean_share_snapshot_builder_test.rb`

Expected: all tests PASS.

- [ ] **Step 5: Write failing refresher-scope tests**

Add tests proving a bean or brew change returns both public bean shares in the same workspace and excludes a public bean share from `other_household`. Use `create_share` for both household beans and a separately created other-workspace share, then assert the IDs returned by `shares_for` exactly match the affected workspace.

- [ ] **Step 6: Run refresher tests and verify RED**

Run: `bin/rails test test/services/public_bean_share_refresher_test.rb`

Expected: FAIL because Bean/Brew cases currently return only the directly linked bean share.

- [ ] **Step 7: Expand only Bean/Brew refresh scope**

Replace the two cases in `PublicBeanShareRefresher.shares_for`:

```ruby
when Bean, Brew
  PublicBeanShare.where(workspace_id: record.workspace_id)
```

Leave Equipment, User, RecordLink, Workspace, and direct PublicBeanShare behavior unchanged.

- [ ] **Step 8: Run focused tests and commit**

Run:

```bash
bin/rails test test/services/public_bean_comparison_ranker_test.rb test/services/public_bean_share_snapshot_builder_test.rb test/services/public_bean_share_refresher_test.rb
```

Expected: all tests PASS.

Commit:

```bash
git add app/services/public_bean_share_snapshot_builder.rb app/services/public_bean_share_refresher.rb test/services/public_bean_share_snapshot_builder_test.rb test/services/public_bean_share_refresher_test.rb
git commit -m "Store and refresh public bean comparisons"
```

### Task 3: Public Comparison Badges

**Files:**
- Create: `app/views/public_bean_pages/_comparison_badge.html.erb`
- Modify: `app/views/public_bean_pages/show.html.erb`
- Modify: `config/locales/en.yml`
- Modify: `test/controllers/public_bean_pages_controller_test.rb`

**Interfaces:**
- Consumes: partial locals `comparison:` and `metric:` where comparison may be nil.
- Produces: `[data-testid="public-bean-<metric>-comparison-badge"]`, optional inline SVG with `data-rank-icon`, and accessible localized rank copy.

- [ ] **Step 1: Write failing badge rendering tests**

Create a helper in the controller test that deep-merges comparison data into a persisted share snapshot. Add tests for:

```ruby
set_comparisons(share,
  "average_rating" => { "rank" => 1, "eligible_count" => 8 },
  "channeling" => { "rank" => 2, "eligible_count" => 6 })

assert_select "[data-testid=public-bean-average-rating-comparison-badge][aria-label='TOP 1 OF 8 BEANS']"
assert_select "[data-testid=public-bean-average-rating-comparison-badge] svg[data-rank-icon=trophy]"
assert_select "[data-testid=public-bean-channeling-comparison-badge][aria-label='TOP 2 OF 6 BEANS']"
assert_select "[data-testid=public-bean-channeling-comparison-badge] svg[data-rank-icon=medal]"
```

Add another test for rank 3 medal and rank 4 with `svg` count zero. Add a legacy-snapshot test that deletes `comparisons` and asserts zero badges.

- [ ] **Step 2: Run public-page tests and verify RED**

Run: `bin/rails test test/controllers/public_bean_pages_controller_test.rb`

Expected: FAIL because comparison badges do not render.

- [ ] **Step 3: Add localized copy and the reusable partial**

Under `public_bean_pages.show` in `config/locales/en.yml`, add:

```yaml
comparison_rank: "TOP %{rank} OF %{count} BEANS"
```

Create `_comparison_badge.html.erb` so it:

- returns no markup when comparison is blank;
- maps ranks 1/2/3 to gold/silver/bronze Tailwind classes;
- uses neutral `rn` surface/line/muted tokens for rank 4+;
- renders a small inline trophy SVG for rank 1 and medal SVG for ranks 2/3, both `aria-hidden="true"` and `focusable="false"`;
- renders no SVG for rank 4+;
- uses `t("public_bean_pages.show.comparison_rank", rank:, count:)` for both visible copy and `aria-label`;
- includes the metric-specific test ID.

- [ ] **Step 4: Render badges from the snapshot**

At the top of `show.html.erb`, add:

```erb
<% comparisons = snapshot["comparisons"] || {} %>
```

Render the rating badge after the five bean icons and the channeling badge after the channeling percentage:

```erb
<%= render "comparison_badge", comparison: comparisons["average_rating"], metric: "average-rating" %>
<%= render "comparison_badge", comparison: comparisons["channeling"], metric: "channeling" %>
```

- [ ] **Step 5: Run public-page tests and commit**

Run: `bin/rails test test/controllers/public_bean_pages_controller_test.rb`

Expected: all tests PASS.

Commit:

```bash
git add app/views/public_bean_pages/_comparison_badge.html.erb app/views/public_bean_pages/show.html.erb config/locales/en.yml test/controllers/public_bean_pages_controller_test.rb
git commit -m "Show public bean comparison badges"
```

### Task 4: Full-Width Details, Taste, Links, and Public Note Flow

**Files:**
- Modify: `app/views/public_bean_pages/show.html.erb`
- Modify: `test/controllers/public_bean_pages_controller_test.rb`

**Interfaces:**
- Produces ordered test IDs: `public-bean-details`, `public-bean-tasting-notes`, `public-bean-links`, `public-bean-public-note`.

- [ ] **Step 1: Write a failing document-order regression test**

Create a public bean link before building the share, request the public page, and assert:

```ruby
assert_select "[data-testid=public-bean-details]"
assert_select "[data-testid=public-bean-tasting-notes]"
assert_select "[data-testid=public-bean-links] a[data-testid=public-bean-link]"
assert_appears_before 'data-testid="public-bean-details"', 'data-testid="public-bean-tasting-notes"'
assert_appears_before 'data-testid="public-bean-tasting-notes"', 'data-testid="public-bean-links"'
assert_no_match(/lg:grid-cols-\[minmax\(0,1fr\)_minmax\(18rem,24rem\)\]/, response.body)
```

- [ ] **Step 2: Run the regression test and verify RED**

Run: `bin/rails test test/controllers/public_bean_pages_controller_test.rb`

Expected: FAIL because tasting notes/links lack ordered test IDs and the desktop sidebar grid is present.

- [ ] **Step 3: Replace the sidebar section with one content flow**

Change the section wrapper to a full-width bordered section without a desktop grid. Keep the Details heading and detail-card `<dl>` first. Add `data-testid="public-bean-tasting-notes"` to tasting notes. Move the Links section immediately after tasting notes with `data-testid="public-bean-links"`. Move public note after Links with `data-testid="public-bean-public-note"`. Preserve the existing external-link attributes and styles.

- [ ] **Step 4: Run the public-page regression suite and commit**

Run: `bin/rails test test/controllers/public_bean_pages_controller_test.rb`

Expected: all tests PASS.

Commit:

```bash
git add app/views/public_bean_pages/show.html.erb test/controllers/public_bean_pages_controller_test.rb
git commit -m "Fix public bean details and links flow"
```

### Task 5: Product Documentation and Feature Verification

**Files:**
- Modify: `docs/public-bean-sharing.md`
- Modify: `docs/status.md`

**Interfaces:**
- Produces durable rules for workspace-only rankings, snapshot privacy, badge eligibility, and Details/Links order.

- [ ] **Step 1: Update product documentation**

Add the approved ranking rules and layout flow to `docs/public-bean-sharing.md`. Update the public bean sharing bullet in `docs/status.md` to mention rating/channeling workspace comparison badges.

- [ ] **Step 2: Run focused verification**

Run:

```bash
bin/rails test test/services/public_bean_comparison_ranker_test.rb test/services/public_bean_share_snapshot_builder_test.rb test/services/public_bean_share_refresher_test.rb test/controllers/public_bean_pages_controller_test.rb
bin/rubocop app/services/public_bean_comparison_ranker.rb app/services/public_bean_share_snapshot_builder.rb app/services/public_bean_share_refresher.rb test/services/public_bean_comparison_ranker_test.rb test/services/public_bean_share_snapshot_builder_test.rb test/services/public_bean_share_refresher_test.rb test/controllers/public_bean_pages_controller_test.rb
```

Expected: all tests PASS and RuboCop reports no offenses.

- [ ] **Step 3: Commit documentation**

```bash
git add docs/public-bean-sharing.md docs/status.md
git commit -m "Document public bean comparison badges"
```

- [ ] **Step 4: Start or reuse the local server and visually inspect**

Run `bin/dev` in the `roastnode-dev` tmux session on port 3001. Open an enabled public bean share in the in-app browser. Verify desktop and mobile widths for rating/channeling badge wrapping, gold/silver/bronze distinction, rank 4 text-only behavior, Details → taste profile → Links → public note order, and absence of horizontal overflow.
