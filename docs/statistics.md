# Statistics And Analytics

Roastnode's first analytics slice is a private workspace statistics page at `/statistics`.

## Included Now

- Dashboard link visible to workspace readers.
- Live query-backed totals:
  - total brews
  - beans ground
  - open beans
  - known bean spend
  - average known brew cost
  - channeling rate
- Most-used grinder and machine.
- Recent brews-by-day bars.
- Recent consumption-by-day bars.
- Manual date range filters and relative timeframe shortcuts for brew-based analytics.
- Independent **Logged by** and **Served to** filters for Brew-based analytics.
- Taste balance distribution.
- Retention marker distribution.
- Brew method distribution, including Quick Drip.
- Bean breakdowns by roaster, origin, and process.
- Bean detail analytics through `BeanStatistics`.
- Equipment detail analytics through `EquipmentStatistics`.
- Preparation tool detail analytics through `PreparationToolStatistics`.
- Statistics links to all-time brew history through a page-level all-brews button and the total-brews card.
- The dashboard's live time-since-last-coffee timer uses only non-guest brews plus External Coffee records. Brews marked as served for guests stay in history and inventory accounting but do not reset that timer.
- Six dashboard comparison cards render their last-four-period trend as quiet, non-interactive Chart.js line/area backgrounds. Chart.js 4.5.1 is vendored locally, loaded only when those Stimulus controllers connect, and the visible comparison sentence remains the accessible meaning.

## Cost Rules

- Bean spend uses `Bean#purchase_price_cents` in the workspace currency.
- Brew cost is calculated from bean weight and the selected bean's price per gram.
- Average brew cost includes only brews whose bean has a known purchase price and positive bag size.
- Unknown prices are allowed and excluded from average-cost calculations.

## Date Range Rules

- The workspace statistics page defaults to the most recent 7 days and marks the "7 days" quick range active when no manual range is supplied.
- `start_date` and `end_date` are inclusive and can be supplied as `YYYY-MM-DD` query parameters.
- `timeframe` can be one of `last_7_days`, `last_30_days`, `last_90_days`, `this_year`, or `all_time`.
- Timeframe shortcuts take precedence over manual date query parameters.
- `all_time` starts at the active workspace's first brew and ends at today or the latest brew date, whichever is later. If there are no brews, it uses today for both ends.
- Quick timeframe links preserve both people selections.
- **Reset date range** keeps the people selections while returning to the normal seven-day range. **Clear people filters** keeps the selected quick timeframe or manual dates. **Reset all** clears the people selections and restores the normal seven-day defaults.
- Links from statistics to brew history do not preserve the selected analytics date range; they always open all-time brew history.

## People Filter Rules

- **Logged by** filters the User who recorded the Brew. It uses `logger_id=<user id>` and is independent of **Served to**.
- **Served to** uses the exact tokens `recipient=self`, `recipient=guests`, or `recipient=user:<user id>`. Omitting either people parameter means all values for that dimension.
- `recipient=self` includes Brews marked as served to their logger. `recipient=guests` combines every Guest Brew without exposing individual Guest names.
- A named User selection combines that User's Self Brews with Brews explicitly served to that User as a household member.
- Named logger options include current household members plus historical Users who logged a Brew in the active workspace. Named recipient options include current household members plus historical Users represented by a Self Brew or an explicit household-member serving in that workspace. The UI uses each User's safe `display_label`; it never uses an email address as an analytics label.
- Guest names remain private Brew display data and never become analytics identities or filter options.
- Logger IDs and recipient tokens are validated against their corresponding option sets above. Unknown, malformed, dimension-ineligible, and foreign-workspace values receive the normal not-found response.
- The people and date controls share a responsive filter surface that wraps at narrow widths and supports the light and dark themes.

## Analytics Scope And Empty States

- The inclusive date range, **Logged by**, and **Served to** selections combine across every Brew-derived total, cost, equipment leader, rate, distribution, and day series. This includes total brews, beans ground or estimated consumed grams, average known Brew cost, grinder and machine leaders, channeling, retention, taste balance, method distribution, and both day-bar series.
- Channeling and retention remain Espresso-only. A filtered range containing only Quick Drip Brews has no Espresso channeling denominator, so the page shows no channeling data instead of inventing `0%`.
- A scope with no matching Brews renders an explicit no-data state. It does not invent equipment leaders, percentages, or other Brew-derived results.
- Daily charts show at most the final ten days of the selected range. Their empty copy describes the displayed chart window, so older matching Brews elsewhere in a longer range are not misreported as absent from the complete filter scope.
- Current Bean catalog facts intentionally ignore date and people filters: open Bean count, known Bean spend, and Bean breakdowns by roaster, origin, and process remain current for the whole workspace. Visible copy identifies this exception.
- Empty current-inventory cards explain when there are no open Beans or no recorded Bean costs. Average Brew cost explains when the selected Brew scope has no known cost data.

## Agent Notes

- All analytics must be scoped to the active workspace.
- `WorkspaceStatistics`, `BeanStatistics`, `EquipmentStatistics`, and `PreparationToolStatistics` own aggregation logic; keep controllers and views thin.
- Use live queries/Ruby aggregation for now. Do not add materialized summaries until data volume requires it.
- Imported brews and beans count like native records.
- Quick Drip is included in broad brew totals, consumed-grams totals, cost calculations when bean price is known, taste balance, method distributions, and brewer/preparation-tool usage analytics.
- Channeling, retention, and grinder tendency metrics are espresso-only. Brewer and Quick Drip preparation-tool analytics should not imply channeling for Quick Drip.
- Richer interactive charts on the dedicated statistics page remain deferred. The dashboard's decorative Chart.js microcharts do not change the server-owned analytics calculations or this statistics-page boundary.
