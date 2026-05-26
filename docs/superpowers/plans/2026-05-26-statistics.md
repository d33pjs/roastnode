# Statistics And Analytics Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a private query-backed workspace statistics page with practical coffee analytics.

**Architecture:** Add a `WorkspaceStatistics` service for all aggregations. Add a `StatisticsController#index`, a `/statistics` route, a dashboard link, and a server-rendered analytics view with compact cards and bar rows.

**Tech Stack:** Rails 8.1, Active Record, PostgreSQL, ERB, Minitest.

---

## Tasks

### Task 1: Statistics Service

- [ ] Write service tests for scoped totals, cost calculations, equipment leaders, recent day series, taste distribution, channeling rate, retention markers, and bean breakdowns.
- [ ] Implement `WorkspaceStatistics`.
- [ ] Run `env PARALLEL_WORKERS=1 bin/rails test test/services/workspace_statistics_test.rb`.
- [ ] Commit with `git commit -m "Add workspace statistics service"`.

### Task 2: Statistics Page

- [ ] Write controller tests for authenticated workspace access, dashboard link, and viewer read access.
- [ ] Add `/statistics` route and controller.
- [ ] Add dashboard link.
- [ ] Add `app/views/statistics/index.html.erb`.
- [ ] Add locale strings.
- [ ] Run focused controller tests.
- [ ] Commit with `git commit -m "Add statistics page"`.

### Task 3: Docs And Verification

- [ ] Add `docs/statistics.md`.
- [ ] Update `docs/README.md`, `docs/coffee-core.md`, and `AGENTS.md`.
- [ ] Run `env PARALLEL_WORKERS=1 bin/rails test`.
- [ ] Run `env RUBOCOP_CACHE_ROOT=tmp/rubocop_cache bin/rubocop`.
- [ ] Run `bundle exec brakeman --quiet --no-pager --exit-on-warn --exit-on-error`.
- [ ] Confirm `http://miniknubbel.internal:3001` returns 200.
- [ ] Commit with `git commit -m "Document statistics analytics"`.
