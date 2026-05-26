# Workspace Export Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add owner-only JSON export for the active workspace.

**Architecture:** Add a focused `WorkspaceExportBuilder` service that returns a plain Ruby hash ready for JSON serialization. Add a singleton `workspace_export` route and controller that authorizes owner access, builds the active workspace export, and sends it as an attachment. Add a dashboard link only for owners.

**Tech Stack:** Rails 8.1, Active Record, Minitest, JSON, ERB views.

---

## Tasks

### Task 1: Export Policy

- [ ] Write a failing `WorkspacePolicyTest` assertion that owners can export and members cannot.
- [ ] Add `Membership#can_export_workspace?` for owner-only export.
- [ ] Add `WorkspacePolicy#export?`.
- [ ] Run `env PARALLEL_WORKERS=1 bin/rails test test/models/workspace_policy_test.rb`.
- [ ] Commit with `git commit -m "Add workspace export policy"`.

### Task 2: Export Builder

- [ ] Write failing tests for `WorkspaceExportBuilder`.
- [ ] Create `app/services/workspace_export_builder.rb`.
- [ ] Include workspace metadata, memberships, beans, equipment, preparation tools, brews, brew preparation tool snapshots, equipment events, event item links, inventory adjustments, and photo metadata.
- [ ] Ensure other workspace records are absent.
- [ ] Run `env PARALLEL_WORKERS=1 bin/rails test test/services/workspace_export_builder_test.rb`.
- [ ] Commit with `git commit -m "Build workspace export payload"`.

### Task 3: Export Download

- [ ] Write failing controller tests for owner download and member denial.
- [ ] Add `resource :workspace_export, only: :show`.
- [ ] Add `WorkspaceExportsController#show`.
- [ ] Send pretty JSON as an attachment named from the workspace.
- [ ] Run `env PARALLEL_WORKERS=1 bin/rails test test/controllers/workspace_exports_controller_test.rb`.
- [ ] Commit with `git commit -m "Add workspace export download"`.

### Task 4: Dashboard Link And Docs

- [ ] Write failing dashboard tests for owner-only export link.
- [ ] Add owner-only export link to the dashboard header.
- [ ] Add locale strings.
- [ ] Add `docs/workspace-export.md`.
- [ ] Update `docs/README.md`, `docs/workspace-core.md`, and `AGENTS.md`.
- [ ] Run `env PARALLEL_WORKERS=1 bin/rails test`.
- [ ] Run `env RUBOCOP_CACHE_ROOT=tmp/rubocop_cache bin/rubocop`.
- [ ] Run `bundle exec brakeman --quiet --no-pager --exit-on-warn --exit-on-error`.
- [ ] Confirm `http://miniknubbel.internal:3001` returns 200.
- [ ] Commit with `git commit -m "Document workspace export"`.
