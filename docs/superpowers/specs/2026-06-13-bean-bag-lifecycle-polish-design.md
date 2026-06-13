# Bean Bag Lifecycle Polish Design

Date: 2026-06-13

## Goal

Polish the private bean bag lifecycle so adding, stocking, opening, rebuying, reviewing, and costing beans is faster and more consistent across the bean form, bean overview, bean detail page, dashboard, and shared back-link behavior.

## Approaches Considered

### Recommended: Focused Bean Lifecycle Slice

Implement the requested behavior directly in the existing Rails monolith surfaces that already own beans: `Bean`, `BeansController`, dashboard services/views, shared back-link helper, exports, backups, and bean views. This keeps the work close to the current implementation, preserves workspace authorization rules, and avoids broad refactoring.

### UI-Only Patch

Change forms and views without adding persistence/export/backup support for new metadata. This is faster but weak: new origin/manufacturer data would be lost or incomplete in workspace export, readable instance backup, and restore.

### Broad Bean Model Restructure

Split bean metadata, inventory lifecycle, and purchase information into new domain objects. This may become useful later, but it is too much blast radius for a polish slice and would slow delivery without solving a current complexity problem.

## Chosen Design

Use the focused bean lifecycle slice.

### Bean Creation And Editing

New bean forms should still default to an open bag, because the current daily workflow expects newly added beans to be brewable unless the user chooses Stock. When the selected bag status is Stock, the `opened_on` input should be disabled in the browser and submitted state should still be enforced server-side by `Bean#apply_bag_status("stock")`, which clears `opened_on`.

Bag size should copy into Remaining one way on the bean form until the user manually edits Remaining. This should mirror the brew form's Ground out to Dose behavior: client-side assistance only, with the existing model default still protecting non-JavaScript and direct POST submissions.

Bean rating should use the same radio-card rating control design as Brew ratings, including a no-rating option. Bean ratings should remain optional and whole-number 1 through 5 in the UI. The existing model currently permits 0; the new no-rating option should submit blank rather than storing 0.

### Origin And Process Metadata

Add persisted bean fields:

- `continent`
- `country_of_manufacturer`
- `manufacturer`

The Origin & process form section should render fields in this order:

1. Continent
2. Countries
3. Region
4. Elevation
5. Variety
6. Percentage
7. Processing
8. Blend
9. Country of Manufacturer
10. Manufacturer
11. Farm
12. Farmer
13. Harvested

The existing `country` column should remain the stored "Countries" field. The existing `blend_percentage`, `process`, and `blend_type` fields should satisfy Percentage, Processing, and Blend.

New metadata should be included in private workspace JSON export, beans CSV export, readable instance backup, full archive restore, and bean duplication. Public bean snapshots should include the new origin/process fields as part of the already curated public bean metadata block; purchase source, purchase cost, private links, filenames, raw attachment IDs, and private notes remain excluded.

### Bean Overview And Detail Purchase Links

When a bean has `purchase_url`, show a Rebuy action on the bean detail page and bean overview card. The link should open the stored purchase URL directly, use `target="_blank"` and `rel="noopener"`, and be visible only when a URL is present.

On bean detail, the Website detail row should render as a shortened clickable URL rather than a raw full string. The shortened text should show host plus a compact path when useful, while the link target remains the full stored URL.

### Dashboard Stock List And Quick Open

Use visual option A from brainstorming: keep the existing Open beans cockpit as the brew-focused section, then add a separate In stock section with simpler unopened-bag cards.

The stock dashboard section should show a limited list of current stock bags from the active workspace, sorted by purchase date, roast date, and creation freshness, matching the existing Beans overview stock ordering. Each card should show photo, name, roaster, unopened remaining amount, purchase/roast context where available, Rebuy when `purchase_url` exists, and a compact quick-open action for writers.

Add a quick-open action for stock bags on:

- Bean detail page
- Bean overview stock cards
- Dashboard In stock cards

Quick open should set the bag to open, set `opened_on` to `Date.current`, preserve `remaining_grams`, clear archived/finished state, refresh affected public shares, and return to the page where the user clicked the action. It should be available only to workspace writers and only for stock bags. Viewers remain read-only.

### Smarter Back Links

Keep the shared back-link partial, but make the helper avoid immediate workflow pages that should not become the next back target. In particular, after visiting a public share new/edit page and returning to a brew detail page, the brew detail back link should not point back to the share page. It should fall through to the view's explicit fallback such as dashboard, beans, or detail pages.

The helper should continue to accept safe same-origin referrers for normal list/detail navigation, reject external and self referrers, and use explicit fallback links for direct visits and workflow-loop referrers. This is a pragmatic breadcrumb-like improvement without storing a full navigation stack.

### Bean Detail Header Origin

Replace the current `origin`-only header subtitle with a derived origin label:

1. `country`
2. `region`
3. `continent`
4. Unknown origin

This fixes detail pages that say Unknown origin even when structured origin data exists.

### Bean Detail Cost Metrics

Add cost metrics to bean detail when `purchase_price_cents` and `bag_size_grams` are present:

- Cost per kg: `purchase_price / bag_size_grams * 1000`
- Cost per package: the recorded purchase price for the recorded bag size
- Cost per shot: `cost_per_gram * average_logged_bean_weight_grams`

Cost per shot should use the bean's actual average logged `bean_weight_grams` from brews when present. If there are no brews for the bag, use an 18g fallback. Costs should use the active workspace currency and existing profile number formatting.

## Data And Privacy Rules

- All bean changes remain scoped through `current_workspace`.
- Controllers must use `current_workspace_policy.write?` or existing write authorization.
- Stock bags stay private and not publishable through public bean sharing until they are opened.
- Public media rules do not change: no raw Active Storage URLs, raw attachment IDs, original filenames, signed URLs, private notes, private purchase source, or private cost on public pages.
- Rebuy links are private app UI links, not public bean-share purchase exposure.

## Testing Strategy

Use test-first changes for each behavior.

Controller and model tests should cover:

- Stock form state and server-side clearing of `opened_on`.
- Bag size to Remaining sync controller source content.
- Bean rating radio control rendering.
- New metadata persistence, duplication, workspace export, CSV export, readable backup, and restore.
- Bean detail origin fallback.
- Purchase URL shortened link and Rebuy actions.
- Quick-open authorization, stock-only behavior, date setting, remaining preservation, redirect target, and viewer denial.
- Dashboard stock list scoping and ordering.
- Back-link helper rejecting public share workflow referrers while preserving normal same-origin back behavior.
- Cost metrics using average logged dose and 18g fallback.

Existing public sharing tests should continue to prove private purchase data, private notes, raw media identifiers, and original filenames do not leak.

## Documentation Follow-up

Update `docs/coffee-core.md`, `docs/navigation.md`, and `docs/status.md` after implementation. Add focused notes for the quick-open action, dashboard stock list, smarter back-link behavior, and bean cost metrics.
