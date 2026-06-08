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
- Taste balance distribution.
- Retention marker distribution.
- Brew method distribution, including Quick Drip.
- Bean breakdowns by roaster, origin, and process.
- Bean detail analytics through `BeanStatistics`.
- Equipment detail analytics through `EquipmentStatistics`.
- Preparation tool detail analytics through `PreparationToolStatistics`.
- Statistics links to all-time brew history through a page-level all-brews button and the total-brews card.

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
- Brew-derived metrics follow the selected range: total brews, beans ground or estimated consumed grams, average brew cost, leaders, channeling, retention, taste balance, method distribution, and day bars.
- Current bean inventory/catalog metrics stay unfiltered: open bean count, known bean spend, and bean breakdowns by roaster/origin/process.
- Empty current-inventory cards explain when there are no open beans or no recorded bean costs. Average brew cost explains when there is no cost data for brews in the selected time range.
- Links from statistics to brew history do not preserve the selected analytics date range; they always open all-time brew history.

## Agent Notes

- All analytics must be scoped to the active workspace.
- `WorkspaceStatistics`, `BeanStatistics`, `EquipmentStatistics`, and `PreparationToolStatistics` own aggregation logic; keep controllers and views thin.
- Use live queries/Ruby aggregation for now. Do not add materialized summaries until data volume requires it.
- Imported brews and beans count like native records.
- Quick Drip is included in broad brew totals, consumed-grams totals, cost calculations when bean price is known, taste balance, method distributions, and brewer/preparation-tool usage analytics.
- Channeling, retention, and grinder tendency metrics are espresso-only. Brewer and Quick Drip preparation-tool analytics should not imply channeling for Quick Drip.
- ECharts/Stimulus interactivity is deferred.
