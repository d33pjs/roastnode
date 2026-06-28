# Brew Serving Metadata Design

Date: 2026-06-28

## Goal

Let workspace writers record who a brew was served for and what finished cup it became, without slowing down the main brew logging flow.

## Scope

Included:

- Private serving metadata on `Brew`: guest flag, optional guest label, and optional cup style.
- A brew-detail "Serving" correction panel near the existing taste correction panel.
- Free-text cup style entry with suggestions from seeded drink styles and active-workspace brew history.
- Private display on brew details and compact brew history cards.
- Workspace JSON/CSV export and instance backup coverage.
- Authorization and workspace-isolation tests for the new update path.

Deferred:

- Dedicated cup-style records or recipe-style drink templates.
- Ingredient tracking for milk, water, ice, syrups, or other finish additions.
- Public sharing of guest labels or cup style.
- Analytics grouped by cup style.
- Main brew-form controls for serving metadata.

## Behavior

Writers can log espresso and Quick Drip brews exactly as they do today. After saving, the brew detail page shows a "Serving" panel with:

- `served_for_guest`: checkbox.
- `guest_name`: optional text label, used only when the guest flag is enabled.
- `cup_style`: optional text label such as "Americano", "Latte", "Flat White", or "Iced Americano".

The Serving panel has an explicit Save button. Submitting it updates only serving metadata. It does not change inventory, brew measurements, equipment, preparation-tool snapshots, taste, rating, notes, photos, public notes, or public links.

Viewers can read private serving metadata on brew details and history cards, but they cannot edit it. Owners, admins, and members follow the existing workspace-write rule for updates.

Cup style is free text rather than an enum. The form offers suggestions by combining `ExternalCoffee::DRINK_TYPE_SUGGESTIONS` with distinct `cup_style` values previously used by brews in the active workspace. Users can still type values that are not suggested.

Guest labels are private household data. They may be names, nicknames, or group labels. Blank guest labels are allowed even when `served_for_guest` is true. When the guest flag is false, the application clears `guest_name` before validation so stale guest labels do not appear later.

## Privacy

Serving metadata is private by default. Public brew, public bean, and public recipe snapshots must not include `served_for_guest`, `guest_name`, or `cup_style` in this slice.

Workspace JSON/CSV exports and instance-readable backups include the fields because they are private owner/admin data exports. The fields must not be rendered on unauthenticated public pages or copied into public media manifests.

## Architecture

Add persisted columns to `brews`:

- `served_for_guest:boolean`, default `false`, null false.
- `guest_name:string`.
- `cup_style:string`.

Normalize `guest_name` and `cup_style` by stripping whitespace and storing blank values as `nil`. Limit both fields to a maximum of 120 characters.

Add a focused member route/action on `BrewsController` for serving metadata, parallel to the existing `taste` action. The action uses the existing active-workspace brew lookup and workspace-write authorization, then strong-parameters only the three serving fields.

Add a small suggestion endpoint only if a native datalist cannot cover the seeded-plus-history behavior cleanly. The endpoint must read suggestions only from `current_workspace.brews` and return distinct present cup styles.

## Display

On brew details, add serving metadata to the existing details grid:

- Show "Cup" with the cup style or "Unknown".
- Show "Guest" with the guest label when present, otherwise a yes/no label for the guest flag.

On compact history cards, show a small metadata chip when either cup style or guest flag is present. Keep the card dense and avoid pushing the existing metric cards out of shape.

Hero Brew Cards stay unchanged in this slice.

## Error Handling

Invalid serving submissions re-render the brew detail page with validation errors and do not persist partial changes. Extra submitted fields are ignored by strong parameters.

If the guest checkbox is unchecked, saved guest-name text is cleared before validation or save.

If cup-style suggestions cannot load, the text field still works normally.

## Tests

- Model test normalizes blank/whitespace serving fields and clears `guest_name` when `served_for_guest` is false.
- Model test enforces maximum lengths for `guest_name` and `cup_style`.
- Controller test confirms workspace writers can update serving metadata from brew detail.
- Controller test confirms the serving update ignores inventory-affecting and public fields.
- Controller/view test confirms viewers cannot see or submit the Serving correction form.
- Controller test confirms another workspace cannot update a brew through the serving route.
- View test confirms private brew details and compact history render saved serving metadata.
- Export tests confirm JSON, CSV, and instance-readable backups include the new fields.
- Public snapshot tests confirm public brew, public bean, and public recipe snapshots do not include serving metadata.

## Documentation

Update `docs/coffee-core.md` to describe private brew serving metadata and the post-brew Serving correction panel. Update `docs/workspace-export.md` to list the new brew export fields.
