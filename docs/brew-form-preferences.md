# Brew Form Preferences

Roastnode keeps daily logging fast by storing small per-user form preferences in Profile.

## Included Now

- `User#default_brew_focus_field` stores the field that should receive autofocus on the new espresso form.
- `User#hidden_brew_field_names` stores optional espresso fields that should be hidden on the new espresso form.
- `User#enabled_brew_methods` stores which method tabs appear on the Log screen. Users must keep at least one method enabled.
- `User#grams_per_coffee_spoon` stores the user's Quick Drip spoon estimate, used when a Quick Drip log has Coffee spoons but no measured Ground coffee.
- The profile page exposes the setting next to the landing screen preference.
- Preferences apply to `BrewsController#new` and validation re-renders from `#create`.
- Brew correction/edit forms do not autofocus or hide fields by default, because editing is a review task rather than the daily quick-entry path.
- Machine extraction options are applied before these profile preferences on new espresso logs. Selecting a machine can expose its pre-infusion, low-flow-start, and flow-control fields; saved historical fields remain available on edit even when the machine configuration later changes.

## Supported Focus Fields

- `bean_weight_grams`
- `ground_weight_grams`
- `dose_grams`
- `beverage_grams`
- `grind_setting`
- `brew_temperature_celsius`
- `total_time_seconds`
- `preinfusion_seconds`
- `low_flow_start_seconds`
- `first_drip_seconds`
- `notes`

Do not add rating, channeling, photos, or taste balance to this list without a real logging need. Those fields should stay deliberate instead of becoming the first active input.

## Hideable Fields

Users can hide optional fields from the daily new espresso form:

- `ground_weight_grams`
- `dose_grams`
- `beverage_grams`
- `grind_setting`
- `brew_temperature_celsius`
- `total_time_seconds`
- `preinfusion_seconds`
- `low_flow_start_seconds`
- `first_drip_seconds`
- `taste_balance`
- `rating`
- `channeling`
- `flow_control_used`
- `notes`
- `photos`

Do not allow hiding the bean selector or bean-in weight; espresso logging needs both for inventory.

## Quick Drip Boundaries

Quick Drip v1 uses method enablement and grams per coffee spoon from Profile, but espresso focus and hidden-field preferences still apply only to the espresso form.

Spoon-only Quick Drip logs estimate consumed inventory from `coffee_spoons * grams_per_coffee_spoon`. Measured Ground coffee takes precedence, and the model falls back to 5g/spoon when no user preference is present.

Quick Drip omits espresso-only fields: temperature, preinfusion, low-flow start, first drip, channeling, and flow-control use.

## Deferred

- Per-method focus preferences for Quick Drip and future methods.
