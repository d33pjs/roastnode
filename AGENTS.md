# Roastnode Agent Guide

Roastnode is a private, self-hostable coffee tracking app for shared household workspaces. Treat the workspace as the ownership and authorization boundary.

## Current Direction

- Build a Rails monolith with Hotwire, Turbo, Stimulus, Tailwind CSS, PostgreSQL, Active Storage, and Solid Queue.
- Keep v1 private by default. Public and federation features are future work and must not leak household data.
- Prefer Rails-native, boring security patterns over custom cleverness.
- Store measurements in canonical metric units: grams, seconds, Celsius.
- Treat `Workspace` as the ownership boundary for domain data. Beans, equipment, brews, inventory, photos, and statistics should belong to a workspace unless a future ADR explicitly says otherwise.
- Treat `User#instance_admin` as an application-level hosting/admin flag, separate from workspace roles. Instance-wide routes must use `authorize_instance_admin!` and must not leak passwords, sessions, invite tokens, signed media URLs, or infrastructure secrets. Keep `InstanceHealthSnapshot` checks read-only and safe for normal page loads.
- Keep documentation in `docs/` current as decisions land.

## Working Rules

- Do not create a nested `roastnode/` app directory. The Rails app lives at the repository root.
- Commit often with small, descriptive commits.
- Protect user changes. Do not revert unrelated local edits.
- Scope early implementation to foundation, authentication, workspaces, memberships, and private household flows.
- Use `current_workspace`, `current_membership`, and `current_workspace_policy` from `ApplicationController` instead of ad hoc workspace lookups in controllers.
- Add tests for authorization and workspace isolation whenever adding workspace-scoped behavior.
- Owners and admins can manage workspace settings and invite links. Workspace settings are singleton active-workspace routes and should not accept workspace IDs. Members can write normal workspace data. Viewers are read-only.
- General product UI should use `User#display_label` instead of `email_address`. Keep email addresses on account/admin surfaces such as Profile, member lists, invites, exports, and the instance-admin account list.
- Users can upload an avatar and public banner from Profile. The avatar may appear on screenshot-friendly brew cards next to the safe display label. Keep both files behind `MediaAttachmentsController`; "public banner" is product intent, not unauthenticated media delivery.
- Do not build public account creation from invite links yet; current invite acceptance assumes the user is already signed in.
- Espresso brew logging requires an open bean. Default to the current user's last active brewed bean, then the first open bean. Redirect to bean creation when no open bean exists. Copy only curated setup fields from the user's last brew: bean, grinder, machine, active preparation tools, grind setting, brew temperature, and pre-infusion seconds. Keep bean weight, ground-out weight, dose, beverage yield, total time, first drip, rating, notes, channeling, and taste fresh.
- The new espresso form autofocuses `User#default_brew_focus_field` and hides fields listed in `User#hidden_brew_field_names`. Keep the supported focus list narrow and intentional; do not include rating, channeling, taste balance, or photos unless the product direction changes. Hideable fields are broader, but the bean selector and bean-in weight must remain visible because they are required for inventory.
- The new espresso form uses browser-local draft recovery through the `brew-draft` Stimulus controller. Draft keys must stay scoped to the current workspace and user, and file/photo inputs must not be stored.
- `root_path` is the user's preferred landing screen and may redirect to the espresso form. Use `dashboard_path` for explicit dashboard/back-to-dashboard navigation.
- Brew corrections must use `Brew#update_with_inventory_correction!` and `Brew#destroy_with_inventory_reversal!` so bean inventory and brew inventory adjustments stay consistent.
- Beans support rich metadata, edit/close/reopen/duplicate workflows, additive package photos, and a destructive danger-zone delete. Duplicate bags should reset remaining grams to bag size, use the current date as opened date, clear archived state, and reuse existing photo blobs. Bean deletion must go through `Bean#destroy_with_history!` so the bean, its brews, and its inventory movements are removed in one transaction.
- Espresso logging must disambiguate only duplicate open bean labels by appending the opened date.
- Brew detail pages and the dashboard use the shared dense Hero Brew Card partial. Show `dose_grams` as Dose, show calculated brew ratio instead of duplicating beverage in the top metrics, show grinder retention from bean-in minus ground-out, render ratio time as smaller secondary text, render rating and balance as separate compact metric cards, keep the bean primary photo to the right of the bean name block, mark first drip in the chart when present, use a vertical right-edge temperature label, and display preparation tools from `BrewPreparationTool#tool_name` snapshots. Show grinder and machine primary photos only as tiny marks in the bottom equipment pills. Do not expose `email_address` on screenshot-friendly brew cards; use `User#display_label`, which falls back to `unknown username`. Keep full log fields such as channeling, notes, bean-in weight, and ground-out weight below the hero card on the brew detail page.
- Brew detail pages should cross-link beans, grinder/machine equipment, and preparation tools below the hero card where the target exists. Keep the Hero Brew Card partial itself free of internal links, because dashboard cards wrap the whole hero card in the one brew-detail link. Use the shared `shared/back_link` partial for old "Back to..." links so mobile users get a real tap target.
- Preparation tools are method-scoped checklist records, not equipment. Brews snapshot selected preparation tool names and preselect active tools from the user's last brew. Preparation tools support detail/edit screens, additive photos, primary-photo/crop/remove media controls, manual position ordering, archive/reopen lifecycle, danger-zone deletion, and query-backed detail analytics through `PreparationToolStatistics`. Preparation tool deletion must go through `PreparationTool#destroy_with_history!` so brew snapshots remain readable with their stored tool names.
- Recipes are deliberately deferred. Do not introduce recipe tables, recipe snapshots, or recipe-based defaults in Coffee Core work.
- Beanconqueror import is currently a conservative JSON subset. Preserve raw import data, use source UUIDs for duplicate handling, map supported rich bean metadata, skip unsupported records with warnings, and do not import media bytes yet.
- Workspace analytics live in `WorkspaceStatistics`; keep aggregation workspace-scoped and query-backed until data volume justifies summaries. Date range filters apply to brew-derived metrics, while open bean counts, known bean spend, and bean breakdowns stay current inventory/catalog views.
- Bean detail analytics live in `BeanStatistics`; keep them scoped through the active workspace bean and query-backed until data volume justifies summaries. Bean detail date range filters apply to brew-derived analytics, while remaining percentage and open age stay current bag facts. Bean list rows show primary photos and remaining amount as `remaining of bag size`; keep channeling on the bean detail page, not the bean list.
- Equipment detail analytics live in `EquipmentStatistics`; keep them scoped through the active workspace equipment record and query-backed until data volume justifies summaries.
- Preparation tool detail analytics live in `PreparationToolStatistics`; keep them scoped through the active workspace preparation tool and based on brew snapshots/associations.
- Equipment supports edit/archive/reopen/delete workflows and additive photos. Equipment list rows show primary photos through private media routes. Archived equipment must be excluded from new brew and new equipment-event selection, but existing brew correction forms should retain the selected historical grinder/machine. Equipment deletion must go through `Equipment#destroy_with_history!` so brew history survives with cleared grinder/machine references.
- Equipment events are first-class workspace records. Use them for grinder and machine maintenance history instead of burying maintenance in equipment notes. A single equipment event can have multiple `event_types`; writers can edit/delete events, and updates replace the selected event types and affected equipment links while preserving/additively attaching photos.
- Photos are private workspace data attached through Active Storage. Render app photos through `media_attachment_path(attachment)`, download them through `download_media_attachment_path(attachment)`, crop them through `crop_media_attachment_path(attachment)`, mark primary photos through `primary_media_attachment_path(attachment)`, and remove them through `MediaAttachmentsController#destroy` so active-workspace and write-policy checks stay centralized; do not use raw Active Storage blob/proxy URLs in app views. Cropping is browser-canvas based and sends a normal replacement upload to the server. Brew detail pages include read-only related photo groups for the selected bean, equipment, and preparation tools.
- Workspace settings include the household logo and banner. The household logo is a small identity mark on Hero Brew Cards. Workspace identity images are visible only for the active workspace and editable only by owners/admins.
- Typography uses self-hosted Elms Sans from `app/assets/fonts/elmssans/` under the SIL Open Font License 1.1. Do not add runtime Google Fonts references; keep the vendored `OFL.txt` with the font files.
- Branding assets live in `app/assets/images/brand/`. Use the shared brand partials with `logo_wordmark_transparent.png` and `logo_mark_transparent.png` for visible UI; the `*_transparent_bg.png` source files currently contain baked checkerboards, so avoid them until they are replaced by true alpha-transparent exports.
- Workspace export is owner-only and uses the active workspace. Keep the JSON export structured for reconstruction, and keep beans/brews CSV exports flat for spreadsheet use. Omit sessions/passwords/invite tokens, and do not include signed media URLs or raw photo bytes until a dedicated media archive design exists.
- Optional demo data is loaded explicitly with `bin/rails roastnode:demo:load`. Keep it idempotent and guarded against accidental production credentials.
- Dashboard recent activity should include brews, equipment events, and manual inventory adjustments. Do not show automatic brew inventory adjustments as separate timeline entries.

## Local Development Intent

- Web server: prefer host port `3001`.
- PostgreSQL: prefer host port `5433` because another local project already owns `5432`.
- Docker Compose should run alongside other local projects without taking common host ports unnecessarily.
- The current Compose image is `postgres:17.5`, chosen because it is already available locally and avoids blocking setup on a Docker image pull.
