# Beanconqueror Import

Beanconqueror Import brings the first practical subset of a Beanconqueror JSON export into the active Roastnode workspace.

## Included Now

- Owner/admin upload screen for Beanconqueror JSON exports.
- `DataImport` batch report with status, summary, warnings, and raw payload.
- Per-record source metadata for imported beans, equipment, preparation tools, and brews.
- Idempotent repeat imports by Beanconqueror `config.uuid`.
- Beans from `BEANS`.
- Grinders from `MILL`.
- Espresso-compatible preparation methods from `PREPARATION` as machine equipment.
- Nested preparation `tools` as Roastnode preparation tools.
- Espresso-compatible brews from `BREWS`. Quick Drip brew import is deferred.
- Brew inventory adjustments through the normal brew creation path.

## Mapping Notes

Beanconqueror records use `config.uuid` as stable source identity. Brew records link to beans, mills, preparation methods, and preparation tools by UUID.

Important mappings:

- `BEANS.name` -> bean name
- `BEANS.roaster` -> roaster name
- `BEANS.roastingDate` -> roast date
- `BEANS.buyDate` -> buy date
- `BEANS.weight` -> bag size
- `BEANS.cost` -> cost
- `BEANS.url` -> website
- `BEANS.aromatics` -> flavor profile
- `BEANS.roast_type` / `roastType` -> roast type
- `BEANS.roast_degree` / `roastDegree` / `degreeOfRoast` -> degree of roast
- `BEANS.blend_type` / `blendType` -> blend type
- `BEANS.decaffeinated` / `decaf` -> decaf flag
- first `BEANS.bean_information` country, region, farm, farmer, elevation, variety, processing, harvested/crop date, and percentage -> variety information
- `BREWS.bean_weight_in`, falling back to `grind_weight` -> bean weight
- `BREWS.grind_weight` -> ground weight and dose
- `BREWS.brew_beverage_quantity`, falling back to `brew_quantity` -> beverage yield
- `BREWS.brew_time` -> total time
- `BREWS.coffee_first_drip_time` -> first drip
- `BREWS.coffee_blooming_time` -> pre-infusion

Imported preparation methods enable the machine pre-infusion option because Beanconqueror blooming time maps to that field. Low-flow-start and flow-control settings are not inferred from imported source data.

Unsupported or invalid records are skipped with warnings instead of failing the whole import.

## Deferred

- ZIP/media import.
- Background job processing.
- Quick Drip import and other non-espresso method templates.
- Settings, waters, green beans, graph data, device data, pressure profiles, and advanced Beanconqueror-specific fields.
- Fuzzy duplicate merge UI.
- Full Beanconqueror round-trip compatibility.

## Agent Notes

- Keep imports scoped to `current_workspace`.
- Preserve raw source data in `DataImport#raw_payload` and per-record `raw_import_data`.
- Do not automatically merge similar beans or brews.
- Do not import media bytes until the media archive design exists.
