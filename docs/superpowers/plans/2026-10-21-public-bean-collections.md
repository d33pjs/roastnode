# Grouped Public Bean Collections Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use exodos-dev:subagent-driven-development or exodos-dev:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** Ship grouped public coffee rankings with deliberate per-bag publishing and deploy the approved release.

**Architecture:** A workspace singleton PublicBeanCollection stores settings, selection IDs, representative share IDs and a curated snapshot. PublicBeanShare snapshots provide approved bag content; CoffeeHistory supplies grouping. Transactional share callbacks refresh collections; public source authorization fails closed on stale snapshots.

**Tech Stack:** Existing Rails 8.1, PostgreSQL, ERB, Tailwind, Hotwire; no new dependencies.

## Global Constraints

- Work on main without branches/worktrees; protect existing edits.
- Workspace is the ownership/authorization boundary. Use ApplicationController workspace helpers.
- Public display uses curated stored snapshots and existing opaque public bean media paths.
- Private purchase price stays private; separate deliberately entered public price is allowed.
- Duplicate/history linking groups coffees without combining private bag inventory.
- Disabled/protected/deleted shares and revoked photos must not leak through stale collection snapshots.
- Release changelog approval precedes annotated tag creation and production deployment.

### Task 1: Collection data, ranking and publishing authorization

Files: migration, app/models/public_bean_collection.rb, app/services/public_bean_collection_snapshot_builder.rb, app/controllers/public_bean_collections_controller.rb, app/controllers/public_bean_collection_pages_controller.rb, test/models/public_bean_collection_test.rb, test/services/public_bean_collection_snapshot_builder_test.rb, test/controllers/public_bean_collections_controller_test.rb.

- [x] Write failing tests for group aggregation, distinct 250/1000/1000g bags, weighted brew mean, selected/automatic exclusions, public prices, snapshot privacy, role/isolation guards and source revocation.
- [x] Run `PATH="$HOME/.rbenv/versions/4.0.7/bin:$PATH" bin/rails test test/models/public_bean_collection_test.rb test/services/public_bean_collection_snapshot_builder_test.rb test/controllers/public_bean_collections_controller_test.rb`; confirm missing feature failures.
- [x] Add collection table (unique workspace, token/digest, title/description, enabled, mode, selected/excluded/representative share ID arrays, snapshot). Add separate nullable public price columns to PublicBeanShare.
- [x] Implement snapshot aggregation from eligible public bag snapshots, stable opaque group keys, public media paths and enabled/unprotected brew links. Implement owner/admin singleton editor, explicit bulk publish, preview and unlisted public Top 10/All routes. Connect source share save/destroy refresh and log filtering. Expose own rating/public price in existing bean snapshot.
- [x] Run targeted tests until green, inspect privacy output and commit tested backend.

### Task 2: Application design and bag linking

Files: app/views/public_bean_collections/, app/views/public_bean_collection_pages/, app/helpers/public_bean_collections_helper.rb, config/locales/bean_collections.*.yml, beans/workspace navigation, bag linking controller/form.

Interfaces: editor receives @collection, @available_shares, @publishable_beans; collection attributes mode selected/automatic, selected_share_ids[], excluded_share_ids[], representative_share_ids[]. Preview/public receives @snapshot and @collection. Snapshot contract is in tmp/bean-collection-design/brief.md. Routes edit_public_bean_collection_path, public_bean_collection_path (PATCH), preview_public_bean_collection_path, public_bean_collection_page_path(token:, view:).

- [x] Delegate real Rails application pages to the frontend design implementer with the brief and existing design docs.
- [x] Add workspace-safe Link bag / Separate bag to bean details, selecting any existing same-workspace coffee group with clear grinder-history notice. Write and run authorization/isolation and refreshed grouping tests first.
- [x] Add explicit public price fields to bean-share editor, including comma-friendly parsing and server validation, with request tests.
- [x] Run focused tests and Tailwind build. Evaluate actual desktop/mobile page screenshots independently; fix reported issues.
- [x] Commit tested interface and linking behavior.

### Task 3: Integration, documentation, review and delivery

- [x] Add collection selection/public-price data to private workspace export and document readable restore limitations consistently with existing permanent shares.
- [x] Update AGENTS.md, docs map/status and public sharing/grouping/export documentation.
- [x] Run full Rails/JS suites, RuboCop, Brakeman, audits and system/browser checks. Resolve failures and independent security/correctness review findings.
- [x] Start bin/dev through roastnode-dev tmux on 0.0.0.0:3001 with LAN DNS permitted, verify local/LAN health.
- [x] Commit and push main; confirm Gitea CI and GitHub mirror. Present exact changelog since latest tag for user approval.
- [x] After approval, create/push annotated next patch tag; verify mirror, release workflow, assets and image signature/provenance.
- [x] Deploy digest-pinned image via SSH Santiago using existing Roastnode Ansible role. Verify production health/version/migrations/jobs and fresh backup. Record verified release and rollout.
