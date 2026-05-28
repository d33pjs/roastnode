# Bean Lifecycle And Grinder Tendency Design

## Context

Bean detail and list pages currently use `archived_at` for too many meanings. A bag that is normally finished, a bag that is discarded because it is stale, and a bag hidden from normal workflows all look like the same lifecycle event. The beans overview also shows roast date and open date, but not the date the bag left active use.

The grinder tendency feature also needs to feel like a normal part of the bean detail page. The manual top action is noisy, and the card should always explain what is known: no first brew yet, first brew logged but not enough same-grinder history, or a usable suggestion.

## Approved Approach

Add a first-class normal finish lifecycle for bean bags, keep exceptional archive/discard separate, and refresh the bean detail and overview pages around the compact card direction.

## Lifecycle Model

Add `finished_at` to `beans`.

`Bean#bag_status` should become:

- `stock`: no `opened_on`, no `finished_at`, no `archived_at`
- `open`: has `opened_on`, no `finished_at`, no `archived_at`, remaining above zero
- `finished`: has `finished_at`; this is the normal end of a bag and may preserve leftover grams
- `used_up`: transitional display support for old zero-remaining records if needed, but new normal flows should prefer `finished`
- `archived`: exceptional removal, represented by `archived_at`

Use "Finished" for the normal endpoint and "Archived" or "Discarded" only for unusual removal such as stale or bad beans. Reopening a bean clears `finished_at` or `archived_at` and restores it to the open workflow.

The normal top action on bean detail should become "Mark finished." Exceptional archive/discard belongs in a lower-risk area, not beside the normal daily actions.

`finished_at` is part of bean reconstruction data. Workspace export, instance readable export, and instance restore should preserve it.

## Finished Statistics

Finished bags should show:

- used grams: `bag_size_grams - remaining_grams`
- days open: `finished_at.to_date - opened_on`, clamped to at least one day
- grams per day: used grams divided by days open
- leftover grams, if any

These stats should appear on bean detail and on finished bean cards in the beans overview.

## Grinder Tendency Card

Always render the grinder tendency card on bean detail.

Remove the top "Suggest grinder setting" action.

Card states:

- No first brew: show "Log the first brew for this bag to calibrate a suggestion."
- First brew exists but not enough comparable same-grinder history: show first-brew calibration facts and the empty-history message.
- Suggestion exists: show suggested setting, first-brew setting, first-brew ratio/time, comparable brew count, and average comparable rating when present.

Add a second compact section inside the card that groups grinder settings used for this bean, rendered like the existing retention marker distribution. It should skip blank settings and be safe for unknown free text.

The card remains workspace-scoped and same-grinder scoped. It should not infer across different grinder records.

## Bean Detail Header

Add the bean primary photo to the top header card. The image links to the photo section at the bottom of the page.

Use bounded dimensions and `object-contain`-style presentation so labels are visible and not cropped. The header should still work when no photo is attached.

The photo section should have a stable anchor target.

## Bean Overview Cards

Use the compact card direction.

Each card should show:

- primary photo thumbnail
- bean name, roaster, and status chip
- rating when present
- roast date, open date, and finish date chips where present
- open bags: remaining amount plus a color-coded remaining bar
- nearly finished open bags: warning color below the default threshold
- finished bags: no remaining bar; show used grams, days open, grams per day, and leftover grams

Remaining bar colors:

- plenty left: accent/green
- medium: amber
- low: red
- finished: no bar

For this slice, use a default low-threshold value of `18g`. The threshold is advisory only. It should not automatically finish a bag.

## Deferred

- User profile setting for the low-bean warning threshold.
- Automatic post-brew prompt after crossing the threshold.
- Automatic finishing of bean bags.
- Full copy cleanup for all historical "archived" references outside the touched bean surfaces.
- Recipe or target-profile support for grinder suggestions.

## Testing

Add focused coverage for:

- `finished_at` changes bean status to finished while preserving leftover grams
- reopen clears `finished_at`
- finished stats compute used grams, days open, and grams per day
- workspace export and instance backup/restore preserve `finished_at`
- bean detail always renders the grinder tendency card
- no first brew shows the calibration empty state
- first brew without enough comparable history shows calibration facts and no crash
- grinder setting distribution skips blanks and groups repeated settings
- bean detail header image links to the photo section
- bean list cards show rating, colored bars for open bags, and finished stats for finished bags
- workspace isolation remains intact
