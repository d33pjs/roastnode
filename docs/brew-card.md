# Brew Card

The brew detail page and dashboard use a compact Hero Brew Card for screenshot-worthy private espresso logs.

## Included Now

- European timestamp with seconds: `dd.mm.yyyy HH:MM:ss`.
- Active workspace/household name on the card.
- Household logo inside the workspace pill when one is attached.
- Bean roaster, bean name, compact origin/process/roast-level descriptor, and the bean primary photo when available. Keep the photo to the right of the name block so the text stays the first read.
- Safe logged-by label from the user's profile username, falling back to `unknown username`.
- User avatar next to the logged-by label when one is attached.
- Dose from the espresso form.
- Brew ratio calculated from beverage yield and dose, including total time when present.
- Grind setting.
- Grinder retention calculated from bean-in minus ground-out weight.
- Rating as five visual bean marks.
- Taste balance as its own compact metric rectangle.
- Extraction chart with beverage curve, preinfusion marker, first-drip marker when present, total time, and a separate temperature line with a vertical right-edge temperature label.
- Chart labels use small callouts when they would otherwise collide with plot or guide lines.
- The beverage y-axis label rounds above the actual beverage yield, for example `45.2 g` displays against a `50 g` axis marker.
- Grinder, machine, and brew preparation tool snapshots in one compact row, with tiny primary equipment photos when available.
- Bean names, bean package photos, grinder/machine pills, and preparation-tool chips link back to their relevant detail or list anchor.
- Edit/delete actions remain available to workspace writers.
- Brew detail pages show the full log below the hero card, including channeling, notes, inventory weights, and timing fields that do not belong in the hero.
- Existing private photos remain below the full log.
- The card does not expose the user's email address.
- The dashboard renders the latest brew and the latest highest-rated brew as hero cards after login.

## Chart Rule

The chart is an illustrative profile generated from stored brew totals. It is not sampled flow telemetry. Roastnode currently stores total beverage, total time, preinfusion, first drip, and temperature, so the curve communicates the brew shape without claiming second-by-second measurement.

## Agent Notes

- Use `BrewPreparationTool#tool_name` for displayed tools, not current `PreparationTool#name`.
- The card shows `dose_grams` as Dose. `bean_weight_grams` remains inventory input and is not the main card dose.
- The metric area uses Dose, Ratio, Grind, Retention, Rating, and Balance. Mobile uses a balanced two-by-three grid and shortens the retention label to `Ret.`.
- Use the profile `display_name` through `User#display_label` for user-facing labels. Do not put `email_address` on screenshot-friendly brew cards.
- Render hero cards through `brews/_hero_card`; do not fork the dashboard and detail versions.
- Use `brew_card_photo_attachment`, which prefers the bean's primary package photo and falls back through the normal primary-photo helper.
- Keep grinder and machine primary photos small inside the bottom equipment pills; they are identity marks, not another full media area.
- Keep user avatars and household logos small; they should act like identity marks, not extra content blocks.
- Keep the card dense; avoid adding explanatory headings inside the chart.
- Keep the mobile chart compact: the x-axis intentionally maps total time into a shorter central span while preserving proportional timing for preinfusion, first drip, and total time.
- Preserve private media rendering through `media_attachment_path`.
