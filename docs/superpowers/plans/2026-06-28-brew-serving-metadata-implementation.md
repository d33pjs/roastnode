# Brew Serving Metadata Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add private post-brew serving metadata for guest/cup style and make the brew detail page read clearly as the saved brew screen on mobile.

**Architecture:** Store serving metadata on `Brew` and update it through a focused member route, parallel to the existing taste correction action. Keep public snapshots unchanged, include the private fields in owner/admin exports and backups, and add a lightweight brew-detail heading so post-create redirects are visually clear.

**Tech Stack:** Rails 8.1, PostgreSQL, ERB, Turbo/Hotwire forms, Tailwind CSS, Rails test.

---

### Task 1: Schema And Model

**Files:**
- Create: `db/migrate/*_add_serving_metadata_to_brews.rb`
- Modify: `app/models/brew.rb`
- Test: `test/models/brew_test.rb`

- [ ] **Step 1: Write failing model tests**

Add tests proving that `guest_name` and `cup_style` normalize blank text to nil, `guest_name` clears when `served_for_guest` is false, and both strings reject values longer than 120 characters.

- [ ] **Step 2: Run model tests to verify RED**

Run: `env RBENV_VERSION=3.3.7 bin/rails test test/models/brew_test.rb`

Expected: failures for missing attributes/method behavior.

- [ ] **Step 3: Add migration and model code**

Add `served_for_guest:boolean, default: false, null: false`, `guest_name:string`, and `cup_style:string`; normalize string fields, validate max length 120, and clear `guest_name` before validation unless the guest flag is true.

- [ ] **Step 4: Run model tests to verify GREEN**

Run: `env RBENV_VERSION=3.3.7 bin/rails test test/models/brew_test.rb`

Expected: model tests pass.

### Task 2: Serving Route, Controller, And Detail UI

**Files:**
- Modify: `config/routes.rb`
- Modify: `app/controllers/brews_controller.rb`
- Modify: `app/views/brews/show.html.erb`
- Modify: `app/views/brews/_compact_card.html.erb`
- Modify: `config/locales/en.yml`
- Test: `test/controllers/brews_controller_test.rb`

- [ ] **Step 1: Write failing controller/view tests**

Add tests for writer visibility, serving-only update behavior, invalid re-render, viewer denial, private detail display, compact-card chip display, and the saved-brew heading on the detail page.

- [ ] **Step 2: Run controller tests to verify RED**

Run: `env RBENV_VERSION=3.3.7 bin/rails test test/controllers/brews_controller_test.rb`

Expected: failures for missing route, fields, and heading.

- [ ] **Step 3: Add route/controller/view code**

Add `patch :serving` as a member route, include it in write authorization and `set_brew`, add `serving` action with strong params for only `served_for_guest`, `guest_name`, and `cup_style`, and render a "Serving" panel on brew detail. Add a "Saved brew" heading and show private serving metadata in the detail grid and compact card.

- [ ] **Step 4: Run controller tests to verify GREEN**

Run: `env RBENV_VERSION=3.3.7 bin/rails test test/controllers/brews_controller_test.rb`

Expected: controller tests pass.

### Task 3: Exports, Backup Coverage, And Public Snapshot Guardrails

**Files:**
- Modify: `app/services/workspace_export_builder.rb`
- Modify: `app/services/workspace_csv_export_builder.rb`
- Test: `test/services/workspace_export_builder_test.rb`
- Test: `test/services/workspace_csv_export_builder_test.rb`
- Test: `test/services/instance_backup_builders_test.rb`
- Test: `test/services/public_brew_share_snapshot_builder_test.rb`
- Test: `test/services/public_bean_share_snapshot_builder_test.rb`
- Test: `test/services/public_recipe_share_snapshot_builder_test.rb`

- [ ] **Step 1: Write failing export and public snapshot tests**

Add assertions that private JSON/CSV/instance-readable backup payloads include serving metadata, and public brew/bean/recipe snapshots do not include it.

- [ ] **Step 2: Run service tests to verify RED**

Run: `env RBENV_VERSION=3.3.7 bin/rails test test/services/workspace_export_builder_test.rb test/services/workspace_csv_export_builder_test.rb test/services/instance_backup_builders_test.rb test/services/public_brew_share_snapshot_builder_test.rb test/services/public_bean_share_snapshot_builder_test.rb test/services/public_recipe_share_snapshot_builder_test.rb`

Expected: export tests fail for missing private fields; public snapshot guard tests should pass or fail only if a leak exists.

- [ ] **Step 3: Add private export fields**

Add `served_for_guest`, `guest_name`, and `cup_style` to workspace JSON and brew CSV exports. Instance-readable backups inherit `WorkspaceExportBuilder`, so verify they include the fields there too.

- [ ] **Step 4: Run service tests to verify GREEN**

Run: same command as Step 2.

Expected: service tests pass.

### Task 4: Documentation, Migration Check, And Final Verification

**Files:**
- Modify: `docs/coffee-core.md`
- Modify: `docs/workspace-export.md`
- Modify: `docs/navigation.md`

- [ ] **Step 1: Update docs**

Document private serving metadata, the post-brew Serving panel, export fields, and that brew detail is the intentional saved-brew landing screen after logging.

- [ ] **Step 2: Run database migration**

Run: `env RBENV_VERSION=3.3.7 bin/rails db:migrate`

Expected: migration succeeds and `db/schema.rb` includes the new columns.

- [ ] **Step 3: Run focused test suite**

Run: `env RBENV_VERSION=3.3.7 bin/rails test test/models/brew_test.rb test/controllers/brews_controller_test.rb test/services/workspace_export_builder_test.rb test/services/workspace_csv_export_builder_test.rb test/services/instance_backup_builders_test.rb test/services/public_brew_share_snapshot_builder_test.rb test/services/public_bean_share_snapshot_builder_test.rb test/services/public_recipe_share_snapshot_builder_test.rb`

Expected: all focused tests pass.

- [ ] **Step 4: Run security/static checks**

Run: `env RBENV_VERSION=3.3.7 bin/brakeman --quiet`

Expected: no new warnings.

- [ ] **Step 5: Start local server**

Run: `env RBENV_VERSION=3.3.7 bin/dev`

Expected: server starts on the project’s normal development port so the user can inspect the mobile detail flow.
