# Statistics And Analytics Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a private query-backed workspace statistics page with practical coffee analytics.

**Architecture:** Add a `WorkspaceStatistics` service for all aggregations. Add a `StatisticsController#index`, a `/statistics` route, a dashboard link, and a server-rendered analytics view with compact cards and bar rows.

**Tech Stack:** Rails 8.1, Active Record, PostgreSQL, ERB, Minitest.

---

## Tasks

### Task 1: Statistics Service

- [x] Write service tests for scoped totals, cost calculations, equipment leaders, recent day series, taste distribution, channeling rate, retention markers, and bean breakdowns.
- [x] Implement `WorkspaceStatistics`.
- [x] Run `env PARALLEL_WORKERS=1 bin/rails test test/services/workspace_statistics_test.rb`.
- [x] Commit with `git commit -m "Add workspace statistics service"`.

### Task 2: Statistics Page

- [x] Write controller tests for authenticated workspace access, dashboard link, and viewer read access.
- [x] Add `/statistics` route and controller.
- [x] Add dashboard link.
- [x] Add `app/views/statistics/index.html.erb`.
- [x] Add locale strings.
- [x] Run focused controller tests.
- [x] Commit with `git commit -m "Add statistics page"`.

### Task 3: Docs And Verification

- [x] Add `docs/statistics.md`.
- [x] Update `docs/README.md`, `docs/coffee-core.md`, and `AGENTS.md`.
- [x] Run `env PARALLEL_WORKERS=1 bin/rails test`.
- [x] Run `env RUBOCOP_CACHE_ROOT=tmp/rubocop_cache bin/rubocop`.
- [x] Run `bundle exec brakeman --quiet --no-pager --exit-on-warn --exit-on-error`.
- [x] Confirm `http://miniknubbel.internal:3001` returns 200.
- [x] Commit with `git commit -m "Document statistics analytics"`.
