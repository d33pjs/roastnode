# Roastnode Agent Guide

Roastnode is a private, self-hostable coffee tracking app for shared household workspaces. Treat the workspace as the ownership and authorization boundary.

## Current Direction

- Build a Rails monolith with Hotwire, Turbo, Stimulus, Tailwind CSS, PostgreSQL, Active Storage, and Solid Queue.
- Keep v1 private by default. Public and federation features are future work and must not leak household data.
- Prefer Rails-native, boring security patterns over custom cleverness.
- Store measurements in canonical metric units: grams, seconds, Celsius.
- Treat `Workspace` as the ownership boundary for domain data. Beans, equipment, brews, inventory, photos, and statistics should belong to a workspace unless a future ADR explicitly says otherwise.
- Keep documentation in `docs/` current as decisions land.

## Working Rules

- Do not create a nested `roastnode/` app directory. The Rails app lives at the repository root.
- Commit often with small, descriptive commits.
- Protect user changes. Do not revert unrelated local edits.
- Scope early implementation to foundation, authentication, workspaces, memberships, and private household flows.
- Use `current_workspace`, `current_membership`, and `current_workspace_policy` from `ApplicationController` instead of ad hoc workspace lookups in controllers.
- Add tests for authorization and workspace isolation whenever adding workspace-scoped behavior.
- Owners and admins can manage workspace settings and invite links. Members can write normal workspace data. Viewers are read-only.
- Do not build public account creation from invite links yet; current invite acceptance assumes the user is already signed in.
- Espresso brew logging requires an open bean. Default to the current user's last active brewed bean, then the first open bean. Redirect to bean creation when no open bean exists. Copy only curated setup fields from the user's last brew: bean, grinder, machine, active preparation tools, grind setting, brew temperature, and pre-infusion seconds. Keep bean weight, ground-out weight, dose, beverage yield, total time, first drip, rating, notes, channeling, and taste fresh.
- Brew corrections must use `Brew#update_with_inventory_correction!` and `Brew#destroy_with_inventory_reversal!` so bean inventory and brew inventory adjustments stay consistent.
- Beans support rich metadata, edit/close/reopen/duplicate workflows, additive package photos, and a destructive danger-zone delete. Duplicate bags should reset remaining grams to bag size, use the current date as opened date, clear archived state, and reuse existing photo blobs. Bean deletion must go through `Bean#destroy_with_history!` so the bean, its brews, and its inventory movements are removed in one transaction.
- Espresso logging must disambiguate only duplicate open bean labels by appending the opened date.
- Brew detail pages and the dashboard use the shared dense Hero Brew Card partial. Show `dose_grams` as Dose, show calculated brew ratio instead of duplicating beverage in the top metrics, render ratio time as smaller secondary text, render rating as visual bean marks, mark first drip in the chart when present, and display preparation tools from `BrewPreparationTool#tool_name` snapshots. Do not expose `email_address` on screenshot-friendly brew cards; use `User#display_label`, which falls back to `unknown username`. Keep full log fields such as channeling, notes, bean-in weight, and ground-out weight below the hero card on the brew detail page.
- Preparation tools are method-scoped checklist records, not equipment. Brews snapshot selected preparation tool names and preselect active tools from the user's last brew.
- Recipes are deliberately deferred. Do not introduce recipe tables, recipe snapshots, or recipe-based defaults in Coffee Core work.
- Beanconqueror import is currently a conservative JSON subset. Preserve raw import data, use source UUIDs for duplicate handling, map supported rich bean metadata, skip unsupported records with warnings, and do not import media bytes yet.
- Workspace analytics live in `WorkspaceStatistics`; keep aggregation workspace-scoped and query-backed until data volume justifies summaries.
- Equipment events are first-class workspace records. Use them for grinder and machine maintenance history instead of burying maintenance in equipment notes. A single equipment event can have multiple `event_types`.
- Photos are private workspace data attached through Active Storage. Render app photos through `media_attachment_path(attachment)` and remove them through `MediaAttachmentsController#destroy` so active-workspace and write-policy checks stay centralized; do not use raw Active Storage blob/proxy URLs in app views.
- Typography uses self-hosted Elms Sans from `app/assets/fonts/elmssans/` under the SIL Open Font License 1.1. Do not add runtime Google Fonts references; keep the vendored `OFL.txt` with the font files.
- Branding assets live in `app/assets/images/brand/`. Use the shared brand partials with `logo_wordmark_transparent.png` and `logo_mark_transparent.png` for visible UI; the `*_transparent_bg.png` source files currently contain baked checkerboards, so avoid them until they are replaced by true alpha-transparent exports.
- Workspace export is owner-only and uses the active workspace. Keep export payloads structured, omit sessions/passwords/invite tokens, and do not include signed media URLs or raw photo bytes until a dedicated media archive design exists.
- Dashboard recent activity should include brews, equipment events, and manual inventory adjustments. Do not show automatic brew inventory adjustments as separate timeline entries.

## Local Development Intent

- Web server: prefer host port `3001`.
- PostgreSQL: prefer host port `5433` because another local project already owns `5432`.
- Docker Compose should run alongside other local projects without taking common host ports unnecessarily.
- The current Compose image is `postgres:17.5`, chosen because it is already available locally and avoids blocking setup on a Docker image pull.
