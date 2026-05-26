# Coffee Core

Coffee Core is the first usable household coffee workflow after Workspace Core.

## Included Now

- Workspace-scoped beans as private bag/lot records.
- Workspace-scoped equipment for grinders and machines.
- Workspace-scoped preparation tools for brew checklists.
- Basic private photos for beans, brews, equipment, and equipment events.
- Espresso brew logging with a required bean.
- Automatic inventory deduction when a brew is saved.
- Brew correction flows for edit/delete with inventory adjustment.
- Inventory adjustment history for brew consumption.
- Compact screenshot-worthy brew detail cards.
- Private workspace statistics and analytics page.
- Dashboard actions, open beans, compact status, and recent activity.

## Explicitly Deferred

- Recipes, recipe snapshots, and target definitions.
- Advanced media handling, including deletion, primary-photo selection, thumbnails, and object storage.
- Advanced maintenance analytics.
- Beanconqueror media import and full round-trip compatibility.
- Interactive ECharts analytics and exportable brew card images.

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
- active preparation tools from the previous brew
- grind setting
- brew temperature
- pre-infusion seconds

Fresh fields:

- bean weight
- ground-out weight
- dose
- beverage yield
- total time
- first drip time
- rating
- notes
- channeling
- taste balance

## Inventory Rules

- `Bean#remaining_grams` defaults to `bag_size_grams` when a bean is created.
- Creating a brew subtracts `bean_weight_grams` from the selected bean.
- Creating a brew also records an `InventoryAdjustment` with reason `brew`.
- Brew editing/deletion adjusts or reverses the brew inventory movement in one transaction.

## Agent Notes

- Query beans, equipment, brews, and inventory through `current_workspace`.
- Use `current_workspace_policy.write?` for create actions.
- Keep viewer access read-only.
- Do not add recipe fields to brew forms until the dedicated recipes slice exists.
- Preparation tools are checklist records, not equipment records.
- Render photos through `media_attachment_path`, never raw Active Storage blob URLs.
- Beanconqueror import is a practical JSON subset, not full feature parity.
