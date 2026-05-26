# Brew Card

The brew detail page uses a compact Hero Brew Card for screenshot-worthy private espresso logs.

## Included Now

- European timestamp with seconds: `dd.mm.yyyy HH:MM:ss`.
- Active workspace/household name on the card.
- Bean roaster, bean name, and compact origin/process/roast-level descriptor.
- Dose from the espresso form.
- Beverage yield.
- Grind setting.
- Rating as five visual bean marks.
- Taste balance as a badge.
- Extraction chart with beverage curve, preinfusion marker, total time, and a separate temperature line.
- Grinder, machine, and brew preparation tool snapshots in one compact row.
- Edit/delete actions remain available to workspace writers.
- Existing private photos and notes remain below the card.

## Chart Rule

The chart is an illustrative profile generated from stored brew totals. It is not sampled flow telemetry. Roastnode currently stores total beverage, total time, preinfusion, and temperature, so the curve communicates the brew shape without claiming second-by-second measurement.

## Agent Notes

- Use `BrewPreparationTool#tool_name` for displayed tools, not current `PreparationTool#name`.
- The card shows `dose_grams` as Dose. `bean_weight_grams` remains inventory input and is not the main card dose.
- Keep the card dense; avoid adding explanatory headings inside the chart.
- Preserve private media rendering through `media_attachment_path`.
