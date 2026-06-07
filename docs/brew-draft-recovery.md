# Brew Draft Recovery

Roastnode keeps unsaved espresso form values in the browser while a user is logging a new brew.

## Included Now

- The new espresso form uses the `brew-draft` Stimulus controller.
- Drafts are stored in `localStorage` under `roastnode:brew:new:<workspace-id>:<user-id>`.
- The key is scoped to the active workspace and current user so shared browsers do not reuse another user's draft by accident.
- Repeat Good Brew uses a separate key, `roastnode:brew:repeat:<workspace-id>:<user-id>:<source-brew-id>`, so a browser draft from normal logging does not overwrite a deliberate repeat form.
- Drafts restore automatically when the new espresso form opens again.
- Restored drafts show a compact notice with a discard button.
- Drafts clear when the form is submitted.

## Stored Fields

The controller stores normal form controls such as text fields, number fields, selects, checkboxes, radios, and text areas.

It deliberately skips:

- file inputs
- hidden fields
- submit/reset/button controls
- disabled fields

Photos are not stored in browser drafts. Users should attach them again after returning to the form.

## Boundaries

Draft recovery applies to new espresso logging only. Brew edit/correction forms do not use browser draft recovery because they start from persisted data and should stay review-oriented.
