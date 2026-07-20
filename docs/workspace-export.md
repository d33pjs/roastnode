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
- Beans, equipment, preparation tools, brews, External Coffees, brew preparation tool snapshots, equipment events, equipment event links, and inventory adjustments.
- External Coffees include drink type, drink size, place text, private coordinates, price/currency, taste axes, rating, notes, public note, and photo metadata.
- Rich bean metadata, including roast type, grind state (`whole_bean` or `pre_ground`), degree of roast, blend type, decaf flag, cost, website, flavor profile, and variety information.
- Equipment machine-capability flags for pre-infusion, low-flow start, and flow control.
- Brew method fields, including espresso low-flow-start seconds and flow-control use, Quick Drip brewer, machine cups, coffee spoons, grams per coffee spoon, coffee amount source, and private serving metadata.
- Quick Drip profile preferences are account-level data. Active workspace exports do not include enabled-method or grams-per-coffee-spoon preferences; full instance backup/readable export payloads include them so restores can rebuild user logging defaults.
- Photo metadata for photo-enabled records.
- Preparation tool lifecycle fields, including active status, position, and photo metadata.

## Media ZIP Export

The media archive is available at `/workspace_export/media.zip`. It contains:

- `manifest.json` with workspace metadata and one row per exported attachment.
- `data/workspace-export.json`, matching the normal JSON export payload.
- Original media files under stable `media/<record_collection>/<record_id>/<attachment_name>/<attachment_id>-<filename>` paths.

The archive includes workspace logo/banner and photos attached to beans, equipment, preparation tools, brews, External Coffees, and equipment events in the active workspace. It does not include user avatars or user public banners, because those belong to user accounts rather than the workspace export contract.

## CSV Exports

CSV exports are separate spreadsheet-friendly downloads:

- `/workspace_export/beans.csv`
- `/workspace_export/brews.csv`
- `/workspace_export/external_coffees.csv`

The beans CSV includes flat bag metadata such as names, roaster, derived status (`stock`, `open`, `used_up`, or `archived`), remaining grams, roast data, variety information, purchase details, rating, notes, and timestamps.

The brews CSV includes flat brew history such as occurred time, method, user labels, bean/equipment names, preparation tool snapshots, weights, Quick Drip cups/spoons/spoon grams, brew ratio, timing (including low-flow start), temperature, flow-control use, taste balance, rating, private guest/cup serving metadata, retention marker, notes, and timestamps.

The External Coffees CSV includes occurred time, user labels, drink type, drink size, place name/location, private coordinates, price, currency, taste axes, rating, notes, public note, and timestamps.

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
  "external_coffees": [],
  "brew_preparation_tools": [],
  "equipment_events": [],
  "equipment_event_items": [],
  "inventory_adjustments": []
}
```

Local IDs are included so relationships can be reconstructed inside a single export file. Decimal measurements are emitted as strings to avoid precision loss.

## Instance Backup Coverage

Instance backups and empty-server restore preserve the same Quick Drip durable fields: brew method, brewer references, machine cups, coffee spoons, grams per coffee spoon, coffee amount source, private serving metadata, bean grind state, preparation tool method, and user enabled-method/spoon preferences. They also preserve machine extraction-capability flags, brew low-flow-start seconds and flow-control use, External Coffee records, and photos. Older backup payloads restore existing machines with pre-infusion enabled for compatibility.

## Deferred

- Workspace deletion and transfer.
- Non-owner export policy variants.
