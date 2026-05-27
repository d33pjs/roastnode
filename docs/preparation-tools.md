# Preparation Tools

Preparation Tools are reusable workspace checklist items for brew preparation. They are separate from equipment: grinders and machines remain `Equipment`, while tools like WDT, puck screens, paper filters, baskets, and tampers live here.

## Included Now

- Workspace-scoped preparation tools.
- Espresso method support.
- Tool index, detail, creation, and edit screens.
- Optional preparation tool photos on create and edit.
- Primary photo selection, private viewing/download, cropping, and removal through the shared media flow.
- Archive and reopen lifecycle.
- Destructive danger-zone delete that keeps brew snapshots readable.
- Manual sort position for checklist ordering.
- Detail analytics for usage count, total coffee ground, average rating/yield/time, channeling rate, taste balance, retention markers, best brews, and recent brews.
- Optional date range filters for brew-derived tool analytics.
- Brew form checklist for active espresso tools.
- Per-brew snapshots of selected tool names.
- Last-brew defaults for active tools from the current user's previous brew.

## Brew Defaults

When opening a new espresso brew form, Roastnode preselects preparation tools from the current user's most recent brew in the active workspace.

Only tools that still exist, are active, belong to the active workspace, and use the `espresso` method are selected.

## Snapshot Rules

Saving a brew creates `BrewPreparationTool` snapshot rows with:

- `preparation_tool_id`
- `tool_name`
- `brew_method`
- `position`

The snapshot keeps old brew history readable if a tool is renamed later.

## Analytics

Preparation tool analytics are scoped through the active workspace tool. Date range filters are inclusive and apply to brew-derived values: usage count, total coffee ground, averages, channeling, taste balance, retention markers, best brews, and recent brews. Tool lifecycle fields such as active status, method, and position remain current tool facts.

## Delete

Preparation tool deletion lives in the detail-page danger zone. It removes the live tool record and its photos, but preserves brew history by keeping `BrewPreparationTool` snapshot rows and clearing their `preparation_tool_id`.

Use `PreparationTool#destroy_with_history!` for destructive deletes so the snapshot-preservation rule stays centralized.

## Deferred

- Recipe-defined preparation tool defaults.
- Drag-and-drop ordering.
