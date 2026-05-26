# Beanconqueror Import Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Import core Beanconqueror JSON exports into the active Roastnode workspace with duplicate-safe source metadata and an import report.

**Architecture:** Add `DataImport` as the batch/audit record and source metadata columns to imported domain records. Implement a focused `BeanconquerorImport` service that parses JSON, builds source UUID maps, imports supported records in dependency order, and records summary/warnings. Add a small upload/report controller for owners/admins.

**Tech Stack:** Rails 8.1, PostgreSQL JSONB, Active Record transactions, Minitest, ERB views.

---

## Tasks

### Task 1: Import Data Model

- [x] Write failing model tests for `DataImport` and source metadata uniqueness.
- [x] Create `data_imports`.
- [x] Add source metadata to beans, equipment, preparation tools, and brews.
- [x] Add `DataImport` model and associations.
- [x] Run `bin/rails db:migrate`.
- [x] Run focused model tests.
- [x] Commit with `git commit -m "Add import data model"`.

### Task 2: Beanconqueror Import Service

- [x] Add compact Beanconqueror JSON fixtures.
- [x] Write failing service tests for import, duplicate skip, unsupported brew skip, and invalid JSON report.
- [x] Implement `BeanconquerorImport`.
- [x] Preserve raw payload in `DataImport#raw_payload` and per-record `raw_import_data`.
- [x] Create inventory adjustments through normal brew creation.
- [x] Run `env PARALLEL_WORKERS=1 bin/rails test test/services/beanconqueror_import_test.rb`.
- [x] Commit with `git commit -m "Import Beanconqueror JSON"`.

### Task 3: Import Upload UI

- [x] Write failing controller tests for owner/admin upload, member denial, and report rendering.
- [x] Add `beanconqueror_imports` routes.
- [x] Add `BeanconquerorImportsController`.
- [x] Add `new` and `show` views.
- [x] Add dashboard link for workspace managers.
- [x] Run focused controller tests.
- [x] Commit with `git commit -m "Add Beanconqueror import UI"`.

### Task 4: Docs And Verification

- [x] Add `docs/beanconqueror-import.md`.
- [x] Update `docs/README.md`, `docs/coffee-core.md`, `docs/workspace-export.md`, and `AGENTS.md`.
- [ ] Run `env PARALLEL_WORKERS=1 bin/rails test`.
- [ ] Run `env RUBOCOP_CACHE_ROOT=tmp/rubocop_cache bin/rubocop`.
- [ ] Run `bundle exec brakeman --quiet --no-pager --exit-on-warn --exit-on-error`.
- [ ] Confirm `http://miniknubbel.internal:3001` returns 200.
- [ ] Commit with `git commit -m "Document Beanconqueror import"`.
