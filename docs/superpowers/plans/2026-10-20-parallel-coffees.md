# Parallel coffees implementation plan

**Goal:** Implement the approved two-coffee espresso workflow, upgrade dependencies, release and deploy.
**Architecture:** Keep the existing Rails forms and Stimulus controllers. An additional session controller manages two independent form DOM trees and browser drafts. A separate grinder-use model/controller records confirmed grinding before Brew save. Server save tokens make retries inventory safe.

## Global constraints

- Work on main; no branches or worktrees. Protect unrelated local edits.
- Two active espresso coffees, stable numbering, one tap switching, mobile at 375px.
- Exact grinder strings such as `1/2,50`; grinding order is independent of save order.
- Workspace writers only; query all references through current_workspace.
- Drafts survive validation/network errors and clear only on successful save.
- No raw media URLs, credentials or private content in public snapshots or logs.
- User approved release and deployment without further confirmation.

## Task 1: Confirmed grinder uses and chronology

Create `GrinderUse`, a migration, `GrinderUsesController`, route and tests. Store workspace, user, bean, grinder, brew method, exact grind setting and unique client confirmation UUID. Server assigns occurrence time once; retrying the same confirmation returns the same use without changing time or accepting changed content. Expose the confirmation ID/time and current grinder reference as authenticated no-store JSON. No inventory changes.

Add nullable Brew `ground_at` and private-export/backup support. Extend `BrewGrinderReminder` and `BrewsHelper` so physical-use references consider confirmed uses and saved Brew grinding/occurrence times, retaining existing bean-specific history semantics. Define a `GrinderUse#matches_brew?(brew)` helper for controller integration: same workspace, user, bean, grinder, method and exact setting. Workspace/User/Bean/Equipment deletion and backup restore must retain their established safety contracts. Do not edit `BrewsController`; the primary agent owns save integration.

Write failing isolation, role, exact-text, confirmation-retry and out-of-order-save tests first. Run focused Rails tests with `PARALLEL_WORKERS=1` and report commands/results. Private export/backup round trips must cover the new fields and reject foreign references.

## Task 2: Mobile parallel drafts and save integration

Modify `app/views/brews/new.html.erb`, `_form.html.erb`, espresso sections, translations and `BrewsController`. Create `brew_session_controller.js` and pure session-state helpers with Node tests. Two independent forms preserve file inputs and existing controllers; clone server-rendered markup with unique IDs before connection. Sticky buttons select each form and freely select Prepare/Extract/Taste. Show only selected stage while keeping all form controls submitted. Group setup with Prepare and optional notes/sharing with Taste. Confirm preparation through Task 1's endpoint using a UUID; on success retain confirmation ID and move to Extract. Failure stays visible and does not advance.

Use per-draft UUID save tokens, scoped uniquely to workspace/user at the database, and a scoped confirmation ID. The server validates confirmation ownership and exact Brew context, stores `ground_at`, and returns Turbo-compatible success JSON when requested by the session controller. JSON contains the saved Brew URL only; validation keeps submitted values. JS submits each form via FormData/fetch, preserves controls on failure, and removes only the acknowledged coffee. If another remains, select it; otherwise visit the saved Brew. Persist an explicit structured session with both drafts, metadata and active selection, and migrate the old single draft. New coffee takes curated setup defaults and fresh grinder state. Current normal/Quick Drip and edit behavior remain available. Cover state transitions, failed saves, retries, stale confirmations, file selections, recipe/repeat state and 375px overflow in focused and browser tests.

## Task 3: Dependency upgrades

Independently inventory Gemfile/lockfile, importmap/vendor JavaScript, Ruby/runtime and workflow tool pins. Query current official package metadata and release notes, upgrade to current stable versions, preserve immutable action pins and document unavoidable compatibility limits. Use the installed runtime when viable and align Docker/CI/setup docs. Never migrate an existing PostgreSQL major/data volume merely as a package update. Own dependency/config/setup files only; do not edit feature files or shared feature docs. Run bundle consistency, outdated checks and dependency audits and report exact version changes.

## Task 4: Integration, review and release

Update coffee-core, grinder-history, draft-recovery, status and README documentation. Run focused tests, full Rails suite, all JavaScript/browser tests, RuboCop, Brakeman and both audits. Request independent code review of the full change and fix material findings. Check production asset compilation. Commit tested units; push main and wait for Gitea CI. Announce public changelog, annotate next patch tag, push it and confirm identical GitHub tag. Verify published digest, both image architectures, signatures and attestations. Record verification evidence.

## Task 5: Deploy from santiago

Read ActinoideAsCode guidance and operational docs, confirm SSH connectivity and backup validity without exposing secrets. Wait for the release workflow's pinned-image update, pull on santiago, syntax-check and run `ansible-playbook local.yml --limit roastnode --tags roastnode`. Verify recap including rescued count, exact web/jobs image, public health, app version, queue heartbeat, migrated database and a new validated full backup. Commit/push deployment notes in the infrastructure repo. Restart local `roastnode-dev` through tmux on all interfaces and verify LAN DNS health.

## Progress

- Design approved in conversation; implementation authorized without further gates.
- Initial checkout clean on main at 59d2e77; latest local tag v0.9.31.
