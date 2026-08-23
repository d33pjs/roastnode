# Bean-Switch Grinder Reminder Design

Date: 2026-08-23
Status: Approved for implementation

## Goal

Help an operator notice when switching beans requires a grinder adjustment while keeping the top of the Brew Log compact. The helper is informational: it must not overwrite the operator's grinder or grind-setting input.

## Scope

The Brew Log bean selector will expose inventory context and recent-use context for every enabled brew method:

- Show remaining grams and rounded remaining percentage for every available bean.
- Mark only the bean from the operator's most recent brew for the selected method with a green check and the label `Last used`.
- Fall back to the workspace's most recent brew for the selected method when the operator has no brew history in the active workspace, matching the existing form-default behavior.
- Do not show red X marks on other beans.

The form will show a compact grinder reminder directly below the bean choices when the selected bean is not the last-used bean and its grinder reference differs from the previous brew's reference.

## Grinder References

The previous reference is the same most recent method-specific brew used for the `Last used` marker. It includes:

- Bean name
- Grinder name when present
- Grind-setting text when present

The selected bean reference comes from that bean's best brew for the selected method. A usable reference must have a grinder or a grind setting. The best usable brew is chosen by:

1. Highest rating
2. Newest `occurred_at` when ratings tie
3. Newest `created_at` as the final tie-breaker

Unrated brews are not best-brew references. If the selected bean has no usable rated reference, the reminder still appears and states that no saved grinder reference is available. This uncertainty itself requires a manual grinder check.

References differ when either the grinder record differs or the normalized grind-setting text differs. Normalization trims surrounding whitespace and compares text case-insensitively; it does not attempt to convert between arbitrary grinder notations or decimal formats.

The reminder is not shown when:

- The last-used bean remains selected.
- Another bean has the same grinder and normalized grind-setting reference as the previous brew.
- There is no previous brew reference for the selected method.

## Interface

Each bean option retains its existing photo, name, and radio button. Its compact metadata line becomes:

`180 g left · 72% left · ✓ Last used`

Only the last-used bean includes the green check and label. The percentage uses the existing `Bean#remaining_percent` calculation, rounded for display.

The reminder uses a compact red notification card immediately below the bean list. Its content is:

`Check grinder settings`

`Previous brew — [bean] · [grinder] · [setting]`

`Best for selected bean — [bean] · [grinder] · [setting]`

When no selected-bean reference exists, the second line says `No rated grinder reference yet`. Missing grinder or setting components are omitted rather than replaced with noisy placeholders.

The card updates immediately when the bean radio changes. It starts in the correct state for the server-selected bean and remains usable if JavaScript is unavailable: all bean labels and inventory metadata still render, while the dynamic reminder is treated as progressive enhancement.

## Architecture and Data Flow

A small query/presenter object will build workspace-scoped, method-scoped grinder reminder data for the available beans. It will reuse the same operator-first, workspace-fallback history rule as the Brew Log defaults and return presentation-ready reference data without exposing database IDs beyond ordinary private form values.

The controller will load this data alongside the existing bean options for new/create form rendering. Edit forms will keep their current historical behavior and will not gain switch reminders in this slice, because their selected values represent an existing record rather than a live logging workflow.

The rendered form will provide the previous reference and per-bean best references to a focused Stimulus controller. The controller will only decide whether to hide or reveal the pre-rendered reminder and populate its text from private, server-rendered data. It will not fetch data, change the selected grinder, or change the grind-setting input.

Espresso and Quick Drip comparisons remain separate. A brew from one method cannot define `Last used` or `Best for selected bean` for the other method.

## Error and Edge-Case Handling

- Closed beans may remain in historical references but cannot become new-form choices under existing rules.
- Archived or deleted historical equipment is displayed only when safely available through the workspace-scoped brew relation; missing equipment does not break rendering.
- Pre-ground beans or brews without a usable rated grinder reference show the explicit no-reference message when switching from another bean.
- Failed create submissions preserve the posted bean choice and rebuild the same workspace-scoped reminder data.
- Repeat Brew and recipe-guided logging keep their existing defaults. The marker still describes actual most recent use, and the reminder reflects the currently selected bean without overriding repeat or recipe values.

## Testing

Implementation will follow a red-green-refactor cycle and cover:

- Remaining percentage and the single `Last used` marker render on the new Brew Log.
- History is operator-first, falls back to the workspace, stays method-specific, and cannot cross workspace boundaries.
- Best references prefer higher ratings and use recency tie-breakers.
- The initial reminder state is correct for default, repeat, and failed-create selections.
- The JavaScript controller reveals the card for a different reference, hides it for the same reference or last-used bean, and shows the unavailable-reference message.
- Existing brew defaults and submitted grinder/grind-setting values remain unchanged.

## Documentation

After implementation, update `docs/coffee-core.md` and `docs/status.md` to describe the compact bean inventory labels and method-specific grinder switch reminder.
