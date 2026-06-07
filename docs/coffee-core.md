# Coffee Core

Coffee Core is the first usable household coffee workflow after Workspace Core.

## Included Now

- Workspace-scoped beans as private bag/lot records.
- Workspace-scoped equipment for grinders and machines.
- Workspace-scoped preparation tools for brew checklists.
- Basic private photos for beans, brews, equipment, and equipment events.
- Workspace writer photo removal through the private media controller.
- Espresso brew logging with a required bean.
- Automatic inventory deduction when a brew is saved.
- Manual bean inventory adjustments for count corrections.
- Brew correction flows for edit/delete with inventory adjustment.
- Inventory adjustment history for brew consumption.
- Compact screenshot-worthy brew detail cards.
- Public notes and multiple typed links for brews, beans, equipment, and preparation tools.
- Curated public brew sharing with optional passwords, selected photos, and public buy/affiliate links.
- Private recipe profiles created from workspace brews, with editable exact espresso targets and prominent target markers.
- Recipe-guided espresso logging that shows recipe targets without overwriting normal last-brew defaults.
- Recipe JSON import/export for portable unlinked recipe snapshots, including finish ingredients and finish notes while excluding media internals.
- Curated public recipe sharing with optional passwords, target markers, finish ingredients, finish notes, public source notes, public recipe links, and explicitly selected recipe photos through opaque public media handles.
- Paginated all-time brew history with compact-card and hero-card views.
- Paginated all-time workspace activity history for brews, manual inventory adjustments, and equipment events.
- Private workspace statistics and analytics page.
- Bean detail analytics for brew history, best brews, taste balance, and retention markers.
- Equipment detail analytics for usage totals, service counters, and maintenance markers.
- User landing preference for opening Roastnode directly on the espresso form.
- User espresso form focus preference for fast daily logging.
- Browser-local unsaved draft recovery for new espresso logs.
- One-way ground-out to dose prefill while logging espresso.
- Dashboard open bean cockpit with current open-bag age, roast age, remaining inventory pressure, latest brew setup, best rated brew, compact status, and recent activity.
- Repeat Good Brew flow from private brew details and dashboard cockpit best brews, pre-filling targetable shot/setup values from the source brew while keeping taste, notes, media, and sharing fields fresh.
- Bean index cards group bags by workflow state: open, stock, finished/used up, and archived. Open bags sort by latest brew use first, then opened date and name for beans without brew history. Historical bags stay below active stock/open bags.

## Explicitly Deferred

- Public overview pages for all shared brews.
- Public overview pages for all shared recipes.
- Fediverse publishing for brew shares.
- Advanced media handling beyond current private/public thumbnails, including object storage.
- Beanconqueror media import and full round-trip compatibility.
- Interactive ECharts analytics and exportable brew card images.

## Brew Bean Selection

Espresso logging always requires an open bean.

Default selection order:

1. The current user's most recent brewed bean in the active workspace, or the workspace's most recent brewed bean when the current user has not logged a brew there yet, if that bean is still open and has remaining inventory.
2. The first other open bean in the workspace, ordered by opened date and then creation date.
3. If no open bean exists, redirect to bean creation before logging a brew.

Archived or depleted beans are not valid brew choices in this slice.

## Last-Brew Defaults

The espresso form pre-fills setup fields from the current user's most recent brew in the active workspace. If the current user has not logged a brew in that workspace yet, it falls back to the workspace's most recent brew so new household members start from the shared setup.

Users can hide optional fields from the new espresso form through Profile. Brew edit/correction screens always show the full log.

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

## Repeat Good Brew

Repeat mode opens the normal new espresso form with `repeat_brew_id`. It is distinct from normal last-brew defaults: it intentionally copies targetable values from the selected source brew so the user can try to reproduce that shot.

Copied fields:

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
- first-drip seconds
- total time seconds

Fresh fields:

- rating
- taste balance
- channeling
- private notes
- public note
- photos
- record links

If neither the source bean nor a duplicated follow-up bag is open, repeat redirects to normal new espresso logging with an alert instead of silently choosing an unrelated open bean.

## Espresso Form Helpers

When Ground out and Dose are both visible, typing Ground out copies that value into Dose until the user manually edits Dose. Dose never writes back to Ground out.

Brew ratings are optional, but when present they must be whole numbers from 1 through 5.

## Inventory Rules

- `Bean#remaining_grams` defaults to `bag_size_grams` when a bean is created.
- Beans can be edited after creation, including remaining grams and additive package photos.
- Bean status is derived from lifecycle fields: Stock means owned but unopened (`opened_on` blank), Open means brewable (`opened_on` present, remaining beans, not archived), Used up means zero remaining beans, and Archived means intentionally removed from normal workflows.
- Beans can be archived, reopened, marked as stock/open/used up from the edit form, or duplicated as a new open bag. Duplicates copy descriptive metadata and photos, set `opened_on` to the current date, clear `archived_at`, and reset remaining grams to the bag size.
- Beans can be deleted from a danger zone. This deletes the bean, its brews, and all inventory movements for that bean in one transaction.
- Bean metadata includes buy date, roast date, roast type, degree of roast, bean rating, blend type, cost, flavor profile, decaf flag, website, notes, and variety information.
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
- Public recipe pages use curated `PublicRecipeShare` snapshots. Ingredients and finish notes are public snapshot content; selected recipe photos render only through `PublicRecipeMediaController` with opaque handles.
- Remove photos through `MediaAttachmentsController#destroy` so workspace and write permissions stay centralized.
- Beanconqueror import is a practical JSON subset, not full feature parity.
