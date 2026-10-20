# Parallel coffees

Espresso logging supports two unfinished coffees in one browser screen. Each coffee has a stable session number and independent form, measurements, recipient, photos and draft. The sticky switcher keeps the other coffee reachable on a phone. Prepare, Extract, Taste and Full form are freely selectable views of the same form; changing views never validates or saves a Brew.

## Daily flow

1. Enter the first coffee's setup, beans and grind values.
2. Confirm preparation with Continue to extraction, or use Prepare next coffee to confirm preparation and open the second coffee directly.
3. Prepare the second coffee while the first extracts. Switch back to enter the first coffee's timing and beverage weight.
4. Save either coffee independently. When another unfinished coffee remains, logging stays on that coffee. Otherwise the saved Brew detail opens.
5. The free slot can prepare a third coffee without renumbering the coffee still in progress.

Preparing another coffee copies setup only. Measurements, taste, notes, recipient and photos start fresh. Recipe/repeat targets retain their separate entry context. Timing remains manual, and field preferences and machine-dependent inputs still apply. The original form remains usable without JavaScript.

## Exact grinder chronology

Confirming preparation creates an immutable private `GrinderUse` immediately, before saving the Brew. It records the active workspace, operator, bean, grinder, method, exact setting text and server-assigned grinding time. Retrying the same confirmation UUID returns the original confirmation; changing its context is rejected. Typing, selecting a reference, moving between views and saving an older Brew do not create a new confirmation.

The latest physical-use reference is per grinder across all household members, beans and brew methods. It compares confirmed uses and saved Brews by grinding time, falling back to occurrence time for legacy/unconfirmed Brews. Equal-time confirmation/Brew ties retain the confirmation. New coffees fetch the latest household reference; an already open coffee keeps its entered setting. Bean-specific suggestions still describe saved Brew history and remain separate from the grinder's last-use reference.

For example, grind Coffee 1 at `1/2,50`, then Coffee 2 at `1/2,75`. Saving Coffee 2 before Coffee 1 leaves `1/2,75` as the reference for Coffee 3. Each Brew retains its original string. Decimal notation, trailing zeros and surrounding text are never numerically parsed or rounded.

Changing the bean, grinder or exact setting after confirming invalidates that coffee's confirmation. Confirm again to record another physical use. No-grinder and pre-ground preparations skip grinder confirmation. Discarding an unfinished coffee does not undo a physical grinder use.

Every newly prepared parallel coffee using whole beans and a grinder requires explicit preparation confirmation before saving, including when its user jumps directly to Taste or Full form. Saving never confirms grinding automatically: a late save must not become a new physical use. The initial ordinary Full form and no-JavaScript logging retain legacy occurrence-time behavior.

## Persistence and privacy

Each coffee has a client draft UUID. The server scopes successful-save retries by workspace and operator so a lost response cannot create another Brew or deduct inventory again. Validation, network and authentication failures keep browser drafts intact. Inventory changes only when each Brew saves.

Espresso sessions use version-2 browser drafts under the established user/workspace/method/entry-context key. Existing single drafts migrate. Recipe-guided sessions additionally isolate their recipe context. Drafts retain both coffees, active selection, view and scroll position. File selections stay attached while switching within the page; after reloading, users must attach photos again. Hidden security fields and media references are excluded from browser payloads.

Only workspace writers can confirm grinding or save coffees. Every bean, equipment and confirmation lookup is scoped to the active workspace; a Brew can claim only its operator's matching confirmation. Operational confirmations and Brew grinding times are included in private workspace exports and instance backups, with reference remapping and legacy archive compatibility. They never enter public Bean, Brew, Recipe or cupping snapshots.

See [Grinder history](grinder-history.md), [Brew draft recovery](brew-draft-recovery.md), [Coffee core](coffee-core.md) and [Workspace export](workspace-export.md).
