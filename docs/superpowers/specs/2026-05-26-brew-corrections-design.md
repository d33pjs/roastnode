# Brew Corrections Design

## Intent

Brew Corrections lets a workspace writer fix or remove a mistakenly logged brew without corrupting bean inventory. This closes the current gap where creating a brew deducts inventory, but later corrections do not exist.

## Included Now

- Edit screen for existing espresso brews in the active workspace.
- Update flow for the same curated brew fields used when creating brews.
- Preparation tool checklist updates with fresh brew snapshots.
- Inventory delta handling when `bean_id` or `bean_weight_grams` changes.
- Inventory adjustment record update when brew consumption changes.
- Delete flow that reverses the brew's inventory deduction and removes the brew.
- Brew photo removal from the correction screen through the shared private media controller.
- Owner, admin, and member write access; viewer read-only.

## Explicitly Deferred

- Full audit trail for every correction.
- Soft-deleting brews.
- Undo after delete.
- Recipe snapshot correction.

## Inventory Rules

Updating a brew runs in one transaction:

1. Add the old `bean_weight_grams` back to the old bean.
2. Apply the new brew attributes.
3. Subtract the new `bean_weight_grams` from the new bean.
4. Update the existing brew inventory adjustment to the new bean, delta, occurred-at timestamp, and note.
5. Resnapshot selected preparation tools.

Deleting a brew runs in one transaction:

1. Add the brew's `bean_weight_grams` back to its bean.
2. Destroy the brew inventory adjustment.
3. Destroy the brew, including preparation tool snapshots.

## Testing Notes

Tests must cover:

- edit form is scoped to the active workspace
- updating dose on the same bean adjusts inventory by the delta
- changing the bean returns inventory to the old bean and deducts from the new bean
- preparation tool snapshots are replaced on update
- deleting a brew restores bean inventory
- viewers cannot edit, update, or delete brews
