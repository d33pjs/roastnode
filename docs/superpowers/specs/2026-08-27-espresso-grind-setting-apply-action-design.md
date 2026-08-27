# Espresso Grind-Setting Apply Action Design

Date: 2026-08-27
Status: Approved for implementation

## Goal

Make bean switching faster on the new Espresso Brew Log by letting the operator copy the selected bean's saved grind-setting reference directly into the grind-setting text field.

## Scope

The new Espresso form will show a compact apply button beside the Grind setting input when all of these conditions are true:

- The selected bean has a usable grind-setting value in its existing best Espresso grinder reference.
- That saved value differs from the current grind-setting input.
- The Grind setting field is visible under the user's brew-form preferences.

The button label will include the value it applies, for example `Use 1/1,50`. Clicking it copies that exact saved string into the Grind setting input and then hides the button because the values match.

The action will not change the selected grinder. Quick Drip remains unchanged.

## Comparison Behavior

The saved value comes from the same method-specific best reference already used by the bean-switch grinder reminder. The current input and saved value are compared after trimming surrounding whitespace and case-folding, matching the reminder's existing free-text comparison behavior.

The button stays hidden when:

- The last-used bean remains selected and its saved value matches the current default.
- The selected bean has no rated Espresso reference with a nonblank grind setting.
- The current input already matches the saved value.
- The Grind setting field is hidden.

Changing the bean or editing the Grind setting input updates the button immediately. A manually entered value is never overwritten unless the operator clicks the button.

## Interface

The Grind setting label remains above the input. The input and compact button share one responsive row beneath the label, with the text field retaining the available width. The button uses the existing rounded secondary-action styling and remains easy to tap on mobile.

The existing red `Check grinder settings` reminder continues to describe the previous and selected-bean references. It remains informational and is not moved or duplicated.

## Architecture and Data Flow

The existing `BrewGrinderReminder` result remains the single source for the selected bean's best reference. The server will render that reference's raw grind-setting text as private form data alongside the existing comparison key and display label.

The existing `brew-grinder-reminder` Stimulus controller will coordinate the bean radios, reminder, grind-setting input, and apply button within the Espresso form. It will:

1. Read the checked bean's saved setting.
2. Compare it with the current grind-setting input.
3. Update the apply button's label, value, and visibility.
4. Copy the value on explicit click and dispatch a normal input event so browser-local draft persistence observes the change.

The controller will not fetch data, submit the form, or mutate the grinder selection.

Quick Drip will keep the controller's existing warning behavior without rendering a setting target or apply button.

## Error and Edge-Case Handling

- Blank or whitespace-only reference settings do not expose the button.
- Arbitrary grinder-setting strings are copied as plain text and never interpreted as HTML.
- Failed form submissions preserve the posted Grind setting and recompute button visibility against it.
- Repeat Brew and recipe-guided logging preserve their existing prefilled Grind setting; the button appears only if the currently selected bean's saved value differs.
- Draft restoration and discard continue to synchronize the reminder and will also synchronize the button through normal input and change events.

## Testing

Implementation will follow a red-green-refactor cycle and cover:

- The new Espresso form renders the field and hidden apply action with the selected bean's saved setting data.
- A differing saved setting reveals `Use [value]` after a bean switch.
- Clicking the button copies the exact value, dispatches the input event, and hides the button.
- Manual Grind setting edits reveal or hide the button as values diverge or match.
- No action appears when the setting matches, is unavailable, or the field is hidden.
- Quick Drip does not render the apply action.
- Existing grinder-reminder and draft-recovery behavior remains intact.

## Documentation

After implementation, update `docs/coffee-core.md` and `docs/status.md` to describe the explicit Espresso-only apply action. The earlier grinder-reminder documentation must no longer state that the helper never changes the grind-setting input without distinguishing automatic changes from this user-initiated action.
