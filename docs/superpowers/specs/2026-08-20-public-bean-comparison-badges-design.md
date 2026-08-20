# Public Bean Comparison Badges Design

Date: 2026-08-20

## Goal

Show how a published bean compares with the other beans in its workspace for average rating and channeling, while preserving the curated public-snapshot privacy boundary and fixing the public bean page's desktop Details/Links flow.

## Scope

- Rank the shared bean by average rating and channeling rate against eligible beans in the same workspace.
- Add compact `TOP N OF C BEANS` badges to the public average-rating and channeling cards.
- Give the first three ranks distinctive icon and color treatments; later ranks remain neutral and text-only.
- Move Links below the taste profile in the normal document flow instead of placing it in a desktop sidebar.
- Keep comparison inputs and other bean identities private.

Private bean details, global instance-wide comparisons, trend history, weighted scoring, confidence intervals, and minimum-sample thresholds are outside this slice.

## Ranking Rules

The comparison pool contains all non-deleted bean bags in the shared bean's workspace that have enough usable data for the metric, regardless of lifecycle status (stock, open, finished, used-up, or archived). A bean does not need to be published or currently publishable to participate; deleted records are naturally absent.

Average rating uses all espresso and Quick Drip brews whose rating is present. The per-bean mean is rounded to the same one-decimal value shown publicly before ranking. Higher is better. One rated brew makes a bean eligible.

Channeling uses all espresso brews for the bean. The number of channeled espresso brews is divided by the bean's total espresso brew count and rounded to the same integer percentage shown publicly before ranking. Lower is better, including a valid `0%`. One espresso brew makes a bean eligible.

Ranks use standard competition ranking. Equal public values receive the same rank, and the next rank skips the occupied positions. For example, `5.0, 5.0, 4.5` produces ranks `1, 1, 3`. The eligible count includes the shared bean. No badge is shown when the shared bean has no value for the metric or fewer than two workspace beans are eligible.

## Architecture

A focused `PublicBeanComparisonRanker` service will calculate both metrics for a workspace. It will aggregate brew data by bean, normalize the values to their public display precision, and return only the shared bean's rank plus the eligible-bean count for each metric.

`PublicBeanShareSnapshotBuilder` will copy those results into a dedicated `comparisons` snapshot object. The public controller and view will continue rendering from the snapshot and will not query live private beans. The snapshot contains no competing bean names, identifiers, metric values, lifecycle states, or links.

The expected snapshot shape is:

```json
{
  "comparisons": {
    "average_rating": { "rank": 1, "eligible_count": 8 },
    "channeling": { "rank": 3, "eligible_count": 6 }
  }
}
```

Missing or inapplicable comparisons are omitted rather than represented with misleading zeroes.

## Refresh Flow

Ranks can change when a different bean in the workspace changes. Bean and brew create, update, and delete flows therefore refresh every public bean share in the affected workspace, not only the directly linked share. Existing refresh behavior for public links, selected media, equipment labels, workspace identity, and brewer identity remains scoped to the shares actually affected by those records.

Household workspaces are expected to contain a modest number of public bean shares. Synchronous workspace-wide snapshot refresh is acceptable for this slice and avoids adding cache tables or background-job consistency concerns.

## Public Presentation

A reusable rank-badge partial will render beside or directly below the metric value inside the existing Average Rating and Channeling cards. Its accessible label will contain the full rank text.

- Rank 1: gold treatment and trophy icon.
- Rank 2: silver treatment and medal icon.
- Rank 3: bronze treatment and medal icon.
- Rank 4 and later: neutral treatment with no icon.

The visible copy is `TOP N OF C BEANS`. Badge styling must remain legible in the current public-page theme, wrap safely on narrow screens, and not rely on a webfont or remote icon asset.

## Details and Links Layout

The current desktop grid explicitly creates a main Details column and a right sidebar, which places Links beside Details and leaves unused space when no public note exists. The section will become one full-width content flow:

1. Details heading and detail cards.
2. Taste profile/tasting notes.
3. Links, when present.
4. Public note, when present.

Links remain named external chips with `target="_blank"` and `rel="noopener"`. Mobile behavior remains naturally stacked.

## Privacy and Failure Behavior

- Comparison queries are always scoped through `bean.workspace`.
- Only rank and eligible count enter the public snapshot.
- A missing rating, missing espresso history, deleted comparison bean, or single eligible bean suppresses the relevant badge.
- Division by zero must not occur; no espresso brews means no channeling comparison.
- Existing snapshots without `comparisons` continue rendering normally without badges.
- Disabled, protected, or unknown public shares retain their current access behavior.

## Testing

- Service tests cover higher-is-better rating, lower-is-better channeling, valid zero channeling, rounded-value ties, shared competition ranks, one-brew eligibility, insufficient pools, and workspace isolation.
- Snapshot-builder tests prove that comparison rank/count data is present and that competing bean details are absent.
- Refresher and controller tests prove that bean and brew changes refresh every public bean share in the affected workspace without crossing workspace boundaries.
- Public-page integration tests cover TOP 1/2/3 icons, text-only later ranks, absent badges, accessible copy, and legacy snapshots.
- Layout tests assert that Links render after tasting notes and that the old desktop sidebar grid is absent.
- A browser check at desktop and mobile widths verifies badge wrapping, icon treatment, and the full-width Details-to-Links flow.

## Documentation

Update `docs/public-bean-sharing.md` and `docs/status.md` to record workspace comparison badges, their eligibility rules, snapshot privacy, and the corrected public-page content flow.
