# Bean Open Duration and Private Ranking Design

Date: 2026-08-20

## Goal

Correct bean analytics so a bag's open age stops when its lifecycle ends, and
show the same workspace comparison ranks from public bean pages inside the
private Bean Analytics cards.

## Open-Duration Semantics

Open duration starts at `opened_on`. Bags without `opened_on` have no duration.
The lifecycle rules are:

- An open bag is measured through `Date.current`.
- A finished bag stops at `finished_at.to_date`.
- An archived bag stops at `archived_at.to_date`.
- A used-up bag stops at its latest brew date. If it has no brew, it falls back
  to `Date.current` because Roastnode has no reliable used-up timestamp.
- A stock bag has no open duration.
- A terminal date before `opened_on` is clamped to zero days.

The current private calculation always uses `Date.current`, which causes
finished and archived bags to continue aging. The public snapshot calculation
also differs because it can use the latest brew date for a still-open bag. One
shared calculator will become the source of truth for private statistics and
public snapshots.

## Ranking Semantics

Private Bean Analytics uses the existing approved public comparison contract:

- The pool is every non-deleted bean bag in the current bean's workspace,
  independent of lifecycle and publication state.
- Rating requires at least one rated brew and ranks the one-decimal displayed
  average from highest to lowest.
- Channeling requires at least one espresso brew and ranks the displayed whole
  percentage from lowest to highest.
- Display-value ties use competition ranks such as `1, 1, 3`.
- At least two eligible beans are required before a badge appears.
- Only rank and eligible count are presented; no peer values or identities are
  exposed by the badge.

Private rankings are calculated live. Public rankings remain stored in curated
`PublicBeanShare` snapshots.

## Components and Data Flow

### Shared duration calculator

A small shared calculator accepts a bean, the latest brew timestamp when one
exists, and the current date. It returns the duration in days or `nil` for an
unopened bag. `BeanStatistics` and `PublicBeanShareSnapshotBuilder` both use it.

### General bean comparison ranker

Rename `PublicBeanComparisonRanker` to `BeanComparisonRanker` because ranking
is no longer public-page-only. Preserve its single workspace brew projection,
rounding, tie behavior, and workspace isolation. Both the public snapshot
builder and `BeanStatistics` call the general service.

`BeanStatistics#call` gains a `comparisons` entry with the same
`average_rating` and `channeling` rank/count hashes used by public snapshots.

### Shared badge partial

Move the public bean comparison badge markup into a shared partial. It accepts
the comparison payload, metric, and test-ID prefix so public and private pages
can use the same presentation without coupling private views to a public-page
template.

The existing Bean Analytics Average Rating and Channeling cards render the
badge under their numeric values:

- Rank 1 uses the gold trophy treatment.
- Rank 2 uses the silver medal treatment.
- Rank 3 uses the bronze medal treatment.
- Rank 4 and later are neutral and text-only.

The accessible label and visible copy remain `TOP N OF C BEANS`. Missing or
ineligible comparison data renders no badge.

## Privacy and Performance

- The private bean route already enforces the active workspace boundary.
- The ranker also scopes its brew projection by `workspace_id`.
- The UI renders only the current bean's rank and eligible count.
- Ranking adds one workspace brew projection to a private bean page, not one
  query per peer bean.
- Public pages continue rendering curated snapshots and never run live private
  comparison queries.

## Testing

Use red-green TDD for each behavior:

- Open bags continue through today.
- Finished bags stop at `finished_at` even when time advances.
- Archived bags stop at `archived_at` even when time advances.
- Used-up bags stop at their latest brew date.
- Used-up bags without brews fall back to today.
- Stock bags return no duration.
- Terminal dates before opening clamp to zero.
- Public snapshots use the same lifecycle rules.
- Bean Analytics renders live rating and channeling badges.
- Podium icons and neutral rank-four behavior match the public badge contract.
- Fewer than two eligible beans suppress the badge.
- Other workspaces never influence the rank.

Run focused service/controller tests and RuboCop, then the full serial Rails
suite. Complete desktop and mobile visual checks of the private analytics cards
and the existing public badges.

## Rejected Alternatives

### Reuse public-named components directly

Calling `PublicBeanComparisonRanker` and the public-page partial from private
analytics would reduce the initial diff, but it would leave misleading
ownership and couple private presentation to public templates.

### Duplicate private calculations and markup

Separate private duration, ranking, and badge implementations would be simple
locally but would recreate the drift that caused the open-age bug. Shared,
domain-named components keep the two surfaces consistent.

## Scope Boundaries

- No database migration or stored private rank is added.
- No new used-up timestamp is introduced.
- No workspace-wide rankings page is added.
- No peer bean identities, values, or links are displayed alongside a rank.
