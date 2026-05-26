# Coffee Core

Coffee Core is the first usable household coffee workflow after Workspace Core.

## Included Now

- Workspace-scoped beans as private bag/lot records.
- Workspace-scoped equipment for grinders and machines.
- Espresso brew logging with a required bean.
- Automatic inventory deduction when a brew is saved.
- Inventory adjustment history for brew consumption.
- Dashboard actions, open beans, compact status, and recent activity.

## Explicitly Deferred

- Recipes, recipe snapshots, and target definitions.
- Photos and media handling.
- Advanced maintenance analytics.
- Beanconqueror import and workspace export.
- Advanced stats and screenshot-ready brew cards.

## Brew Bean Selection

Espresso logging always requires an open bean.

Default selection order:

1. The current user's most recent brewed bean in the active workspace, if that bean is still open and has remaining inventory.
2. The first other open bean in the workspace, ordered by opened date and then creation date.
3. If no open bean exists, redirect to bean creation before logging a brew.

Archived or depleted beans are not valid brew choices in this slice.

## Last-Brew Defaults

The espresso form pre-fills setup fields from the current user's most recent brew in the active workspace.

Copied fields:

- bean, if still open
- grinder
- machine
- bean weight
- ground weight
- dose
- beverage yield
- grind setting
- brew temperature
- total time
- pre-infusion time
- first drip time

Fresh fields:

- rating
- notes
- channeling
- taste balance

## Inventory Rules

- `Bean#remaining_grams` defaults to `bag_size_grams` when a bean is created.
- Creating a brew subtracts `bean_weight_grams` from the selected bean.
- Creating a brew also records an `InventoryAdjustment` with reason `brew`.
- Brew editing/deletion inventory reversal is deferred and must be designed before implementation.

## Agent Notes

- Query beans, equipment, brews, and inventory through `current_workspace`.
- Use `current_workspace_policy.write?` for create actions.
- Keep viewer access read-only.
- Do not add recipe fields to brew forms until the dedicated recipes slice exists.
