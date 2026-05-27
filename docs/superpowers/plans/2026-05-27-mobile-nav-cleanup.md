# Mobile Navigation Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the jumpy floating mobile bottom bar and duplicate dashboard action strips with one stable navigation structure.

**Architecture:** Keep the Rails partial-based app shell. `shared/_app_navigation.html.erb` owns the full navigation; the dashboard becomes an overview page instead of a second command surface. Styling stays in `app/assets/tailwind/application.css` and the compiled Tailwind build.

**Tech Stack:** Rails views, Rails integration tests, Tailwind CSS, Hotwire-compatible HTML.

---

### Task 1: Lock The Navigation Contract With Tests

**Files:**
- Modify: `test/controllers/home_controller_test.rb`
- Modify: `test/controllers/statistics_controller_test.rb`

- [ ] **Step 1: Update the app navigation test to require the approved IA**

Replace the assertions in `test "signed-in app renders themed shell navigation"` with assertions for:

```ruby
assert_select "[data-testid=app-navigation]"
assert_select "[data-testid=app-mobile-menu]"
assert_select "[data-testid=app-desktop-navigation]"
assert_select "[data-testid=app-mobile-navigation]", count: 0
assert_select "[data-testid=app-nav-more]", count: 0
assert_select "a[data-testid=app-nav-log][href=?]", new_brew_path
assert_select "a[data-testid=app-nav-dashboard][href=?]", dashboard_path
assert_select "a[data-testid=app-nav-beans][href=?]", beans_path
assert_select "a[data-testid=app-nav-statistics][href=?]", statistics_path
assert_select "[data-testid=app-nav-gear]"
assert_select "[data-testid=app-nav-account]"
assert_select "[data-testid=app-nav-settings]"
assert_select "a[href=?]", equipment_index_path, text: I18n.t("shared.app_navigation.equipment")
assert_select "a[href=?]", preparation_tools_path, text: I18n.t("shared.app_navigation.preparation_tools")
assert_select "a[href=?]", edit_profile_path, text: I18n.t("shared.app_navigation.profile")
assert_select "a[href=?]", memberships_path, text: I18n.t("shared.app_navigation.members")
assert_select "a[href=?]", workspace_export_path, text: I18n.t("shared.app_navigation.export")
assert_select "a[href=?]", new_beanconqueror_import_path, text: I18n.t("shared.app_navigation.import")
assert_select "form[action=?][method=post]", session_path
assert_no_match(/fixed inset-x-3 bottom-3/, response.body)
assert_no_match user.email_address, response.body
```

- [ ] **Step 2: Update dashboard tests to reject duplicated command strips**

In dashboard tests, replace assertions requiring `dashboard-primary-actions`, `dashboard-secondary-actions`, and dashboard links to `new_brew_path`, `new_bean_path`, `new_equipment_path`, and `new_equipment_event_path` with:

```ruby
assert_select "[data-testid=dashboard-primary-actions]", count: 0
assert_select "[data-testid=dashboard-secondary-actions]", count: 0
assert_select "main [href=?]", new_brew_path, count: 0
assert_select "main [href=?]", new_bean_path, count: 0
assert_select "main [href=?]", new_equipment_path, count: 0
assert_select "main [href=?]", new_equipment_event_path, count: 0
```

- [ ] **Step 3: Run the focused test and verify it fails**

Run:

```bash
bin/rails test test/controllers/home_controller_test.rb
```

Expected: failure because the current app still renders the floating mobile nav, `More`, and dashboard command strips.

- [ ] **Step 4: Update the statistics dashboard-link test**

In `test/controllers/statistics_controller_test.rb`, change the dashboard link assertion to target the global Stats navigation link:

```ruby
assert_select "a[data-testid=app-nav-statistics][href=?]", statistics_path, text: I18n.t("shared.app_navigation.statistics")
```

### Task 2: Implement Stable Single Navigation

**Files:**
- Modify: `app/views/shared/_app_navigation.html.erb`
- Delete: `app/views/shared/_app_navigation_more_links.html.erb`
- Modify: `config/locales/en.yml`

- [ ] **Step 1: Replace the navigation partial**

Use a normal-flow shell:

- top-level desktop links: Log, Dashboard, Beans, Stats
- grouped desktop details: Gear, Account, Settings
- mobile header with visible Log link and one normal-flow menu disclosure
- no `fixed` mobile nav
- no `More` menu

- [ ] **Step 2: Split grouped links into named groups**

Remove `shared/_app_navigation_more_links.html.erb` and render named grouped links directly from `shared/_app_navigation.html.erb`: Gear includes equipment/preparation tools, Account includes profile/members/workspace/invites, Settings includes import/export, and sign out remains last.

- [ ] **Step 3: Update translations**

Add translation labels for `gear`, `account`, `menu`, and keep `settings` for import/export. Remove reliance on `more`.

### Task 3: Remove Dashboard Command Duplicates

**Files:**
- Modify: `app/views/workspaces/show.html.erb`
- Modify: `test/controllers/home_controller_test.rb`

- [ ] **Step 1: Remove dashboard action sections**

Delete the `dashboard-primary-actions` header block and `dashboard-secondary-actions` section. Keep the dashboard as overview, hero cards, stats, open beans, and recent activity.

- [ ] **Step 2: Keep contextual view links**

Keep `View all` for open beans because it is contextual navigation from a list, not a duplicate global command.

### Task 4: Stabilize Styling

**Files:**
- Modify: `app/assets/tailwind/application.css`

- [ ] **Step 1: Remove floating mobile nav component styles**

Remove styles for `.rn-mobile-nav-link`, `.rn-mobile-nav-icon`, `.rn-mobile-nav-link-log`, and `.rn-mobile-nav-log-icon`.

- [ ] **Step 2: Add stable navigation styles**

Add styles for `.rn-app-nav`, `.rn-nav-menu-panel`, `.rn-nav-group`, `.rn-nav-group-title`, `.rn-nav-sub-link`, and `.rn-nav-sign-out`.

- [ ] **Step 3: Rebuild Tailwind**

Run:

```bash
bin/rails tailwindcss:build
```

Expected: compiled CSS updates without errors.

### Task 5: Verify And Commit

**Files:**
- All changed files

- [ ] **Step 1: Run focused tests**

Run:

```bash
bin/rails test test/controllers/home_controller_test.rb
```

Expected: passing.

- [ ] **Step 2: Run broader verification**

Run:

```bash
env PARALLEL_WORKERS=1 bin/rails test
```

Expected: passing serial suite.

- [ ] **Step 3: Commit**

Run:

```bash
git add docs/superpowers/specs/2026-05-27-mobile-first-ui-refresh-design.md docs/superpowers/plans/2026-05-27-mobile-nav-cleanup.md app/views/shared/_app_navigation.html.erb app/views/shared/_app_navigation_more_links.html.erb app/views/workspaces/show.html.erb app/assets/tailwind/application.css config/locales/en.yml test/controllers/home_controller_test.rb test/controllers/statistics_controller_test.rb
git commit -m "Simplify mobile app navigation"
```
