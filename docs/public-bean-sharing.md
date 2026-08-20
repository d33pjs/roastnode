# Public Bean Sharing

Public Bean Sharing lets workspace writers publish one curated bean bag page without opening the private workspace.

## Included Now

- One public share per opened, finished, used-up, or archived bean bag, provided the bag was opened before it was archived.
- Unlisted public URL at `/b/:token`.
- Optional per-share password gate.
- Selected bean package photos only.
- Snapshot-driven public bean page with remaining inventory for open bags, brew count, public status, consumed grams, dead grams, average rating, channeling rate, taste balance, rating distribution, grinder-setting distribution, open duration, and a compact clustered timeline.
- The timeline uses opened and finished/current endpoint markers, brew/count dots on the line, and lane-stacked date plus rating labels above or below the line so dense brew groups stay readable on mobile.
- All espresso and Quick Drip brews for the bag, rendered as public-safe compact cards with rating metric cards. Espresso rows that already have an enabled public brew page show the named public brew link as a compact chip near the date and method.
- Workspace settings management with URL, enabled/protected state, view count, and recent IP history.
- The workspace support badge footer, when configured for public pages.

## Privacy Contract

Public bean shares render from `PublicBeanShare` snapshots. They must not render private notes, purchase source, purchase cost, private links, brew photos, raw record/database IDs, raw attachment IDs, original filenames, signed Active Storage URLs, private media routes, user email addresses, invite tokens, session data, admin data, export data, backup data, environment variables, or infrastructure secrets.

Workspace name/logo and brewer display labels/avatars are intentional public identity surfaces when copied into the snapshot media allowlist. They must still render through public media handles, not raw Active Storage URLs.

The optional workspace support badge configuration is not copied into public bean snapshots. Public bean page controllers may read it from the share's workspace at request time to render the global footer support badge.

Public bean pages include all espresso and Quick Drip brews for the bag as public-safe summaries. Brew summaries may include public notes, public metrics, method labels, taste, rating, channeling, and equipment labels from the snapshot, but they must not include private brew notes or brew photos.

Dead grams include espresso retention (`bean_weight_grams - ground_weight_grams` where both values exist). When a bag is publicly finished while still showing remaining beans, the leftover remaining grams are also counted as dead grams and the remaining inventory hero card is omitted.

## Public Media

Public bean pages use `PublicBeanMediaController` and opaque media handles. The only user-selected photos in v1 are bean package photos. Workspace logos and brewer avatars may appear through the snapshot media allowlist.

Public bean media streams only safe browser-raster image content types: JPEG, PNG, GIF, and WebP. HTML, SVG, and other active or non-image content types return `404 Not Found`.

Public bean pages must not use `MediaAttachmentsController`, `rails_blob_path`, `rails_storage_proxy_path`, signed blob URLs, raw private media routes, raw record/database IDs, raw attachment IDs, original filenames, or private media handles.

Disabled shares, unknown tokens, locked password-protected shares, unsupported variants, deleted attachments, unselected bean photos, and attachments outside the snapshot allowlist return `404 Not Found`.

## Share Management

Workspace writers can create and manage public bean shares for their own publishable bean bags. Owners and admins can manage any public bean share in the workspace. Viewers cannot create or manage shares.

The workspace settings page lists public bean shares with the public URL, enabled/protected state, linked bean, timestamps, total page views, capped recent full-IP view history, and open/edit/remove actions.

Disabled shares and unknown tokens return `404 Not Found`. Password unlock state is scoped to the share token and current password fingerprint, so changing a share password invalidates previous browser unlocks.

Archived opened bags stay shareable and continue to use the public `finished` presentation. Their archive time closes the public timeline, and any positive remaining inventory is counted as dead grams. Archiving does not automatically enable a disabled share.

## Snapshot Refresh

Public bean shares stay snapshot based, but public-safe source changes refresh affected shares.

Refresh triggers include:

- the shared bean
- brews for the shared bean
- brew creation, correction, or deletion that can affect comparison ratings or channeling refreshes all public bean shares in that workspace, including the directly linked share
- deleting a bean refreshes remaining public bean shares in its workspace when its brew metrics are removed from comparisons
- public brew share enabled/title changes for brews on the shared bean
- grinder, machine, or brewer records referenced by those brews
- public links on the shared bean
- selected bean media changes
- workspace name/logo changes
- brewer public-label/avatar changes for users whose brews appear on the public bean page

Public pages still render from the refreshed snapshot. They do not read arbitrary live private fields at request time.

## Agent Notes

- Use `PublicBeanShareSnapshotBuilder` for public bean data.
- Use `PublicBeanShareRefresher` when public-safe source records change.
- Treat `/b/:token` as bearer access and do not log raw share tokens.
- Public pages must not use `MediaAttachmentsController`, raw Active Storage routes, raw record/database IDs, or private record links.
- Use opaque public media handles in public HTML; do not render raw Active Storage attachment IDs.
- Keep public bean pages and public bean media independent from `current_workspace`.
