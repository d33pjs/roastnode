# Private Media Thumbnails Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Serve private thumbnail variants for preview images without exposing raw Active Storage URLs.

**Architecture:** Extend `MediaAttachmentsController#show` with a whitelisted `variant=thumbnail` branch. Update image preview views to request the thumbnail variant while preserving original links and downloads.

**Tech Stack:** Rails 8.1, Active Storage variants, image_processing, ERB, Minitest.

---

### Task 1: Controller Thumbnail Variant

**Files:**
- Modify: `app/controllers/media_attachments_controller.rb`
- Test: `test/controllers/media_attachments_controller_test.rb`

- [x] Add a failing controller test for `media_attachment_path(attachment, variant: :thumbnail)`.
- [x] Add a failing controller test proving unsupported variants return `404 Not Found`.
- [x] Implement `THUMBNAIL_VARIANT` and `THUMBNAIL_TRANSFORMATIONS`.
- [x] Serve thumbnails only after the existing active-workspace attachment check.
- [x] Fall back to original bytes when local image processing cannot run.
- [x] Run `bin/rails test test/controllers/media_attachments_controller_test.rb`.

### Task 2: Preview Views

**Files:**
- Modify: `app/views/shared/_photo_grid.html.erb`
- Modify: `app/views/shared/_related_photo_group.html.erb`
- Modify: `app/views/beans/index.html.erb`
- Modify: `app/views/equipment/index.html.erb`
- Modify: `app/views/profiles/edit.html.erb`
- Modify: `app/views/workspaces/edit.html.erb`
- Modify: `app/views/brews/_hero_card.html.erb`
- Tests: affected controller tests for beans, equipment, brews, profiles, workspaces, preparation tools, equipment events, and media attachments

- [x] Update preview image tags to use `media_attachment_path(photo, variant: :thumbnail)`.
- [x] Keep link and download targets on original `media_attachment_path(photo)` or `download_media_attachment_path(photo)`.
- [x] Keep crop-editor image tags on original media.
- [x] Update controller view assertions to expect thumbnail URLs for previews.
- [x] Run affected controller tests serially.

### Task 3: Documentation And Verification

**Files:**
- Modify: `docs/private-media.md`
- Modify: `docs/status.md`
- Modify: `AGENTS.md`

- [x] Document the thumbnail policy and local runtime fallback.
- [x] Remove generated thumbnails from the deferred media list.
- [x] Run `env PARALLEL_WORKERS=1 bin/rails test`.
