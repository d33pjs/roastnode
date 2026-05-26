# Bean Danger Zone

Bean Danger Zone documents the deliberately destructive bean deletion flow.

## Included Now

- Workspace writers see a danger zone on bean detail pages.
- Deleting a bean deletes the bean, its brews, and all inventory movements for that bean.
- The confirmation message includes the current brew count.
- Viewers can read bean detail pages but cannot see or call the destructive action.

## Deletion Rules

Bean deletion uses `Bean#destroy_with_history!`.

The transaction:

1. captures the bean's brews
2. destroys all inventory adjustments for the bean, including brew and manual adjustments
3. destroys the captured brews
4. destroys the bean

It does not restore inventory before deleting brews because the bean itself is being removed.

## Agent Notes

- Controllers must call `Bean#destroy_with_history!` for this flow. Do not call `destroy!` directly from the controller.
- Keep deletion scoped through `current_workspace.beans.find(params[:id])`.
- Keep the action write-scoped through `current_workspace_policy.write?`.
- Inventory adjustments must be removed before brews, because brews restrict deletion while their inventory adjustment exists.
- Reset the loaded `brews` association before destroying the bean so the model's restrict guard sees the database state.
