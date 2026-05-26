# Preparation Tools Design

## Intent

Preparation Tools completes the missing part of the last-brew default contract. Espresso brews can record reusable workflow tools like WDT, puck screen, paper filter, basket, and tamper without treating those items as grinder or machine equipment.

## Included Now

- Workspace-scoped preparation tools.
- Tools are method-scoped, with `espresso` as the first method.
- Owners, admins, and members can create, edit, archive, and reopen tools.
- Viewers can read tools but not manage them.
- Tools have detail pages, manual position ordering, notes, and additive photo management.
- Tool photos use the shared private media flow for primary selection, viewing, download, crop, and removal.
- Espresso brew forms show active workspace tools as a checklist.
- Brews snapshot selected tool names at save time.
- New espresso brews preselect active tools from the current user's last brew.
- Workspace JSON export includes preparation tool active status, position, and photo metadata.

## Explicitly Deferred

- Recipe-defined default tools.
- Drag-and-drop ordering and per-user hidden fields.
- Analytics by preparation tool.
- Destructive delete/danger-zone workflow.

## Domain Model

`PreparationTool` belongs to a workspace and represents a reusable method-scoped checklist item.

Fields:

- `workspace`
- `name`
- `brew_method`, default `espresso`
- `active`, default `true`
- `position`, default `0`
- `notes`
- `primary_photo_attachment_id`
- `photos`, Active Storage attachments

`BrewPreparationTool` belongs to a brew and optionally points back to a `PreparationTool`. It also stores `tool_name` and `brew_method` snapshots so brew history remains readable if a tool is renamed later.

## Brew Defaults

The new espresso form copies preparation tools from the current user's most recent brew in the active workspace. Only tools that still exist, are active, and belong to the active workspace are preselected.

## Authorization And Isolation

- All preparation tool queries go through `current_workspace`.
- Eventual brew selection accepts only active tools from the current workspace.
- Cross-workspace tool IDs are ignored rather than linked.

## Testing Notes

Tests must cover:

- workspace-scoped tool listing, details, creation, editing, archive, and reopen
- viewer write denial
- photo attachment management on edit
- brew creation snapshotting selected tools
- cross-workspace tool IDs not being linked
- new brew form preselecting last brew tools
