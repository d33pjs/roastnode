# Private Media

Private Media adds basic photo capture to the current household coffee records.

## Included Now

- Active Storage-backed photo attachments for beans.
- Active Storage-backed photo attachments for brews.
- Active Storage-backed photo attachments for equipment.
- Active Storage-backed photo attachments for equipment events.
- Multi-photo upload fields on the create forms for those records.
- Photo galleries on detail pages.
- Per-photo removal controls for workspace writers.
- Current photo management on bean and brew edit screens.
- App-scoped media delivery through `MediaAttachmentsController`.

## Privacy Rule

Photos inherit the workspace of the record they are attached to.

Views must render photos through `media_attachment_path(attachment)`, not raw Rails Active Storage blob URLs. The media controller checks the attachment record's `workspace_id` against `current_workspace.id` and returns `404 Not Found` when the attachment does not belong to the active workspace.

Removing a photo uses the same scoped media route and additionally requires `current_workspace_policy.write?`. The controller detaches the attachment from the parent record instead of purging the blob immediately, because duplicated bean bags can intentionally reuse the same photo blob.

## Current Limits

- There is no primary-photo picker yet.
- Images are served inline at original size.
- Variants, thumbnails, direct-upload progress, S3/object storage, and archive/export handling are deferred.
- Orphaned blob cleanup is deferred until the storage policy is formalized.

## Agent Notes

- Keep new photo-enabled models workspace-scoped before attaching photos.
- Add controller tests for both allowed and cross-workspace media access whenever changing media delivery.
- Do not expose `rails_blob_path`, `rails_storage_proxy_path`, or signed blob URLs in app views unless the privacy model is redesigned first.
- Keep photo removal write-scoped and routed through `MediaAttachmentsController#destroy`.
- Avoid image variants until the project has a real image-processing dependency and thumbnail policy.
