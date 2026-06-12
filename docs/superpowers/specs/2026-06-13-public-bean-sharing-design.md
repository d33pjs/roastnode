# Public Bean Sharing Design

Date: 2026-06-13

## Goal

Add public sharing for an opened bean bag. A public bean share should work like existing public brew and public recipe shares: unlisted token URL, optional password gate, explicit public media selection, snapshot rendering, view tracking, and management from the private app. The public page should present the bean as a shareable bag story with useful statistics, a compact no-scroll timeline, and every brew logged against that bag.

## Approaches Considered

### Recommended: Snapshot-based `PublicBeanShare`

Create a dedicated public bean share model with its own curated snapshot builder, media controller, page controller, refresher, and view tracking. This matches the privacy model already used by public brew and recipe shares and gives the bean page enough room for bean-specific stats, timeline data, and all-brew summaries.

### Live public bean page

Render directly from `Bean` and its brews on each public request. This is simpler, but it does not match Roastnode's current public-share privacy pattern and makes it easier to accidentally expose private fields, raw media routes, or future private data.

### Aggregate existing public brew shares

Build a bean page from brews that already have public brew shares. This reuses existing share records, but it does not meet the v1 requirement because the public bean page must include all brews for the bag automatically, including Quick Drip brews.

## Chosen Design

Use a new `PublicBeanShare` that parallels `PublicBrewShare`.

The share has:

- one record per bean bag
- `workspace`, `bean`, `created_by`, and `updated_by` associations
- `token` and `token_digest`, with public lookup by digest
- `enabled`, `title`, optional `password_digest`, selected bean photo attachment IDs, `snapshot`, and `views_count`
- a `PublicBeanShareView` table for recent full-IP view history, capped like public brew share views

The public routes are separate from existing share types:

- `/b/:token` for the public bean page
- `/b/:token/password` for password unlock
- `/b/:token/media/:media_id` for selected public bean photos

Public media must use opaque per-share media handles. The rendered public HTML must not expose raw attachment IDs, signed Active Storage URLs, private media routes, or original filenames.

## Publish Scope

Public bean sharing is allowed only for bags that have been opened:

- `open`
- `finished`
- `used_up`

Stock bags and archived bags cannot be published. The public status collapses to:

- `Open` for currently open bags
- `Finished` for finished or used-up bags

All brews for the bean bag are included in v1. This includes espresso and Quick Drip brews. There is no per-brew include/exclude control in v1.

## Privacy Contract

The public page renders from `PublicBeanShare#snapshot`, not live private records, except for the existing global footer support badge setting on the workspace.

The snapshot may include:

- workspace name and logo
- public-safe brewer display labels and avatars for brews included in the public brew cards
- roaster name and bean name
- selected bean package photos
- current remaining grams, bag size, and remaining percentage
- brew count
- public status
- consumed grams
- dead grams, defined as espresso `bean_weight_grams - ground_weight_grams` summed where both values exist
- average rating and rating distribution
- channeling count and channeling percentage for espresso brews
- taste-balance distribution
- grinder setting distribution
- open duration
- fixed-width timeline data from opened date to finished date or latest brew date
- public-safe bean details: origin, process, roast date/type/degree, decaf, country, region, farm, farmer, elevation, variety, harvested, blend type, blend percentage, and tasting notes
- bean `public_note`
- public bean links
- public-safe compact summaries for every brew on the bean
- a `public_media` allowlist for selected bean photos, workspace logo, and public-safe brewer avatars

The snapshot and public page must not include:

- private bean notes
- private brew notes
- purchase source
- purchase price or cost
- private links
- brew photos in v1
- raw private media URLs
- signed Active Storage URLs
- raw attachment IDs in rendered HTML
- original uploaded filenames
- user email addresses
- passwords or password digests
- workspace invite/session/admin/export/backup/environment data

Selected media is limited to bean package photos in v1. Brew photos remain private even though all brew summaries appear on the public page.

## Public Page UI

Use the selected "Balanced Bean Story" layout.

The public page starts with bean identity and inventory:

- roaster name
- bean name
- selected primary/public bean photo
- remaining grams out of bag size
- remaining percentage
- brew count
- public status
- average rating

The timeline is a compact, noninteractive visualization. It spans from opened date to finished date when finished, otherwise from opened date to latest brew. Opening and finish/latest are endpoint markers. Brews render as compressed small dots or ticks so the timeline always fits the viewport without horizontal scrolling. When many brews cluster, the visualization should favor density and aggregate labels over exact spacing.

Analytics sections show:

- grinder setting distribution
- consumed grams
- dead grams
- channeling rate
- taste balance distribution
- rating distribution
- open duration

Details sections show public-safe bean details, public note, and public links.

The all-brews section lists every brew for the bag, newest first, using public-safe compact cards:

- espresso cards show espresso metrics and brewer identity
- Quick Drip cards show method-specific batch metrics
- cards do not show brew photos in v1
- cards do not link to private brew pages

The page shows the workspace support badge footer in the same style as public brew and recipe pages when that workspace setting is configured. The support badge configuration is read from the share's workspace at request time and is not copied into the snapshot.

## Management Flow

Private bean detail pages get a `Share bean` action for writers.

Share permissions:

- owners and admins can manage any public bean share in the workspace
- members can manage shares they created
- viewers cannot create, edit, delete, or view the private share editor

The share editor mirrors public brew sharing:

- title
- enabled toggle
- optional password
- clear password
- selected bean photos
- public URL
- remove action

Workspace settings should list public bean shares alongside the current public brew share management surface. Each row should show the URL, enabled/protected state, linked bean, creation/update timestamps, view count, recent IP history, and quick open/edit/remove actions.

## Snapshot Refresh

Public bean shares stay snapshot based, but the snapshot refreshes when public-safe source data changes.

Refresh triggers include:

- the bean changes
- selected bean media changes
- public links on the bean change
- any brew for the bean is created, edited, or deleted
- user public label/avatar changes for users represented in included brew cards
- workspace name or logo changes

Refreshing removes selected bean photos that no longer belong to the bean. Disabled shares keep their records but remain unavailable publicly.

## Data Flow

Creating or updating a share validates that the bean belongs to the active workspace and is publishable. The controller filters selected photo IDs to attachments on that bean only, then asks `PublicBeanShareSnapshotBuilder` to build the snapshot.

The public page controller looks up enabled shares by `token_digest`. It renders a password gate when needed. Successful unlocked page renders record a view; password-gate and media requests do not count as page views.

The media controller looks up the share by token digest, checks the password unlock state, resolves the opaque media handle against the share's allowlist, and streams only the selected attachment or thumbnail variant.

## Error Handling

Unknown tokens, disabled shares, unpublished lifecycle states, bad media handles, unselected photos, unsupported variants, and locked password-protected media return `404 Not Found`.

Wrong passwords re-render the password gate with an error and use the same rate-limit shape as public brew and recipe password gates.

If thumbnail processing fails, public bean media may fall back to the original bytes while logging only redacted share and attachment identifiers.

## Testing

Add targeted coverage for:

- model token digest lookup, enabled/disabled behavior, password fingerprinting, media handles, lifecycle restrictions, and management permissions
- snapshot builder public fields and private-field exclusions
- create/update/destroy authorization for owner/admin/member/viewer roles
- stock and archived publish refusal
- password gate and unlock behavior
- view tracking and recent IP retention
- public media whitelist, opaque handles, selected bean photos, disabled shares, locked shares, unsupported variants, and no raw private media URLs
- snapshot refresh for bean updates, brew create/update/delete, public bean links, selected media changes, workspace logo/name changes, and user public label/avatar changes
- public page inclusion of all espresso and Quick Drip brews for the bean
- public page exclusion of private notes, private links, costs, purchase source, user emails, raw attachment IDs, original filenames, and brew photos

## Documentation Follow-up

Add `docs/public-bean-sharing.md` as the durable feature contract.

Update:

- `docs/README.md`
- `docs/status.md`
- `docs/coffee-core.md`
- `docs/private-media.md`
- `AGENTS.md`

The docs should emphasize that public bean pages use curated snapshots, selected bean-photo allowlists, opaque public media handles, and all-brew public summaries without exposing private notes or brew photos.
