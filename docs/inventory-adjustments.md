# Inventory Adjustments

Manual inventory adjustments let workspace writers correct bean inventory without creating a brew.

## Behavior

- Adjustments are created from a bean detail page.
- The form shows current remaining grams and defaults to **Set remaining weight**: enter the amount measured on your scale and the app records the difference automatically. Zero is supported; negative, missing, and malformed targets are rejected. Repeating an unchanged target produces no ledger or activity entry.
- **Add or remove an amount** keeps the existing signed-delta entry and Add/Remove controls.
- The adjustment stores a signed gram delta, occurred-at time, optional note, user, bean, and workspace.
- Positive deltas add beans back to the bag.
- Negative deltas remove beans from the bag.
- Remaining inventory is clamped at zero so manual corrections cannot make a bag negative.
- Manual adjustments appear in dashboard recent activity.
- Persisted corrections refresh existing curated public bean/brew snapshots inside the inventory transaction; unchanged weighing does not write snapshots.

## Data Rules

Automatic brew consumption uses `InventoryAdjustment#reason = "brew"` and is managed by the brew create/edit/delete flows. Manual corrections use `reason = "manual"` and apply their delta inside `InventoryAdjustment#save_with_inventory_update`.

Keep all inventory mutations workspace-scoped and guarded by the current workspace write policy.

## Moving Leftovers

**Mark as finished** opens a confirmation page with current remaining grams. Finish normally to retain leftovers on that bag, or move all leftovers to a matching open/unopened bag. Matches require the same grind state and either shared CoffeeHistory or the same normalized coffee/roaster names within the active workspace. An unopened destination is opened as part of the move. The page also offers **Duplicate a new bag, open it, and add leftovers**. Finished bags with remaining grams have a **Move leftovers** action, so opening or duplicating a replacement first also works.

Weigh the old bag with **Adjust inventory** before moving it when the measured amount differs. Transfers lock both bags in stable ID order, recheck eligibility, move all remaining grams, and finish the source in one transaction. Repeated requests cannot transfer the same grams twice. Both sides receive a signed ledger row with `reason = "transfer"`, with zero net inventory change. Activity events and public snapshot refresh roll back with the move on failure. Stock/archived sources and finished/archived/unrelated/foreign destinations are rejected.

Bag size and purchase price remain the original purchased amount. Finished usage includes net transferred inventory, so moving leftovers does not claim they were consumed by the old bag. Workspace exports and instance backups preserve transfer rows without a format-version change. Transfer rows and private notes do not add public snapshot fields.
