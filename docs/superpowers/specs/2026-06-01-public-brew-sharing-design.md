# Public Brew Sharing Design

## Goal

Let workspace members manually share a curated public espresso brew page with selected brew data, photos, product notes, and affiliate links, while preserving Roastnode's private-workspace boundary.

## Scope

- Add manual public sharing for a single brew through an unlisted token URL.
- Support optional per-share password protection.
- Store public share content as a reviewed snapshot instead of reading live private records.
- Add public notes to brews, beans, equipment, and preparation tools.
- Add multiple typed links to brews, beans, equipment, and preparation tools.
- Render a polished public Editorial Scroll page centered on the Hero Brew Card.
- Include selected photos and public product sections for the bean, grinder, machine, and selected preparation tools.

## Explicitly Deferred

- Fediverse publishing.
- A public overview/index of all shared brews.
- Public comments, reactions, analytics, or tracking.
- Dedicated mug records. Mugs can be represented as preparation tools in this slice.
- Public profiles beyond the identity already shown on a shared brew page.
- Automatic regeneration of public shares after private records change.

## Data Model

`PublicBrewShare` is workspace scoped and belongs to one private `Brew`. It stores a random public token, enabled/disabled state, optional password digest, share title, creator/last editor metadata, and a JSON snapshot used by the public page.

The snapshot is created or regenerated from current public-safe fields selected in the share editor. It includes:

- brew metrics suitable for the public Hero Brew Card
- public brew note
- workspace name and logo attachment reference
- logged-by username/display label and avatar attachment reference
- bean name, roaster, origin, process, roast details, tasting notes, public note, purchase price, selected photo references, and public links
- grinder and machine name, kind, model, public note, selected photo references, and public links
- preparation tool snapshot names plus linked tool public note, selected photo references, and public links when the live tool still exists
- selected brew photos and related record photos

The snapshot does not copy private `notes`, email addresses, invite tokens, raw private media URLs, signed media URLs, environment data, or equipment/tool cost fields. Bean purchase price may appear publicly when present because it is useful coffee/product context.

`public_note` is added to `brews`, `beans`, `equipment`, and `preparation_tools`. These notes are separate from the existing private `notes` fields and are the only long-form notes copied into a public share snapshot.

`RecordLink` is a polymorphic workspace-scoped link model for `Brew`, `Bean`, `Equipment`, and `PreparationTool`. It stores:

- `label`
- `url`
- `kind`: `info`, `buy`, or `affiliate`
- `visibility`: `private` or `public`
- `position`

Only links with `visibility: public` are copied into public share snapshots. Affiliate and buy links are visually prominent on the public page but still tied to their record section.

## Sharing Workflow

On a private brew detail page, eligible users see a public sharing action.

If no share exists, the action opens a share editor prefilled from the brew, bean, grinder, machine, and selected preparation tools. The editor lets the user:

- enable or disable the public page
- set or clear the optional password
- edit the share title
- review the public brew note copied from `brew.public_note`
- choose which photos to include
- review public links included from the brew, bean, gear, and tools
- regenerate the snapshot from current public fields after changing notes, links, or photo choices

Photo inclusion is explicit. Defaults are helpful rather than automatic publication:

- brew primary photo or first brew photo
- bean primary photo
- grinder primary photo
- machine primary photo
- selected preparation tools' primary photos

Users can add or remove eligible photos before saving the public snapshot. Unselected photos do not render on the public page.

Access rules:

- Workspace writers can create and manage shares for brews they logged.
- Owners and admins can manage any share in the workspace.
- Viewers cannot create or manage shares.
- Public visitors use `/s/:token`.
- Disabled shares and unknown tokens return not found.
- Password-protected shares show a minimal password gate before the public page.

## Public Page

The public page uses an Editorial Scroll layout:

- top bar with workspace name/logo and user username/avatar
- public Hero Brew Card as the opening object
- Hero Card bottom gear/tool pills as anchor links to detail sections
- public brew note as a short story below the card
- curated photo gallery from selected photos only
- sections for bean, grinder, machine, and preparation tools
- each product section shows a selected hero photo when present, public note, useful public facts, and public links

The public Hero Brew Card keeps the existing identity marks. Workspace name/logo and user username/avatar are considered intentional public identity surfaces for this feature. The card remains adapted for public rendering so it can use snapshot values and public media routes without depending on `current_workspace`.

Public data may include:

- brew dose, yield, ratio, grind setting, retention, rating, taste balance, temperature, preinfusion, first drip, total time, channeling, and occurred time
- bean origin, process, roast date, roast type, roast level, roast degree, tasting notes, public note, purchase source, purchase URL when marked public through links, and bean price
- gear/tool name, kind, model, public note, selected photos, and public links

Public data must not include:

- private `notes`
- user email addresses
- private media URLs or signed Active Storage URLs
- workspace invite links or tokens
- backup/export/admin data
- equipment or preparation tool purchase prices

## Public Media

Public pages cannot use the existing authenticated `MediaAttachmentsController` route because that controller intentionally checks active workspace membership. V1 needs a public-safe media route that streams only attachments referenced by an enabled `PublicBrewShare` snapshot after any password gate has been satisfied.

The public media route should:

- support thumbnails for in-page previews
- avoid raw Active Storage blob URLs
- return not found for attachments not included in the share snapshot
- return not found for disabled shares or unknown share tokens
- apply the same password-gate state as the HTML page

## Tests

Tests must cover:

- public pages are inaccessible until a share is enabled
- unknown and disabled shares return not found
- optional password gate blocks incorrect passwords and allows correct passwords
- private notes do not appear in the snapshot or public HTML
- equipment/tool costs do not appear publicly
- bean price may appear publicly when present
- selected photos render through the public-safe media route
- unselected photos do not render
- public media route rejects attachments outside the share snapshot
- cross-workspace users cannot manage another workspace's shares
- writers can manage shares for their own brews
- owners/admins can manage all workspace shares
- viewers cannot manage shares
- public links include only `visibility: public`
- public Hero Card uses snapshot identity values for workspace/user display

## Documentation

Add `docs/public-brew-sharing.md` for durable product and privacy rules. Update:

- `docs/README.md`
- `docs/status.md`
- `docs/coffee-core.md`
- `docs/brew-card.md`
- `docs/private-media.md`
- `AGENTS.md` when the new public-sharing privacy rule needs to be visible to future coding agents
