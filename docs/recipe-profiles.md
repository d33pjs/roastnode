# Recipe Profiles

Recipe profiles are workspace-scoped brew targets created from existing brews. They let a household save "this worked" as exact espresso targets without changing the normal brew logging defaults.

## Included Now

- Private recipe records owned by the active workspace.
- Recipe creation from an existing workspace brew.
- Editable exact espresso target values:
  - bean in
  - ground out
  - dose
  - beverage yield
  - grinder setting
  - temperature
  - pre-infusion seconds
  - first-drip seconds
  - total time
- A prominent target guide that puts the key markers first: set grinder, watch dose/bean-in, and stop at time/yield.
- Optional guide notes for flow/blonding observations and pressure-gauge behavior.
- Source brew provenance and public-safe bean/equipment/tool snapshots.
- Public-safe recipe links through the shared record-link system.
- Viewer read-only access. Workspace writers can create, edit, delete, and start recipe-guided logging flows.

## Privacy And Ownership

- `Recipe` belongs to `Workspace`; every controller lookup must go through `current_workspace.recipes`.
- Recipes may reference a `source_brew`, but only from the same workspace.
- Recipe snapshots copy public-safe context from the source brew. They must not copy private brew notes, private record links, private media URLs, signed Active Storage URLs, invite tokens, emails, equipment costs, or raw attachment IDs.
- Recipes are private by default. Public recipe sharing must use a separate curated snapshot, not live private records.

## Current Limits

- Espresso is the only recipe method in v1.
- Recipes are built from existing brews; blank recipe authoring is not the primary path yet.
- Targets are exact values, not ranges.
- The private library exists before guided logging integration. Opening a recipe log flow must not overwrite normal last-brew defaults; the recipe should appear as an overlay/guide only.
- Machine-readable brew profile files are deferred.
- Public recipe sharing, JSON import/export, recipe media, comments, reactions, analytics, and public recipe indexes are deferred to later slices.

## Agent Notes

- Use `current_workspace`, `current_membership`, and `current_workspace_policy`.
- Use `current_workspace_policy.write?` for create/edit/delete/log actions; viewers can index and show only.
- Keep recipe profile data in canonical metric units: grams, seconds, Celsius.
- When a brew is eventually logged with a recipe, store both `recipe_id` and a brew-time `recipe_snapshot` so future recipe edits do not rewrite history.
- Recipe import must create an unlinked recipe snapshot only. Do not auto-create beans, equipment, tools, media, or brews from imported recipe data.
