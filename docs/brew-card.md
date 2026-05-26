# Brew Card

The brew detail page and dashboard use a compact Hero Brew Card for screenshot-worthy private espresso logs.

## Included Now

- European timestamp with seconds: `dd.mm.yyyy HH:MM:ss`.
- Active workspace/household name on the card.
- Bean roaster, bean name, and compact origin/process/roast-level descriptor.
- Safe logged-by label from the user's profile username, falling back to `unknown username`.
- Dose from the espresso form.
- Brew ratio calculated from beverage yield and dose, including total time when present.
- Grind setting.
- Rating as five visual bean marks, with taste balance below it in the same metric rectangle.
- Extraction chart with beverage curve, preinfusion marker, first-drip marker when present, total time, and a separate temperature line.
- Chart labels use small callouts when they would otherwise collide with plot or guide lines.
- The beverage y-axis label rounds above the actual beverage yield, for example `45.2 g` displays against a `50 g` axis marker.
- Grinder, machine, and brew preparation tool snapshots in one compact row.
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
- The top metric row stays four-up at narrow widths: Dose, Ratio, Grind, Rating/Balance. Keep ratio large and show total time as smaller secondary text inside the same rectangle.
- Use the profile `display_name` through `User#display_label` for user-facing labels. Do not put `email_address` on screenshot-friendly brew cards.
- Render hero cards through `brews/_hero_card`; do not fork the dashboard and detail versions.
- Keep the card dense; avoid adding explanatory headings inside the chart.
- Preserve private media rendering through `media_attachment_path`.
