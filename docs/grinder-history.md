# Grinder history

The Brew Log reads the latest recorded setting for the selected coffee, grinder, and brew method. The green Last used marker still describes the operator's previous method-specific bean, falling back to the workspace when the operator has no history.

## References and chart

A reference requires a nonblank setting and an existing grinder in the active workspace. Rating does not filter or order it. Recency uses `occurred_at`, then `created_at`, then ID. The selected bag's own latest value takes priority; when it has none for this grinder/method, linked bags supply the latest compatible value. Whole-bean and pre-ground records are kept separate. Archived grinders retain their history; missing/deleted grinders do not supply settings to another grinder.

The panel shows previous-brew context, the selected coffee's latest setting and date, a previous-bag source when applicable, and its top three setting frequencies. Counts include all compatible recorded settings in the shared history and report the total brews and contributing bags. Chart grouping trims surrounding whitespace and ignores case, without treating different numeric notation as equivalent. The latest setting remains visible even when outside the top three.

Bean and grinder changes update the panel from embedded, workspace-scoped data. They never overwrite the input. Espresso's explicit copy action preserves the recorded text and participates in draft recovery; hidden fields stay hidden. Quick Drip is informational, and pre-ground beans do not prompt for grinder settings. Recipe targets and Repeat Good Brew keep their separate behavior.

`BrewGrinderReminder` uses bounded PostgreSQL latest-row queries and SQL frequency aggregation rather than loading all historical Brews or querying every bag individually.

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
