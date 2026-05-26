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
- Taste balance distribution.
- Retention marker distribution.
- Bean breakdowns by roaster, origin, and process.

## Cost Rules

- Bean spend uses `Bean#purchase_price_cents` in the workspace currency.
- Brew cost is calculated from bean weight and the selected bean's price per gram.
- Average brew cost includes only brews whose bean has a known purchase price and positive bag size.
- Unknown prices are allowed and excluded from average-cost calculations.

## Agent Notes

- All analytics must be scoped to the active workspace.
- `WorkspaceStatistics` owns aggregation logic; keep controllers and views thin.
- Use live queries/Ruby aggregation for now. Do not add materialized summaries until data volume requires it.
- Imported brews and beans count like native records.
- ECharts/Stimulus interactivity is deferred.
