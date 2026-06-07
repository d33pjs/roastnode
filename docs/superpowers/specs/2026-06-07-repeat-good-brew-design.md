# Repeat Good Brew Design

## Purpose

Repeat Good Brew lets a workspace writer start a new espresso log from a previous successful brew without turning that brew into a recipe profile. It is a fast daily workflow for "do this one again" from the dashboard cockpit or a brew detail page.

## Approved Scope

- Add repeat entry points from the dashboard open bean cockpit's best-brew area and from private brew detail actions.
- Open the normal new espresso form with `repeat_brew_id`.
- Restrict repeat sources to the active workspace.
- Copy targetable setup and shot values from the source brew:
  - bean, with duplicate-bag fallback described below
  - grinder, machine, and active espresso preparation tools
  - bean in, ground out, dose, beverage yield
  - grind setting, temperature, pre-infusion, first drip, and total time
- Keep evaluative and private/public publishing fields fresh:
  - rating, taste balance, channeling, private notes, public note, photos, and record links are not copied.
- Show a compact notice on the new form identifying the source brew so repeat mode is visibly different from normal last-brew defaults.
- Do not let browser-local draft recovery silently override repeat mode. Repeat mode uses a repeat-specific draft key.

## Duplicate-Bag Fallback

If the source brew's original bean is still open and has remaining inventory, repeat uses that bean.

If the original bean is not open, repeat walks to the root duplicated bag and searches that duplicate family for open follow-up bags, including chained duplicates. It uses the newest open duplicate by `opened_on`, then creation time. This supports following bags of the same coffee type.

If neither the source bean nor a duplicated follow-up bag is open, repeat mode redirects to normal new espresso logging with an alert.

## Authorization And Privacy

Repeat uses `current_workspace.brews.find(params[:repeat_brew_id])`, so cross-workspace brew IDs return not found. Only workspace writers can open the repeat form because `BrewsController#new` already requires write access.

The repeat notice can show the source bean display name and date. It must not copy private notes, public notes, photos, public share data, or record links.

## Deferred

- Repeat from public brew pages.
- Repeat from public recipe pages.
- A dedicated "favorite brew" marker.
- Guide-only target overlays. Recipe profiles already cover target-guided logging.
