# Preparation Tools

Preparation Tools are reusable workspace checklist items for brew preparation. They are separate from equipment: grinders and machines remain `Equipment`, while tools like WDT, puck screens, paper filters, baskets, and tampers live here.

## Included Now

- Workspace-scoped preparation tools.
- Espresso method support.
- Tool index and creation screens.
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
- Inactive/archive UI.
- Tool ordering controls.
- Tool photos.
- Preparation tool analytics.
