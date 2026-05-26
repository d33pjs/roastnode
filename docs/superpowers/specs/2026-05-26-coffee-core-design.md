# Coffee Core Design

Date: 2026-05-26

## Goal

Turn the workspace dashboard from placeholders into a usable private household coffee tracker: real beans, real equipment, required-bean espresso logging, automatic inventory deduction, and a recent workspace timeline.

## Scope

Included:

- Workspace-scoped bean bag records.
- Workspace-scoped equipment records for grinders and machines/brewers.
- Espresso brew logging with a required bean.
- Automatic bean inventory deduction when a brew is created.
- Inventory adjustment history for brew consumption and manual corrections.
- Dashboard actions for adding beans, equipment, and brews.
- Dashboard status for open beans, brews this week, grams remaining, and recent activity.
- Tests for workspace isolation, role permissions, bean selection, and inventory deduction.

Deferred:

- Recipes and recipe snapshots.
- Photos and Active Storage attachments.
- Equipment events and maintenance analytics.
- Beanconqueror import and workspace export.
- Advanced stats, charts, and screenshot-worthy brew cards.
- Editing/deleting brews with inventory reversal.

## Product Decisions

Espresso brew logging requires a bean. The form defaults to the current user's last brewed bean in the active workspace when that bean is still open and has remaining inventory. If that bean is unavailable, the form selects the first open bean ordered by opened date, then creation date. If no open beans exist, the user is sent to create a bean before logging a brew.

Recipes are intentionally excluded from this slice. Brews record actual outcomes directly. Targets and recipe-based defaults will be a later advanced feature.

## Data Model

### Beans

`Bean` represents one private workspace bag or lot, not a global coffee identity.

Fields:

- `workspace_id`
- `name`
- `roaster_name`
- `origin`
- `process`
- `roast_date`
- `roast_level`
- `tasting_notes`
- `bag_size_grams`
- `remaining_grams`
- `opened_on`
- `archived_at`
- `purchase_source`
- `purchase_url`
- `purchased_on`
- `purchase_price_cents`
- `rating`
- `notes`

Open beans are not archived and have `remaining_grams > 0`.

### Equipment

`Equipment` represents reusable workspace equipment.

Fields:

- `workspace_id`
- `name`
- `kind`: `grinder` or `machine`
- `model`
- `notes`

### Brews

`Brew` records one espresso brew outcome.

Fields:

- `workspace_id`
- `user_id`
- `bean_id`
- `grinder_id`, optional equipment
- `machine_id`, optional equipment
- `method`, default `espresso`
- `occurred_at`
- `bean_weight_grams`
- `ground_weight_grams`
- `dose_grams`
- `beverage_grams`
- `grind_setting`
- `brew_temperature_celsius`
- `total_time_seconds`
- `preinfusion_seconds`
- `first_drip_seconds`
- `channeling`
- `taste_balance`
- `rating`
- `notes`
- `retention_marker`

`retention_marker` is calculated from `ground_weight_grams - bean_weight_grams` when both values are present. More than `+0.2g` is `exchange`, less than `-0.2g` is `retention`, otherwise `normal`.

### Inventory Adjustments

`InventoryAdjustment` records bean inventory movement.

Fields:

- `workspace_id`
- `bean_id`
- `user_id`
- `brew_id`, optional
- `delta_grams`
- `reason`: `brew`, `manual`
- `note`
- `occurred_at`

Creating a brew subtracts `bean_weight_grams` from the selected bean. If `bean_weight_grams` is missing, the brew is invalid in this slice; fallback to dose can come later if real use shows that is needed.

## Authorization

- Owners, admins, and members can create beans, equipment, brews, and manual inventory adjustments.
- Viewers can read beans, equipment, brews, and the dashboard but cannot write.
- Every query loads through `current_workspace`.
- Beans, equipment, and brews from another workspace must not be visible or selectable.

## User Flows

### Beans

The beans index lists open beans first, then archived/depleted beans. Users with write permission can add a bean. Creating a bean sets `remaining_grams` to `bag_size_grams` when remaining is blank.

### Equipment

The equipment index lists grinders and machines. Users with write permission can add equipment. Espresso brew forms use grinder and machine records as optional selectors.

### Brew Logging

The dashboard has a primary "Log espresso" action. The new brew form selects the required default bean using last-bean-then-first-open behavior. If no open bean exists, the controller redirects to the new bean form with an alert.

Saving a brew creates an inventory adjustment, subtracts from the bean's remaining grams, stores the retention marker, and redirects to the brew detail page.

### Dashboard

The workspace dashboard shows:

- primary actions: log espresso, add bean, add equipment
- compact status: brews this week, open beans, grams remaining
- current open beans
- recent brews and inventory adjustments

## Testing

Add model and controller tests for:

- bean open scope and default remaining grams
- write permission for member and denial for viewer
- workspace isolation for beans/equipment/brews
- required bean selection and redirect when none exists
- brew creation subtracting inventory and writing adjustment history
- retention marker calculation
- dashboard showing real actions and recent activity

## Documentation

Update `docs/workspace-core.md` or add a dedicated coffee-core doc so future agents know recipes are deferred and bean selection is mandatory for espresso brews.
