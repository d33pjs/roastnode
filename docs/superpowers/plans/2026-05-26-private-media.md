# Private Media Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add private workspace photo uploads and previews for beans, brews, equipment, and equipment events.

**Architecture:** Use Rails Active Storage for blobs/attachments, but render images through a small authenticated controller that checks parent workspace ownership before streaming. Keep the first slice simple: multiple photos, no primary selector, no deletion UI.

**Tech Stack:** Rails 8.1, Active Storage, PostgreSQL, ERB views, Tailwind utility classes, Minitest.

---

## Tasks

### Task 1: Active Storage And Attachments

- [ ] Install Active Storage migrations.
- [ ] Add `has_many_attached :photos` to Bean, Brew, Equipment, and EquipmentEvent.
- [ ] Add an image fixture for upload tests.
- [ ] Write model tests proving each parent accepts photos.
- [ ] Run focused model tests.
- [ ] Commit with `git commit -m "Add private photo attachments"`.

### Task 2: Scoped Media Delivery

- [ ] Write controller tests for same-workspace and cross-workspace attachment access.
- [ ] Add `MediaAttachmentsController#show`.
- [ ] Add `media_attachment_path`.
- [ ] Stream blobs only when the attachment record belongs to `current_workspace`.
- [ ] Run focused media controller tests.
- [ ] Commit with `git commit -m "Add scoped media delivery"`.

### Task 3: Upload And Display

- [ ] Add photo fields to bean, brew, equipment, and equipment event forms.
- [ ] Permit `photos: []` in each controller.
- [ ] Show photo grids on bean, brew, equipment, and event detail pages.
- [ ] Add/update controller tests for attachment creation and scoped image links.
- [ ] Run focused controller tests.
- [ ] Commit with `git commit -m "Add photo upload fields"`.

### Task 4: Docs And Verification

- [ ] Add `docs/private-media.md`.
- [ ] Update `docs/README.md` and `AGENTS.md`.
- [ ] Run `env PARALLEL_WORKERS=1 bin/rails test`.
- [ ] Run `env RUBOCOP_CACHE_ROOT=tmp/rubocop_cache bin/rubocop`.
- [ ] Run `bundle exec brakeman --quiet --no-pager --exit-on-warn --exit-on-error`.
- [ ] Confirm `http://miniknubbel.internal:3001` returns 200.
- [ ] Commit docs with `git commit -m "Document private media"`.
