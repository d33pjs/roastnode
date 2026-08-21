# Bean Workflow Polish Design

## Goal

Make new and duplicated Bean bags start as stock, improve Bean entry and rating controls, add distinct private purchase/origin websites, link all Bean brews from analytics, and explain the waste-aware Cost per shot calculation.

## New And Duplicated Bag Defaults

New Beans default to In stock. They have no `opened_on`, `finished_at`, or `archived_at`, and remaining grams initialize from bag size through the existing one-way default.

Duplicating a bag copies descriptive metadata, photos, primary-photo identity, price, purchase/origin websites, private/public notes, and appropriate Bean fields. The duplicate:

- resets remaining grams to bag size;
- has no opened, finished, or archived date;
- derives In stock status; and
- retains its duplicate-family relationship.

Because duplicates are no longer opened automatically, they do not enter Brew selection or Repeat Good Brew until a user explicitly opens them.

## Bean Form Improvements

The rating control moves out of the five-column Roast row into a full-width layout that can display No rating plus all five values without squeezing. Bean rating is blank or an integer from 1 through 5. Any legacy `0` value is migrated to blank before tightening validation.

String inputs gain these exact examples:

- Elevation: `1100-1200m`
- Variety: `Arabica and/or Robusta`
- Percentage: `50%/60%`
- Processing: `washed or natural`
- Coffee Origin Website: `URL to original Coffee`

The existing Website field remains in Purchase and is relabeled Purchase Website. A new Coffee Origin Website URL field appears in Origin & process. Purchase Website may use concise guidance that it is the place to buy the bag again.

## Bean Rating Correction

Bean detail pages gain a focused Adjust rating form matching the Brew correction pattern. Workspace writers can set or clear only `rating`; submitted Bean status, inventory, price, notes, or ownership fields are ignored by this endpoint. Viewers cannot see or call the control, and foreign-workspace Beans remain inaccessible.

Rating changes refresh public snapshots that contain public-safe Bean fields and emit the appropriate Bean update activity. They do not alter Brew-derived average-rating or channeling comparison ranks.

## Bean-Filtered Coffee History

The Recent brews heading in Bean analytics gains View all. It opens the main Coffees history with Brews active and the current Bean selected.

`BrewsController#index` accepts a workspace-scoped Bean filter. The result includes Espresso and Quick Drip Brews for that Bean, excludes other Beans and every External Coffee, and preserves Bean selection across Compact/Hero view, compatible Coffee-type filters, and pagination. The page displays a removable active-Bean chip so the narrowed scope is apparent. Choosing External clears the incompatible Bean filter.

A missing or foreign-workspace Bean identifier returns not found rather than falling back to an unfiltered history.

## Purchase And Origin Websites

The existing `purchase_url` remains the Purchase Website and continues powering Rebuy actions. A nullable `coffee_origin_url` stores the Coffee Origin Website. Both values are trimmed, accept only HTTP or HTTPS URLs with a host, duplicate with a Bean bag, and participate in private export and backup/restore.

The private Links section synthesizes two system chips when values exist:

- `Purchase URL` with `BUY` and `PRIVATE` badges.
- `Origin Coffee URL` with `INFO` and `PRIVATE` badges.

These are presentation entries, not synchronized `RecordLink` rows. Users therefore do not see duplicate editable links or risk system/user link divergence. Normal `RecordLink` rows continue below them.

Neither direct URL enters Public Bean, Brew, or Recipe snapshots. Purchase Website is still a private Rebuy source. Existing Beanconqueror URL mapping remains Purchase Website for backward compatibility unless a future import-specific decision changes it.

## Cost Per Shot

Cost per shot is:

`purchase price per gram × average Bean In across this Bean's Espresso Brews`

Only Espresso contributes to the average; Quick Drip quantities do not distort a per-shot metric. Before the first Espresso Brew, the existing 18g fallback remains. The displayed currency rounding remains unchanged.

Bean In is the full amount removed from the bag. A Brew with 20g Bean In, 19g Ground Out, and 17g Dose therefore costs the full 20g. Ground Out and Dose are not added again, which would double-count the same loss.

An accessible information control exposes this explanation on hover and keyboard focus. Generic negative manual Inventory Adjustments do not alter Cost per shot because existing data cannot distinguish discarded beans from count corrections, gifts, spills, or other reasons. A future structured discard reason can extend the formula without guessing about historical rows.

## Verification

Automated coverage includes:

- new and duplicate stock status, full remaining grams, and blank lifecycle dates;
- copied metadata/photos/URLs and explicit-open Brew eligibility;
- placeholder and rating layout markup;
- blank-or-1-through-5 Bean rating validation and legacy-zero migration;
- focused rating authorization, parameter allowlist, and public comparison refresh;
- Bean-filtered Espresso/Quick Drip history, isolation, view/pagination persistence, active chip, and External behavior;
- Purchase/Origin URL validation, normalization, duplication, private link chips, export, and restore;
- negative public assertions for both direct URLs;
- Espresso-only Cost per shot averaging, 18g fallback, and 20g waste example; and
- accessible cost explanation markup.

## Documentation

Implementation updates `docs/coffee-core.md`, `docs/bean-analytics.md`, `docs/bean-danger-zone.md` where applicable, `docs/formatting.md`, `docs/navigation.md`, `docs/workspace-export.md`, `docs/backup-system.md`, and `docs/status.md`.
