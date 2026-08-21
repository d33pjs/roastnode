# Public Bean Share Title Design

## Goal

Replace the repeated roaster-and-coffee display name in the public bean hero with the public share title. Keep the title useful when no custom value is saved by applying a clear public-safe fallback chain.

## Public Page Presentation

The public bean hero keeps this order:

1. Roaster name.
2. Coffee name as the large page heading.
3. Share-title line.
4. Average rating, status, brews, and remaining-inventory cards.

The share-title line replaces the current `bean.display_name` line. Its displayed value is resolved in this order:

1. The snapshot share title, when present.
2. The available roast type and blend type, normalized for display and joined with a middle dot, such as `Espresso · Blend`.
3. The literal fallback `404 — share title not found` when the title, roast type, and blend type are all absent.

If only one of roast type or blend type is present, that single value is used. The public page continues to read only curated snapshot data.

## Share Form Guidance

The share-title field gains help text explaining that the title appears below the large coffee name on the public bean page. The help text also explains that an empty title falls back to roast type and blend type, and finally to the 404 message.

The field uses this humorous placeholder without saving it as a value:

`Italian coffee called—it wants its hand gestures back.`

Existing generated values remain unchanged. A user must clear an existing generated title before the roast/blend fallback becomes visible.

## Implementation Shape

A focused public-bean helper resolves the display line from the snapshot title and bean snapshot. This keeps the template readable, preserves compatibility with existing snapshots, and avoids adding a redundant resolved field to the snapshot contract.

User-facing form copy and the terminal 404 fallback live in locale strings. No database migration or private-data lookup is needed.

## Verification

Automated tests cover:

- a custom snapshot title displayed below the coffee name and above the hero statistic cards;
- the roast-type and blend-type fallback when the title is empty;
- a single available roast/blend fallback value;
- the final `404 — share title not found` fallback;
- removal of the repeated bean display name from that hero position;
- the share form help text and humorous placeholder; and
- continued rendering from snapshot data only.

The public bean sharing documentation is updated to record the hero title hierarchy and fallback behavior.
