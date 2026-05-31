# Brew Taste Corrections And Dose Sync Design

Date: 2026-05-31

## Goal

Make day-to-day brew logging smoother by allowing deliberate post-save taste corrections, tightening rating bounds, and copying ground-out weight into dose while the user is logging a shot.

## Scope

Included:

- A compact brew-detail form for rating and taste balance only.
- A dedicated update path that changes only subjective taste fields.
- Rating validation and UI controls constrained to `1..5` or blank.
- One-way browser-side dose prefill from `ground_weight_grams` to `dose_grams`.
- Tests for authorization, validation, and JavaScript wiring.

Deferred:

- Auto-saving subjective fields.
- Editing other brew fields from the detail page.
- Changing bean ratings.
- Any preference toggle for dose sync.

## Behavior

Writers see an "Adjust taste" panel on the brew detail page. The panel contains taste balance, rating, and an explicit Save button. Changing a field without pressing Save does not persist anything. Viewers do not see the panel.

Submitting the panel updates only `taste_balance` and `rating`. It does not touch inventory, preparation-tool snapshots, dose, yield, notes, photos, or equipment. The normal full edit page remains the correction path for all other brew fields.

Rating accepts blank or an integer from 1 through 5. The application rejects 0, values above 5, decimals, and non-numeric input. The new/edit brew form and taste correction form both render number inputs with `min=1`, `max=5`, and `step=1`.

When a user types in Ground out on the brew form, JavaScript copies that value into Dose if the dose field has not been manually changed in the current form session. Editing Dose marks it as user-controlled, and later Ground out changes no longer overwrite it. Dose never writes back to Ground out.

## Architecture

Add a small member route on `brews` for subjective fields, implemented as a dedicated controller action using the existing active-workspace lookup and write authorization. Keep the inventory-safe `update` action unchanged for full corrections.

Add a focused Stimulus controller for dose sync and attach it to the shared brew form only when both fields render. This keeps the behavior local to the form and independent of browser-local draft recovery.

## Error Handling

Invalid taste-correction submissions re-render the brew detail page with validation errors and do not persist partial changes. Unauthorized users continue to redirect through existing workspace-write authorization.

If hidden-field preferences hide either Ground out or Dose, dose sync is not attached. If the fields are present but blank, the sync simply copies the current typed string and leaves server-side decimal normalization unchanged.

## Tests

- Model test rejects rating `0`, `6`, decimals, and accepts blank plus `1..5`.
- Controller test confirms writers can update only taste balance and rating from the detail page.
- Controller test confirms the taste update does not change inventory-affecting fields when extra params are submitted.
- Controller/view test confirms viewers do not see or submit taste corrections.
- Form/view tests confirm rating fields use `min=1`, `max=5`, and `step=1`.
- Asset test confirms the dose-sync controller listens one way from ground out to dose and disables overwrite after dose input.

## Documentation

Update coffee-core or brew-corrections documentation to state that subjective taste fields can be adjusted from brew detail without running the full inventory correction flow.
