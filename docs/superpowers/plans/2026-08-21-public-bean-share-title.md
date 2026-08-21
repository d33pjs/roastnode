# Public Bean Share Title Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use exodos-dev:subagent-driven-development (recommended) or exodos-dev:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show the public bean share title beneath the coffee name with roast/blend and 404 fallbacks, and explain that behavior on the share form.

**Architecture:** Preserve the user-entered share title, including an intentional blank, in `PublicBeanShare` snapshots and refreshes. Resolve the public display line in `PublicBeanSharesHelper` from curated snapshot fields, then render it at a stable, tested hero position. Keep all user-facing copy in `config/locales/en.yml` and document the public contract.

**Tech Stack:** Rails 8, ERB, Action View helpers, I18n YAML, Minitest integration/helper tests, Tailwind CSS.

## Global Constraints

- The public hero order is roaster name, coffee name, share-title line, then hero statistic cards.
- Resolve the line in this order: snapshot share title; available roast/blend values joined as `Espresso · Blend`; `404 — share title not found`.
- If only roast type or blend type is present, show that single normalized value.
- The humorous text is a placeholder only: `Italian coffee called—it wants its hand gestures back.`
- Public rendering must continue to use curated snapshot data only.
- Do not add a database migration or a resolved subtitle field to the snapshot contract.
- Protect unrelated user changes and remain on `main`.

---

## File Structure

- `app/services/public_bean_share_snapshot_builder.rb`: preserve the submitted share title exactly in newly built snapshots.
- `app/services/public_bean_share_refresher.rb`: preserve an intentional blank title during automatic snapshot refreshes.
- `app/helpers/public_bean_shares_helper.rb`: own the public-safe fallback resolver and label normalization.
- `app/views/public_bean_pages/show.html.erb`: render the resolved share-title line in the hero.
- `app/views/public_bean_shares/_form.html.erb`: render the placeholder and explanatory help text.
- `config/locales/en.yml`: own the missing-title fallback, help copy, and placeholder.
- `test/services/public_bean_share_snapshot_builder_test.rb`: verify snapshot title preservation.
- `test/services/public_bean_share_refresher_test.rb`: verify refreshes do not regenerate a cleared title.
- `test/helpers/public_bean_shares_helper_test.rb`: verify every fallback branch without controller setup.
- `test/controllers/public_bean_pages_controller_test.rb`: verify public hero content, order, and removal of the duplicated display name.
- `test/controllers/public_bean_shares_controller_test.rb`: verify form guidance and placeholder.
- `docs/public-bean-sharing.md`: record the public hero title hierarchy and fallback contract.

---

### Task 1: Preserve Intentional Blank Share Titles

**Files:**
- Modify: `test/services/public_bean_share_snapshot_builder_test.rb`
- Modify: `test/services/public_bean_share_refresher_test.rb`
- Modify: `app/services/public_bean_share_snapshot_builder.rb`
- Modify: `app/services/public_bean_share_refresher.rb`

**Interfaces:**
- Consumes: `PublicBeanShareSnapshotBuilder.new(bean:, title:, selected_photo_attachment_ids:).call`.
- Produces: snapshot key `"title"` containing the submitted string, including `""`; `PublicBeanShareRefresher.refresh(share)` preserving `share.title == ""`.

- [ ] **Step 1: Write the failing snapshot-builder test**

Add this test to `test/services/public_bean_share_snapshot_builder_test.rb`:

```ruby
test "preserves an intentionally blank share title for public fallback rendering" do
  snapshot = PublicBeanShareSnapshotBuilder.new(
    bean: beans(:open_household),
    title: "",
    selected_photo_attachment_ids: []
  ).call

  assert_equal "", snapshot.fetch("title")
end
```

- [ ] **Step 2: Run the test and verify the current generated default fails it**

Run:

```bash
bin/rails test test/services/public_bean_share_snapshot_builder_test.rb
```

Expected: FAIL because `snapshot.fetch("title")` is currently the bean display name rather than `""`.

- [ ] **Step 3: Preserve the submitted title in the snapshot builder**

Change the first entry in `PublicBeanShareSnapshotBuilder#call`:

```ruby
payload = {
  "title" => title,
  "workspace" => workspace_payload,
  "bean" => bean_payload,
  # existing keys remain unchanged
}
```

Do not change `PublicBeanShare.default_title_for`; the new-share form still starts with its existing generated title.

- [ ] **Step 4: Run the snapshot-builder tests and verify green**

Run:

```bash
bin/rails test test/services/public_bean_share_snapshot_builder_test.rb
```

Expected: PASS.

- [ ] **Step 5: Write the failing refresher test**

Add this test to `test/services/public_bean_share_refresher_test.rb`:

```ruby
test "refresh preserves a cleared title for public fallback rendering" do
  bean = beans(:open_household)
  share = create_share(bean)
  share.update!(title: "", snapshot: share.snapshot.merge("title" => ""))

  PublicBeanShareRefresher.refresh(share)

  assert_equal "", share.reload.title
  assert_equal "", share.snapshot.fetch("title")
end
```

- [ ] **Step 6: Run the refresher test and verify it fails by regenerating the title**

Run:

```bash
bin/rails test test/services/public_bean_share_refresher_test.rb
```

Expected: FAIL because the refresher currently replaces a blank title with `PublicBeanShare.default_title_for(bean)`.

- [ ] **Step 7: Preserve the share record title during refresh**

Replace the generated-title assignment in `PublicBeanShareRefresher#refresh`:

```ruby
selected_photo_attachment_ids = share.valid_selected_photo_attachment_ids
title = share.title
snapshot = PublicBeanShareSnapshotBuilder.new(
  bean: share.bean,
  title:,
  selected_photo_attachment_ids:
).call
```

- [ ] **Step 8: Run both focused service suites**

Run:

```bash
bin/rails test test/services/public_bean_share_snapshot_builder_test.rb test/services/public_bean_share_refresher_test.rb
```

Expected: PASS with no errors or warnings.

- [ ] **Step 9: Commit the title-preservation behavior**

```bash
git add app/services/public_bean_share_snapshot_builder.rb app/services/public_bean_share_refresher.rb test/services/public_bean_share_snapshot_builder_test.rb test/services/public_bean_share_refresher_test.rb
git commit -m "Preserve blank public bean share titles"
```

---

### Task 2: Resolve and Render the Public Hero Share Title

**Files:**
- Modify: `test/helpers/public_bean_shares_helper_test.rb`
- Modify: `test/controllers/public_bean_pages_controller_test.rb`
- Modify: `app/helpers/public_bean_shares_helper.rb`
- Modify: `app/views/public_bean_pages/show.html.erb`
- Modify: `config/locales/en.yml`

**Interfaces:**
- Consumes: curated snapshot shape `{ "title" => String?, "bean" => { "roast_type" => String?, "blend_type" => String? } }`.
- Produces: `public_bean_share_title(snapshot) -> String` and `[data-testid="public-bean-share-title"]` in the public hero.

- [ ] **Step 1: Write failing helper tests for the complete fallback chain**

Add these tests near the top of `test/helpers/public_bean_shares_helper_test.rb`:

```ruby
test "share title prefers the snapshot title" do
  snapshot = {
    "title" => "Sunday spro club",
    "bean" => { "roast_type" => "espresso", "blend_type" => "blend" }
  }

  assert_equal "Sunday spro club", public_bean_share_title(snapshot)
end

test "share title falls back to normalized roast and blend types" do
  snapshot = {
    "title" => "",
    "bean" => { "roast_type" => "espresso", "blend_type" => "blend" }
  }

  assert_equal "Espresso · Blend", public_bean_share_title(snapshot)
end

test "share title uses the single available type" do
  snapshot = {
    "title" => nil,
    "bean" => { "roast_type" => "quick_drip", "blend_type" => nil }
  }

  assert_equal "Quick drip", public_bean_share_title(snapshot)
end

test "share title uses the missing-title message when no fallback data exists" do
  snapshot = { "title" => "", "bean" => {} }

  assert_equal "404 — share title not found", public_bean_share_title(snapshot)
end
```

- [ ] **Step 2: Run the helper suite and verify the missing method fails**

Run:

```bash
bin/rails test test/helpers/public_bean_shares_helper_test.rb
```

Expected: ERROR with `undefined method 'public_bean_share_title'`.

- [ ] **Step 3: Add the locale-backed resolver**

Add under `public_bean_rating` in `app/helpers/public_bean_shares_helper.rb`:

```ruby
def public_bean_share_title(snapshot)
  snapshot ||= {}
  return snapshot["title"] if snapshot["title"].present?

  bean = snapshot["bean"] || {}
  type_fallback = [ bean["roast_type"], bean["blend_type"] ]
    .compact_blank
    .map(&:humanize)
    .join(" · ")

  type_fallback.presence || t("public_bean_pages.show.share_title_missing")
end
```

Add this key beneath `public_bean_pages.show.roast_type` in `config/locales/en.yml`:

```yaml
      share_title_missing: "404 — share title not found"
```

- [ ] **Step 4: Run the helper suite and verify green**

Run:

```bash
bin/rails test test/helpers/public_bean_shares_helper_test.rb
```

Expected: PASS.

- [ ] **Step 5: Write the failing public-page placement test**

Add this test to `test/controllers/public_bean_pages_controller_test.rb`:

```ruby
test "hero shows the share title between the coffee name and statistic cards" do
  share = create_share(enabled: true)

  get public_bean_page_path(share.token)

  assert_response :success
  assert_select "[data-testid=public-bean-coffee-name]", text: share.snapshot.dig("bean", "name")
  assert_select "[data-testid=public-bean-share-title]", text: "Shared bean"
  assert_select "[data-testid=public-bean-share-title]", text: share.snapshot.dig("bean", "display_name"), count: 0
  assert_appears_before "data-testid=\"public-bean-coffee-name\"", "data-testid=\"public-bean-share-title\""
  assert_appears_before "data-testid=\"public-bean-share-title\"", "data-testid=\"public-bean-hero-stat-average-rating\""
end
```

- [ ] **Step 6: Run the controller test and verify the missing selector fails**

Run:

```bash
bin/rails test test/controllers/public_bean_pages_controller_test.rb
```

Expected: FAIL because `[data-testid=public-bean-share-title]` does not exist and the hero still renders `bean["display_name"]`.

- [ ] **Step 7: Replace the duplicated display-name block in the hero**

In `app/views/public_bean_pages/show.html.erb`, add a stable selector to the existing coffee-name heading and replace the conditional `bean["display_name"]` paragraph immediately below it:

```erb
<h1 data-testid="public-bean-coffee-name" class="mt-2 text-4xl font-black leading-tight text-rn-ink sm:text-6xl"><%= bean["name"].presence || snapshot["title"].presence || unknown %></h1>
<p data-testid="public-bean-share-title" class="mt-4 text-xl font-extrabold text-rn-muted"><%= public_bean_share_title(snapshot) %></p>
```

The following hero statistic grid remains unchanged with `mt-6`, preserving spacing and placing the title above Average rating.

- [ ] **Step 8: Run helper and public-page tests together**

Run:

```bash
bin/rails test test/helpers/public_bean_shares_helper_test.rb test/controllers/public_bean_pages_controller_test.rb
```

Expected: PASS with the custom title, fallback resolver, placement, and privacy assertions green.

- [ ] **Step 9: Commit the public hero behavior**

```bash
git add app/helpers/public_bean_shares_helper.rb app/views/public_bean_pages/show.html.erb config/locales/en.yml test/helpers/public_bean_shares_helper_test.rb test/controllers/public_bean_pages_controller_test.rb
git commit -m "Show share titles on public bean pages"
```

---

### Task 3: Explain Share-Title Placement and Defaults

**Files:**
- Modify: `test/controllers/public_bean_shares_controller_test.rb`
- Modify: `app/views/public_bean_shares/_form.html.erb`
- Modify: `config/locales/en.yml`
- Modify: `docs/public-bean-sharing.md`

**Interfaces:**
- Consumes: `public_bean_shares.form.title_help` and `public_bean_shares.form.title_placeholder` locale keys.
- Produces: title input `placeholder` text and `[data-testid="public-bean-share-title-help"]` guidance on both new and edit forms.

- [ ] **Step 1: Write the failing share-form guidance test**

Extend `test "writer can open new share form for own publishable bean"` in `test/controllers/public_bean_shares_controller_test.rb` with:

```ruby
assert_select "input[name=?][placeholder=?]",
  "public_bean_share[title]",
  "Italian coffee called—it wants its hand gestures back."
assert_select "[data-testid=public-bean-share-title-help]", text: /below the large coffee name/i
assert_select "[data-testid=public-bean-share-title-help]", text: /Espresso · Blend/
assert_select "[data-testid=public-bean-share-title-help]", text: /404 — share title not found/
```

- [ ] **Step 2: Run the controller suite and verify the new form assertions fail**

Run:

```bash
bin/rails test test/controllers/public_bean_shares_controller_test.rb
```

Expected: FAIL because the title input has no placeholder and the help element does not exist.

- [ ] **Step 3: Add the exact form copy to I18n**

Add beneath `public_bean_shares.form.title` in `config/locales/en.yml`:

```yaml
      title_help: "Shown below the large coffee name on the public bean page. Leave blank to use the roast type and blend type (for example, Espresso · Blend). If neither is available, visitors see ‘404 — share title not found’."
      title_placeholder: "Italian coffee called—it wants its hand gestures back."
```

- [ ] **Step 4: Render the placeholder and help text**

Replace the share-title field block in `app/views/public_bean_shares/_form.html.erb` with:

```erb
<div>
  <%= form.label :title, t(".title"), class: label_class %>
  <%= form.text_field :title, placeholder: t(".title_placeholder"), class: input_class %>
  <p data-testid="public-bean-share-title-help" class="mt-1 text-sm font-semibold text-rn-muted"><%= t(".title_help") %></p>
</div>
```

- [ ] **Step 5: Run the share-management controller tests and verify green**

Run:

```bash
bin/rails test test/controllers/public_bean_shares_controller_test.rb
```

Expected: PASS.

- [ ] **Step 6: Document the hero hierarchy and fallback**

Add this bullet under `docs/public-bean-sharing.md` → `Included Now`:

```markdown
- A public hero ordered as roaster, large coffee name, and share title before the metric cards. A blank share title falls back to the available roast and blend types (for example, `Espresso · Blend`), then to `404 — share title not found` when neither type exists.
```

Add this sentence under `docs/public-bean-sharing.md` → `Snapshot Refresh`:

```markdown
An intentionally blank share title remains blank in the share record and snapshot during refresh so the public page can apply the roast/blend fallback consistently.
```

- [ ] **Step 7: Run all focused feature tests**

Run:

```bash
bin/rails test test/services/public_bean_share_snapshot_builder_test.rb test/services/public_bean_share_refresher_test.rb test/helpers/public_bean_shares_helper_test.rb test/controllers/public_bean_pages_controller_test.rb test/controllers/public_bean_shares_controller_test.rb
```

Expected: PASS with no errors or warnings.

- [ ] **Step 8: Run formatting and the full test suite**

Run:

```bash
bin/rubocop
bin/rails test
```

Expected: RuboCop reports no offenses and the full test suite passes.

- [ ] **Step 9: Commit the form guidance and documentation**

```bash
git add app/views/public_bean_shares/_form.html.erb config/locales/en.yml test/controllers/public_bean_shares_controller_test.rb docs/public-bean-sharing.md
git commit -m "Explain public bean share title defaults"
```

---

### Task 4: Start the Local Review Server

**Files:**
- No file changes.

**Interfaces:**
- Consumes: the completed and verified Rails application.
- Produces: `bin/dev` running inside the `roastnode-dev` tmux session and reachable on the configured development host/port.

- [ ] **Step 1: Stop a stale project tmux session if one exists**

Run:

```bash
tmux has-session -t roastnode-dev 2>/dev/null && tmux kill-session -t roastnode-dev
```

Expected: the old `roastnode-dev` session is absent or stopped without touching unrelated tmux sessions.

- [ ] **Step 2: Start `bin/dev` in the required project session**

Run:

```bash
tmux new-session -d -s roastnode-dev -c /Users/d33pjs/Documents/developing/roastnode bin/dev
```

Expected: `tmux ls` lists `roastnode-dev`.

- [ ] **Step 3: Verify the server output and reachability**

Run:

```bash
tmux capture-pane -pt roastnode-dev -S -80
curl -I http://localhost:3001
```

Expected: the development processes remain running and the HTTP response confirms the Rails server is reachable on port 3001.
