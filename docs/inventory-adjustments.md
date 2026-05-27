# Inventory Adjustments

Manual inventory adjustments let workspace writers correct bean inventory without creating a brew.

## Behavior

- Adjustments are created from a bean detail page.
- The adjustment stores a signed gram delta, occurred-at time, optional note, user, bean, and workspace.
- Positive deltas add beans back to the bag.
- Negative deltas remove beans from the bag.
- Remaining inventory is clamped at zero so manual corrections cannot make a bag negative.
- Manual adjustments appear in dashboard recent activity.

## Data Rules

Automatic brew consumption uses `InventoryAdjustment#reason = "brew"` and is managed by the brew create/edit/delete flows. Manual corrections use `reason = "manual"` and apply their delta inside `InventoryAdjustment#save_with_inventory_update`.

Keep all inventory mutations workspace-scoped and guarded by the current workspace write policy.
