# Brew Corrections

Brew Corrections lets workspace writers fix or delete a logged brew without leaving bean inventory wrong.

## Included Now

- Edit screen for espresso brews.
- Update flow for brew fields, equipment, bean, and preparation tools.
- Delete flow for brews.
- Current brew photo removal from the correction screen.
- Taste balance and rating adjustment from the brew detail page with an explicit save button.
- Inventory correction when the bean or bean weight changes.
- Inventory reversal when a brew is deleted.
- Existing brew inventory adjustment is updated with the corrected bean, delta, and occurred-at timestamp.

## Inventory Rules

Creating a brew subtracts `bean_weight_grams` from the selected bean and creates a `brew` inventory adjustment.

Updating a brew:

- adds the old `bean_weight_grams` back to the old bean
- saves the corrected brew
- subtracts the new `bean_weight_grams` from the new bean
- updates the existing inventory adjustment
- replaces preparation tool snapshots

Deleting a brew:

- adds the brew's `bean_weight_grams` back to the bean
- deletes the brew inventory adjustment
- deletes preparation tool snapshots with the brew

## Taste Corrections

Workspace writers can adjust only taste balance and rating from a saved brew's detail page. This path does not run inventory correction and ignores inventory-affecting fields. Use the full brew edit screen for bean, weight, equipment, preparation-tool, photo, and note corrections.

Brew ratings are optional, but saved ratings must be whole numbers from 1 through 5.

## Deferred

- Full audit history for corrections.
- Soft-delete and undo.
- Recipe snapshot correction.
