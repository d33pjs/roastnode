# Bean Editing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add rich bean metadata, editing, close/reopen, duplicate-with-photos, and duplicate-name disambiguation in espresso logging.

**Architecture:** Extend `beans` with explicit metadata columns and keep the `Bean` model responsible for display labels and duplication. Reuse one Rails partial for the bean form across new/edit, keep controller actions workspace-scoped, and update import/export mappings to preserve the new fields.

**Tech Stack:** Rails 8.1, Active Record migrations, PostgreSQL, Active Storage, ERB, Minitest.

---

### Task 1: Bean Metadata Schema And Model

**Files:**
- Create: `db/migrate/*_expand_bean_metadata.rb`
- Modify: `app/models/bean.rb`
- Test: `test/models/bean_test.rb`

- [ ] **Step 1: Write failing tests**
  - Assert `Bean` accepts `roast_type`, `blend_type`, `roast_degree`, `decaffeinated`, variety fields, and validates enum-like values.
  - Assert `duplicate_for_new_bag!` copies metadata/photos, resets `opened_on`, resets `remaining_grams` to `bag_size_grams`, and clears `archived_at`.
  - Assert `display_name_for_collection` appends opened date only when another open bean has the same roaster/name.

- [ ] **Step 2: Run red tests**
  - Run: `bin/rails test test/models/bean_test.rb`
  - Expected: failures for missing columns/methods.

- [ ] **Step 3: Implement schema/model**
  - Add metadata columns.
  - Add constants for roast/blend options.
  - Add validations.
  - Add `duplicate_for_new_bag!`, `close!`, `reopen!`, and duplicate-aware display helpers.

- [ ] **Step 4: Run green tests**
  - Run: `bin/rails test test/models/bean_test.rb`
  - Expected: 0 failures.

### Task 2: Bean Forms And Controller Actions

**Files:**
- Modify: `config/routes.rb`
- Modify: `app/controllers/beans_controller.rb`
- Create: `app/views/beans/_form.html.erb`
- Modify: `app/views/beans/new.html.erb`
- Create: `app/views/beans/edit.html.erb`
- Modify: `app/views/beans/show.html.erb`
- Test: `test/controllers/beans_controller_test.rb`

- [ ] **Step 1: Write failing controller/view tests**
  - Assert new/edit render all requested fields, including variety section.
  - Assert update accepts multiple photos and remaining grams.
  - Assert close/reopen mutate bag status.
  - Assert duplicate creates a new open bag with photos and full remaining amount.

- [ ] **Step 2: Run red tests**
  - Run: `bin/rails test test/controllers/beans_controller_test.rb`
  - Expected: failures for missing routes/actions/views.

- [ ] **Step 3: Implement controller/views**
  - Add `edit/update/close/reopen/duplicate`.
  - Reuse `_form`.
  - Add show-page action buttons and richer metadata display.

- [ ] **Step 4: Run green tests**
  - Run: `bin/rails test test/controllers/beans_controller_test.rb`
  - Expected: 0 failures.

### Task 3: Brew Form Bean Disambiguation

**Files:**
- Modify: `app/controllers/brews_controller.rb`
- Modify: `app/views/brews/_form.html.erb`
- Test: `test/controllers/brews_controller_test.rb`

- [ ] **Step 1: Write failing test**
  - Create two open beans with the same roaster/name.
  - Assert log espresso options include opened dates for those duplicate labels.

- [ ] **Step 2: Run red test**
  - Run: `bin/rails test test/controllers/brews_controller_test.rb`
  - Expected: duplicate options are not disambiguated yet.

- [ ] **Step 3: Implement label helper usage**
  - Use `Bean#display_name_for_collection` with the active open-bean collection.

- [ ] **Step 4: Run green test**
  - Run: `bin/rails test test/controllers/brews_controller_test.rb`
  - Expected: 0 failures.

### Task 4: Import Export And Docs

**Files:**
- Modify: `app/services/beanconqueror_import.rb`
- Modify: `app/services/workspace_export_builder.rb`
- Modify: `test/services/beanconqueror_import_test.rb`
- Modify: `test/controllers/workspace_exports_controller_test.rb`
- Modify: `docs/coffee-core.md`
- Modify: `docs/beanconqueror-import.md`
- Modify: `AGENTS.md`

- [ ] **Step 1: Write failing tests**
  - Assert import maps new Beanconqueror bean fields from fixture data.
  - Assert workspace export includes the new bean metadata.

- [ ] **Step 2: Run red tests**
  - Run: `bin/rails test test/services/beanconqueror_import_test.rb test/controllers/workspace_exports_controller_test.rb`
  - Expected: missing fields.

- [ ] **Step 3: Implement mapping and docs**
  - Persist new fields where source data exists.
  - Include fields in export payload.
  - Update docs for bean editing and import mapping.

- [ ] **Step 4: Run full verification and commit**
  - Run: `env PARALLEL_WORKERS=1 bin/rails test`
  - Run: `env RUBOCOP_CACHE_ROOT=tmp/rubocop_cache bin/rubocop`
  - Run: `bundle exec brakeman --quiet --no-pager --exit-on-warn --exit-on-error`
  - Run host smoke check for `miniknubbel.internal:3001`.
