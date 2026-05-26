# Private Media Design

## Intent

Private Media adds the first Active Storage-backed photo support for Roastnode. Photos must remain private to the workspace that owns the parent record.

## Included Now

- Active Storage database tables.
- Multiple `photos` attachments on beans, brews, equipment, and equipment events.
- Upload fields on create forms for beans, brews, equipment, and equipment events.
- Photo previews on detail pages.
- Scoped media delivery through an authenticated controller.

## Explicitly Deferred

- Primary photo selection UI.
- Deleting individual photos.
- Direct-upload progress UI.
- Image variants and thumbnail generation.
- S3-compatible storage setup.
- Media ZIP export.

## Privacy Rule

Photos inherit parent visibility. The app must not render raw Active Storage blob routes directly in views. Views should use the scoped media route for attachment IDs. The media controller checks the attached record belongs to `current_workspace` before streaming the blob.

## Supported Parents

- `Bean`
- `Brew`
- `Equipment`
- `EquipmentEvent`

Each parent has `has_many_attached :photos`.

## Testing Notes

Tests must cover:

- attaching photos during create actions
- rendering scoped media URLs on detail pages
- active workspace access to an attachment
- cross-workspace access returning not found
