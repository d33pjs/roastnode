# Brew And Activity History Design

## Goal

Add first-class, private history pages for all brews and all dashboard activity in the active workspace. The pages should make older records easy to browse without overloading the dashboard or statistics page.

## Approved Direction

Use two separate all-time history pages:

- Brew history at `GET /brews`, using the existing brews resource index route.
- Activity history at `GET /activity`, using a new `activity#index` route.

Both pages are scoped to `current_workspace`, sort newest first by `occurred_at` and then `created_at`, and are paginated.

The brew history page defaults to a new compact card/list design. It also offers a hero-card view option using the existing `brews/_hero_card` partial. The compact design is the default because it is better for scanning long history, while hero cards remain available when the household wants the screenshot-style view.

The activity history page uses dashboard-style activity cards, not a table. The cards must use stronger contrast than the exploratory mockup: primary activity text should use the main ink color, and secondary metadata should remain readable on the white/surface background.

## Navigation

Dashboard:

- Add a `View all` link next to the `Latest brew` heading.
- Add a `View all` link next to the `Recent activity` heading.
- Keep the existing `Open beans` `View all` pattern as the visual reference.

Statistics:

- Add a new page-level button for all brews.
- Add a `View all` link inside the `Total brews` stat card.
- Links from statistics always open the all-time brew history, not the currently selected statistics date range.

## Brew History

The compact brew card should show the information needed to identify and compare a brew quickly:

- timestamp
- bean name and roaster
- dose, beverage yield, ratio, total time
- grinder and machine when present
- grind setting when present
- rating and taste balance when present
- logged-by display label

Each compact card links to the brew detail page. The list should not expose user email addresses or raw media URLs.

The hero view renders the existing shared hero-card partial for each brew. It should preserve the existing rule that hero card internals are link-free. Each hero card can be wrapped in one link to the brew detail page, matching the dashboard pattern.

View selection can be query-based, for example `?view=compact` and `?view=hero`, with compact as the fallback for blank or unsupported values. Pagination links should preserve the selected view.

## Activity History

The activity page includes the same event families as dashboard recent activity:

- brews
- manual inventory adjustments
- equipment events

The list should combine those records, sort by `occurred_at` and `created_at` newest first, then paginate the combined result. Ruby-side aggregation is acceptable for this slice because the app has no summary table yet and the activity families are small private workspace records. Activity cards link to the related detail page when one exists:

- brew cards link to brew details
- equipment event cards link to equipment event details
- manual inventory adjustment cards are non-link cards unless a dedicated adjustment detail page exists later

Each card should show the activity summary, timestamp, event type, and actor display label when available. It should stay readable on mobile without horizontal scrolling.

## Pagination

Use a small Rails-native pagination helper rather than adding a dependency. A simple limit-plus-one paginator is enough for this slice and should work with both Active Record relations and pre-sorted arrays:

- default page size: 20 records
- `page` query parameter is 1-based
- previous and next links render only when applicable
- invalid, blank, or negative page values fall back to page 1

The helper should be reusable by brew history and activity history. It does not need numbered page links yet.

## Authorization And Data Rules

- Readers, including viewers, can see both history pages.
- Workspace writers keep existing brew edit/delete permissions on brew detail pages only; list pages are read-oriented.
- Every query must start from `current_workspace`.
- Do not add global record finders for convenience.
- Do not leak passwords, sessions, invite tokens, signed media URLs, raw private media URLs, environment variables, infrastructure secrets, or user email addresses.

## Tests

Add controller or integration coverage for:

- dashboard `View all` links for brews and activity
- statistics all-brews button and total-brews card link
- brew history is scoped to the active workspace
- brew history sorts newest first
- compact brew history is the default
- hero-card brew history can be selected
- pagination shows next/previous behavior
- activity history includes brews, manual adjustments, and equipment events
- activity history is scoped to the active workspace
- viewers can read both history pages

## Documentation

Update `docs/coffee-core.md` and `docs/navigation.md` after implementation to record the new history pages and entry points. Update `docs/statistics.md` to note that statistics links to all-time brew history rather than preserving the current analytics range.

## Deferred

- Filtering or searching history pages.
- Date-range filtering on history pages.
- Numbered pagination.
- Activity detail pages for inventory adjustments.
- Export from history pages.
