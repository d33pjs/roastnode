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
- Rich private Bean metadata, including roast type, grind state (`whole_bean` or `pre_ground`), degree of roast, blend type, decaf flag, cost, Purchase Website (`purchase_url`), Coffee Origin Website (`coffee_origin_url`), flavor profile, and variety information. Both direct website fields are included in the owner-only JSON and Beans CSV exports.
- Equipment machine-capability flags for pre-infusion, low-flow start, and flow control.
- Brew method fields, including espresso low-flow-start seconds and flow-control use, Quick Drip brewer, machine cups, coffee spoons, grams per coffee spoon, coffee amount source, and the private six-field recipient/Cup contract.
- Private Guest cupping comments as `cupping_feedback_comment` on Brew rows in JSON only.
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

The beans CSV includes flat bag metadata such as names, roaster, derived status (`stock`, `open`, `finished`, `used_up`, or `archived`), remaining grams, roast data, variety information, purchase details, both private Bean website columns, rating, notes, and timestamps.

The brews CSV includes flat brew history such as occurred time, method, user labels, bean/equipment names, preparation tool snapshots, weights, Quick Drip cups/spoons/spoon grams, brew ratio, timing (including low-flow start), temperature, flow-control use, taste balance, rating, the exact private recipient/Cup fields below, retention marker, notes, and timestamps.

The brews CSV deliberately omits `cupping_feedback_comment`. Use the owner-only JSON when the private Guest comment is needed.

The External Coffees CSV includes occurred time, user labels, drink type, drink size, place name/location, private coordinates, price, currency, taste axes, rating, notes, public note, and timestamps.

CSV exports are useful for spreadsheets and quick analysis. They are not intended to fully reconstruct all relationships; use the JSON export for that.

## Privacy And Authorization

The export route uses the current active workspace and does not accept a workspace ID. `WorkspacePolicy#export?` is owner-only in this slice.

The export intentionally excludes:

- password digests
- sessions
- invite tokens
- cupping bearer tokens, token digests, deadlines, and request state
- signed media URLs
- records from other workspaces

Raw photo bytes are included only in the separate owner-only media ZIP.

Recipient email is intentionally present in owner-only workspace exports and in instance-admin readable/full backup payloads so a household recipient can be identified during inspection and restoration. Product coffee pages and public snapshots never expose it.

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

Each JSON Brew object emits these six fields in this exact order, including keys whose value is `null`; the brews CSV uses the same adjacent column order:

1. `recipient_kind`
2. `recipient_user_id`
3. `recipient_user_display_name`
4. `recipient_user_email_address`
5. `recipient_name`
6. `cup_style`

`recipient_kind` is `self`, `household_member`, or `guest`. The User fields are populated only from the linked recipient User; a former member remains reconstructable because the exported local User relationship survives membership removal. `recipient_name` is private Guest text, and Cup is independent of recipient kind. New exports do not emit the legacy `served_for_guest` or `guest_name` columns. The embedded `data/workspace-export.json` in a media ZIP uses this same payload contract.

Each Brew JSON object also includes `cupping_feedback_comment`, which is the private Guest comment or `null`. The workspace payload intentionally has no top-level `cupping_requests` collection. Its JSON and the media ZIP's embedded JSON therefore preserve the comment without preserving an anonymous bearer capability. Cupping requests select no record photos, so the media ZIP adds no cupping-specific media.

## Instance Backup Coverage

Instance backups and empty-server restore preserve the same Quick Drip durable fields: brew method, brewer references, machine cups, coffee spoons, grams per coffee spoon, coffee amount source, all six recipient/Cup fields, bean grind state, preparation tool method, and user enabled-method/spoon preferences. They also preserve machine extraction-capability flags, brew low-flow-start seconds and flow-control use, External Coffee records, and photos. Older backup payloads restore existing machines with pre-infusion enabled for compatibility, and older Brew recipient rows use the narrow legacy rules in [Instance Backup System](backup-system.md).

## Deferred

- Workspace deletion and transfer.
- Non-owner export policy variants.
