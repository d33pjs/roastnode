# Public Share Refresh And Management Design

Date: 2026-06-03
Status: Approved for implementation planning

## Context

Public brew sharing currently renders from `PublicBrewShare.snapshot`. That snapshot boundary is intentional: public pages must not query arbitrary private workspace records or expose private notes, private links, raw Active Storage URLs, signed media URLs, raw attachment IDs, original filenames, share tokens in logs, equipment/tool costs, or other private workspace data.

The product now needs public shares to feel current when public-safe source data changes. In particular, public links added to beans, equipment, tools, or brews should appear on every affected public share without opening and saving each share manually.

The same slice also improves the public page presentation, adds a private workspace list of public shares, records full-IP page views, and surfaces record links on bean and gear detail pages.

## Goals

- Keep public brew pages snapshot-rendered.
- Automatically refresh affected public brew share snapshots when public-safe source data changes.
- Preserve each share's existing public URL, enabled state, password state, selected photos, and custom share title.
- Improve the public hero card so it mirrors the private Hero Brew Card more closely while removing identity clutter from inside the public card.
- Make public photos fit inside their cards without cropping and open in a mobile-friendly full-screen viewer.
- Make public links visually obvious as links, including a link icon.
- Add a private household-settings list of all public brew shares with quick URL, edit, and remove actions.
- Track public page views with full IP addresses after successful page access.
- Add public-link lists to bean and gear detail pages.
- Keep the existing enabled-share marker on the brew edit page and make it more useful only if needed.

## Non-Goals

- Public overview pages outside the private app.
- Public comments, reactions, or visitor identity beyond IP/user-agent request metadata.
- Public recipe share changes.
- Live public reads from private source records during page render.
- Exposing private links, private notes, raw media URLs, or internal media identifiers.
- Recording password-gate attempts as page views.

## Chosen Approach

Use automatic snapshot refreshes, not live public reads.

`PublicBrewShare` remains the public rendering boundary. A new refresh service wraps `PublicBrewShareSnapshotBuilder` and regenerates the snapshot for affected shares using only public-safe fields. The public page continues to render only from `@share.snapshot`.

This preserves the privacy model while making public-safe edits propagate broadly. It also gives tests one stable assertion point: if data appears on a public page, it first had to be copied into the curated snapshot.

## Snapshot Refresh Model

Add `PublicBrewShareRefresher`.

For a share, the service:

- reloads the share's brew and associated records;
- filters `selected_photo_attachment_ids` to photos that still belong to the share's allowed public records;
- calls `PublicBrewShareSnapshotBuilder` with the existing title and filtered selected photo IDs;
- updates `snapshot`, `selected_photo_attachment_ids`, and `updated_at`;
- does not change `token`, `token_digest`, `enabled`, `password_digest`, `created_by`, `updated_by`, or `title`.

If a share cannot be safely rebuilt because the brew is gone, normal model dependencies already remove the share with the brew. If a referenced live record was deleted while the brew keeps historical snapshot data, the refreshed snapshot should keep safe brew-time snapshot names where available and omit live-only extras such as new links/photos for the deleted record.

## Refresh Triggers

Affected public brew shares should refresh after successful commits that change public-safe display inputs.

Trigger changes include:

- `Brew`: public note, public links, selected metrics, selected photos, primary photo, bean, grinder, machine, preparation tools, and user/workspace identity references.
- `Bean`: public note, public links, name, roaster, origin, process, roast metadata, purchase/opened dates, purchase price, tasting notes, selected photos, and primary photo.
- `Equipment`: public note, public links, name, model, selected photos, and primary photo.
- `PreparationTool`: public note, public links, name, method, selected photos, and primary photo.
- `RecordLink`: public-visible link create/update/delete for `Brew`, `Bean`, `Equipment`, and `PreparationTool`.
- `Workspace`: name and logo.
- `User`: display label and avatar.

Implementation can use model callbacks, controller-level service calls after successful updates, or a small mix of both. The key requirement is that refreshes happen after the transaction commits so snapshots do not capture rolled-back state.

## Snapshot Payload Changes

The builder should include additional public-safe bean fields:

- purchased date;
- opened bag date;
- roast date;
- purchase price cents;
- origin, process, roast type/level/degree;
- tasting notes;
- public note;
- public links.

The builder already includes core brew timing and temperature fields. Public hero rendering will use:

- dose;
- ratio plus total time subvalue;
- grind;
- rating;
- taste balance;
- beverage yield;
- preinfusion seconds;
- first drip seconds;
- total time seconds;
- temperature.

Retention stays out of the public hero card.

The default title remains `Espresso with Bean Name`, using the bean name rather than roaster-led display text. A manually edited share title remains respected.

## Public Page UI

The public page keeps the share title as the main page title. The public hero card removes household, method, and logged-by identity from inside the dark card. Larger household logo/name and user avatar/display label move below the hero card.

The public hero metrics mirror the private Hero Brew Card's rectangle treatment:

- Dose;
- Ratio, with total time as a subvalue when present;
- Grind;
- Rating, using the same visual rating marks where practical;
- Balance.

Temperature moves into the chart area. The desktop temperature callout must fit inside its rectangle; shorter wording such as `Temp` is acceptable. The chart should show clear markers for preinfusion, first drip when present, and total time at the end of the extraction so a value like `32s` is visually anchored.

Public brew and product photos use fixed-height cards with `object-contain` and a neutral background so the entire image is visible. Each photo opens a full-screen in-page viewer that works on mobile. The viewer uses existing opaque public media URLs, never private media routes or raw Active Storage URLs.

Public links become more visibly link-like:

- include a link icon;
- use stronger contrast and underline treatment;
- keep buy/affiliate links prominent;
- open in a new tab with `rel="noopener"`.

Bean product sections adopt the same polished title/subtitle pattern used by grinder and machine sections. Beans also show available public-safe facts such as buy date, opened bag date, roast date, purchase cost, origin/process/roast, tasting notes, public note, and links. Equipment and preparation tools remain simpler: title, subtitle/model, public note, and links.

## Private Share Management

Add a Public Shares section to the singleton household settings page for owners/admins.

The section lists every `PublicBrewShare` in the active workspace and shows:

- share title;
- enabled/disabled state;
- password-protected state;
- public URL;
- linked brew;
- created and updated timestamps;
- total page views;
- latest viewer IP and time;
- quick actions to open the URL, edit the share, and remove the share.

Removing a share from this list destroys the `PublicBrewShare`, which stops the URL from working. The action uses the same authorization as normal share management: owners/admins may manage any workspace share; writers may manage their own shares from the brew detail/share editor. The household settings list is admin-only because it exposes all workspace shares and visitor IP data.

## Page View Logging

Add a `views_count` integer column to `public_brew_shares` for all-time successful page views.

Add `PublicBrewShareView` with:

- `workspace_id`;
- `public_brew_share_id`;
- `ip_address`;
- `user_agent`;
- `viewed_at`;
- timestamps.

Public page views create a row only after the visitor can see the share:

- enabled share with no password: count on successful page render;
- password-protected share: count after the page is unlocked and rendered;
- disabled, unknown, and locked shares: do not count.

The app stores full IP addresses. The private settings UI shows full IPs only to owners/admins. To limit accidental long-term collection, retain the latest 100 `PublicBrewShareView` rows per share. Deleting older rows must not reduce `public_brew_shares.views_count`; that counter is all-time successful page views, while the retained rows are the recent visitor log.

## Detail Page Link Lists

Bean and equipment detail pages should show their configured record links without requiring edit mode. The lists should distinguish public/private visibility and link type, use the shared record-link labels, and keep workspace scoping through the existing controller lookups.

Preparation tool detail pages may use the same shared partial if it is cheap and consistent, but this slice requires beans and gear.

## Authorization And Privacy

- Public page rendering stays unauthenticated but snapshot-only.
- Public media stays behind `PublicBrewMediaController` and opaque media handles.
- The private share list and visitor IPs are visible only to owners/admins.
- Writers keep existing per-brew share management for their own brews.
- Viewers cannot create, edit, delete, or inspect share management data.
- Public snapshots must not include private notes, private links, purchase source text, equipment/tool prices, raw media URLs, signed URLs, raw attachment IDs in HTML, original filenames, user emails, invite/session/admin/backup/env data, or raw share tokens in logs.

## Testing

Add or update focused tests for:

- snapshot refresh when a public bean/equipment/tool/brew link is added or changed;
- no refresh leakage of private notes or private links;
- filtered public media allowlist after selected photos change or disappear;
- household settings lists all active-workspace public shares and excludes other workspaces;
- only owners/admins see the share management/IP view;
- quick remove destroys the share and makes the public URL return 404;
- public page view rows are created for successful page views and not for password gates, disabled shares, or unknown tokens;
- full IP address appears in the private management UI;
- public page photos use public media paths and do not expose private media routes;
- public hero card includes dose, ratio, grind, rating, balance, preinfusion, first drip, total time, and temperature while omitting retention and in-card identity labels;
- bean/equipment detail pages render link lists.

## Documentation

Update `docs/public-brew-sharing.md`, `docs/private-media.md`, `docs/workspace-settings.md`, `docs/coffee-core.md`, and `docs/status.md` after implementation so they describe automatic public-safe snapshot refreshes, share management, full-IP view logging, and the revised public page media behavior.
