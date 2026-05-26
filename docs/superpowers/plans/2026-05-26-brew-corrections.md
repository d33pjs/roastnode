# Brew Corrections Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Allow workspace writers to edit and delete brews while keeping bean inventory and brew inventory adjustments consistent.

**Architecture:** Add model-level correction methods on `Brew` for inventory-safe updates and deletion. Extend `BrewsController` with `edit`, `update`, and `destroy`, reusing existing form option loading and preparation tool snapshot behavior. Add a shared brew form partial so new/edit stay aligned without inventing a second form.

**Tech Stack:** Rails 8.1, Active Record transactions, Minitest, ERB views, Tailwind.

---

## Tasks

### Task 1: Model Correction Rules

- [ ] Write failing model tests for same-bean delta, changed-bean delta, preparation tool replacement, and delete reversal.
- [ ] Add `Brew#update_with_inventory_correction!(attributes, preparation_tools:)`.
- [ ] Add `Brew#destroy_with_inventory_reversal!`.
- [ ] Keep all inventory and adjustment changes inside transactions.
- [ ] Run `env PARALLEL_WORKERS=1 bin/rails test test/models/brew_test.rb`.
- [ ] Commit with `git commit -m "Add brew inventory corrections"`.

### Task 2: Edit And Delete Controller

- [ ] Write failing controller tests for edit, update, destroy, viewer denial, and workspace isolation.
- [ ] Add `edit`, `update`, and `destroy` routes for brews.
- [ ] Add controller actions that use the model correction methods.
- [ ] Preserve selected preparation tools when rendering validation errors.
- [ ] Run `env PARALLEL_WORKERS=1 bin/rails test test/controllers/brews_controller_test.rb`.
- [ ] Commit with `git commit -m "Add brew correction screens"`.

### Task 3: Views And Docs

- [ ] Extract a shared brew form partial from `app/views/brews/new.html.erb`.
- [ ] Add `app/views/brews/edit.html.erb`.
- [ ] Add edit/delete links on brew show for writers.
- [ ] Add locale strings.
- [ ] Add `docs/brew-corrections.md`.
- [ ] Update `docs/coffee-core.md` and `AGENTS.md`.
- [ ] Run focused controller tests.
- [ ] Commit with `git commit -m "Document brew corrections"`.
