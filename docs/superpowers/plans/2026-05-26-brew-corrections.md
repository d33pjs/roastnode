# Brew Corrections Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Allow workspace writers to edit and delete brews while keeping bean inventory and brew inventory adjustments consistent.

**Architecture:** Add model-level correction methods on `Brew` for inventory-safe updates and deletion. Extend `BrewsController` with `edit`, `update`, and `destroy`, reusing existing form option loading and preparation tool snapshot behavior. Add a shared brew form partial so new/edit stay aligned without inventing a second form.

**Tech Stack:** Rails 8.1, Active Record transactions, Minitest, ERB views, Tailwind.

---

## Tasks

### Task 1: Model Correction Rules

- [x] Write failing model tests for same-bean delta, changed-bean delta, preparation tool replacement, and delete reversal.
- [x] Add `Brew#update_with_inventory_correction!(attributes, preparation_tools:)`.
- [x] Add `Brew#destroy_with_inventory_reversal!`.
- [x] Keep all inventory and adjustment changes inside transactions.
- [x] Run `env PARALLEL_WORKERS=1 bin/rails test test/models/brew_test.rb`.
- [x] Commit with `git commit -m "Add brew inventory corrections"`.

### Task 2: Edit And Delete Controller

- [x] Write failing controller tests for edit, update, destroy, viewer denial, and workspace isolation.
- [x] Add `edit`, `update`, and `destroy` routes for brews.
- [x] Add controller actions that use the model correction methods.
- [x] Preserve selected preparation tools when rendering validation errors.
- [x] Run `env PARALLEL_WORKERS=1 bin/rails test test/controllers/brews_controller_test.rb`.
- [x] Commit with `git commit -m "Add brew correction screens"`.

### Task 3: Views And Docs

- [x] Extract a shared brew form partial from `app/views/brews/new.html.erb`.
- [x] Add `app/views/brews/edit.html.erb`.
- [x] Add edit/delete links on brew show for writers.
- [x] Add locale strings.
- [x] Add `docs/brew-corrections.md`.
- [x] Update `docs/coffee-core.md` and `AGENTS.md`.
- [x] Run focused controller tests.
- [x] Commit with `git commit -m "Document brew corrections"`.
