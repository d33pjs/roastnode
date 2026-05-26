# Workspace Export Design

## Intent

Workspace Export gives a household owner a private, structured JSON snapshot of the active workspace. This is the first data portability slice and prepares the project for later Beanconqueror import, richer export formats, and media archive export.

## Included Now

- Owner-only export of the current active workspace.
- A dashboard link for owners.
- Downloaded JSON with a stable top-level format name and version.
- Workspace metadata.
- Membership role data with user email/display name, without password/session fields.
- Beans, equipment, preparation tools, brews, brew preparation tool snapshots, equipment events, equipment event item links, and inventory adjustments.
- Photo attachment metadata for supported photo parents.

## Explicitly Deferred

- Media bytes and ZIP export.
- Beanconqueror-compatible export.
- Import screens.
- Scheduled backups.
- Workspace deletion or transfer flows.
- Admin/viewer export policy variants.

## Authorization

Only the active workspace owner may export in this slice. The export route always uses `current_workspace`; it does not accept a workspace ID from params.

Admins, members, and viewers receive the same denial behavior as other restricted workspace actions: redirect to the dashboard with the authorization alert.

## Data Shape

The payload is JSON:

```json
{
  "format": "roastnode.workspace_export",
  "version": 1,
  "generated_at": "2026-05-26T10:00:00Z",
  "workspace": {},
  "memberships": [],
  "beans": [],
  "equipment": [],
  "preparation_tools": [],
  "brews": [],
  "brew_preparation_tools": [],
  "equipment_events": [],
  "equipment_event_items": [],
  "inventory_adjustments": []
}
```

Records include local IDs so relationships remain reconstructable inside one export file. Photo metadata includes attachment ID, filename, content type, byte size, checksum, created timestamp, and parent attachment name; it does not include signed URLs or raw bytes.

## Testing Notes

Tests must cover:

- owner can download JSON for the active workspace
- non-owner cannot export
- other workspace data is absent
- dashboard export link is visible only to owners
- photo metadata is included without using blob URLs
