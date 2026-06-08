# Quick Drip Design

## Goal

Add Roastnode's first non-espresso daily logging method: Quick Drip. The slice should make automatic drip-style filter coffee fast to log, keep bean inventory roughly useful through spoon-based estimates, and preserve the existing private workspace model.

Quick Drip is intentionally not a broad "Filter coffee" umbrella in the UI. It is the visible method tab for the user's fast machine workflow: ground coffee into a filter, choose the machine cup scale, press start, wait for the thermos/pot, and log the result.

## Accepted Approach

Use one **Log** entry point with stable method tabs. Users enable or disable visible brew method tabs in Profile, but disabled methods do not hide historical brews or household activity. The Log screen opens the user's last logged enabled method without reordering the tabs.

The first enabled methods are:

- Espresso
- Quick Drip

Existing and new users get both enabled by default. Profile must require at least one enabled method.

Quick Drip uses first-class typed brew fields for the values that drive validation, inventory, defaults, repeat, stats, and card rendering. Optional output reuses `Brew#beverage_grams`, optional brew duration reuses `Brew#total_time_seconds`, and canonical consumed coffee grams continue to live in `Brew#bean_weight_grams`.

## Considered Alternatives

### Broad Filter Coffee Method

We considered making "Filter coffee" the visible method, then selecting Quick Drip as a template under it. This was rejected because it adds a daily step and makes the first shipped workflow feel less direct. "Filter coffee" remains useful background language for future methods such as pour-over, but v1 presents Quick Drip directly.

### Moving Tabs By Last Use

We considered ordering method tabs by last used method. This was rejected because moving tabs are confusing. The selected method can be smart; the tab order must remain stable.

### JSON Method Payload

We considered storing method-specific fields in a JSON payload. This was rejected for the core Quick Drip fields because they drive inventory, validation, repeat mode, and statistics. Typed columns are easier to query, test, export, and migrate.

## Data Model

### Brew Methods

`Brew#method` expands from espresso-only to include `quick_drip`.

Espresso remains the existing method with espresso-specific fields and card behavior.

Quick Drip requires:

- open bean
- brewer
- machine cups
- either coffee spoons or measured ground coffee grams

Quick Drip allows:

- optional grinder
- optional grind setting when a grinder is selected
- optional output amount
- optional brew duration
- optional preparation tools
- optional taste, rating, notes, photos, and record links

Quick Drip omits:

- espresso machine
- brew temperature
- preinfusion
- first drip
- channeling

### Brew Fields

Add typed Quick Drip fields to `Brew`:

- `brewer_id`, optional foreign key to `Equipment`
- `machine_cups`, decimal
- `coffee_spoons`, decimal
- `grams_per_coffee_spoon`, decimal snapshot
- `coffee_amount_source`, string enum such as `measured` or `estimated_spoons`

`bean_weight_grams` remains the canonical consumed-coffee grams used for inventory. The label is method-specific:

- Espresso: Bean in (g)
- Quick Drip measured: Ground coffee (g)
- Quick Drip estimated: estimated consumed coffee, displayed with `~`

When Quick Drip is saved:

- if measured Ground coffee (g) is present, it wins for inventory
- if measured grams are blank, calculate inventory from `coffee_spoons * grams_per_coffee_spoon`
- if the user's grams-per-spoon setting is blank, use the app fallback of 5g per spoon
- snapshot `grams_per_coffee_spoon` whenever coffee spoons are present
- store the final consumed grams in `bean_weight_grams`
- store `coffee_amount_source` so estimated values display with a tilde

### Bean Grind State

Add `Bean#grind_state` with values:

- `whole_bean`
- `pre_ground`

Backfill existing beans to `whole_bean`. New beans default to whole bean unless changed.

Pre-ground affects Quick Drip defaults and display, but does not restrict method choice. Quick Drip supports both whole-bean and pre-ground bags.

### Equipment

Add `brewer` as an `Equipment#kind` alongside `grinder` and `machine`.

Machine means espresso equipment. Brewer means non-espresso brewing equipment. Quick Drip requires a Brewer because Machine cups are brewer-specific.

Method-specific equipment validation should enforce:

- espresso uses `machine_id`, not `brewer_id`
- Quick Drip uses `brewer_id`, not `machine_id`
- Quick Drip `brewer_id` must point to active workspace equipment with kind `brewer`
- Quick Drip optional `grinder_id` must still point to equipment kind `grinder`

Brewer records reuse the existing Equipment screens, media, lifecycle, links, and events. New Brewer creation opens the existing equipment form with kind preselected.

### User Preferences

Add user preferences:

- enabled brew methods, defaulting to espresso and Quick Drip
- grams per coffee spoon, optional decimal

Profile owns these settings. Profile must reject saving with no enabled methods. The grams-per-spoon label should be "Grams per coffee spoon" with help text explaining that Quick Drip uses it for spoon-based inventory estimates and defaults to 5g when blank.

The existing espresso hidden-field and default-focus preferences do not apply to Quick Drip v1.

### Preparation Tools

Preparation Tools already have `brew_method`. Add Quick Drip support so active Quick Drip tools can appear on the Quick Drip form. Tools remain optional.

Coffee spoon calibration is not a Preparation Tool in v1. It is a user preference because it changes inventory estimation.

## Log Screen And Form

`new_brew_path` becomes the single Log screen, with a method parameter such as `/brews/new?method=quick_drip`. Method tabs are real links so refresh, browser history, and direct links behave clearly.

If no `method` param is provided, choose:

1. the user's last logged enabled method in the active workspace
2. otherwise the first enabled method in stable app order

If the selected method is disabled for the user, fall back to the first enabled method.

Quick Drip form order:

1. method tabs
2. bean
3. batch: Machine cups, Coffee spoons, optional Ground coffee (g), optional Output
4. setup: Brewer, optional Grinder/Grind setting, Preparation Tools
5. taste, notes, photos, links

Quick Drip autofocuses Machine cups.

Quick Drip decimal fields must use the existing localized comma-friendly decimal parsing:

- Machine cups
- Coffee spoons
- Ground coffee (g)
- Output
- Grams per coffee spoon

Validation:

- Machine cups must be greater than zero and may be decimal
- Coffee spoons may be decimal
- Grams per coffee spoon must be positive when supplied
- Quick Drip requires either measured Ground coffee (g) or Coffee spoons
- spoon-only Quick Drip is valid even when the user's grams-per-spoon setting is blank, using the 5g fallback

Defaulting:

- Quick Drip defaults from the user's last Quick Drip in the active workspace
- default bean: last open Quick Drip bean, then open filter beans, then open omni beans, then any open bean
- bean picker shows all open beans, with filter/omni preferred rather than enforced
- default Machine cups and Coffee spoons from the user's last Quick Drip; leave blank for first-time Quick Drip
- default Brewer from last Quick Drip; if none exists and exactly one active Brewer exists, select it
- if no open bean exists, redirect to add a bean
- if no active Brewer exists, redirect to add Equipment with kind Brewer
- for pre-ground beans, default grinder blank
- for whole-bean beans, default optional grinder from last Quick Drip when available
- show Grind setting only when a grinder is selected

Quick Drip gets browser-local draft recovery with a method-specific draft key so espresso and Quick Drip drafts do not overwrite each other.

## Taste

Quick Drip uses method-specific taste labels:

- Weak
- Balanced
- Harsh

For v1, these map to the existing `taste_balance` enum:

- Weak -> `sour`
- Balanced -> `neutral`
- Harsh -> `bitter`

The Quick Drip form hides `very_sour` and `very_bitter`. Espresso keeps its existing taste scale.

## Repeat Good Brew

Repeat Good Brew becomes method-aware.

Quick Drip repeat copies targetable setup and batch values:

- bean, if still open
- brewer, if active
- optional grinder, if active
- active Quick Drip preparation tools
- machine cups
- coffee spoons
- measured/estimated consumed coffee context
- optional output
- optional brew duration

It does not copy:

- rating
- taste balance
- notes
- photos
- record links
- public/share fields

Repeat mode uses a repeat-specific draft key as espresso does.

## Cards, History, And Dashboard

Quick Drip gets a method-specific Hero Brew Card in the existing dense visual family. The accepted direction is a metric-first batch summary, not a decorative process illustration.

The Quick Drip Hero Card shows key method facts such as:

- method badge: Quick Drip
- bean and workspace/user identity
- Machine cups
- Coffee spoons or measured Ground coffee
- estimated or measured consumed grams, using `~` for estimates
- optional output
- optional brew duration
- rating and Quick Drip taste label
- Brewer
- optional Grinder
- selected Preparation Tools

It does not show the espresso extraction chart, recipe ghost, retention, preinfusion, first drip, temperature, or channeling.

The full brew detail page should show the estimate math when applicable, for example `6 spoons x 5g = ~30g`. The Hero Card should stay compact and not show the full calculation.

Brew history compact cards become method-aware:

- Espresso keeps espresso-style ratio, grind, time, and equipment facts.
- Quick Drip shows Machine cups, spoons or measured grams, estimated consumed grams, and Brewer.

Dashboard latest and best brew cards include Quick Drip. The card partial decides how to render each method.

## Analytics

Quick Drip is included in shared totals where meaningful:

- total brew count
- total coffee consumed
- bean detail totals and brew history
- equipment detail usage for Brewers
- dashboard best/latest brew selection

Quick Drip is excluded from espresso-specific analytics:

- grinder tendency
- retention marker analysis
- channeling
- espresso ratio/extraction timing
- espresso temperature analysis

Brewer equipment detail follows the existing Equipment detail pattern with method-appropriate metrics:

- usage count
- total measured/estimated coffee consumed
- average rating
- recent Quick Drip brews
- maintenance events

Brewer maintenance uses the existing Equipment Events system. Add only minimal generic event coverage needed for Brewer maintenance, such as cleaning, descaling, or filter change, if the existing list is too espresso/grinder-specific.

## Authorization And Privacy

Quick Drip follows the existing workspace boundary:

- owners, admins, and members can log Quick Drip
- viewers remain read-only and cannot access the Log screen for creation
- all beans, equipment, tools, brews, media, and links are scoped through `current_workspace`

V1 Quick Drip is private logging only.

Photos and private record links are allowed because they are normal private brew affordances. Public Quick Drip sharing is deferred because public brew shares and public Hero Cards currently assume espresso metrics and need a separate privacy review.

## Export, Backup, Import, And Demo Data

Roastnode workspace exports, readable instance backups, and restore paths must include the new Quick Drip fields, Brewer equipment kind, Bean grind state, and user preferences so data stays reconstructable.

Beanconqueror Quick Drip import is deferred. Existing Beanconqueror behavior should continue to import the supported espresso subset without trying to map non-espresso records into Quick Drip.

Demo data should include:

- one Brewer
- one pre-ground or filter-oriented bean
- one Quick Drip brew
- optional Quick Drip preparation tool such as a paper filter

Production workspaces should not receive auto-created Quick Drip equipment, beans, or tools.

## Documentation

Update durable docs after implementation:

- `docs/README.md`
- `docs/status.md`
- `docs/coffee-core.md`
- `docs/brew-form-preferences.md`
- `docs/brew-draft-recovery.md`
- `docs/brew-card.md`
- `docs/preparation-tools.md`
- `docs/equipment-lifecycle.md`
- `docs/equipment-events.md`
- `docs/statistics.md`
- `docs/workspace-export.md`
- `docs/demo-data.md`
- `AGENTS.md` if the final implementation adds new agent-critical method/privacy rules

## Tests

Add coverage for:

- user enabled brew methods default to espresso and Quick Drip
- users cannot disable all brew methods
- Log screen opens the last logged enabled method without changing tab order
- disabled methods disappear from the Log tabs but historical brews stay visible
- viewers cannot open/create from the Log screen
- Quick Drip requires an open bean
- Quick Drip redirects to bean creation when no open bean exists
- Quick Drip requires a Brewer and redirects to Add Brewer when none exists
- Quick Drip validates Machine cups and either Coffee spoons or Ground coffee
- comma decimal parsing works for Machine cups, Coffee spoons, Ground coffee, output, and grams per spoon
- spoon-only Quick Drip stores estimated consumed grams, source, and grams-per-spoon snapshot
- measured Ground coffee overrides spoon estimate for inventory
- 5g fallback is used when the user has no grams-per-spoon setting
- editing and deleting Quick Drip brews correct/reverse inventory
- Bean grind state defaults existing beans to whole bean and supports pre-ground
- Quick Drip optional grinder and conditional grind setting behavior
- Quick Drip preparation tools are method-scoped
- Repeat Good Brew copies Quick Drip targetable setup/batch fields and leaves subjective/media/link fields fresh
- method-specific draft keys keep espresso and Quick Drip drafts separate
- Quick Drip Hero Card renders metric-first batch facts and not espresso chart fields
- compact history and dashboard cards render method-aware facts
- Quick Drip taste labels map to the existing enum values
- shared totals include Quick Drip while espresso-specific analytics exclude it
- Brewer equipment lifecycle, detail analytics, and events work in the active workspace
- workspace export/backups include Quick Drip fields and restore them
- Beanconqueror import remains conservative and does not attempt Quick Drip mapping
- public Quick Drip sharing and Quick Drip recipes are not exposed in v1

## Explicitly Deferred

- Quick Drip recipe profiles.
- Public Quick Drip brew sharing.
- Public Quick Drip media allowlists and public card rendering.
- Beanconqueror Quick Drip import.
- Brewer cup calibration such as 1 Machine cup = X ml.
- Water grams/ml fields and ratio analytics.
- Professional filter methods such as pour-over or batch brew.
- Per-method hidden field and autofocus preferences.
- User-custom tab ordering beyond enabled/disabled method visibility.
