# Statistics And Analytics Design

## Goal

Add Roastnode's first private analytics page for the active workspace. It should make the household's coffee data useful immediately without adding background summaries, public sharing, or a charting dependency.

## Scope

The first analytics slice adds a `/statistics` page linked from the workspace dashboard. It uses live PostgreSQL-backed Active Record queries and server-rendered cards/charts.

Included:

- total brews
- total beans ground from `Brew#bean_weight_grams`
- open beans
- known bean spend in the workspace currency
- average known brew cost
- most-used grinder
- most-used machine
- brews by recent day
- bean consumption by recent day
- taste balance distribution
- channeling rate
- retention/exchange marker counts
- top roasters, origins, and processes by bean count

## Architecture

Create a focused `WorkspaceStatistics` service that accepts a workspace and returns a plain object/hash for the view. Keep the controller thin: authorize read access through the active workspace, call the service, render the page.

The view should be dense and utilitarian, consistent with the current Rails/Tailwind UI. Charts are compact HTML/SVG-style bar rows for now. The service shape should make it easy to replace the visual layer with Stimulus + ECharts later.

## Data Rules

- All queries are scoped to `current_workspace`.
- Cost analytics use only beans with `purchase_price_cents` and positive `bag_size_grams`.
- Brew cost is `brew.bean_weight_grams * (bean.purchase_price_cents / bean.bag_size_grams)`.
- Average known brew cost divides known brew cost by the count of brews whose bean has price data.
- Unknown grinders/machines are not candidates for "most used".
- Imported data is included like any other workspace data.

## Deferred

- ECharts/Stimulus interactivity.
- Date range filters.
- Per-bean detail analytics.
- Per-equipment analytics beyond existing equipment detail counters.
- Exporting charts.
- Materialized summary tables.
