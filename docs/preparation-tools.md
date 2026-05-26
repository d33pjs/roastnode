# Preparation Tools

Preparation Tools are reusable workspace checklist items for brew preparation. They are separate from equipment: grinders and machines remain `Equipment`, while tools like WDT, puck screens, paper filters, baskets, and tampers live here.

## Included Now

- Workspace-scoped preparation tools.
- Espresso method support.
- Tool index, detail, creation, and edit screens.
- Optional preparation tool photos on create and edit.
- Primary photo selection, private viewing/download, cropping, and removal through the shared media flow.
- Archive and reopen lifecycle.
- Manual sort position for checklist ordering.
- Detail analytics for usage count, total coffee ground, average rating/yield/time, channeling rate, taste balance, retention markers, best brews, and recent brews.
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

## Deferred

- Recipe-defined preparation tool defaults.
- Drag-and-drop ordering.
- Destructive delete/danger-zone workflow.
