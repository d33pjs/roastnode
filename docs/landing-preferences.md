# Landing Preferences

Roastnode lets each user choose what opens after sign-in or when visiting `/`.

## Included Now

- `User#default_landing_screen` stores the preference.
- Supported values are:
  - `dashboard`
  - `log_espresso`
- The profile page exposes the preference next to the username.
- `/` honors the preference for authenticated users with an active workspace.
- `/dashboard` always renders the workspace dashboard and bypasses the preference.

## Navigation Rule

Use `root_path` when a link should mean "go to my preferred start screen".

Use `dashboard_path` when a link specifically says "Back to dashboard" or must avoid opening the brew form again. This prevents navigation loops for users whose preferred landing screen is `log_espresso`.

## Deferred

- More landing screens.
- Per-workspace landing preferences.
