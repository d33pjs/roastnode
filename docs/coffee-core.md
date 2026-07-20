# Coffee Core

Coffee Core is the first usable household coffee workflow after Workspace Core.

## Included Now

- Workspace-scoped beans as private bag/lot records.
- Workspace-scoped equipment for grinders, machines, and brewers.
- Workspace-scoped preparation tools for brew checklists.
- Basic private photos for beans, brews, equipment, and equipment events.
- Workspace writer photo removal through the private media controller.
- Espresso brew logging with a required bean.
- Quick Drip logging as Roastnode's first non-espresso brew method for private automatic drip/filter-style daily coffee.
- Editable log timestamps for espresso and Quick Drip brews, defaulting to the current time on new logs.
- Automatic inventory deduction when a brew is saved.
- Manual bean inventory adjustments for count corrections.
- Brew correction flows for edit/delete with inventory adjustment.
- Private serving metadata during initial brew logging and post-brew correction for whether a cup was served to a guest, an optional guest label, and the finished cup style such as Americano or Latte.
- Inventory adjustment history for brew consumption.
- Compact screenshot-worthy brew detail cards.
- Public notes and multiple typed links for brews, beans, equipment, and preparation tools.
- Curated public espresso brew sharing with optional passwords, selected photos, and public buy/affiliate links.
- Curated public bean sharing for opened, finished, used-up, or previously opened archived bags with optional passwords, selected bean package photos, all-brew public summaries, and workspace settings management.
- Private recipe profiles created from workspace brews, with editable exact espresso targets and prominent target markers.
- Recipe-guided espresso logging that shows recipe targets without overwriting normal last-brew defaults.
- Recipe JSON import/export for portable unlinked recipe snapshots, including finish ingredients and finish notes while excluding media internals.
- Curated public recipe sharing with optional passwords, target markers, finish ingredients, finish notes, public source notes, public recipe links, and explicitly selected recipe photos through opaque public media handles.
- Paginated all-time brew history with compact-card and hero-card views.
- Paginated all-time workspace activity history for brews, manual inventory adjustments, and equipment events.
- Private workspace statistics and analytics page.
- Bean detail analytics for brew history, best brews, taste balance, and retention markers.
- Search-while-type roaster suggestions on bean entry, sourced from existing active-workspace bean history.
- Equipment detail analytics for usage totals, service counters, and maintenance markers.
- User landing preference for opening Roastnode directly on the log form.
- User enabled brew methods and grams-per-coffee-spoon preference in Profile.
- User espresso form focus preference for fast daily logging.
- Browser-local unsaved draft recovery for new brew logs.
- One-way ground-out to dose prefill while logging espresso.
- Dashboard compact live time-since-last-coffee header that ignores brews marked as served for guests, row-major four-column metric grid for mixed Brew and External Coffee daily/weekly cards, rough daily/weekly spend, unopened-stock versus open-bean inventory split, open-bean count, closed-bag daily/weekly counts, last-4-week trend line chart components, open bean cockpit with current open-bag age, roast age, remaining inventory pressure, latest brew setup, best rated brew, compact status, and recent activity.
- Dashboard bean stock shelf with unopened in-stock bags, quick-open actions, and bean cost metrics for stocked/open inventory.
- Repeat Good Brew flow from private brew details and dashboard cockpit best brews, pre-filling targetable shot/setup values from the source brew while keeping taste, notes, media, and sharing fields fresh.
- Bean index cards group bags by workflow state: open, stock, finished/used up, and archived. Open bags sort by latest brew use first, then opened date and name for beans without brew history. Historical bags stay below active stock/open bags. Stock cards expose quick-open and Rebuy actions.

## Explicitly Deferred

- Public overview pages for all shared brews.
- Public overview pages for all shared recipes.
- Quick Drip recipes and standalone public Quick Drip brew share pages. Quick Drip brews may appear as public-safe summaries inside public bean shares.
- Beanconqueror Quick Drip import.
- Brewer cup/water calibration and professional filter method templates.
- Fediverse publishing for brew shares.
- Advanced media handling beyond current private/public thumbnails, including object storage.
- Beanconqueror media import and full round-trip compatibility.
- Interactive ECharts analytics and exportable brew card images.

## Brew Bean Selection

Espresso and Quick Drip logging always require an open bean.

Default selection order:

1. The current user's most recent brewed bean in the active workspace, or the workspace's most recent brewed bean when the current user has not logged a brew there yet, if that bean is still open and has remaining inventory.
2. The first other open bean in the workspace, ordered by opened date and then creation date.
3. If no open bean exists, redirect to bean creation before logging a brew.

Archived or depleted beans are not valid brew choices in this slice.

## Quick Drip Logging

Quick Drip is the first non-espresso brew method. It is a private daily logging flow for automatic drip/filter-style coffee, not a broad professional filter-method suite.

Quick Drip requires:

- open bean
- Brewer equipment
- Machine cups
- either Coffee spoons or measured Ground coffee

Measured Ground coffee takes precedence for inventory. Spoon-only logs estimate consumed grams from the user's Profile `grams_per_coffee_spoon`, falling back to 5g per spoon, and store the calculated value in `bean_weight_grams` for normal inventory deduction.

Quick Drip omits espresso-only fields: temperature, preinfusion, low-flow start, first drip, channeling, and flow-control use. Quick Drip taste labels are Weak, Balanced, and Harsh for the existing sour/neutral/bitter values.

## Last-Brew Defaults

The log form pre-fills setup fields from the current user's most recent brew for the selected method in the active workspace. If the current user has not logged that method in that workspace yet, it falls back to the workspace's most recent brew for that method so new household members start from the shared setup.

Users can hide optional fields from the new espresso form through Profile. Brew edit/correction screens always show the full log.

New espresso and Quick Drip logs expose an editable log time that defaults to the current time. Brew edit/correction screens expose the saved log time; changing it also moves the associated inventory consumption adjustment so activity and inventory history stay aligned.

Espresso copied fields:

- bean, if still open
- grinder
- machine
- active preparation tools from the previous brew
- grind setting
- brew temperature
- pre-infusion seconds, when the selected machine enables pre-infusion
- low-flow-start seconds, when the selected machine enables low-flow start

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
- flow-control-used state
- taste balance

Quick Drip copied fields:

- bean, if still open
- brewer
- grinder, unless the bean is pre-ground
- active Quick Drip preparation tools from the previous Quick Drip brew
- machine cups
- coffee spoons

Quick Drip spoon grams are not copied from the last brew during normal logging. The form uses the user's Profile preference, and the model falls back to 5g per spoon when that preference is blank. Repeat Good Brew snapshots the source brew's spoon grams instead.

Quick Drip fresh fields:

- measured ground coffee
- beverage yield
- total time
- rating
- taste balance
- notes
- photos

## Repeat Good Brew

Repeat mode opens the normal new brew form with `repeat_brew_id` and the source brew's method. It is distinct from normal last-brew defaults: it intentionally copies targetable values from the selected source brew so the user can try to reproduce that brew.

Espresso copied fields:

- bean, if still open
- newest open duplicated follow-up bag from the same duplicate family when the source bean is no longer open
- grinder, if still active
- machine, if still active
- active espresso preparation tools
- bean weight
- ground-out weight
- dose
- beverage yield
- grind setting
- brew temperature
- pre-infusion seconds
- low-flow-start seconds, when supported by the selected machine
- first-drip seconds
- total time seconds

Quick Drip copied fields:

- bean, if still open
- brewer, if still active
- grinder, if still active and relevant
- active Quick Drip preparation tools
- grind setting
- machine cups
- coffee spoons
- grams per coffee spoon
- measured ground coffee, when the source used measured coffee
- beverage yield
- total time seconds

Espresso fresh fields:

- rating
- taste balance
- channeling
- flow-control-used state
- private notes
- public note
- photos
- record links

Quick Drip fresh fields:

- rating
- taste balance
- private notes
- public note
- photos
- record links

If neither the source bean nor a duplicated follow-up bag is open, repeat redirects to normal new logging for that method with an alert instead of silently choosing an unrelated open bean.

## Espresso Form Helpers

When Ground out and Dose are both visible, typing Ground out copies that value into Dose until the user manually edits Dose. Dose never writes back to Ground out.

Brew ratings are optional, but when present they must be whole numbers from 1 through 5.

## Post-Brew Serving Metadata

New brews redirect to the brew detail page after saving. That page is the intentional saved-brew screen: it shows the Hero Brew Card, quick post-brew correction panels, and the detailed private log below it.

Workspace writers can set private serving metadata while initially logging Espresso or Quick Drip, and can update it later from the brew detail page without running the full inventory correction flow:

- whether the brew was served for a guest
- optional guest label, stored as free text with suggestions from household member display labels and active-workspace guest history
- optional cup style, stored as free text with suggestions from common drink styles and active-workspace brew history

Selecting or typing a guest label marks the brew as served for a guest, even if the guest checkbox is not explicitly toggled. Free-text guest labels become future suggestions after they are saved on a brew. Guest-serving brews remain in private history and inventory accounting, but they do not reset the dashboard's live time-since-last-coffee timer.

Serving updates do not change inventory, brew measurements, equipment, preparation-tool snapshots, taste, rating, notes, photos, public notes, or public links.

Serving metadata is private by default. It can appear on private brew details and private brew history cards, and it is included in private workspace exports and instance backups. Public brew, bean, and recipe snapshots do not include guest labels, guest flags, or cup styles.

## Inventory Rules

- `Bean#remaining_grams` defaults to `bag_size_grams` when a bean is created.
- Beans can be edited after creation, including remaining grams and additive package photos.
- Bean status is derived from lifecycle fields: Stock means owned but unopened (`opened_on` blank), Open means brewable (`opened_on` present, remaining beans, not archived), Used up means zero remaining beans, and Archived means intentionally removed from normal workflows.
- Beans can be archived, reopened, marked as stock/open/used up from the edit form, or duplicated as a new open bag. Duplicates copy descriptive metadata and photos, set `opened_on` to the current date, clear `archived_at`, and reset remaining grams to the bag size.
- Stock-aware open-date behavior keeps unopened stock bags without an opened date, stamps quick-opened bags with the current date, and prevents stock bags from silently appearing in brew selection before they are opened.
- Bag size can initialize or resync remaining grams in one direction for unopened stock bags, but editing remaining grams does not write back to the package size.
- Beans can be deleted from a danger zone. This deletes the bean, its brews, and all inventory movements for that bean in one transaction.
- Bean metadata includes buy date, roast date, roast type, degree of roast, bean rating, blend type, cost, flavor profile, decaf flag, website, notes, richer origin/manufacturer fields, and variety information.
- Public notes and public links are separate from private notes. Public brew shares copy only `public_note` and public links into their snapshots.
- If multiple open beans have the same roaster/name, the espresso logging selector appends the opened date to those duplicate labels only.
- The bean overview groups bags by lifecycle before sorting. Open bags prioritize recently used beans by newest brew, then fall back to opened-date/name ordering. Stock bags sort by purchase, roast, and creation freshness. Finished, used-up, and archived bags stay in historical sections so old bags do not jump above active workflow items.
- The dashboard open bean cockpit shows up to five open beans, ordered by latest brew use and then opened freshness. Each card keeps the bean as the primary inventory link and links latest/best brews separately.
- Creating a brew subtracts `bean_weight_grams` from the selected bean.
- Creating a brew also records an `InventoryAdjustment` with reason `brew`.
- Manual inventory adjustments are logged from a bean detail page with reason `manual`; they add their signed gram delta to the bean and clamp remaining inventory at zero.
- Brew editing/deletion adjusts or reverses the brew inventory movement in one transaction.

## Agent Notes

- Query beans, equipment, brews, and inventory through `current_workspace`.
- Use `current_workspace_policy.write?` for create actions.
- Keep viewer access read-only.
- Recipe profiles are workspace records; do not let recipe-guided logging overwrite normal last-brew defaults.
- Do not allow hiding the bean selector or bean-in weight from the new espresso form, because they are required for inventory.
- Preparation tools are checklist records, not equipment records.
- Use `Bean#destroy_with_history!` for destructive bean deletion; plain `destroy!` is intentionally blocked by dependent brew and inventory guards.
- Render photos through `media_attachment_path`, never raw Active Storage blob URLs.
- Public brew pages are the exception to private media routing: they render selected snapshot media through `public_brew_media_path`, never raw Active Storage blob URLs.
- Public bean pages use curated `PublicBeanShare` snapshots. Selected bean package photos render only through `PublicBeanMediaController` with opaque handles; brew photos, purchase source, purchase cost, private notes, private links, and private record routes must not render.
- Public recipe pages use curated `PublicRecipeShare` snapshots. Ingredients and finish notes are public snapshot content; selected recipe photos render only through `PublicRecipeMediaController` with opaque handles.
- Remove photos through `MediaAttachmentsController#destroy` so workspace and write permissions stay centralized.
- Beanconqueror import is a practical JSON subset, not full feature parity.
