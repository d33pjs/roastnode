# Brew Card

The brew detail page and dashboard use compact Hero Brew Cards for screenshot-worthy private brew logs.

## Included Now

- European timestamp with seconds: `dd.mm.yyyy HH:MM:ss`.
- Active workspace/household name on the card.
- Household logo inside the workspace pill when one is attached.
- Bean roaster, bean name, compact origin/roast-level descriptor, and a decorative two-photo Hero backdrop when Bean/Brew primary photos are available. The Bean occupies the contained left half and the finished Brew occupies the covered right half; either missing half stays black. Keep processing off the private Hero Brew Card.
- Safe logged-by label from the user's profile username, falling back to `unknown username`.
- User avatar next to the logged-by label when one is attached.
- Dose from the espresso form on espresso cards.
- Brew ratio calculated from beverage yield and dose, including total time when present.
- Grind setting.
- Grinder retention calculated from bean-in minus ground-out weight.
- Rating as five visual bean marks.
- Taste balance as its own compact metric rectangle.
- Extraction chart with beverage curve, preinfusion marker, first-drip marker when present, total time, and a separate temperature line with a vertical right-edge temperature label.
- Chart labels use small callouts when they would otherwise collide with plot or guide lines.
- Brews logged with a recipe snapshot show a faint recipe target ghost in the chart, including small target labels for preinfusion, first drip, total time, beverage yield, and temperature when those targets are present.
- Target temperature lines render above the current temperature line when the target is hotter, and below it when the target is cooler or the current temperature is unknown.
- Recipe snapshot targets for dose, yield/time, and grind appear as smaller target sub-values inside the matching metric rectangles.
- The beverage y-axis label rounds above the actual beverage yield, for example `45.2g` displays against a `50g` axis marker.
- Grinder, machine, brewer, and brew preparation tool snapshots in one compact row, with tiny primary equipment photos when available.
- Hero card internals are intentionally not links. On the dashboard the whole card is wrapped in a single brew-detail link, and nested anchors break browser rendering.
- Edit/delete actions remain available to workspace writers.
- Brew detail pages show the full log below the hero card, including channeling, notes, inventory weights, and timing fields that do not belong in the hero.
- Existing private brew photos remain below the full log, followed by read-only related photos from the bean, grinder, machine, brewer, and selected preparation tools when those records have photos.
- The card does not expose the user's email address.
- The dashboard renders the latest brew and the latest highest-rated brew as hero cards after login.
- Public brew share pages render a snapshot-driven public Hero Brew Card adapted from the private card's visual language. Its bottom gear/tool pills anchor to public product sections instead of private record routes.

## Quick Drip Cards

Quick Drip uses the same private Hero Brew Card family, but renders method-specific batch metrics instead of the espresso extraction chart. It shows machine cups, coffee amount, consumed coffee, beverage, time, rating, balance, brewer, grinder when present, and Quick Drip preparation tool snapshots.

Estimated consumed grams use a leading `~`. The Quick Drip card does not show espresso-only charting, retention, preinfusion, first drip, temperature, or channeling.

## Chart Rule

The chart is an illustrative profile generated from stored brew totals. It is not sampled flow telemetry. Roastnode currently stores total beverage, total time, preinfusion, first drip, and temperature, so the curve communicates the brew shape without claiming second-by-second measurement.

## Agent Notes

- Use `BrewPreparationTool#tool_name` for displayed tools, not current `PreparationTool#name`.
- The card shows `dose_grams` as Dose. `bean_weight_grams` remains inventory input and is not the main card dose.
- The espresso metric area uses Dose, Ratio, Grind, Retention, Rating, and Balance. Mobile uses a balanced two-by-three grid and can show the full retention label; the tighter desktop six-column row shortens it to `Ret.`.
- Use the profile `display_name` through `User#display_label` for user-facing labels. Do not put `email_address` on screenshot-friendly brew cards.
- Render hero cards through `brews/_hero_card`; do not fork the dashboard and detail versions.
- Public brew share pages use `public_brew_pages/_hero_card` because they render snapshot data and public media routes without `current_workspace`. Standalone public Quick Drip brew share pages are deferred, so public brew shares only resolve espresso brews. Public bean shares may still render Quick Drip brews as compact public-safe summaries.
- Keep cross-links in the full brew details below the hero card, not inside the hero card partial.
- Render the private Hero backdrop through the shared `brew_hero_backdrop` partial with independent Bean and Brew primary-photo URLs using the named `hero` private-media variant. Never substitute one photo for a missing half.
- Keep grinder, machine, and brewer primary photos small inside the bottom equipment pills; they are identity marks, not another full media area.
- Keep user avatars and household logos small; they should act like identity marks, not extra content blocks.
- Keep the card dense; avoid adding explanatory headings inside the chart.
- Keep recipe target ghosts subtle; the live brew remains the primary chart.
- Keep the mobile chart compact: the x-axis intentionally maps total time into a shorter central span while preserving proportional timing for preinfusion, first drip, and total time.
- Preserve private media rendering through `media_attachment_path`.
