# Workspace Settings

Workspace settings are scoped to the current active workspace.

## Included Now

- Owners and admins can open `/workspace/edit`.
- The page edits the household/workspace name and default currency.
- The route is singleton and uses `current_workspace`; it does not accept a workspace ID.
- Members and viewers are redirected by the existing workspace admin authorization helper.
- `Workspace#default_currency` is normalized to uppercase.

## Boundaries

The settings page does not edit workspace kind, ownership transfer, deletion, public visibility, or billing settings. Those are separate future slices.

Use `dashboard_path` after updates so users whose preferred landing screen is `log_espresso` return to the dashboard after changing settings.
