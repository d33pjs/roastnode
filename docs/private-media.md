# Private Media

Private Media adds basic photo capture to the current household coffee records.

## Included Now

- Active Storage-backed photo attachments for beans.
- Active Storage-backed photo attachments for brews.
- Active Storage-backed photo attachments for equipment.
- Active Storage-backed photo attachments for equipment events.
- Active Storage-backed photo attachments for preparation tools.
- Active Storage-backed identity images for users: avatar and public banner.
- Active Storage-backed identity images for workspaces: logo and banner.
- Multi-photo upload fields on create forms for photo-enabled records where a create form exists.
- Photo galleries on detail pages.
- Clickable photo thumbnails that open the private original image in a new tab.
- Per-photo private download links.
- Primary-photo selection for photo-enabled records.
- Browser-side photo cropping with save-as-new and overwrite modes.
- Per-photo removal controls for workspace writers.
- Current photo management on bean and brew edit screens.
- App-scoped media delivery through `MediaAttachmentsController`.

## Privacy Rule

Photos inherit the workspace of the record they are attached to. User identity images are visible to the user and to members of the active workspace that user belongs to. Workspace identity images are visible only when that workspace is the current active workspace.

Views must render photos through `media_attachment_path(attachment)`, not raw Rails Active Storage blob URLs. The media controller checks the attachment record's `workspace_id` against `current_workspace.id` and returns `404 Not Found` when the attachment does not belong to the active workspace.

Viewing and downloading photos use `MediaAttachmentsController#show` and `MediaAttachmentsController#download`. Both actions are read-scoped to the active workspace. Removing a photo uses the same scoped media route and additionally requires `current_workspace_policy.write?`. The controller detaches the attachment from the parent record instead of purging the blob immediately, because duplicated bean bags can intentionally reuse the same photo blob.

User avatar/banner replacement is limited to the signed-in user. Workspace logo/banner replacement is limited to owners and admins through the workspace settings page.

Primary photo selection uses `MediaAttachmentsController#primary` and requires workspace write access. Primary photos are stored as `primary_photo_attachment_id` on beans, brews, equipment, and equipment events. `HasPrimaryPhoto#primary_photo_attachment` falls back to the first attached photo when no explicit primary is set or when the stored attachment is no longer valid. Preparation tool photos do not currently have a primary-photo workflow.

Cropping uses `MediaAttachmentsController#crop` and requires workspace write access. The crop page renders the private image through `media_attachment_path`, then the `photo-crop` Stimulus controller uses browser canvas APIs to create a normal image upload. Save-as-new adds another photo to the same record. Overwrite attaches the cropped image and removes the old attachment; if the overwritten photo was primary, the new attachment becomes primary automatically. This avoids depending on native libvips/ImageMagick availability in the app runtime.

## Current Limits

- Images are served inline or downloaded at original size unless the user explicitly saves a cropped replacement.
- Generated variants, thumbnails, direct-upload progress, S3/object storage, and archive/export handling are deferred.
- Orphaned blob cleanup is deferred until the storage policy is formalized.

## Agent Notes

- Keep new photo-enabled models workspace-scoped before attaching photos. For exceptions such as `User` identity images, add an explicit membership-based media authorization rule.
- Add controller tests for both allowed and cross-workspace media access whenever changing media delivery.
- Do not expose `rails_blob_path`, `rails_storage_proxy_path`, or signed blob URLs in app views unless the privacy model is redesigned first.
- Keep photo removal write-scoped and routed through `MediaAttachmentsController#destroy`.
- Keep photo viewing and download links routed through `MediaAttachmentsController` so workspace scoping stays centralized.
- Keep primary photo changes routed through `MediaAttachmentsController#primary` so workspace scoping and write authorization stay centralized.
- Keep photo cropping routed through `MediaAttachmentsController#crop`; it accepts a browser-generated image upload rather than processing the source blob on the server.
- Avoid generated image variants until the project has a thumbnail policy and a verified native image-processing runtime.
