# Workspace Settings

Workspace settings are scoped to the current active workspace.

## Included Now

- Owners and admins can open `/workspace/edit`.
- The page edits the household/workspace name, default currency, household logo, and household banner.
- Owners see a deletion danger zone with typed-name confirmation.
- The route is singleton and uses `current_workspace`; it does not accept a workspace ID.
- Members and viewers are redirected by the existing workspace admin authorization helper.
- `Workspace#default_currency` is normalized to uppercase.
- The household logo is shown in the Hero Brew Card workspace pill when available.

## Boundaries

The settings page does not edit workspace kind, ownership transfer, public visibility, or billing settings. Ownership transfer lives on the members page.

Use `dashboard_path` after updates so users whose preferred landing screen is `log_espresso` return to the dashboard after changing settings.
