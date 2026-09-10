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
- Private persona statistics: maker and recipient rankings, maker-to-recipient stacked bars, beans received and highest-rated beans per recipient, self/others totals, distinct beans tried, and rating coverage.
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
- `recipient=self` includes Brews marked as served to their logger. `recipient=guests` selects all Guest Brews together; the persona section below can break down those results by saved guest name.
- A named User selection combines that User's Self Brews with Brews explicitly served to that User as a household member.
- Named logger options include current household members plus historical Users who logged a Brew in the active workspace. Named recipient options include current household members plus historical Users represented by a Self Brew or an explicit household-member serving in that workspace. The UI uses each User's safe `display_label`; it never uses an email address as an analytics label.
- Guest filter options remain combined. On the private persona statistics section, named guests are grouped by trimmed, case-insensitive saved name; unnamed guests share a separate bucket. These names never enter public shares or new filter parameters. Guest and User identities stay separate even when names match.
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
- The dedicated statistics page uses local Chart.js stacked horizontal bars for maker-to-recipient relationships. All exact counts remain available in HTML without JavaScript. Theme changes redraw the chart; Turbo disconnect destroys it. Rank, bean-use, and rating bars are server-rendered.

## Persona Counts And Favorites

- `WorkspacePersonaStatistics` receives the already filtered brew array from `WorkspaceStatistics`. Date, logger, and recipient selections apply consistently to every persona result. External Coffee records are outside this Brew-based scope.
- The logger is the maker. Every logged Brew counts once, including Quick Drip batches; machine cups are not multiplied into these counts.
- Self brews are received by their logger. Household servings belong to their recipient User. Historical users remain included, with safe `display_label` labels. Duplicate display names are separate identities internally.
- Named guest identity is approximate: two guests with the same normalized name are combined. Names with different spelling remain separate. This is private household analytics, with no new guest records or public identities.
- Bean counts refer to individual Bean records (bags), including repeat purchases. Beans with identical names remain separate entries.
- Favorites use the arithmetic mean of non-null Brew ratings from 1–5. Guest cupping feedback already updates that authoritative value. The recipient grouping does not claim verified rating authorship because ratings may also be recorded through private Brew editing. Missing ratings never become zero.
- Rankings show the mean and rated sample count; ties use rated count then label. A single rating may lead the ranking and is visibly identified as a small sample. Recipients with no rated brews see an explicit unrated state.
- Persona/chart payloads contain only safe labels and aggregate numeric values, with escaped HTML/data attributes. No notes, feedback comments, email addresses, raw model serialization, media URLs, or cupping capabilities are included.
