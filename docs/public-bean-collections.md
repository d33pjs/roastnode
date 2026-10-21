# Public bean collections

Owners and admins can publish one ranked coffee collection per active workspace. Open **Public bean collection** from Beans or Workspace settings. Save a draft, inspect Preview, then enable the unlisted `/l/:token` URL. Collections start disabled; deploying this feature publishes nothing automatically.

## Coffees and bags

A coffee is the existing workspace-owned `CoffeeHistory` group. Duplicate bags already share that group, including duplicate chains. Bean details now offer **Link bag to the same coffee**: choose another bag in the workspace, including differently spelled names, or separate this bag. Only the selected bag moves. Linking also shares grinder-setting history; inventory and ordinary private bag analytics remain separate. Names never merge automatically, and linking alone grants no public access.

Each collection coffee has a representative bag for its name, roaster, public description, selected photos and public links. If several representatives are checked, the earliest-created eligible marked share wins; otherwise the earliest-created eligible share wins. Expanded rows show each published bag's package size, opened date, roast date, status, own rating, brew average/count, deliberate public price and selected photos. Total grams means combined package size, not consumption or current stock. Unpublished siblings never enter counts, ranks, photos, prices or averages.

## Selection

- **Selected bags:** explicitly chosen enabled, unprotected public bean shares.
- **Automatic public beans:** all eligible enabled, unprotected public bean shares except exclusions. This intentionally makes their unlisted URLs discoverable from the collection, including future eligible shares.
- Per-bag exclusions persist across temporary disabling/password protection. Per-coffee exclusions use group membership and cover future bags in that group.
- The bulk-publication section lists opened publishable bags with no existing share. Only checked bags are published, using their current safe-raster primary package photo if present. The collection is saved disabled whenever fresh bag shares are bulk-published; review Preview and explicitly enable it afterwards. Those new standalone bag shares are enabled unlisted pages as the bulk action explains.
- Existing protected or disabled shares must be managed on their own share editor; bulk publication never removes a password or re-enables them.

## Ratings and presentation

The primary score averages non-null stored bean ratings equally across included bags. Duplicate currently copies the bean rating; these are stored bag assessments, not claims of independent reviews. The separate brew score averages every non-null 1–5 Brew rating from included bags, rather than averaging bag means. Rated and total sample counts remain visible. Missing ratings stay absent, never zero.

Scores are rounded to one decimal before ordering. Sort by bean average descending, then brew average descending, then rated Brew count descending; roaster/name and an opaque stable group key stabilize equal rows. Equal full score/count tuples share competition rank. Top 10 includes ranks 1–10 and their ties; All adds the unrated tail. Collection ranks and counts refer only to included public coffees; existing per-bag workspace comparisons remain a different metric.

Cards use contained selected package photos, restrained podium ranks, separate labeled scores and expandable bag details. Public bean pages supply the deeper per-bag brew history. The collection links enabled, unprotected public Espresso Brew pages only. Quick Drip contributes allowed bag summaries and ratings but has no standalone public share. Public buy/info/affiliate links come from the representative bag's public links; affiliate links are labeled and marked sponsored. Prices and bag state do not claim live shop stock or current pricing.

## Deliberate public prices

The bean-share editor has independent optional public amount, ISO currency and recorded-date fields. Comma decimals work. Entering a public price is an explicit publication choice; the private purchase price, purchase website and origin website are never copied automatically. Clear the public amount to hide it. Negative, nonnumeric, nonfinite and out-of-range values fail normal validation. Per-kg prices use that bag's package size and retain the entered currency; no exchange conversion is performed. These approved fields may appear on the bag page and collection.

## Snapshot and authorization

`PublicBeanCollectionSnapshotBuilder` writes curated stored snapshots. Public display reads that snapshot, not arbitrary private records. Collection grouping reads current CoffeeHistory membership only while building the snapshot. Internal IDs stay private; group keys are opaque HMAC values and selected photos use the existing per-share public bean media routes/handles and live allowlists. Source password gates, raster-type gates and revocation still apply.

Source share saves/deletes refresh the collection in the source transaction. Existing multi-share refresh batches coalesce collection rebuilds once per workspace. The request also checks source eligibility and fails closed on a stale source set; protected or disabled public Brew links are removed before rendering. Private notes/costs/URLs, Guest details, emails, internal IDs, attachment IDs, filenames and signed media URLs never enter collection snapshots. Collection token paths and redirects are redacted; public responses use no-store, no-referrer and noindex/nofollow. Unlisted and noindex are discovery choices, not authentication.

## Export and restore

Owner workspace JSON and instance archives include collection settings, group exclusions and deliberate public bag settings through `BeanCollectionPortability`. They omit collection/share bearer tokens, password digests and stored public snapshots. Validated restore remaps bean/group/media IDs and rebuilds disabled bag-share and collection drafts with new tokens. Review and deliberately republish after restoring; original permanent public URLs do not survive this portability path. Existing permanent Brew links are not restored. Legacy archives without these optional settings remain compatible. Private exports can contain private costs and filenames under the existing owner/admin export contract; public pages cannot.
