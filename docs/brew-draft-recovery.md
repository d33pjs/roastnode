# Brew Draft Recovery

Roastnode keeps unsaved form values in the browser while a user is logging a new brew.

## Included Now

- The new brew form uses the `brew-draft` Stimulus controller.
- Normal drafts are stored in `localStorage` under `roastnode:brew:new:<method>:<workspace-id>:<user-id>`.
- The key is scoped to the active workspace and current user so shared browsers do not reuse another user's draft by accident.
- The key includes the brew method so espresso and Quick Drip drafts do not overwrite each other.
- Repeat Good Brew uses a separate key, `roastnode:brew:repeat:<source-method>:<workspace-id>:<user-id>:<source-brew-id>`, so a browser draft from normal logging does not overwrite a deliberate repeat form and repeat drafts stay tied to the source method and source brew.
- Drafts restore automatically when the matching new brew form opens again.
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

Draft recovery applies to new brew logging only. Brew edit/correction forms do not use browser draft recovery because they start from persisted data and should stay review-oriented.
