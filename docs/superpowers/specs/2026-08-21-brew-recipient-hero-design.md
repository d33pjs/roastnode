# Brew Recipient And Hero Design

## Goal

Distinguish brews served to the logger, a household member, or a guest; show that recipient clearly on private and curated public cards; and turn the upper Hero Brew Card into a readable two-photo Bean/Brew backdrop.

## Recipient Model

Replace guest inference with three explicit recipient kinds:

- `self`
- `household_member`
- `guest`

A Brew stores an optional recipient User reference and an optional private recipient name. The User reference targets `users`, not `memberships`, because membership rows can be removed while historical brews must remain valid.

Invariants are:

- Self has no separate recipient User and no recipient name; the recipient is the Brew logger.
- Household member requires a recipient User who belongs to the Brew workspace when selected and clears the free-text recipient name.
- Guest clears the recipient User and may store a private free-text name.
- Selecting the Brew logger as a household member is normalized to Self.
- `cup_style` remains independent of recipient identity.

Submitted recipient identifiers are resolved through `current_workspace.users`; a foreign-workspace identifier cannot be assigned by changing form parameters.

## Migration And Compatibility

Existing `served_for_guest = true` Brews become Guest and retain their current private guest names. Existing non-guest Brews become Self. Existing names are never matched to household accounts because display labels are mutable and non-unique.

Private JSON/CSV exports and instance backups gain the new recipient kind and reconstructable recipient reference. Restore accepts both the new payload and legacy `served_for_guest`/`guest_name` payloads. The work also fixes the existing omission where serving metadata is exported by backups but not restored.

Recipe snapshots remain recipient-free because a recipe is not a serving event.

## Serving Form

New Brew, Brew edit, and focused post-Brew correction share one “Served to” control. It defaults to Myself, offers stable-ID household member choices with display labels and avatars where available, and accepts a free-text person name as Guest. Entering a name that is not a selected household record sets the Guest kind automatically; the old “Served for guest” checkbox disappears.

Server-side rules remain authoritative when JavaScript is unavailable or parameters are manipulated. Validation errors return the chosen state without changing inventory or unrelated Brew attributes.

## Private Recipient Presentation

Espresso and Quick Drip Hero Cards add a compact header badge:

- Self: light blue, person icon, “For me”.
- Household member: orange, household/person icon, “For Petra”, plus avatar when available.
- Guest: green, guest/group icon, “For Anna” when named and “For a guest” when unnamed.

The byline expresses both sides of the serving relationship, such as “Logged by d33p.js for Petra,” with logger and recipient avatars where authorized. Compact Coffee-list cards use the same recipient presenter and colors. Private guest names remain visible on private detail and compact cards.

Former household recipients remain identifiable by safe label when the User record exists. If their avatar is no longer authorized through active-workspace private media rules, the UI falls back without a broken image.

## Two-Photo Hero Backdrop

The upper content area of both Hero variants becomes a layered two-column media backdrop:

- the Bean bag primary photo occupies the left half;
- the Brew primary photo occupies the right half;
- each missing half stays black, including when the other image exists;
- the Bean image is scaled proportionally with contained fitting and is never visually re-cropped;
- the Brew image scales proportionally with cover fitting;
- a soft center blend joins two available images; and
- a dark vignette plus top/bottom gradients protect text and metric contrast.

Header badges, bean identity, byline, and translucent metric panels render above the media layer. The current small Bean thumbnail beside the name is removed. Dashboard, Brew detail, and Hero-view Coffee history inherit the change through the shared Hero partials.

A dedicated contained Hero media variant may reduce payload size, but it must use resize-to-limit semantics rather than crop semantics for the Bean image. Private media continues through `MediaAttachmentsController` and safe raster types only.

## Curated Public Projection

Public Brew snapshots receive explicit selected Bean-Hero and Brew-Hero attachment references. A Hero reference is present only when that record's primary photo was explicitly selected in the share editor. If it was not selected, its half stays black; the page never falls back to an unselected attachment.

Public media continues through opaque handles and `PublicBrewMediaController`. No raw attachment IDs, private media paths, signed URLs, or original filenames render in HTML.

Public recipient payloads are curated by kind:

- Self identifies the logger as the recipient.
- Household member may include display label and avatar through the snapshot public-media allowlist, as explicitly approved.
- Guest includes only the Guest kind. The private guest name never enters any public snapshot or HTML, and public copy reads “Logged by d33p.js for a guest.”

Public Bean-share Brew summaries receive the same privacy-safe recipient projection. Public Recipe pages remain unchanged. Serving, recipient profile/avatar, selected-photo, and public-safe Brew changes refresh affected snapshots.

## Timer And Analytics Semantics

Guest Brews continue to be excluded from the dashboard time-since-last-coffee calculation. Self and household-member Brews remain household coffee activity and can reset that workspace timer. Recipient-aware statistics are defined separately in the recipient-statistics design.

## Verification

Automated coverage includes:

- recipient invariants, normalization, and cross-workspace rejection;
- legacy serving migration and old/new backup round trips;
- focused serving updates that cannot alter inventory or unrelated fields;
- Self, member, named guest, and unnamed guest private displays;
- member/avatar fallbacks after membership removal;
- all four image combinations on Espresso and Quick Drip Heroes;
- contained Bean fitting, removal of the small thumbnail, and readable overlay structure;
- explicit public photo selection and black unselected halves;
- opaque public media handles and safe variants;
- household-member public identity; and
- negative public assertions for guest names, private recipient fields, raw IDs, filenames, signed URLs, and private media routes.

Responsive browser checks cover mobile and desktop private/public cards, long labels, both themes, image seams, and contrast over bright or dark photographs.

## Documentation

Implementation updates `docs/coffee-core.md`, `docs/brew-card.md`, `docs/brew-corrections.md`, `docs/public-brew-sharing.md`, `docs/public-bean-sharing.md`, `docs/private-media.md`, `docs/account-privacy.md`, `docs/workspace-export.md`, `docs/backup-system.md`, and `docs/status.md`.
