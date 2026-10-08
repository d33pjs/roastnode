# Grinder history

The Brew Log reads the latest recorded setting for the selected coffee, grinder, and brew method. The green Last used marker still describes the operator's previous method-specific bean, falling back to the workspace when the operator has no history.

## References and chart

A reference requires a nonblank setting and an existing grinder in the active workspace. Rating does not filter or order it. Recency uses `occurred_at`, then `created_at`, then ID. The selected bag's own latest value takes priority; when it has none for this grinder/method, linked bags supply the latest compatible value. Whole-bean and pre-ground records are kept separate. Archived grinders retain their history; missing/deleted grinders do not supply settings to another grinder.

The panel shows previous-brew context, the selected coffee's latest setting and date, and a previous-bag source when applicable. A compact selector shows up to three settings by **Recent** (default), **Best rated**, or **Most used**. Recent sorts by last occurrence, creation time, then ID; Best rated uses average Brew rating, rated sample size, then recency, and excludes settings without rated brews; Most used sorts by brew count then recency. Every row shows brew count and last-use date, plus the average rating and rated sample count when available. Counts include all compatible recorded settings in the shared history and report the total brews and contributing bags. Grouping trims surrounding whitespace and ignores case, without treating different numeric notation as equivalent. The latest reference stays visible independently of the selected sort mode.

Bean and grinder changes update the panel from embedded, workspace-scoped data. They never overwrite the input. Espresso's explicit copy action preserves the recorded text and participates in draft recovery; hidden fields stay hidden. Quick Drip is informational, and pre-ground beans do not prompt for grinder settings. Recipe targets and Repeat Good Brew keep their separate behavior.

The panel and latest coffee setting turn red with **Check grinder setting** when the current input differs from the coffee reference, and green with **Setting matches** as soon as typing or the explicit copy action matches it. A separate red input outline and **Double-check grinder** overlay compare the grinder's last recorded use with both the coffee reference and entered setting. This physical check follows all household members and brew methods because the grinder is shared, and remains when copying makes the panel green but the saved grinder position still differs. The overlay hides before it collides with long input text; the outline and accessible description remain. If the grind field is hidden, the panel instead compares the reference with the shared last-use setting so physical mismatches still stay visible. Missing coffee history or a blank last-use setting calls for a manual check; an older nonblank entry is not treated as the current position. Pre-ground coffee and no-grinder selections suppress warnings.

New Brew Log pages opt out of Turbo's page cache so browser Back/Forward reloads current settings and bag history. Normal new logs default the selected grinder's setting from its latest household use across users and methods, including blank unknown settings. Other setup defaults remain operator-specific. Unsaved drafts and Repeat Good Brew retain their intentional input values against fresh household guidance. Defaults use the same occurrence/creation/ID recency tie-break as the panel.

`BrewGrinderReminder` uses bounded PostgreSQL latest-row queries and SQL frequency/rating/recency aggregation rather than loading all historical Brews or querying every bag individually. It returns at most the union of the three top-three modes per compatible history and grinder.

## Bags and ownership

`CoffeeHistory` belongs to a Workspace; every Bean belongs to one CoffeeHistory in that same workspace. The group stores membership only. Saved Brews remain the source of settings, so corrections and deletions are reflected immediately. Linking does not merge bag inventory, bag analytics, or public summaries.

- Duplicating a bag automatically shares its existing group, including duplicate chains.
- Independently created bags start separate. Nonblank matching roaster and coffee names offer an explicit sharing choice, normalized for case and whitespace.
- Editing a bag can link it to a matching group or start a separate history. Renaming does not silently change membership.
- Only workspace writers can request suggestions or change membership. Submitted IDs resolve through the active workspace; raw history foreign keys cannot be mass-assigned.
- Successful link changes are recorded in the existing Bean Activity contract with a `coffee_history_changed` flag, without exposing group IDs in activity metadata.

The migration backfills valid duplicate connected components within each workspace; same-name independent bags remain separate. Broken/foreign ancestry is ignored and cycles terminate. Deleting a source bag does not sever surviving group membership; deleting its brews removes those observations.

## Portability and privacy

Private workspace JSON and instance backups include group rows and bag memberships. Restore remaps IDs per workspace and rejects malformed, missing, or foreign authoritative references. Legacy version-1 archives without either history field reconstruct groups from restored duplicate ancestry. Beanconqueror imports start independent histories.

Public Bean, Brew, and Recipe snapshots remain curated and unchanged. Sharing private grinder history never expands public data or media access. See [Workspace export](workspace-export.md) and [Instance backups](backup-system.md).
