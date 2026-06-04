# Workspace Settings

Workspace settings are scoped to the current active workspace.

## Included Now

- Owners and admins can open `/workspace/edit`.
- The page edits the household/workspace name, default currency, household logo, and household banner.
- The page can configure a public footer support badge for the household. It supports the existing simple Buy Me a Coffee URL badge and an opt-in official Buy Me a Coffee script badge driven by slug and display text.
- The page lists public brew shares for the active workspace, including each public URL, linked brew, enabled state, creation/update timestamps, view count, retained recent IP history as a compact list, and quick open/edit/remove actions.
- Owners see a deletion danger zone with typed-name confirmation.
- The route is singleton and uses `current_workspace`; it does not accept a workspace ID.
- Members and viewers are redirected by the existing workspace admin authorization helper.
- `Workspace#default_currency` is normalized to uppercase.
- `Workspace#buy_me_a_coffee_url` is optional and accepts only HTTP(S) URLs on `buymeacoffee.com` or `www.buymeacoffee.com`.
- Official Buy Me a Coffee badge mode stores only slug and text, validates the slug, and loads `https://cdnjs.buymeacoffee.com/1.0.0/button.prod.min.js` on public shared pages.
- The household logo is shown in the Hero Brew Card workspace pill when available.
- Household logo changes refresh existing public brew-share snapshots that belong to the workspace.

## Boundaries

The settings page does not edit workspace kind, ownership transfer, public visibility, or billing settings. It also does not expose public recipe-share management yet. Ownership transfer lives on the members page.

Use `dashboard_path` after updates so users whose preferred landing screen is `log_espresso` return to the dashboard after changing settings.
