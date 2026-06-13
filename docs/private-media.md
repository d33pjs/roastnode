# Private Media

Private Media adds basic photo capture to the current household coffee records.

## Included Now

- Active Storage-backed photo attachments for beans.
- Active Storage-backed photo attachments for brews.
- Active Storage-backed photo attachments for equipment.
- Active Storage-backed photo attachments for equipment events.
- Active Storage-backed photo attachments for preparation tools.
- Active Storage-backed photo attachments for External Coffees.
- Active Storage-backed finished-drink photo attachments for recipes.
- Active Storage-backed identity images for users: avatar and public banner.
- Active Storage-backed identity images for workspaces: logo and banner.
- Shared rounded photo upload controls on create/edit forms for image-enabled records where a form exists. These controls mirror the original External Coffee log input treatment and avoid hidden empty file params so saving an edit without choosing a new file does not remove existing photos.
- Photo galleries on detail pages.
- Contained photo thumbnails that open the private original image in an in-page lightbox, with raw view links still available.
- Generated private thumbnail variants for in-page previews without CSS zoom/crop.
- Per-photo private download links.
- Primary-photo selection for photo-enabled records.
- Browser-side photo cropping with save-as-new and overwrite modes.
- Per-photo removal controls for workspace writers.
- Current photo management on bean and brew edit screens.
- App-scoped media delivery through `MediaAttachmentsController`.
- Owner-only media ZIP export for workspace-owned originals, including External Coffee photos.

## Privacy Rule

Photos inherit the workspace of the record they are attached to. User identity images are visible to the user and to members of the active workspace that user belongs to. Workspace identity images are visible only when that workspace is the current active workspace.

Views must render photos through `media_attachment_path(attachment)`, not raw Rails Active Storage blob URLs. The media controller checks the attachment record's `workspace_id` against `current_workspace.id` and returns `404 Not Found` when the attachment does not belong to the active workspace.

Photo delivery only streams safe browser-raster image types: JPEG, PNG, GIF, and WebP. HTML, SVG, and other active or non-image content types return `404 Not Found`, even if they are attached to a photo collection.

Viewing and downloading photos use `MediaAttachmentsController#show` and `MediaAttachmentsController#download`. Both actions are read-scoped to the active workspace. Removing a photo uses the same scoped media route and additionally requires `current_workspace_policy.write?`. The controller detaches the attachment from the parent record instead of purging the blob immediately, because duplicated bean bags can intentionally reuse the same photo blob.

In-page previews can request `media_attachment_path(attachment, variant: :thumbnail)`. The controller only supports the `thumbnail` variant, applies the same workspace visibility checks as original media, and returns `404 Not Found` for unknown variants. Thumbnails use Active Storage variants with `resize_to_limit: [480, 480]`. Views render those thumbnails with contained object fitting so the full uploaded or cropped image remains visible instead of being visually re-cropped. If the local native image-processing runtime is missing or cannot process a file, the controller logs the error and falls back to the original bytes for that thumbnail response.

User avatar/banner replacement is limited to the signed-in user. Workspace logo/banner replacement is limited to owners and admins through the workspace settings page.

## Public Brew Share Media

Public brew share pages must use `PublicBrewMediaController`, not `MediaAttachmentsController`.

The public media controller streams only attachment IDs allowed by an enabled `PublicBrewShare` snapshot and its selected photo list. New snapshots use a builder-generated `public_media` manifest as the media allowlist; legacy snapshots fall back to live validation against selected share photos and public identity images. This includes selected brew/bean/equipment/tool photos plus the workspace logo and user avatar when those identity images are referenced by the snapshot. Unsupported variants, disabled shares, unknown tokens, locked password-protected shares, and attachments outside the public whitelist return `404 Not Found`.

Public media responses should not expose original uploaded filenames and only stream safe raster image content types. Public pages should not expose `rails_blob_path`, `rails_storage_proxy_path`, signed Active Storage URLs, private `media_attachment_path` URLs, or raw Active Storage attachment IDs.

## Public Recipe Share Media

Public recipe share pages may render explicitly selected recipe photos through `PublicRecipeMediaController`. They must not use `MediaAttachmentsController`, raw Active Storage URLs, signed URLs, or private media attachment paths.

The public recipe media controller streams only recipe photo attachment IDs that are both selected on the `PublicRecipeShare` and present in the share snapshot's `public_media` allowlist. Disabled shares, unknown tokens, locked password-protected shares, unsupported variants, deleted attachments, unselected recipe photos, and attachments outside the snapshot allowlist return `404 Not Found`.

Public recipe media responses use generic filenames, opaque per-share media handles, and safe raster image content types only. Rendered public recipe HTML must not expose raw attachment IDs or original filenames. Request and redirect logs must not expose raw share tokens or media handles.

## Public Bean Share Media

Public bean share pages may render selected bean package photos through `PublicBeanMediaController`. They must not use `MediaAttachmentsController`, raw Active Storage URLs, signed URLs, or private media attachment paths.

The public bean media controller streams only bean photo attachment IDs that are both selected on the `PublicBeanShare` and present in the share snapshot's `public_media` allowlist. Workspace logos and brewer avatars may appear only when referenced by the snapshot media allowlist. Disabled shares, unknown tokens, locked password-protected shares, unsupported variants, deleted attachments, unselected bean photos, and attachments outside the snapshot allowlist return `404 Not Found`.

Public bean media responses use generic filenames, opaque per-share media handles, and safe raster image content types only. Rendered public bean HTML must not expose raw record/database IDs, raw attachment IDs, original filenames, brew photos, private media routes, or signed Active Storage URLs. Request and redirect logs must not expose raw share tokens or media handles.

Primary photo selection uses `MediaAttachmentsController#primary` and requires workspace write access. Primary photos are stored as `primary_photo_attachment_id` on beans, brews, equipment, equipment events, preparation tools, and recipes. `HasPrimaryPhoto#primary_photo_attachment` falls back to the first attached photo when no explicit primary is set or when the stored attachment is no longer valid.

Cropping uses `MediaAttachmentsController#crop` and requires workspace write access. The crop page renders the private image through `media_attachment_path`, then the `photo-crop` Stimulus controller maps the selected crop box through the actual displayed image rectangle before using browser canvas APIs to create a normal image upload. This keeps square selections square even when the image is letterboxed by contained fitting. Save-as-new adds another photo to the same record. Overwrite attaches the cropped image and removes the old attachment; if the overwritten photo was primary, the new attachment becomes primary automatically. This avoids depending on native libvips/ImageMagick availability in the app runtime.

## Current Limits

- Originals are served inline or downloaded at original size unless the user explicitly saves a cropped replacement.
- Direct-upload progress and S3/object storage are deferred.
- Orphaned blob cleanup is deferred until the storage policy is formalized.

## Agent Notes

- Keep new photo-enabled models workspace-scoped before attaching photos. For exceptions such as `User` identity images, add an explicit membership-based media authorization rule.
- Add controller tests for both allowed and cross-workspace media access whenever changing media delivery.
- Do not expose `rails_blob_path`, `rails_storage_proxy_path`, or signed blob URLs in app views unless the privacy model is redesigned first.
- Keep photo removal write-scoped and routed through `MediaAttachmentsController#destroy`.
- Keep photo viewing and download links routed through `MediaAttachmentsController` so workspace scoping stays centralized.
- Keep primary photo changes routed through `MediaAttachmentsController#primary` so workspace scoping and write authorization stay centralized.
- Keep photo cropping routed through `MediaAttachmentsController#crop`; it accepts a browser-generated image upload rather than processing the source blob on the server.
- Keep preview thumbnails behind `MediaAttachmentsController` with `variant: :thumbnail`; do not expose raw variant/blob URLs.
- Keep public-share thumbnails behind `PublicBrewMediaController` with `variant: :thumbnail`; apply the share password gate and attachment whitelist before streaming bytes.
- Keep public recipe thumbnails behind `PublicRecipeMediaController` with `variant: :thumbnail`; apply the share password gate and selected recipe-photo allowlist before streaming bytes.
- Keep public bean thumbnails behind `PublicBeanMediaController` with `variant: :thumbnail`; apply the share password gate and selected bean-photo allowlist before streaming bytes.
- Keep workspace media archives owner-only through `WorkspaceExportsController#media`. Include workspace-owned media, External Coffee photos, and workspace identity images, but do not include user avatars/public banners without a separate account-data export decision.
