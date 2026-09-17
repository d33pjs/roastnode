# Grinder History Across Bean Bags

Status: approved by the user and implemented on 2026-09-17.

## Problem confirmed

The green Last used marker describes the operator's last method-specific bean.
The adjacent grinder reminder uses a different rule: it queries the highest-rated
brew per selected bag and discards unrated brews. It ignores duplicate ancestry
and does not react to the selected grinder. These rules explain stale references,
missing settings after a first unrated brew, and missing history for new bags.

Three isolated regression probes on 2026-09-17 reproduced the first three cases:
an older `1/2,75` won over the latest `1/1,25`, an unrated first brew returned no
reference, and an opened duplicate returned no reference despite its source's
recorded setting. No production records were changed during diagnosis.

## Approved behavior

- Preserve the existing green Last used bean marker and normal form defaults.
- The selected coffee's reference is its **last recorded nonblank setting**, not
  its best-rated brew. Rating is irrelevant to this lookup.
- Resolve history within the active workspace, selected brew method, and selected
  grinder. Changing the grinder updates the reference and chart. A missing or
  deleted grinder is never treated as a match for a named grinder.
- Prefer the selected bag's latest recorded setting for that grinder/method. If
  that bag has none, use the newest recorded setting from its linked coffee bags.
  Mark fallback values as coming from a previous bag and show the source date.
- Order references by brew occurrence time, then creation time and ID for a
  deterministic tie break. Blank or whitespace-only settings do not hide earlier
  known settings; the label says Last recorded, rather than implying that every
  later brew recorded a value.
- Keep setting text intact, including strings such as `1/1,25`. The chart groups
  values using surrounding-whitespace trimming and case-insensitive matching;
  it does not guess numerical equivalence between distinct grinder notation.
- Switching beans or grinders does not silently rewrite input fields. An explicit
  Use this setting button copies the same-grinder reference, emits an input event
  for draft recovery, and disappears when the input matches. Hidden fields remain
  hidden. Quick Drip retains informational behavior; pre-ground beans need no
  grinder warning. Recipe targets and Repeat Good Brew retain their own meanings.

## Reminder layout

Use a calm Grinder check panel with clear spacing and readable values:

1. Grinder name and method establish the comparison context.
2. A compact Your previous brew row shows the bean and setting from the existing
   operator-history baseline. If it used a different grinder, identify that
   grinder explicitly and do not present its setting as applicable to the current
   grinder.
3. A highlighted Last setting / Selected coffee block shows the bean, large setting,
   source date, and the explicit copy action.
4. A small horizontal Top 3 chart shows the most frequent settings for the linked
   coffee, selected grinder, and method. Bars carry exact counts. Include the
   total brew count and number of bags, so the top three are not mistaken for the
   entire distribution. The latest value stays visible even when outside the top
   three.

The selected reference remains readable even after applying it; an amber
check indicator is used for a pending change rather than a red error wall.
Empty states distinguish no setting for this grinder from a previous-bag fallback.
No history means no chart and no copy button. Long names wrap, and the layout must
work at 375px in both themes with a polite status region and keyboard controls.

An alternative mockup places the highlighted latest setting below the chart.
Recommendation: above the chart, because the next action stays immediately visible.

## Sharing history across bags

Three approaches were considered:

| Approach | Trade-off |
| --- | --- |
| Traverse only the existing duplicate links | Smallest change; does not cover independently created bags, and deleting a linking bag can split the history. |
| Group automatically by roaster plus name | No explicit link needed, but renames and different coffees with reused names can silently combine or split history. |
| Explicit workspace-owned coffee history group | Recommended: persistent links across bags, automatic inheritance for duplicates, and a deliberate choice for name matches. |

Introduce a small `CoffeeHistory` record owned by a Workspace and referenced by
multiple Beans. It identifies a history group, not a stored grinder preset. Brew
records remain the only source of recorded settings and counts. Do not create a
second settings table or copy synthetic brews into new bags.

Duplicating a bag automatically joins its existing history group. For a new bag
created from scratch, the proposed default is to offer a **Share grinder history**
choice when roaster and coffee name match existing bags after trimming, collapsing
whitespace, and case folding. Require nonblank roaster and name for suggestions.
Show distinct matching groups separately; default to a separate history until the
user explicitly chooses one. Suggestions and submitted choices are always scoped
to the active workspace. Keep pre-ground and whole-bean histories distinguishable
and display relevant differences when presenting a match.

Provide the same explicit history choice on bag edit so existing independently
created bags can be linked. Editing a name or roaster never silently merges
groups; the form shows the existing sharing state and offers Start separate
history if the bag represents a different coffee. Sharing affects grinder
references and the new chart only; inventory and bag-specific statistics remain
per bag.

Backfill existing valid duplicate families into one history group per family;
other bags start separately. Do not auto-merge existing bags by name. Scope the
backfill by workspace and handle broken or cyclic ancestry deterministically.
Deleting an earlier bag must leave links between surviving group members intact;
deleting its brews naturally removes those observations from the history.

## Boundaries and implementation shape

- Keep reads in a workspace-scoped query/service with bounded latest-reference
  queries and SQL aggregation for top-three counts. Avoid loading all historical
  brews on every form render or querying separately for every bean.
- Serve only the fields needed by the reminder. Bean and grinder changes must
  reject foreign IDs; async responses must not overwrite a newer selection.
- Add workspace-consistency validation for history membership and writer-only
  linking. Viewers remain read-only. Record link changes using the existing Bean
  activity contract, without exposing history groups on public pages.
- Include groups and bag membership in private workspace export and instance
  backup/restore with ID remapping. Restore older archives by building history
  groups from existing duplicate links; reject cross-workspace relationships.
  Beanconqueror imports keep new independent groups until explicitly linked.
- Keep public Bean/Brew/Recipe snapshots unchanged. Sharing this private history
  must not broaden any public summary or media allowlist.

## Verification required

Turn the three probes into permanent behavioral regressions. Cover unrated brews,
older high-rated brews, blank settings, timestamp ties, grinder and method changes,
other household members' bag history, duplicate chains, deleted source bags,
matching-name opt-in, separate groups with identical names, foreign workspace IDs,
viewer restrictions, export/restore round trips, legacy backups, and public
privacy boundaries. Exercise the controller with real DOM behavior, including
rapid selection changes, explicit copy, hidden fields, and restored drafts.

Run focused tests, the full Rails and JavaScript suites, RuboCop, security checks,
and production assets. Visually check the used-bag, inherited-history, empty,
different-grinder, long-name, and many-setting states at mobile and desktop widths
in both themes. Restart the development server in `roastnode-dev` after completion.
