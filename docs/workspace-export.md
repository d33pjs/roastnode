# Workspace Export

Workspace Export is the first Roastnode data portability feature.

## Included Now

- Owner-only JSON export for the active workspace.
- Owner-only CSV exports for beans and brews.
- Owner-only media ZIP export for workspace-owned photos.
- Dashboard export link visible only to owners.
- Structured payload format with `format`, `version`, and `generated_at`.
- Workspace metadata.
- Membership roles with user email/display name.
- Import batch metadata.
- Beans, equipment, preparation tools, brews, brew preparation tool snapshots, equipment events, equipment event links, and inventory adjustments.
- Rich bean metadata, including roast type, degree of roast, blend type, decaf flag, cost, website, flavor profile, and variety information.
- Photo metadata for photo-enabled records.
- Preparation tool lifecycle fields, including active status, position, and photo metadata.

## Media ZIP Export

The media archive is available at `/workspace_export/media.zip`. It contains:

- `manifest.json` with workspace metadata and one row per exported attachment.
- `data/workspace-export.json`, matching the normal JSON export payload.
- Original media files under stable `media/<record_collection>/<record_id>/<attachment_name>/<attachment_id>-<filename>` paths.

The archive includes workspace logo/banner and photos attached to beans, equipment, preparation tools, brews, and equipment events in the active workspace. It does not include user avatars or user public banners, because those belong to user accounts rather than the workspace export contract.

## CSV Exports

CSV exports are separate spreadsheet-friendly downloads:

- `/workspace_export/beans.csv`
- `/workspace_export/brews.csv`

The beans CSV includes flat bag metadata such as names, roaster, derived status (`stock`, `open`, `used_up`, or `archived`), remaining grams, roast data, variety information, purchase details, rating, notes, and timestamps.

The brews CSV includes flat brew history such as occurred time, user labels, bean/equipment names, preparation tool snapshots, weights, brew ratio, timing, temperature, taste balance, rating, retention marker, notes, and timestamps.

CSV exports are useful for spreadsheets and quick analysis. They are not intended to fully reconstruct all relationships; use the JSON export for that.

## Privacy And Authorization

The export route uses the current active workspace and does not accept a workspace ID. `WorkspacePolicy#export?` is owner-only in this slice.

The export intentionally excludes:

- password digests
- sessions
- invite tokens
- signed media URLs
- records from other workspaces

Raw photo bytes are included only in the separate owner-only media ZIP.

## Payload Contract

The top-level JSON shape is:

```json
{
  "format": "roastnode.workspace_export",
  "version": 1,
  "generated_at": "2026-05-26T10:00:00Z",
  "workspace": {},
  "memberships": [],
  "data_imports": [],
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

Local IDs are included so relationships can be reconstructed inside a single export file. Decimal measurements are emitted as strings to avoid precision loss.

## Deferred

- Instance-wide scheduled backups and empty-server restore. These are a separate v1 operations slice, not an active-workspace export feature.
- Workspace deletion and transfer.
- Non-owner export policy variants.
