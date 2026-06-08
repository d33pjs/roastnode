# Preparation Tools

Preparation Tools are reusable workspace checklist items for brew preparation. They are separate from equipment: grinders, machines, and brewers remain `Equipment`, while tools like WDT, puck screens, paper filters, baskets, and tampers live here.

## Included Now

- Workspace-scoped preparation tools.
- Espresso and Quick Drip method support.
- Tool index and detail screens for all workspace members with read access.
- Owner/admin-only creation and edit screens.
- Optional preparation tool photos on create and edit.
- Owner/admin-only primary photo selection, cropping, removal, archive/reopen, and destructive danger-zone delete.
- Private viewing/download of preparation tool photos for workspace members with read access.
- Manual sort position for checklist ordering.
- Detail analytics for usage count, total coffee ground, average rating/yield/time, taste balance, best brews, and recent brews. Channeling and retention metrics are espresso-only.
- Optional date range filters for brew-derived tool analytics.
- Brew form checklist for active tools for the selected method.
- Per-brew snapshots of selected tool names.
- Last-brew defaults for active same-method tools from the current user's previous brew.

## Brew Defaults

When opening a new brew form, Roastnode preselects preparation tools from the current user's most recent brew for the selected method in the active workspace.

Only tools that still exist, are active, belong to the active workspace, and use the selected method are selected. Espresso and Quick Drip tool snapshots do not mix; Quick Drip uses Quick Drip tools such as paper filters, while espresso tools such as WDT or puck screens stay on espresso brews.

## Snapshot Rules

Saving a brew creates `BrewPreparationTool` snapshot rows with:

- `preparation_tool_id`
- `tool_name`
- `brew_method`
- `position`

The snapshot keeps old brew history readable if a tool is renamed later.

## Analytics

Preparation tool analytics are scoped through the active workspace tool. Date range filters are inclusive and apply to brew-derived values: usage count, total coffee ground, averages, taste balance, best brews, and recent brews. Channeling and retention are espresso-only and should not be implied for Quick Drip tools. Tool lifecycle fields such as active status, method, and position remain current tool facts.

## Authorization

Owners and admins manage preparation tool records and photos. Members can view tools and use active tools while logging brews, but cannot add, edit, archive, reopen, delete, or manage photos for preparation tools. Viewers are read-only.

## Delete

Preparation tool deletion lives in the detail-page danger zone. It removes the live tool record and its photos, but preserves brew history by keeping `BrewPreparationTool` snapshot rows and clearing their `preparation_tool_id`.

Use `PreparationTool#destroy_with_history!` for destructive deletes so the snapshot-preservation rule stays centralized.

## Deferred

- Recipe-defined preparation tool defaults.
- Drag-and-drop ordering.
