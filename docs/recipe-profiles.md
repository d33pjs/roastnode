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
- One optional private finished-drink photo rendered through authenticated media routes.
- Recipe creation from a source brew can explicitly reuse the source brew's primary photo; reuse is suggested but never preselected.
- Source brew provenance and public-safe bean/equipment/tool snapshots.
- Public-safe recipe links through the shared record-link system.
- Viewer read-only access. Workspace writers can create, edit, delete, and start recipe-guided logging flows.
- Recipe-guided brew logging overlays the target guide beside the normal espresso form.
- Guided logging stores `recipe_id` and a brew-time `recipe_snapshot` on the saved brew.
- Hero Brew Cards render a subtle recipe target ghost from the brew-time snapshot when one exists.
- Portable recipe JSON export and import using schema `roastnode.recipe`, version `1`.
- Recipe import creates an unlinked private recipe snapshot and public recipe links only.
- Public recipe sharing through unlisted token pages with optional password protection.
- Public recipe pages render the prominent target markers, public guide notes, public source-brew note, and public recipe links from a curated snapshot.

## Privacy And Ownership

- `Recipe` belongs to `Workspace`; every controller lookup must go through `current_workspace.recipes`.
- Recipes may reference a `source_brew`, but only from the same workspace.
- Private recipe photos belong to the recipe workspace and must render through `MediaAttachmentsController`.
- Reused source brew photos attach the source blob to the recipe; forged or cross-workspace source photo IDs must not create recipes.
- Recipe snapshots copy public-safe context from the source brew. They must not copy private brew notes, private record links, private media URLs, signed Active Storage URLs, invite tokens, emails, equipment costs, or raw attachment IDs.
- Recipes are private by default. Public recipe sharing uses `PublicRecipeShare` and a separate curated snapshot, not live private records.
- Workspace owners/admins can manage any workspace recipe share. Workspace writers can manage only shares for recipes they created. Viewers cannot manage recipe shares.
- Public recipe pages do not expose recipe media in v1. They must not render raw Active Storage routes, media attachment routes, raw attachment IDs, original filenames, or private media handles.

## Current Limits

- Espresso is the only recipe method in v1.
- Recipes are built from existing brews; blank recipe authoring is not the primary path yet.
- Targets are exact values, not ranges.
- Opening a recipe log flow does not overwrite normal last-brew defaults. Recipe targets are an overlay/guide only.
- Machine-readable brew profile files are deferred.
- Public recipe media, comments, reactions, analytics, and public recipe indexes are deferred to later slices.

## Agent Notes

- Use `current_workspace`, `current_membership`, and `current_workspace_policy`.
- Use `current_workspace_policy.write?` for create/edit/delete/log actions; viewers can index and show only.
- Keep recipe profile data in canonical metric units: grams, seconds, Celsius.
- Brews logged with a recipe must store both `recipe_id` and a brew-time `recipe_snapshot` so future recipe edits do not rewrite history.
- Recipe import creates an unlinked recipe snapshot only. Do not auto-create beans, equipment, tools, media, or brews from imported recipe data.
- Public recipe pages must use curated `PublicRecipeShare` snapshots. Do not read live private recipe/source-brew/bean/equipment/tool records while rendering a public recipe page.
