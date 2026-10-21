# Grouped public bean collections

Approved direction: the conversation of 2026-10-21 authorizes implementation, commit, push, release and deployment. Release changelog approval remains required by AGENTS.md.

## Public experience

One optional collection per workspace, disabled by default, with an unlisted `/l/:token` URL, a public title/description, Top 10 and All views. Each ranked coffee combines explicitly published bags in the same existing CoffeeHistory. Duplicates already inherit this membership; a workspace-scoped Link bag / Separate bag control supports manual corrections, with explicit notice that grinder history is shared as well. Private inventory remains per bag.

Cards contain a selected representative bag's public name, roaster, origin/process/roast/tasting notes, approved photos, public links, average bag rating, brew average, rated/total brew counts, total published bag size and bag count. Expanded bag rows show size, opened date, roast date, public status, own rating, brew mean/count, optional deliberately entered public price, selected gallery and existing public bean link. Public espresso brew links include only enabled unprotected shares. Quick Drip remains a summary on existing bean pages.

## Selection and ranking

Selected mode includes chosen enabled, unprotected, publishable PublicBeanShares. Automatic mode includes all such shares except persistent per-bag exclusions. Group-level inclusion/exclusion is available through all bag checkboxes in the editor. Bulk publication creates only deliberately selected eligible bag shares using their selected primary safe raster photo, followed by an exact collection preview before enabling. Linking alone never publishes a bag. New duplicates remain private until deliberately shared (or bulk published).

Default group rating is the arithmetic mean of non-null published bag ratings, each bag equal weight. Brew mean uses all non-null individual Brew ratings in the published bag snapshots, never a mean of bag means. Bean rating determines order, then brew mean, rated sample count, name, opaque stable group key. Display precision is one decimal and ranking uses displayed precision. Equal metric tuples share competition rank. Top 10 includes all ranked groups with rank <= 10; unrated coffees appear separately in All. No invented zero ratings. Optional combined score is deferred because the separate averages meet the approved concept without unresolved weighting assumptions. Duplicated ratings remain stored bag assessments, not verified independent reviews.

## Ownership, snapshot and privacy

Owners/admins manage the collection through active-workspace singleton routes. Members can link bags through existing write policy; viewers cannot mutate. Public rendering reads a stored curated collection snapshot; no private notes, URLs, prices, internal IDs, original filenames, guest details or arbitrary private fields enter that snapshot. Only existing approved public bean media paths are used, maintaining live share/password/photo authorization. Source share changes rebuild collections transactionally. Public rendering additionally fails closed if snapshot sources are no longer enabled/unprotected/publishable, preventing stale source disclosure. Public links remain typed HTTP(S) links and affiliate links are labeled sponsored.

Public prices are separate optional fields on PublicBeanShare: decimal amount, ISO currency and recorded date. They never copy private purchase costs automatically, and are explicitly eligible in the bean snapshot. Show dated per-bag price and normalized price/kg; no currency conversion or live availability claims. Existing public bean snapshots gain the own bean rating and public price only.

## Operations

Document the privacy exception for intentionally entered public prices, preserve collection settings/price data in private workspace exports and readable/full instance archives. Restore validates and remaps references and recreates disabled drafts with new tokens, deliberately revoking original permanent public capabilities. Add negative tests for workspace isolation, protected/disabled/deleted sources, media selection, private fields and token logs. Verify targeted tests, full Rails and JS suites, RuboCop/security checks, desktop/mobile browser experience and local LAN server. Commit on main, push to Gitea, verify GitHub mirror and CI, approve changelog, tag the next patch release, verify signed image and assets, deploy via Santiago Ansible, verify health/version/migrations/jobs and backup.
