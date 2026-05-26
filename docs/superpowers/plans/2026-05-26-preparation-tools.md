# Preparation Tools Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add workspace preparation tools and snapshot selected tools on espresso brews.

**Architecture:** Add `PreparationTool` as the reusable workspace checklist item and `BrewPreparationTool` as the per-brew snapshot join. Keep the brew form server-rendered and reuse current workspace scoping/authorization patterns.

**Tech Stack:** Rails 8.1, Active Record, PostgreSQL, ERB views, Tailwind utility classes, Minitest.

---

## Tasks

### Task 1: Data Model

- [ ] Write model tests for valid preparation tools and brew tool snapshots.
- [ ] Add migrations for `preparation_tools` and `brew_preparation_tools`.
- [ ] Add `PreparationTool` and `BrewPreparationTool` models.
- [ ] Add associations to `Workspace` and `Brew`.
- [ ] Add fixtures for espresso tools.
- [ ] Run `env PARALLEL_WORKERS=1 bin/rails test test/models/preparation_tool_test.rb test/models/brew_preparation_tool_test.rb`.
- [ ] Commit with `git commit -m "Add preparation tool data model"`.

### Task 2: Tool Management

- [ ] Write controller tests for listing, creating, viewer denial, and workspace isolation.
- [ ] Add `resources :preparation_tools, only: %i[index new create]`.
- [ ] Add `PreparationToolsController`.
- [ ] Add index and new views.
- [ ] Link preparation tools from the dashboard.
- [ ] Run `env PARALLEL_WORKERS=1 bin/rails test test/controllers/preparation_tools_controller_test.rb`.
- [ ] Commit with `git commit -m "Add preparation tool screens"`.

### Task 3: Brew Checklist And Defaults

- [ ] Write brew controller tests for checklist rendering, snapshot creation, and last-brew tool defaults.
- [ ] Load active preparation tools in `BrewsController`.
- [ ] Render preparation tool checkboxes in the espresso form.
- [ ] Snapshot selected tools after brew creation.
- [ ] Preselect active tools from the current user's last brew.
- [ ] Run `env PARALLEL_WORKERS=1 bin/rails test test/controllers/brews_controller_test.rb test/models/brew_test.rb`.
- [ ] Commit with `git commit -m "Snapshot brew preparation tools"`.

### Task 4: Docs And Verification

- [ ] Add `docs/preparation-tools.md`.
- [ ] Update `docs/README.md`, `docs/coffee-core.md`, and `AGENTS.md`.
- [ ] Run `env PARALLEL_WORKERS=1 bin/rails test`.
- [ ] Run `env RUBOCOP_CACHE_ROOT=tmp/rubocop_cache bin/rubocop`.
- [ ] Run `bundle exec brakeman --quiet --no-pager --exit-on-warn --exit-on-error`.
- [ ] Confirm `http://miniknubbel.internal:3001` returns 200.
- [ ] Commit docs with `git commit -m "Document preparation tools"`.
