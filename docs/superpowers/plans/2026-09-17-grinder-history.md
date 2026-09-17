# Grinder History Implementation Plan

> **For agentic workers:** Use exodos-dev:subagent-driven-development for delegated tasks and test-driven development for each behavior. The user approved the design and implementation; proceed without further execution-choice prompts.

**Goal:** Correct latest grinder references, inherit history across bean bags, and replace the warning wall with the approved layout A.

**Architecture:** Workspace-owned CoffeeHistory groups link bags; saved Brews remain the source of settings. Bounded PostgreSQL queries produce references and top-three setting counts, embedded in the form so bean/grinder changes are immediate and cannot race a network response.

**Tech Stack:** Rails 8.1, PostgreSQL 17, Stimulus, existing Tailwind tokens and Elms Sans. No new dependencies.

## Global Constraints

- Work on `main`, preserve unrelated changes, and use `current_workspace` for controller access.
- Latest means nonblank setting ordered by occurrence time, creation time, and ID; ratings never filter references.
- Histories are scoped to workspace, selected grinder, brew method, and compatible bean grind state.
- Prefer the selected bag's history; only fall back to linked bags when it has none for that grinder/method.
- No automatic input overwrite, no synthetic Brews, no public history exposure.
- Duplicates inherit; name matches offer an explicit choice; inventory and existing per-bag analytics remain unchanged.
- Use `POSTGRES_PORT=55433 PARALLEL_WORKERS=1` locally. Concurrent test runs require separate test database names.
- Complete migration, backward-compatible backup/restore, authorization, behavioral tests, visual review, docs, and server restart.

## Task 1: Persist and preserve coffee history groups

**Files:** `app/models/coffee_history.rb`, `app/models/bean.rb`, `app/models/workspace.rb`, new migration, `db/schema.rb`, fixtures, `app/services/workspace_export_builder.rb`, `app/services/instance_backup_restorer.rb`, backup validation as needed, model/migration/export/restore tests.

**Interface:** CoffeeHistory belongs to Workspace, has many Beans; table stores workspace reference and timestamps. Bean belongs to CoffeeHistory and creates an independent group when absent. Duplication copies `coffee_history`. Validate workspace consistency. Workspace owns group cleanup after bags.

- [x] Add failing tests for independent groups, duplicate-chain inheritance, foreign-workspace rejection, and surviving links after source deletion.
- [x] Add the schema and deterministic per-workspace backfill of existing duplicate connected components. Broken/foreign ancestry does not join workspaces; cycles terminate. Existing identical names remain separate.
- [x] Implement associations and default history creation without creating records for invalid Beans.
- [x] Export `coffee_histories: [{id, created_at, updated_at}]` and `beans[].coffee_history_id`; restore groups with workspace-scoped ID remapping. New exports are authoritative; malformed or foreign references fail closed. Legacy archives without group fields reconstruct duplicate families after source links restore.
- [x] Add round-trip, old-archive, source-deletion, malformed-reference, and workspace-deletion tests; migrate development/test databases and run focused tests.
- [x] Review and commit this coherent persistence/portability change.

## Task 2: Correct and aggregate grinder references

**Files:** `app/services/brew_grinder_reminder.rb`, `test/services/brew_grinder_reminder_test.rb`.

**Interface:** Existing initializer `workspace:, user:, method:, beans:` remains. Result exposes `last_bean`, `last_bean_id`, `previous`, and `histories_for(bean)` (Hash keyed by grinder ID strings). Each History exposes `reference`, `settings` (`[{setting:, count:}]`), `brew_count`, `bag_count`, `inherited`; Reference exposes `brew`, `bean`, `grinder`, `grind_setting`, `display_parts` and `comparison_key`.

- [x] Convert the reproduced failures into permanent tests: older high-rated reference loses to latest, unrated first setting is found, new duplicate inherits.
- [x] Cover blanks, tie-breaking, other users, grinder/method/workspace/grind-state isolation, own-bag priority, corrected/deleted brews, and empty history.
- [x] Replace rated lookup with bounded latest-per-bag/grinder and latest-per-group/grinder queries. Restrict every query to the active workspace and only the requested history groups.
- [x] Aggregate normalized settings by group/grinder in SQL, choose three by count then latest use, and report total recorded brews and contributing bag count. Preserve original setting text for copying.
- [x] Resolve own-bag-first fallback in memory from bounded query results, never load all Brew records. Keep green last-used marker/operator baseline behavior.
- [x] Verify exact top-three counts and bounded query behavior with multiple bags and settings.

## Task 3: Explicitly link matching bags

**Files:** `app/controllers/beans_controller.rb`, new history-choice service if useful, `config/routes.rb`, `app/services/activity/event_contract.rb` and safe metadata builders as needed, focused controller tests.

**Interface:** GET `coffee_history_suggestions_beans_path` accepts `name`, `roaster_name`, optional `bean_id`, returns `{suggestions: [{id, label, bag_count}]}`. Suggestions are distinct local groups matching normalized nonblank roaster and name. `bean[coffee_history_choice]` accepts blank (keep existing/new separate), `separate` (new group), or a local group ID.

- [x] Add failing tests for explicit opt-in, edit linking/separation, same-name distinct groups, invalid/foreign/scalar IDs, viewers, and validation redisplay.
- [x] Resolve choices through `current_workspace.coffee_histories`, never mass-assign a raw submitted history ID. Do not merge groups globally; move only the saved bag's membership.
- [x] Expose normalized local suggestions, labels distinguishing group/bag dates and grind state, and current sharing state. Guard stale async suggestion responses on the client.
- [x] Record the changed link in the existing Bean activity event contract. Invalid saves create no orphan history rows.

## Task 4: Implement approved frontend

**Files:** Brew form/selector/grinder-field partials, Bean form/history partial, helper payload serialization, reminder and history-choice Stimulus controllers, translation files, controller tests, JavaScript behavior tests, existing draft-reminder system tests.

**Interfaces:** Consume Task 2 Result/History and Task 3 endpoint/choice. Embed data for all relevant grinder/bean combinations; no new reminder endpoint. Expose grinder radios as Stimulus targets with change actions. Keep server-rendered labels and user date formatting.

- [x] Write behavioral regressions for bean/grinder switching, latest references, inherited sources, explicit copy, hidden fields, Quick Drip/pre-ground, and restored drafts.
- [x] Build layout A using project fonts/tokens: context, previous brew row, highlighted latest setting/source, copy button, then accessible top-three horizontal bars/counts. Keep latest visible after applying; show a pending-check badge only when relevant.
- [x] Render no-history states without chart/button and no-grinder states without applying a setting from another grinder. Escape all display text; no untrusted HTML injection.
- [x] Add a compact Share grinder history choice beneath bean identity. Preserve current link on edit, offer separate history, and populate matching-group options without auto-selecting a new group.
- [x] Keep existing operator marker/defaults, recipe/repeat values, and draft field behavior. Add behavioral JS tests in place of implementation-string assertions.
- [x] Perform frontend evaluation at mobile/desktop widths, light/dark themes, long names, empty/fallback/many-settings states, and keyboard focus. Address findings.

## Task 5: Final verification and delivery

- [x] Update `docs/coffee-core.md`, `docs/workspace-export.md`, `docs/backup-system.md`, `docs/status.md`, and add a focused grinder-history document linked from docs/README.md.
- [x] Run focused tests then `env POSTGRES_PORT=55433 PARALLEL_WORKERS=1 bin/rails test`, `node --test test/javascript/*.mjs`, `bin/rubocop`, `bin/bundler-audit check`, `bin/importmap audit`, and Brakeman.
- [x] Verify production assets/build and independent code review; fix actionable findings and rerun covering tests.
- [x] Commit verified changes. Restart `bin/dev` through `roastnode-dev` tmux on port 3001 with LAN DNS access and verify health/login pages.

## Progress

- Approved design: `docs/superpowers/specs/2026-09-17-grinder-history-design.md`.
- Previous isolated diagnosis: three expected regression failures; no app behavior changed before approval.
- API documentation: official Rails association/migration guides and Stimulus target/action references checked; Context7 unavailable in this session.

## Completion — 2026-09-17

- Implemented latest same-grinder references, SQL top-three counts, persistent groups, explicit matching-bag linking, and the approved layout A.
- Full Rails suite: 1,480 tests / 14,975 assertions; JavaScript: 14 tests; focused browser suite: 5 tests / 56 assertions. All passed.
- RuboCop: 406 files clean. Fresh RubySec and Importmap audits: no vulnerabilities. Brakeman: no warnings. Test seeds and production asset compilation passed.
- Independent storage/backend/frontend and final code reviews approved. Live visual evaluation passed at 375/768/1200/1440px in both themes; all three final polish findings resolved. German singular/plural copy verified through Rails I18n rendering.
- Legacy archive regressions cover reversed duplicate chains and cycles. Public snapshot regression confirms linked history does not broaden public data.
- Development server restarted in `roastnode-dev` on port3001, bound to all interfaces. Local health, LAN DNS login, and stylesheet checks returned200. Temporary QA workspace/account removed.
- Work committed locally on main; no push, release tag, or deployment performed.
