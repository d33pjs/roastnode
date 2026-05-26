# Workspace Export

Workspace Export is the first Roastnode data portability feature.

## Included Now

- Owner-only JSON export for the active workspace.
- Dashboard export link visible only to owners.
- Structured payload format with `format`, `version`, and `generated_at`.
- Workspace metadata.
- Membership roles with user email/display name.
- Import batch metadata.
- Beans, equipment, preparation tools, brews, brew preparation tool snapshots, equipment events, equipment event links, and inventory adjustments.
- Rich bean metadata, including roast type, degree of roast, blend type, decaf flag, cost, website, flavor profile, and variety information.
- Photo metadata for photo-enabled records.

## Privacy And Authorization

The export route uses the current active workspace and does not accept a workspace ID. `WorkspacePolicy#export?` is owner-only in this slice.

The export intentionally excludes:

- password digests
- sessions
- invite tokens
- raw photo bytes
- signed media URLs
- records from other workspaces

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

- Media ZIP export.
- Scheduled backups.
- Workspace deletion and transfer.
- Non-owner export policy variants.
