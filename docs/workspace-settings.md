# Workspace Settings

Workspace settings are scoped to the current active workspace.

## Included Now

- Owners and admins can open `/workspace/edit`.
- The page edits the household/workspace name, default currency, household logo, and household banner.
- The page can store one optional Buy Me a Coffee URL for the household. When present, public shared brew and recipe pages show it as a footer support badge.
- The page lists public brew shares for the active workspace, including each public URL, linked brew, enabled state, creation/update timestamps, view count, latest view IP/time, retained recent IP history, and quick open/edit/remove actions.
- Owners see a deletion danger zone with typed-name confirmation.
- The route is singleton and uses `current_workspace`; it does not accept a workspace ID.
- Members and viewers are redirected by the existing workspace admin authorization helper.
- `Workspace#default_currency` is normalized to uppercase.
- `Workspace#buy_me_a_coffee_url` is optional and accepts only HTTP(S) URLs on `buymeacoffee.com` or `www.buymeacoffee.com`.
- The household logo is shown in the Hero Brew Card workspace pill when available.
- Household logo changes refresh existing public brew-share snapshots that belong to the workspace.

## Boundaries

The settings page does not edit workspace kind, ownership transfer, public visibility, or billing settings. It also does not expose public recipe-share management yet. Ownership transfer lives on the members page.

Use `dashboard_path` after updates so users whose preferred landing screen is `log_espresso` return to the dashboard after changing settings.
