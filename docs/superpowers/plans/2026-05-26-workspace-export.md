# Workspace Export Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add owner-only JSON export for the active workspace.

**Architecture:** Add a focused `WorkspaceExportBuilder` service that returns a plain Ruby hash ready for JSON serialization. Add a singleton `workspace_export` route and controller that authorizes owner access, builds the active workspace export, and sends it as an attachment. Add a dashboard link only for owners.

**Tech Stack:** Rails 8.1, Active Record, Minitest, JSON, ERB views.

---

## Tasks

### Task 1: Export Policy

- [x] Write a failing `WorkspacePolicyTest` assertion that owners can export and members cannot.
- [x] Add `Membership#can_export_workspace?` for owner-only export.
- [x] Add `WorkspacePolicy#export?`.
- [x] Run `env PARALLEL_WORKERS=1 bin/rails test test/models/workspace_policy_test.rb`.
- [x] Commit with `git commit -m "Add workspace export policy"`.

### Task 2: Export Builder

- [x] Write failing tests for `WorkspaceExportBuilder`.
- [x] Create `app/services/workspace_export_builder.rb`.
- [x] Include workspace metadata, memberships, beans, equipment, preparation tools, brews, brew preparation tool snapshots, equipment events, event item links, inventory adjustments, and photo metadata.
- [x] Ensure other workspace records are absent.
- [x] Run `env PARALLEL_WORKERS=1 bin/rails test test/services/workspace_export_builder_test.rb`.
- [x] Commit with `git commit -m "Build workspace export payload"`.

### Task 3: Export Download

- [x] Write failing controller tests for owner download and member denial.
- [x] Add `resource :workspace_export, only: :show`.
- [x] Add `WorkspaceExportsController#show`.
- [x] Send pretty JSON as an attachment named from the workspace.
- [x] Run `env PARALLEL_WORKERS=1 bin/rails test test/controllers/workspace_exports_controller_test.rb`.
- [x] Commit with `git commit -m "Add workspace export download"`.

### Task 4: Dashboard Link And Docs

- [x] Write failing dashboard tests for owner-only export link.
- [x] Add owner-only export link to the dashboard header.
- [x] Add locale strings.
- [x] Add `docs/workspace-export.md`.
- [x] Update `docs/README.md`, `docs/workspace-core.md`, and `AGENTS.md`.
- [x] Run `env PARALLEL_WORKERS=1 bin/rails test`.
- [x] Run `env RUBOCOP_CACHE_ROOT=tmp/rubocop_cache bin/rubocop`.
- [x] Run `bundle exec brakeman --quiet --no-pager --exit-on-warn --exit-on-error`.
- [x] Confirm `http://localhost:3001` returns 200.
- [ ] Commit with `git commit -m "Document workspace export"`.
