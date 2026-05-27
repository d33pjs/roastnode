# Private Media Thumbnails Design

## Goal

Reduce bandwidth and layout cost on media-heavy pages by serving thumbnail variants for in-page image previews while keeping originals private and available for view/download actions.

## Scope

- Add a `thumbnail` variant to `MediaAttachmentsController#show` using the existing private media route.
- Keep original view and download links pointed at the original attachment.
- Use thumbnail URLs for list rows, profile/workspace previews, hero-card identity marks, hero-card bean photos, and photo grids.
- Keep the crop editor on the original private image so users crop from the source attachment.

## Design

The app requests thumbnails with `media_attachment_path(attachment, variant: :thumbnail)`. The media controller still loads the `ActiveStorage::Attachment`, checks active-workspace access, and only then processes or serves the thumbnail. Unsupported variants return `404 Not Found`.

Thumbnails use Active Storage variants with `resize_to_limit: [480, 480]`. If the local runtime cannot process variants, for example because libvips is missing, the controller logs the failure and falls back to the original bytes for that thumbnail response. This keeps development and self-hosted installs usable while still enabling generated variants where the native image-processing runtime is installed.

## Privacy Notes

- Thumbnail responses are never raw Active Storage URLs.
- Workspace and user/media visibility rules stay centralized in `MediaAttachmentsController`.
- Originals remain the target for explicit view and download links.
- The media archive continues to export original files, not generated thumbnails.

## Tests

- Thumbnail requests through `media_attachment_path(..., variant: :thumbnail)` are scoped and return an inline response.
- Unsupported variant names return `404 Not Found`.
- Photo grids and small preview views render thumbnail URLs.
- Crop editing continues to render the original private media URL.
