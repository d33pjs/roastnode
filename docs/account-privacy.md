# Account Privacy

Roastnode uses email addresses for authentication, invites, password resets, and owner/admin export data. Email addresses should not be shown on general dashboard or screenshot-oriented coffee pages.

## User-Facing Labels

Use `User#display_label` for casual product UI:

- app navigation sign-out identity
- Brew Hero Card logger and household-recipient identity
- brew and equipment-event bylines

`display_label` uses the profile username and falls back to `unknown username`. Do not fall back to `email_address` in these places.

## Profile Media

Users can upload an avatar and a public banner from the Profile page. On private Brew cards, small logger and household-recipient avatars render only after confirming that each User is a current member of the active Workspace. A former logger or recipient keeps a safe display label but no private avatar URL. Both files are served through the private media controller in authenticated product UI; the "public" banner name does not itself make a file unauthenticated.

## Brew Recipient Privacy

Private Brew surfaces may show an optional Guest `recipient_name` and Cup style. Household recipients use `User#display_label`, never email. A historical household recipient who has left the Workspace keeps the safe display label but no avatar; only the focused serving-correction choice appends the localized **(former member)** marker so the historical selection is explicit.

Public Brew and Bean shares use an automatic curated recipient projection rather than the private fields or a per-share identity toggle:

- Self publishes only its kind and renders as **themself**.
- Named and unnamed Guests publish only the Guest kind and render as **a guest**; Guest name and Cup style never enter the public snapshot.
- A household member publishes a safe display label. An avatar reference is eligible only after current membership in the Brew Workspace is checked before attachment access.
- A former member keeps the already safe historical label but no avatar; malformed or unsupported data falls back to **someone** without identity media.

Public identity images are delivered only through opaque per-share media handles intersected with the current live allowlist and safe-raster gate. Membership removal refreshes affected public Brew and Bean snapshots transactionally, and the live media check revokes a stale recipient-avatar handle on the next request.

## Email Placement

The Profile page shows the signed-in user's email as a read-only account detail. Workspace member lists, invite management, owner-only exports, backups, and the instance-admin account list may still use email addresses where account identity or durable restoration is the point of the surface. Public snapshots and screenshot-oriented coffee pages never use email as a display-label fallback.

The Profile page also shows the user's active household role as read-only account context. Screenshot-oriented dashboard pages should not repeat the signed-in label or role line.

When adding a new surface, ask whether it is a coffee/product surface or an account/admin surface. Coffee/product surfaces should prefer display labels.

## Passkeys

Passkey controls belong in Profile because they are account-security UI. They may show the signed-in user's email address as account context, but coffee/product pages should continue to use `User#display_label`.
