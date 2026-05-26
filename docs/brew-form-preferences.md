# Brew Form Preferences

Roastnode keeps espresso logging fast by storing small per-user form preferences.

## Included Now

- `User#default_brew_focus_field` stores the field that should receive autofocus on the new espresso form.
- The profile page exposes the setting next to the landing screen preference.
- The preference applies to `BrewsController#new` and validation re-renders from `#create`.
- Brew correction/edit forms do not autofocus by default, because editing is a review task rather than the daily quick-entry path.

## Supported Focus Fields

- `bean_weight_grams`
- `ground_weight_grams`
- `dose_grams`
- `beverage_grams`
- `grind_setting`
- `brew_temperature_celsius`
- `total_time_seconds`
- `preinfusion_seconds`
- `first_drip_seconds`
- `notes`

Do not add rating, channeling, photos, or taste balance to this list without a real logging need. Those fields should stay deliberate instead of becoming the first active input.

## Deferred

- Hiding optional fields per user.
- Per-method focus preferences once non-espresso templates exist.
- Unsaved draft recovery for fast mobile brew entry.
