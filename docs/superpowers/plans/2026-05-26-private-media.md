# Private Media Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add private workspace photo uploads and previews for beans, brews, equipment, and equipment events.

**Architecture:** Use Rails Active Storage for blobs/attachments, but render images through a small authenticated controller that checks parent workspace ownership before streaming. Keep the first slice simple: multiple photos and no primary selector. A later media-management slice added write-scoped individual photo removal through the same controller.

**Tech Stack:** Rails 8.1, Active Storage, PostgreSQL, ERB views, Tailwind utility classes, Minitest.

---

## Tasks

### Task 1: Active Storage And Attachments

- [x] Install Active Storage migrations.
- [x] Add `has_many_attached :photos` to Bean, Brew, Equipment, and EquipmentEvent.
- [x] Add an image fixture for upload tests.
- [x] Write model tests proving each parent accepts photos.
- [x] Run focused model tests.
- [x] Commit with `git commit -m "Add private photo attachments"`.

### Task 2: Scoped Media Delivery

- [x] Write controller tests for same-workspace and cross-workspace attachment access.
- [x] Add `MediaAttachmentsController#show`.
- [x] Add `media_attachment_path`.
- [x] Stream blobs only when the attachment record belongs to `current_workspace`.
- [x] Run focused media controller tests.
- [x] Commit with `git commit -m "Add scoped media delivery"`.

### Task 3: Upload And Display

- [x] Add photo fields to bean, brew, equipment, and equipment event forms.
- [x] Permit `photos: []` in each controller.
- [x] Show photo grids on bean, brew, equipment, and event detail pages.
- [x] Add/update controller tests for attachment creation and scoped image links.
- [x] Run focused controller tests.
- [x] Commit with `git commit -m "Add photo upload fields"`.

### Task 4: Docs And Verification

- [x] Add `docs/private-media.md`.
- [x] Update `docs/README.md` and `AGENTS.md`.
- [x] Run `env PARALLEL_WORKERS=1 bin/rails test`.
- [x] Run `env RUBOCOP_CACHE_ROOT=tmp/rubocop_cache bin/rubocop`.
- [x] Run `bundle exec brakeman --quiet --no-pager --exit-on-warn --exit-on-error`.
- [x] Confirm `http://miniknubbel.internal:3001` returns 200.
- [ ] Commit docs with `git commit -m "Document private media"`.

### Later Slice: Photo Removal

- [x] Add `MediaAttachmentsController#destroy` with active-workspace and write-policy checks.
- [x] Add remove controls to shared photo galleries.
- [x] Show current photo management on bean and brew edit screens.
- [x] Keep removal as attachment detachment so duplicated bean bags can continue reusing the same blob.
