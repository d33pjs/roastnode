# Account Privacy

Roastnode uses email addresses for authentication, invites, password resets, and owner/admin export data. Email addresses should not be shown on general dashboard or screenshot-oriented coffee pages.

## User-Facing Labels

Use `User#display_label` for casual product UI:

- app navigation sign-out identity
- brew hero cards
- brew and equipment-event bylines

`display_label` uses the profile username and falls back to `unknown username`. Do not fall back to `email_address` in these places.

## Profile Media

Users can upload an avatar and a public banner from the Profile page. The avatar is shown next to the logged-by label on Hero Brew Cards when available. Both files are still served through the private media controller; the "public" banner name describes intended future profile use, not unauthenticated file delivery.

## Email Placement

The Profile page shows the signed-in user's email as a read-only account detail. Workspace member lists, invite management, exports, and the instance-admin account list may still use email addresses where account identity is the point of the screen.

The Profile page also shows the user's active household role as read-only account context. Screenshot-oriented dashboard pages should not repeat the signed-in label or role line.

When adding a new surface, ask whether it is a coffee/product surface or an account/admin surface. Coffee/product surfaces should prefer display labels.

## Passkeys

Passkey controls belong in Profile because they are account-security UI. They may show the signed-in user's email address as account context, but coffee/product pages should continue to use `User#display_label`.
