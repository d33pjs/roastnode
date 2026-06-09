# External Coffees

External Coffees are purchased or otherwise household-external coffee drinks logged by workspace members for memory, comparison, and optional sharing.

## Implemented Slice 1

- Workspace-private External Coffee records, separate from inventory-backed Brews.
- Default External Coffee tab on the Log screen, beside brew-method tabs without becoming a Brew method.
- Dedicated External Coffee create/list/detail/edit routes and pages, while still surfacing records in shared timeline/history UI.
- The renamed Coffees history page at `/coffees` combines inventory-backed Brews and External Coffees, defaults to compact cards, can switch to hero cards, and has quick filters for All, Brews, and External.
- External Coffees still have a dedicated index page for focused browsing, but the main household coffee history should link to `/coffees`.
- Required occurred-at timestamp defaulting to the current time.
- Searchable free-text Drink Type with a broad seeded cafe-drink catalogue plus workspace-history suggestions.
- Drink Type may include adjacent cafe drinks such as matcha latte; the feature does not validate that every entry is strictly coffee-based.
- Place name suggestions sourced only from active-workspace External Coffee history.
- Optional free-text Drink Size.
- Optional free-text place name and place location.
- Optional explicit current-location capture per entry, storing private coordinates only when the member asks for it. Browser geolocation requires HTTPS, or `localhost` on the same device; phone access over plain HTTP LAN hostnames should show a clear secure-context message.
- Optional price stored as integer minor units with currency defaulting to the workspace currency. Private UI should prefer familiar currency symbols for known currencies, falling back to the ISO code when no symbol mapping exists.
- Rating, private notes, public note, public/private links, and private photos in the first slice.
- External Coffee Taste uses Brew-style choice controls with three visible choices per axis: Sour/Balanced/Bitter and Weak/Balanced/Strong, plus Unknown. Legacy stronger values remain readable for existing records.
- Photo-forward External Coffee Hero Card that still works without a photo, rendered prominently on External Coffee detail pages and available in the Coffees hero-card history view. Private hero cards include the current workspace logo and logging user avatar when those identity images exist, and use a compact logged-at timestamp without seconds.
- Dashboard recent activity includes External Coffees as concise activity rows. The dashboard's top "Latest coffee" hero can be either a Brew or an External Coffee; the "Latest best brew" hero remains Brew-only.
- General history/activity participation, with separate External Coffee Comparison for price, rating, taste, drink type, and place.
- Workspace JSON export, external-coffee CSV export, media ZIP export, instance backup, and empty-server restore coverage.

## Planned Slice 2

- Public External Coffee Share pages built from curated snapshots.
- Separate public External Coffee share URL namespace, likely `/e/:token`, instead of reusing public brew `/s/:token` routes.
- Optional password protection on public External Coffee shares, consistent with public brew and recipe shares.
- Per-share visibility controls for date, time, place name, and location.
- Explicit selected photos and public links only on public shares.

Do not include public sharing work in the first External Coffee implementation.

## Planned Scope

External Coffee Comparison should grow into dedicated analytics for price, rating, taste, drink type, and place once there are enough records to justify the UI.

## Out Of Scope For V1

- Reusable CoffeeShop/place records.
- Automatic background location capture.
- Bean inventory deduction or household equipment references.
- Bean/equipment/preparation-tool analytics participation.
- Repeat/duplicate External Coffee shortcuts.
- Comments or reactions on private External Coffee records.
- Exact cafe ingredient modeling, milk type, caffeine, temperature, staff, visit type, or normalized volume fields.

## Future Ideas

- Generic public-page comments or reactions across public brews, public recipes, and public External Coffees.

## Privacy Rules

External Coffees follow normal workspace-private visibility. Public sharing is explicit and snapshot based.

Location is opt-in per entry. Public date, time, place name, and location visibility are chosen per External Coffee Share, not globally.

Public External Coffee media must use opaque public media handles and explicit photo allowlists. Public pages must not expose private notes, raw media routes, signed Active Storage URLs, raw attachment IDs, original filenames, raw share tokens, location fields hidden by share settings, or private links.

## Field Rules

External Coffee creation requires only Drink Type and occurred-at timestamp. Place, size, price, taste axes, rating, private notes, public note, photos, links, and location are optional.

Saving an External Coffee edit without choosing a new photo must preserve existing photos. Blank file-upload params from native browser controls should be ignored, not treated as a command to detach existing media.

Drink Type suggestions may combine global seeded suggestions with active-workspace history. Place name suggestions should come only from active-workspace history.

The Intensity taste axis accepts `unknown`, `weak`, `balanced`, `strong`, and legacy `harsh`, but the form presents `unknown`, `weak`, `balanced`, and `strong`.

The acidity-to-bitterness axis accepts `unknown`, `very_sour`, `sour`, `balanced`, `bitter`, and `very_bitter`, but the form presents `unknown`, `sour`, `balanced`, and `bitter`.

Rating uses the same optional whole-number `1..5` scale as Brews.

## Agent Notes

- Do not model External Coffee as a third `Brew.method`; current Brew records require beans and inventory behavior.
- Do not route External Coffee detail pages through `/brews/:id`; keep separate resources even when records appear in shared history surfaces.
- Do not reuse public brew share `/s/:token` routes for External Coffee shares; use a separate public namespace and media controller.
- Keep External Coffee comparisons separate from bean/equipment analytics.
- Include External Coffees in durable data export and backup/restore flows when implemented.
