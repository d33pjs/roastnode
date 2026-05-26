# Beanconqueror Import Design

## Intent

Beanconqueror Import lets a workspace owner or admin upload a Beanconqueror JSON export and bring over the core private coffee history that Roastnode already understands. It is practical import first, not full feature parity.

## Upstream Shape

Beanconqueror sample exports use top-level arrays such as `BEANS`, `BREWS`, `MILL`, `PREPARATION`, `SETTINGS`, and `VERSION`. Records use `config.uuid` for stable IDs. Brews link to beans, mills, and preparation methods by those UUIDs.

The first import slice maps:

- `BEANS` to `Bean`
- `MILL` to grinder `Equipment`
- `PREPARATION` to machine/brewer `Equipment`
- nested preparation `tools` to `PreparationTool`
- espresso-compatible `BREWS` to `Brew`

## Included Now

- Owner/admin upload screen for Beanconqueror JSON.
- `DataImport` batch record with source, status, summary, warnings, and raw payload.
- Per-record import metadata on imported beans, equipment, preparation tools, and brews.
- Idempotent duplicate handling by source UUID within the active workspace.
- Import report after upload.
- Conservative skip behavior for unsupported or invalid records.

## Explicitly Deferred

- ZIP import and media attachment import.
- Background job processing.
- Beanconqueror round-trip export.
- Importing non-espresso brew methods into dedicated method templates.
- Importing settings, waters, green beans, pressure profiles, and graph/device data.
- Fuzzy duplicate merge UI.

## Mapping Rules

Beans:

- `name` -> `name`
- `roaster` -> `roaster_name`
- `roastingDate` -> `roast_date`
- first `bean_information.country/region` -> `origin`
- first `bean_information.processing` -> `process`
- `aromatics` -> `tasting_notes`
- `note` -> `notes`
- `weight` -> `bag_size_grams`
- `cost` -> `purchase_price_cents`
- `buyDate` -> `purchased_on`
- `openDate` -> `opened_on`
- `url` -> `purchase_url`
- `rating` -> `rating`

Brews:

- `bean` source UUID -> `bean_id`
- `mill` source UUID -> grinder
- `method_of_preparation` source UUID -> machine/brewer equipment
- `bean_weight_in`, falling back to `grind_weight` -> `bean_weight_grams`
- `grind_weight` -> `ground_weight_grams` and `dose_grams`
- `brew_beverage_quantity`, falling back to `brew_quantity` -> `beverage_grams`
- `brew_time` -> `total_time_seconds`
- `coffee_first_drip_time` -> `first_drip_seconds`
- `coffee_blooming_time` -> `preinfusion_seconds`
- `grind_size` -> `grind_setting`
- `brew_temperature` -> `brew_temperature_celsius`
- `note` -> `notes`
- `rating` -> `rating`
- `config.unix_timestamp` -> `occurred_at`

Unsupported brew records are skipped with warnings rather than blocking the whole import.

## Testing Notes

Tests must cover:

- valid import creates beans, equipment, preparation tools, brews, snapshots, and inventory adjustments
- repeat import skips already imported source UUIDs
- unsupported/non-espresso brews are skipped with warnings
- invalid JSON produces a failed import report
- members/viewers cannot import
