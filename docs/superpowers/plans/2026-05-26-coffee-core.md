# Coffee Core Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build workspace-scoped beans, equipment, required-bean espresso brew logging, inventory deduction, and a real dashboard timeline without recipes.

**Architecture:** Add small Rails models for beans, equipment, brews, and inventory adjustments, each scoped to `Workspace`. Controllers load all domain data through `current_workspace`, use existing workspace policy helpers for role checks, and render server-side ERB pages styled with the current Tailwind conventions.

**Tech Stack:** Rails 8.1, Active Record, Minitest, ERB, Tailwind CSS, PostgreSQL.

---

## File Structure

- Create migrations for `beans`, `equipment`, `brews`, and `inventory_adjustments`.
- Create models: `Bean`, `Equipment`, `Brew`, `InventoryAdjustment`.
- Modify `Workspace` and `User` associations.
- Create controllers: `BeansController`, `EquipmentController`, `BrewsController`.
- Add views under `app/views/beans`, `app/views/equipment`, and `app/views/brews`.
- Modify `app/views/workspaces/show.html.erb` into a real dashboard.
- Update routes and English locale copy.
- Add fixtures and model/controller tests.
- Add docs for Coffee Core decisions.

## Task 1: Coffee Core Data Model

**Files:**

- Create: `db/migrate/*_create_beans.rb`
- Create: `db/migrate/*_create_equipment.rb`
- Create: `db/migrate/*_create_brews.rb`
- Create: `db/migrate/*_create_inventory_adjustments.rb`
- Create: `app/models/bean.rb`
- Create: `app/models/equipment.rb`
- Create: `app/models/brew.rb`
- Create: `app/models/inventory_adjustment.rb`
- Modify: `app/models/workspace.rb`
- Modify: `app/models/user.rb`
- Test: `test/models/bean_test.rb`
- Test: `test/models/brew_test.rb`
- Fixtures: `test/fixtures/beans.yml`, `test/fixtures/equipment.yml`, `test/fixtures/brews.yml`, `test/fixtures/inventory_adjustments.yml`

- [ ] Write model tests for bean default remaining grams, open scope, brew inventory deduction, adjustment creation, and retention marker calculation.
- [ ] Run model tests and confirm they fail because tables/models are missing.
- [ ] Add migrations, associations, enums, validations, scopes, and callbacks.
- [ ] Run `bin/rails db:migrate`.
- [ ] Run `bin/rails test test/models/bean_test.rb test/models/brew_test.rb`.
- [ ] Commit with `git commit -m "Add coffee core data model"`.

## Task 2: Beans Screens

**Files:**

- Create: `app/controllers/beans_controller.rb`
- Create: `app/views/beans/index.html.erb`
- Create: `app/views/beans/new.html.erb`
- Create: `app/views/beans/show.html.erb`
- Modify: `config/routes.rb`
- Modify: `config/locales/en.yml`
- Test: `test/controllers/beans_controller_test.rb`

- [ ] Write controller tests for listing workspace beans, creating a bean, viewer write denial, and cross-workspace isolation.
- [ ] Run tests and confirm controller/routes are missing.
- [ ] Implement beans index/new/create/show through `current_workspace`.
- [ ] Run `bin/rails test test/controllers/beans_controller_test.rb`.
- [ ] Commit with `git commit -m "Add workspace bean screens"`.

## Task 3: Equipment Screens

**Files:**

- Create: `app/controllers/equipment_controller.rb`
- Create: `app/views/equipment/index.html.erb`
- Create: `app/views/equipment/new.html.erb`
- Modify: `config/routes.rb`
- Modify: `config/locales/en.yml`
- Test: `test/controllers/equipment_controller_test.rb`

- [ ] Write controller tests for listing equipment, creating grinder/machine records, viewer write denial, and cross-workspace isolation.
- [ ] Run tests and confirm failures.
- [ ] Implement equipment index/new/create.
- [ ] Run `bin/rails test test/controllers/equipment_controller_test.rb`.
- [ ] Commit with `git commit -m "Add workspace equipment screens"`.

## Task 4: Required-Bean Espresso Logging

**Files:**

- Create: `app/controllers/brews_controller.rb`
- Create: `app/views/brews/new.html.erb`
- Create: `app/views/brews/show.html.erb`
- Modify: `config/routes.rb`
- Modify: `config/locales/en.yml`
- Test: `test/controllers/brews_controller_test.rb`

- [ ] Write controller tests for redirecting to new bean when no open bean exists, defaulting to the last active bean, falling back to first open bean, creating a brew, and denying viewer writes.
- [ ] Run tests and confirm failures.
- [ ] Implement brew new/create/show with required bean selection and optional grinder/machine selectors.
- [ ] Run `bin/rails test test/controllers/brews_controller_test.rb test/models/brew_test.rb`.
- [ ] Commit with `git commit -m "Add required bean espresso logging"`.

## Task 5: Dashboard Timeline

**Files:**

- Modify: `app/controllers/home_controller.rb`
- Modify: `app/views/workspaces/show.html.erb`
- Modify: `config/locales/en.yml`
- Test: `test/controllers/home_controller_test.rb`

- [ ] Write dashboard tests for real action links, open beans, compact status, and recent brew visibility.
- [ ] Run tests and confirm placeholder dashboard fails.
- [ ] Load dashboard data from `current_workspace`.
- [ ] Replace placeholder cards with real actions, status, open beans, and recent activity.
- [ ] Run `bin/rails test test/controllers/home_controller_test.rb`.
- [ ] Commit with `git commit -m "Add coffee core dashboard"`.

## Task 6: Docs And Verification

**Files:**

- Create: `docs/coffee-core.md`
- Modify: `docs/README.md`
- Modify: `AGENTS.md`

- [ ] Document that recipes are deferred and espresso brews require an open bean.
- [ ] Run `bin/rails test`.
- [ ] Run `env RUBOCOP_CACHE_ROOT=tmp/rubocop_cache bin/rubocop`.
- [ ] Run `bundle exec brakeman --quiet --no-pager --exit-on-warn --exit-on-error`.
- [ ] Browser-smoke bean creation, equipment creation, brew creation, inventory deduction, and dashboard timeline on `http://127.0.0.1:3001`.
- [ ] Commit with `git commit -m "Document coffee core"`.
