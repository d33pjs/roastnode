# Dashboard Metrics Design

## Goal

Add a richer dashboard overview that answers "how much coffee is happening right now?" without demoting the existing visual coffee hero cards.

The dashboard should make time since the last coffee immediately visible, add daily and weekly coffee/brew/spend counts, clarify bean stock versus open-bean inventory, and show small trend visualizations against recent averages.

## Accepted Approach

Use the revised "Prominent Timer + Existing Heroes + Compact Metrics" layout.

The top dashboard order becomes:

1. a prominent live "time since last coffee" card
2. the existing full `Latest coffee` hero card and existing full `Latest best brew` hero card, not wrapped inside another visual card container
3. a compact metric grid with strong contrast labels, values, sparklines, and explicit average comparison text where relevant
4. the existing open-bean cockpit and recent activity sections

The timer must be checked on wide monitors. It should lead the page without becoming awkwardly stretched or visually empty. The implementation should use a constrained inner layout or responsive grid behavior if the full-width timer reads poorly at large desktop widths.

## Metrics

All metrics are scoped to `current_workspace`.

- `Coffees today`: count of brews plus external coffees whose `occurred_at` falls within today.
- `Coffees this week`: count of brews plus external coffees whose `occurred_at` falls within the current week.
- `Brews today`: count of `Brew` records whose `occurred_at` falls within today.
- `Brews this week`: count of `Brew` records whose `occurred_at` falls within the current week.
- `Bean bags in stock`: count of unopened stock beans, not open bags.
- `Grams in stock`: sum of `remaining_grams` for unopened stock beans.
- `Grams remaining in open beans`: renamed existing open-bean remaining total, using only open beans.
- `Spent today`: estimated brew bean cost plus explicit external coffee prices for today.
- `Spent this week`: estimated brew bean cost plus explicit external coffee prices for the current week.
- `Time since last coffee`: live duration since the newest Brew or External Coffee, updating every second in the browser.

## Cost Rules

Brew spend uses the same rough cost basis as statistics: `brew.bean_weight_grams * bean.purchase_price_cents / bean.bag_size_grams` when the bean has a known purchase price and positive bag size. Brews without cost data contribute zero to the rough spend total.

External coffee spend uses `ExternalCoffee#price_cents` when present. External coffees without a price contribute zero.

Dashboard spend is intentionally "rough" because brew costs are estimated from beans and external coffees only have explicit prices when the user enters them.

## Average Comparisons

Only these cards get an average comparison and sparkline:

- Coffees today
- Coffees this week
- Brews today
- Brews this week
- Spent today
- Spent this week

Today metrics compare against the average of the same weekday over the last 4 completed weeks. For example, a Wednesday compares against the previous 4 Wednesdays.

This-week metrics compare against the average of the last 4 completed weeks, excluding the current partial week.

Each comparison card shows:

- the current value
- a small line chart showing the four baseline values plus the current value
- a compact label such as `+12% over last 4 weeks`, `-4% over last 4 weeks`, or `same as last 4 weeks`

The text label is the precise explanation. The sparkline is only a directional visual aid.

When the average baseline is zero:

- if the current value is also zero, show `same as last 4 weeks`
- if the current value is positive, show `new over last 4 weeks`

## UI Details

Metric card typography should be readable on white backgrounds. Avoid light gray labels for primary metric text. Labels, values, deltas, and sparklines need enough contrast to scan quickly.

Use green for over-average trend lines and labels, red for under-average trend lines and labels, and neutral muted styling for flat or unavailable comparisons. Do not rely on color alone; the plus/minus text must remain visible.

The metric grid should remain compact on desktop, collapse cleanly on tablet/mobile, and avoid text overflow for money values and the longer `Grams remaining in open beans` label.

The timer card should use one live-updating Stimulus controller with a server-rendered starting timestamp. It should degrade gracefully if JavaScript is unavailable by showing the server-rendered duration at page load.

## Data Flow

Move dashboard metric aggregation out of `HomeController#load_dashboard` into a small query-backed service so the controller remains thin and the metric behavior can be unit tested.

The service should return plain values suitable for rendering:

- counts and gram totals
- money totals in cents
- the latest coffee timestamp
- comparison percentages, labels, trend direction, and sparkline points

The view should render these values without performing aggregation queries.

## Testing

Add service tests for:

- workspace isolation
- coffee counts including both brews and external coffees
- brew-only counts excluding external coffees
- stock bean counts and grams excluding open beans
- open-bean remaining grams excluding stock beans
- rough spend from priced brews and priced external coffees
- missing prices contributing zero to spend
- last-4-week comparison labels and baseline-zero behavior

Add controller/view tests for:

- dashboard renders the new labels and values
- `Latest coffee` and `Latest best brew` remain full hero card sections
- the timer card appears before the hero cards
- trend cards include explicit `over last 4 weeks` text

Add a lightweight Stimulus test for the live duration formatter if the existing JavaScript test setup supports it.

Before finishing implementation, visually check the dashboard at normal desktop, wide desktop, and mobile widths, with particular attention to whether the timer card looks awkward on wide monitors.
