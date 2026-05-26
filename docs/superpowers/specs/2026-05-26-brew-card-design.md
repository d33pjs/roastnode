# Brew Card Design

## Goal

Make the brew detail page and dashboard feel like compact, screenshot-worthy private brew surfaces while still preserving all practical espresso data needed for comparison and correction.

## Approved Direction

Use a dense Hero Brew Card, not a sparse detail page. The card should fit more information into one strong visual surface:

- European timestamp first: `dd.mm.yyyy HH:MM:ss`
- household/workspace name second
- brew method
- bean name and roaster
- bean origin/process/roast level when present
- safe logged-by profile label
- dose from the espresso form, not bean-in inventory weight
- calculated brew ratio with total time as smaller secondary text, not duplicated beverage yield in the top metric row
- grind setting
- rating as visual bean marks
- balance as a compact badge
- extraction chart showing beverage curve, preinfusion marker, first drip when present, total time, and a separate temperature line
- grinder, machine, and preparation tool snapshots in one compact line

The chart should not include a title or subtitle inside the card. It should be short enough to keep the whole card compact. The beverage curve and temperature line need enough vertical separation so the labels do not visually collide. Labels that sit near plotted lines should use small callouts. The beverage y-axis should round above the actual beverage yield, so the curve has visual headroom. The top metric row should remain four compact rectangles even at phone-like widths.

The dashboard should reuse the same hero card partial for the latest brew and the latest highest-rated brew. The brew detail page should keep the hero focused, then place the complete logged espresso data below it, including channeling, notes, inventory weights, timing fields, equipment, and preparation tools.

## Data Rules

The card is workspace-private and rendered from the active workspace's brew through `brews/_hero_card`. Preparation tools must use the brew snapshot (`BrewPreparationTool#tool_name`) rather than current tool names. Screenshot-friendly cards must not expose `User#email_address`; user labels should use `User#display_label`, falling back to `unknown username`.

The chart is an illustrative extraction profile based on stored totals, not a sampled telemetry graph. Roastnode currently stores total beverage, total time, preinfusion, first drip, and temperature, but not per-second flow data.

## Deferred

- Exporting the brew card as an image.
- Public sharing links.
- Workspace/household name editing.
- Real flow telemetry or smart-scale data.
- Multiple chart styles.
