# Activity Audit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use exodos-dev:subagent-driven-development (recommended) or exodos-dev:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the inferred dashboard/activity feed with a durable, filterable, append-only `ActivityEvent` ledger that records every approved authenticated mutation and scheduled/system operation without storing or presenting secrets.

**Architecture:** Add one workspace-aware ledger table whose rows contain an allowlisted action, derived category/default visibility, optional actor and polymorphic subject, occurrence time, and a deliberately small safe snapshot. Explicit controller, service, and job transaction boundaries call one emitter; an authorization-aware relation powers both Dashboard Recent Activity and `/activity`, while one presenter and one shared card partial provide copy, links, restricted markers, and fail-closed Material-symbol icons. A single migration creates the ledger and truthfully seeds only reconstructable historical rows.

**Tech Stack:** Rails 8.1, Ruby 3.3, PostgreSQL 17, Active Record transactions/JSONB, Hotwire/ERB, Tailwind CSS, I18n, Minitest, Active Job/Solid Queue.

## Global Constraints

- `Workspace` remains the ownership and authorization boundary for every workspace-scoped event.
- Use a purpose-built append-only `ActivityEvent` ledger; add no generic model-versioning dependency and store no full record diffs.
- An event has a required workspace for workspace-scoped activity or no workspace for an instance-wide event, an optional actor, an allowlisted category/action, `occurred_at`, `workspace|workspace_admin|instance_admin` visibility, an optional polymorphic subject, and a small JSON metadata payload.
- Metadata may preserve only a safe actor label, deleted-subject display label, record kind, and action-specific numeric or short enumerated summary.
- Metadata must not contain passwords, password digests, invite/share/reset tokens, session identifiers, signed or private media URLs, raw attachment identifiers, original filenames, viewer IP addresses, full backup paths, environment variables, infrastructure secrets, unfiltered exception text, emails, private notes, costs, or raw record/database IDs.
- Events are immutable after creation. Corrections create another event; subject deletion retains the event and safe tombstone summary and removes its link.
- Create the event in the same database transaction as the successful mutation. A validation failure, authorization rejection, exception, or rollback creates no event.
- Every public-snapshot refresher directly caused by a mutation runs inside that same outer transaction; a refresher failure rolls back the domain row, inventory effects, refreshed snapshots, and all events together.
- Each focused mutation test asserts the exact multiset of newly inserted actions, not merely the presence of the expected action; `bean.used_up` is the only documented secondary action.
- Controllers and domain services select explicit actions. Do not add model callbacks that infer arbitrary field changes.
- A meaningful lifecycle action such as `bean.finished`, `public_brew_share.disabled`, or `passkey.second_factor_enabled` replaces a generic update for that same subject and operation.
- Brew, External Coffee, manual Inventory Adjustment, and Equipment Event creation uses the domain `occurred_at`; edits, transitions, sharing, security, export, and backup operations use commit time.
- Imports emit one current import-summary event; imported Brew rows may also keep their truthful historical occurrence events and must not be moved to import time.
- Backfill only existing Brews, External Coffees, manual Inventory Adjustments, Equipment Events, Recipes/Public Shares with authoritative creators, and completed Data Imports with a user and stored summary. Do not invent Bean, Equipment, Preparation Tool, workspace-setting, membership, edit, transition, or deleted history.
- `workspace` events are readable by owner/admin/member/viewer membership in the active workspace; `workspace_admin` events only by that workspace's owner/admin; `instance_admin` events only by instance admins and only when `workspace_id` is null.
- Instance-admin status does not grant access to another role's `workspace_admin` events; it only adds authorized instance-wide rows to the active-workspace result.
- Dashboard Recent Activity and `/activity` must use the same query and shared card partial.
- `/activity` filters are exactly `category`, `actor`, `start_date`, and `end_date`; start/end dates are inclusive in the signed-in user's configured timezone and pagination preserves all active parameters.
- Actor options come only from the already-authorized event relation, include current and former actors plus `System` when present, and use snapshotted `User#display_label` values, never email.
- Quick Drip copy says `Quick Drip`, not Espresso. External Coffee copy stays distinct. Unknown actions render neutral copy/icon, no subject link, and no category guess.
- Anonymous public Brew/Bean/Recipe page views and public media reads remain only in existing share analytics and never create `ActivityEvent` rows.
- Parent create/update events cover nested public/private record-link and upload changes; standalone crop/primary/remove actions emit one concise parent `*.media_updated` event and never include URL, attachment, or filename data.
- Remain on `main`, do not create a branch/worktree, protect unrelated changes, use `apply_patch` for edits, and commit after every completed task.


---

## Dependency And File Structure

No external gem or JavaScript dependency is added.

**Ledger and contract**

- Create: `db/migrate/20260821120000_create_activity_events.rb` — table, constraints, indexes, and reconstructable historical seed in one deployment migration.
- Modify: `db/schema.rb` — generated schema after migration.
- Create: `app/models/activity_event.rb` — associations, validation, append-only behavior, and authorized ordering scopes.
- Modify: `app/models/workspace.rb` — `activity_events` association; database cascade owns workspace deletion.
- Modify: `app/models/user.rb` — actor association without Rails-side nullification writes.
- Create: `test/fixtures/activity_events.yml` — ordinary, restricted, instance, system, Quick Drip, and tombstone examples.
- Create: `test/models/activity_event_test.rb` — contract, immutability, deletion, metadata, and database-scope coverage.
- Create: `test/migrations/create_activity_events_test.rb` — precise historical inclusion/exclusion, time/actor reconstruction, and negative secret assertions.
- Create: `app/services/activity/event_contract.rb` — sole action/category/visibility/icon/summary/detail-key registry.
- Create: `app/services/activity/metadata.rb` — safe actor/subject snapshot and flat detail sanitizer.
- Create: `app/services/activity/emitter.rb` — exact emission API and scope checks.
- Modify: `app/controllers/application_controller.rb` — reusable same-transaction workspace/account emission wrappers.
- Create: `test/services/activity/emitter_test.rb` — derivation, redaction, mismatch, system actor, and rollback tests.
- Create: `test/test_helpers/activity_event_test_helper.rb` — focused integration assertion helper.
- Modify: `test/test_helper.rb` — load/include the activity helper.

**Query and presentation**

- Create: `app/services/activity/query.rb` — active-workspace authorization, actor options, filters, and stable ordering.
- Create: `test/services/activity/query_test.rb` — isolation, roles, instance admin, actor/date/category/combined filters.
- Create: `app/presenters/activity/presenter.rb` — safe copy, actor snapshot, category color, icon, restricted state, and authorized subject paths.
- Create: `test/presenters/activity/presenter_test.rb` — Quick Drip/External copy, tombstones, unknown action, icons, and link authorization.
- Modify: `app/helpers/application_helper.rb` — missing self-hosted Material-symbol SVG paths used by activity.
- Create: `app/views/activity/_event.html.erb` — the only activity-row markup used by dashboard/history.
- Modify: `app/controllers/activity_controller.rb` — validated filter/query/pagination setup.
- Modify: `app/controllers/home_controller.rb` — the same authorized relation with `limit(8)`.
- Modify: `app/views/activity/index.html.erb` — filter form, shared rows, filtered empty state, preserved pagination.
- Modify: `app/views/workspaces/show.html.erb` — replace type branches with the shared partial.
- Modify: `config/locales/en.yml` — categories, filters, summaries, markers, and empty states.
- Replace: `test/services/workspace_activity_feed_test.rb` with query coverage, then delete `app/services/workspace_activity_feed.rb` after both consumers move.
- Modify: `test/controllers/activity_controller_test.rb` — full-page authorization/filter/pagination/privacy assertions.
- Modify: `test/controllers/home_controller_test.rb` — dashboard/full-page parity and restricted-row absence.

**Explicit mutation emitters**

- Modify: `app/controllers/brews_controller.rb`, `test/controllers/brews_controller_test.rb` — Brew create/correct/taste/serving/delete.
- Modify: `app/controllers/external_coffees_controller.rb`, `test/controllers/external_coffees_controller_test.rb` — External Coffee create/edit/delete.
- Modify: `app/controllers/beans_controller.rb`, `test/controllers/beans_controller_test.rb` — Bean create/edit/lifecycle/duplicate/delete.
- Modify: `app/controllers/inventory_adjustments_controller.rb`, `test/controllers/inventory_adjustments_controller_test.rb` — manual adjustment.
- Modify: `app/controllers/equipment_controller.rb`, `test/controllers/equipment_controller_test.rb` — Equipment create/edit/archive/reopen/delete.
- Modify: `app/controllers/preparation_tools_controller.rb`, `test/controllers/preparation_tools_controller_test.rb` — Preparation Tool create/edit/archive/reopen/delete.
- Modify: `app/controllers/equipment_events_controller.rb`, `test/controllers/equipment_events_controller_test.rb` — maintenance create/edit/delete.
- Modify: `app/controllers/media_attachments_controller.rb`, `test/controllers/media_attachments_controller_test.rb` — crop/primary/remove as parent updates.
- Modify: `app/controllers/recipes_controller.rb`, `test/controllers/recipes_controller_test.rb` — Recipe create/edit/import/export/delete.
- Modify: `app/controllers/public_brew_shares_controller.rb`, `test/controllers/public_brew_shares_controller_test.rb` — create/publish/edit/disable/delete.
- Modify: `app/controllers/public_bean_shares_controller.rb`, `test/controllers/public_bean_shares_controller_test.rb` — create/publish/edit/disable/delete.
- Modify: `app/controllers/public_recipe_shares_controller.rb`, `test/controllers/public_recipe_shares_controller_test.rb` — create/publish/edit/disable/delete.
- Modify: `test/controllers/public_brew_pages_controller_test.rb`, `test/controllers/public_bean_pages_controller_test.rb`, `test/controllers/public_recipe_pages_controller_test.rb` — prove anonymous views create no ledger rows.
- Modify: `app/controllers/workspace_onboardings_controller.rb`, `test/controllers/workspace_onboardings_controller_test.rb` — workspace creation.
- Modify: `app/controllers/workspaces_controller.rb`, `test/controllers/workspaces_controller_test.rb` — settings/media/ownership/deletion.
- Modify: `app/services/workspace_membership_manager.rb`, `test/services/workspace_membership_manager_test.rb` — role/remove/ownership transactions.
- Modify: `app/controllers/workspace_invites_controller.rb`, `test/controllers/workspace_invites_controller_test.rb` — create/accept/revoke/resend/reinvite.
- Modify: `app/controllers/household_invites_controller.rb`, `test/controllers/household_invites_controller_test.rb` — accepted instance invite/new workspace.
- Modify: `app/controllers/instance_admin/household_invites_controller.rb`, `test/controllers/instance_admin_household_invites_controller_test.rb` — instance invite management.
- Modify: `app/controllers/profiles_controller.rb`, `test/controllers/profiles_controller_test.rb` — profile/security-safe update.
- Modify: `app/controllers/password_changes_controller.rb`, `test/controllers/password_changes_controller_test.rb` — authenticated password change.
- Modify: `app/controllers/passwords_controller.rb`, `test/controllers/passwords_controller_test.rb` — completed reset only; request stays unlogged.
- Modify: `app/controllers/passkey_credentials_controller.rb`, `test/controllers/passkey_credentials_controller_test.rb` — add/rename/delete/second-factor transitions.
- Modify: `app/controllers/sessions_controller.rb`, `test/controllers/sessions_controller_test.rb` — successful password sign-in/sign-out only.
- Modify: `app/controllers/passkey_sessions_controller.rb`, `test/controllers/passkey_sessions_controller_test.rb` — successful passkey sign-in.
- Modify: `app/controllers/passkey_second_factors_controller.rb`, `test/controllers/passkey_second_factors_controller_test.rb` — successful password-plus-passkey sign-in.
- Modify: `app/controllers/first_user_setups_controller.rb`, `test/controllers/first_user_setups_controller_test.rb` — first instance admin creation.
- Modify: `app/services/beanconqueror_import.rb`, `test/services/beanconqueror_import_test.rb` — one summary plus truthful imported-Brew occurrence rows.
- Modify: `app/controllers/workspace_exports_controller.rb`, `test/controllers/workspace_exports_controller_test.rb` — successful JSON/CSV/media export kinds.
- Modify: `app/controllers/instance_admin/backup_profiles_controller.rb`, `test/controllers/instance_backup_profiles_controller_test.rb` — profile changes/manual queue.
- Modify: `app/models/instance_backup_profile.rb`, `test/models/instance_backup_profile_test.rb` — scheduled queue event and optional actor.
- Modify: `app/models/instance_backup_run.rb`, `test/jobs/instance_backup_jobs_test.rb` — succeeded/failed safe system events at the shared model boundary used by the job.

**Durability/export/docs**

- Create: `app/services/activity/export_serializer.rb`, `test/services/activity/export_serializer_test.rb` — one safe event payload shared by workspace/readable exports.
- Modify: `app/services/workspace_export_builder.rb`, `test/services/workspace_export_builder_test.rb` — workspace-owned ledger payload.
- Modify: `app/services/instance_readable_export_builder.rb`, `test/services/instance_backup_builders_test.rb` — workspace and instance event payloads without secret fields.
- Modify: `app/services/instance_backup_restorer.rb`, `test/services/instance_backup_restore_test.rb` — remap actor/workspace/known subjects and keep tombstones unlinked.
- Create: `docs/activity-audit.md`; modify `docs/README.md`, `docs/coffee-core.md`, `docs/equipment-events.md`, `docs/navigation.md`, `docs/workspace-core.md`, `docs/instance-admin.md`, `docs/backup-system.md`, and `docs/status.md` — durable ledger, visibility, filters, backup/restore, and shipped status.


---

## Canonical Event Registry

`Activity::EventContract` is the only source of truth. `category` and default `visibility` are never supplied ad hoc by callers. `occurred_at = domain` means the create/log action passes the saved record's occurrence timestamp; every other row uses transaction commit time.

### Coffee

| Action | Visibility | Time | Subject | Summary/icon |
|---|---|---|---|---|
| `brew.created` | `workspace` | domain | Brew | logged / `local_cafe` |
| `brew.updated` | `workspace` | commit | Brew | corrected / `edit` |
| `brew.taste_changed` | `workspace` | commit | Brew | taste changed / `local_cafe` |
| `brew.serving_changed` | `workspace` | commit | Brew | serving changed / `group` |
| `brew.deleted` | `workspace` | commit | deleted Brew tombstone | deleted / `delete` |
| `brew.media_updated` | `workspace` | commit | Brew | photos updated / `photo` |
| `external_coffee.created` | `workspace` | domain | ExternalCoffee | logged / `local_cafe` |
| `external_coffee.updated` | `workspace` | commit | ExternalCoffee | corrected / `edit` |
| `external_coffee.deleted` | `workspace` | commit | deleted ExternalCoffee tombstone | deleted / `delete` |
| `external_coffee.media_updated` | `workspace` | commit | ExternalCoffee | photos updated / `photo` |

### Beans & inventory

| Action | Visibility | Time | Subject | Summary/icon |
|---|---|---|---|---|
| `bean.created` | `workspace` | commit | Bean | created / `inventory_2` |
| `bean.updated` | `workspace` | commit | Bean | updated / `edit` |
| `bean.duplicated` | `workspace` | commit | new Bean | duplicated / `content_copy` |
| `bean.opened` | `workspace` | commit | Bean | opened / `inventory_2` |
| `bean.finished` | `workspace` | commit | Bean | finished / `check_circle` |
| `bean.used_up` | `workspace` | commit | Bean | used up / `check_circle` |
| `bean.archived` | `workspace` | commit | Bean | archived / `archive` |
| `bean.reopened` | `workspace` | commit | Bean | reopened / `refresh` |
| `bean.deleted` | `workspace` | commit | deleted Bean tombstone | deleted / `delete` |
| `bean.media_updated` | `workspace` | commit | Bean | photos updated / `photo` |
| `inventory_adjustment.created` | `workspace` | domain | InventoryAdjustment | signed grams adjusted / `scale` |

### Gear & maintenance

| Action | Visibility | Time | Subject | Summary/icon |
|---|---|---|---|---|
| `equipment.created` | `workspace` | commit | Equipment | created / `build` |
| `equipment.updated` | `workspace` | commit | Equipment | updated / `edit` |
| `equipment.archived` | `workspace` | commit | Equipment | archived / `archive` |
| `equipment.reopened` | `workspace` | commit | Equipment | reopened / `refresh` |
| `equipment.deleted` | `workspace` | commit | deleted Equipment tombstone | deleted / `delete` |
| `equipment.media_updated` | `workspace` | commit | Equipment | photos updated / `photo` |
| `preparation_tool.created` | `workspace` | commit | PreparationTool | created / `build` |
| `preparation_tool.updated` | `workspace` | commit | PreparationTool | updated / `edit` |
| `preparation_tool.archived` | `workspace` | commit | PreparationTool | archived / `archive` |
| `preparation_tool.reopened` | `workspace` | commit | PreparationTool | reopened / `refresh` |
| `preparation_tool.deleted` | `workspace` | commit | deleted PreparationTool tombstone | deleted / `delete` |
| `preparation_tool.media_updated` | `workspace` | commit | PreparationTool | photos updated / `photo` |
| `equipment_event.created` | `workspace` | domain | EquipmentEvent | maintenance logged / `build` |
| `equipment_event.updated` | `workspace` | commit | EquipmentEvent | maintenance corrected / `edit` |
| `equipment_event.deleted` | `workspace` | commit | deleted EquipmentEvent tombstone | deleted / `delete` |
| `equipment_event.media_updated` | `workspace` | commit | EquipmentEvent | photos updated / `photo` |

### Sharing & recipes

| Action | Visibility | Time | Subject | Summary/icon |
|---|---|---|---|---|
| `recipe.created` | `workspace` | commit | Recipe | created / `bookmark_add` |
| `recipe.imported` | `workspace` | commit | Recipe | imported / `upload_file` |
| `recipe.updated` | `workspace` | commit | Recipe | updated / `edit` |
| `recipe.exported` | `workspace` | commit | Recipe | exported / `file_download` |
| `recipe.deleted` | `workspace` | commit | deleted Recipe tombstone | deleted / `delete` |
| `recipe.media_updated` | `workspace` | commit | Recipe | photos updated / `photo` |
| `public_brew_share.created` | `workspace` | commit | PublicBrewShare | draft created / `ios_share` |
| `public_brew_share.published` | `workspace` | commit | PublicBrewShare | published / `public` |
| `public_brew_share.updated` | `workspace` | commit | PublicBrewShare | updated / `edit` |
| `public_brew_share.disabled` | `workspace` | commit | PublicBrewShare | disabled / `visibility_off` |
| `public_brew_share.deleted` | `workspace` | commit | deleted PublicBrewShare tombstone | deleted / `link_off` |
| `public_bean_share.created` | `workspace` | commit | PublicBeanShare | draft created / `ios_share` |
| `public_bean_share.published` | `workspace` | commit | PublicBeanShare | published / `public` |
| `public_bean_share.updated` | `workspace` | commit | PublicBeanShare | updated / `edit` |
| `public_bean_share.disabled` | `workspace` | commit | PublicBeanShare | disabled / `visibility_off` |
| `public_bean_share.deleted` | `workspace` | commit | deleted PublicBeanShare tombstone | deleted / `link_off` |
| `public_recipe_share.created` | `workspace` | commit | PublicRecipeShare | draft created / `ios_share` |
| `public_recipe_share.published` | `workspace` | commit | PublicRecipeShare | published / `public` |
| `public_recipe_share.updated` | `workspace` | commit | PublicRecipeShare | updated / `edit` |
| `public_recipe_share.disabled` | `workspace` | commit | PublicRecipeShare | disabled / `visibility_off` |
| `public_recipe_share.deleted` | `workspace` | commit | deleted PublicRecipeShare tombstone | deleted / `link_off` |

### Household administration

| Action | Visibility | Time | Subject | Summary/icon |
|---|---|---|---|---|
| `workspace.created` | `workspace_admin` | commit | Workspace | created / `group` |
| `workspace.updated` | `workspace_admin` | commit | Workspace | settings updated / `edit` |
| `workspace.media_updated` | `workspace_admin` | commit | Workspace | identity media updated / `photo` |
| `workspace.deleted` | `instance_admin` | commit | deleted Workspace tombstone | deleted / `delete` |
| `workspace_invite.created` | `workspace_admin` | commit | WorkspaceInvite | created / `group` |
| `workspace_invite.accepted` | `workspace_admin` | commit | WorkspaceInvite | accepted / `check_circle` |
| `workspace_invite.revoked` | `workspace_admin` | commit | WorkspaceInvite | revoked / `link_off` |
| `workspace_invite.resent` | `workspace_admin` | commit | WorkspaceInvite | resent / `ios_share` |
| `workspace_invite.reinvited` | `workspace_admin` | commit | new WorkspaceInvite | re-invited / `refresh` |
| `membership.role_changed` | `workspace_admin` | commit | Membership | role changed / `group` |
| `membership.removed` | `workspace_admin` | commit | deleted Membership tombstone | removed / `delete` |
| `membership.ownership_transferred` | `workspace_admin` | commit | new-owner Membership | ownership transferred / `group` |
| `household_invite.created` | `instance_admin` | commit | HouseholdInvite | created / `group` |
| `household_invite.accepted` | `workspace_admin` | commit | HouseholdInvite linked to new Workspace | accepted / `check_circle` |
| `household_invite.revoked` | `instance_admin` | commit | HouseholdInvite | revoked / `link_off` |
| `household_invite.resent` | `instance_admin` | commit | HouseholdInvite | resent / `ios_share` |
| `household_invite.reinvited` | `instance_admin` | commit | new HouseholdInvite | re-invited / `refresh` |

### System & security

| Action | Visibility | Time | Subject | Summary/icon |
|---|---|---|---|---|
| `profile.updated` | `workspace_admin` | commit | User | profile updated / `edit` |
| `profile.media_updated` | `workspace_admin` | commit | User | identity media updated / `photo` |
| `password.changed` | `workspace_admin` | commit | User | password changed / `key` |
| `password.reset` | `workspace_admin` | commit | User | password reset / `key` |
| `passkey.created` | `workspace_admin` | commit | PasskeyCredential | passkey added / `key` |
| `passkey.renamed` | `workspace_admin` | commit | PasskeyCredential | passkey renamed / `edit` |
| `passkey.deleted` | `workspace_admin` | commit | deleted PasskeyCredential tombstone | passkey removed / `delete` |
| `passkey.second_factor_enabled` | `workspace_admin` | commit | User | second factor enabled / `security` |
| `passkey.second_factor_disabled` | `workspace_admin` | commit | User | second factor disabled / `security` |
| `session.signed_in` | `workspace_admin` | commit | User | signed in / `login` |
| `session.signed_out` | `workspace_admin` | commit | User | signed out / `logout` |
| `data_import.completed` | `workspace_admin` | commit | DataImport | import completed / `upload_file` |
| `data_import.failed` | `workspace_admin` | commit | DataImport | import failed safely / `upload_file` |
| `workspace_export.generated` | `workspace_admin` | commit | Workspace | export generated / `file_download` |
| `instance_backup_profile.created` | `instance_admin` | commit | InstanceBackupProfile | created / `backup` |
| `instance_backup_profile.updated` | `instance_admin` | commit | InstanceBackupProfile | updated / `edit` |
| `instance_backup_run.queued` | `instance_admin` | commit | InstanceBackupRun | queued / `backup` |
| `instance_backup_run.succeeded` | `instance_admin` | commit | InstanceBackupRun | succeeded / `check_circle` |
| `instance_backup_run.failed` | `instance_admin` | commit | InstanceBackupRun | failed safely / `backup` |
| `instance.first_user_created` | `instance_admin` | commit | User | first admin created / `security` |

The registry deliberately has no actions for anonymous public page/media reads, password-reset requests, failed sign-ins, failed authorization, read-only health checks, dashboard/page visits, active-workspace navigation switches, share-view counters, automatic Brew inventory rows, background retention file deletion, or public snapshot refreshes. Those either are reads/analytics, would reveal account existence, are implementation side effects of a recorded parent action, or would create duplicate noise.


---

### Task 1: Create, Backfill, And Lock The Append-Only Ledger

**Files:**

- Create: `test/models/activity_event_test.rb`
- Create: `test/migrations/create_activity_events_test.rb`
- Create: `db/migrate/20260821120000_create_activity_events.rb`
- Create: `app/models/activity_event.rb`
- Create: `test/fixtures/activity_events.yml`
- Modify: `app/models/workspace.rb`
- Modify: `app/models/user.rb`
- Modify: `db/schema.rb` (generated)

**Interfaces:**

- Consumes: existing User/Workspace/domain rows and PostgreSQL JSONB.
- Produces: `ActivityEvent.recent -> ActiveRecord::Relation<ActivityEvent>` ordered by `occurred_at DESC, id DESC`.
- Produces persisted columns `workspace_id`, `actor_id`, `category`, `action`, `occurred_at`, `visibility`, `subject_type`, `subject_id`, `metadata`, `created_at`, `updated_at`.
- Database invariant: `instance_admin` requires `workspace_id IS NULL`; `workspace` and `workspace_admin` require `workspace_id IS NOT NULL`.
- Database invariant: polymorphic `subject_type` and `subject_id` are both null or both present.
- `ActivityEvent#readonly?` is true after insert; subject rows have no foreign key so tombstones survive.
- The self-contained backfill applies the same maximum lengths, array bounds, URL/email/path rejection, and secret-shaped text rejection as `Activity::Metadata` to every metadata scalar and array element before `insert_all!` bypasses model validation.

- [ ] **Step 1: Write the failing immutable-ledger model tests**

Create `test/models/activity_event_test.rb`:

~~~ruby
require "test_helper"

class ActivityEventTest < ActiveSupport::TestCase
  test "requires a scope category action occurrence visibility and JSON object metadata" do
    event = ActivityEvent.new(metadata: nil)

    assert_not event.valid?
    assert_includes event.errors[:category], "can't be blank"
    assert_includes event.errors[:action], "can't be blank"
    assert_includes event.errors[:occurred_at], "can't be blank"
    assert_includes event.errors[:visibility], "can't be blank"
    assert_includes event.errors[:metadata], "must be a JSON object"
  end

  test "requires workspace visibility rows to have a workspace" do
    event = ActivityEvent.new(
      actor: users(:one),
      category: "coffee",
      action: "brew.created",
      occurred_at: Time.current,
      visibility: "workspace",
      metadata: {}
    )

    assert_not event.valid?
    assert_includes event.errors[:workspace], "must be present for workspace activity"
  end

  test "requires instance events to have no workspace" do
    event = ActivityEvent.new(
      workspace: workspaces(:household),
      actor: users(:one),
      category: "system_security",
      action: "instance_backup_run.queued",
      occurred_at: Time.current,
      visibility: "instance_admin",
      metadata: {}
    )

    assert_not event.valid?
    assert_includes event.errors[:workspace], "must be blank for instance activity"
  end

  test "persisted events cannot be updated touched or destroyed" do
    event = activity_events(:morning_brew_created)

    assert_predicate event, :readonly?
    assert_raises(ActiveRecord::ReadOnlyRecord) { event.update!(action: "brew.updated") }
    assert_raises(ActiveRecord::ReadOnlyRecord) { event.touch }
    assert_raises(ActiveRecord::ReadOnlyRecord) { event.destroy! }
  end

  test "deleting a subject retains the event as a tombstone" do
    equipment = workspaces(:household).equipment.create!(name: "Temporary grinder", kind: "grinder")
    event = ActivityEvent.create!(
      workspace: workspaces(:household),
      actor: users(:one),
      category: "gear_maintenance",
      action: "equipment.deleted",
      occurred_at: Time.current,
      visibility: "workspace",
      subject: equipment,
      metadata: {
        "actor_kind" => "user",
        "actor_label" => "Jens",
        "record_kind" => "equipment",
        "subject_label" => "Temporary grinder"
      }
    )

    equipment.destroy!

    assert_equal event.id, ActivityEvent.find(event.id).id
    assert_nil event.reload.subject
    assert_equal "Temporary grinder", event.metadata.fetch("subject_label")
  end

  test "workspace deletion cascades its private history while an instance tombstone survives" do
    workspace = Workspace.create!(name: "Disposable household", default_currency: "EUR")
    scoped = ActivityEvent.create!(
      workspace:,
      actor: users(:one),
      category: "household_administration",
      action: "workspace.created",
      occurred_at: Time.current,
      visibility: "workspace_admin",
      subject: workspace,
      metadata: { "actor_kind" => "user", "actor_label" => "Jens", "record_kind" => "workspace", "subject_label" => workspace.name }
    )
    tombstone = ActivityEvent.create!(
      actor: users(:one),
      category: "household_administration",
      action: "workspace.deleted",
      occurred_at: Time.current,
      visibility: "instance_admin",
      subject: workspace,
      metadata: { "actor_kind" => "user", "actor_label" => "Jens", "record_kind" => "workspace", "subject_label" => workspace.name }
    )

    workspace.destroy!

    assert_not ActivityEvent.exists?(scoped.id)
    assert ActivityEvent.exists?(tombstone.id)
    assert_nil tombstone.reload.subject
  end

  test "recent uses occurrence time and id as stable descending order" do
    same_time = Time.zone.local(2026, 8, 21, 12, 0, 0)
    older_id = ActivityEvent.create!(
      workspace: workspaces(:household), actor: users(:one), category: "coffee", action: "brew.created",
      occurred_at: same_time, visibility: "workspace",
      metadata: { "actor_kind" => "user", "actor_label" => "Jens" }
    )
    newer_id = ActivityEvent.create!(
      workspace: workspaces(:household), actor: users(:one), category: "coffee", action: "brew.updated",
      occurred_at: same_time, visibility: "workspace",
      metadata: { "actor_kind" => "user", "actor_label" => "Jens" }
    )

    assert_equal [ newer_id, older_id ], ActivityEvent.where(id: [ older_id.id, newer_id.id ]).recent.to_a
  end
end
~~~

- [ ] **Step 2: Run the model test and verify the ledger does not exist**

Run:

~~~bash
bin/rails test test/models/activity_event_test.rb
~~~

Expected: ERROR with `uninitialized constant ActivityEvent`.

- [ ] **Step 3: Create the schema and truthful historical seed in the one reserved migration**

Create `db/migrate/20260821120000_create_activity_events.rb`. Keep the migration self-contained so a future deploy never depends on whatever the application models look like then:

~~~ruby
class CreateActivityEvents < ActiveRecord::Migration[8.1]
  MAX_TEXT = 160
  MAX_ARRAY = 10
  SENSITIVE = %r{https?://|rails/active_storage|[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}|(?:password|digest|token|secret|session|signed_id|attachment|filename|ip_address|file_path|error)\s*[:=]}i

  class ActivityRow < ActiveRecord::Base
    self.table_name = "activity_events"
  end

  class LegacyUser < ActiveRecord::Base
    self.table_name = "users"
  end

  class LegacyBean < ActiveRecord::Base
    self.table_name = "beans"
  end

  class LegacyBrew < ActiveRecord::Base
    self.table_name = "brews"
    belongs_to :user, class_name: "CreateActivityEvents::LegacyUser"
    belongs_to :bean, class_name: "CreateActivityEvents::LegacyBean"
  end

  class LegacyExternalCoffee < ActiveRecord::Base
    self.table_name = "external_coffees"
    belongs_to :user, class_name: "CreateActivityEvents::LegacyUser"
  end

  class LegacyInventoryAdjustment < ActiveRecord::Base
    self.table_name = "inventory_adjustments"
    belongs_to :user, class_name: "CreateActivityEvents::LegacyUser"
    belongs_to :bean, class_name: "CreateActivityEvents::LegacyBean"
  end

  class LegacyEquipment < ActiveRecord::Base
    self.table_name = "equipment"
  end

  class LegacyEquipmentEventItem < ActiveRecord::Base
    self.table_name = "equipment_event_items"
    belongs_to :equipment, class_name: "CreateActivityEvents::LegacyEquipment"
  end

  class LegacyEquipmentEvent < ActiveRecord::Base
    self.table_name = "equipment_events"
    belongs_to :user, class_name: "CreateActivityEvents::LegacyUser"
    has_many :items, class_name: "CreateActivityEvents::LegacyEquipmentEventItem", foreign_key: :equipment_event_id
    has_many :equipment, through: :items
  end

  class LegacyRecipe < ActiveRecord::Base
    self.table_name = "recipes"
    belongs_to :creator, class_name: "CreateActivityEvents::LegacyUser", foreign_key: :created_by_id
  end

  class LegacyPublicBrewShare < ActiveRecord::Base
    self.table_name = "public_brew_shares"
    belongs_to :creator, class_name: "CreateActivityEvents::LegacyUser", foreign_key: :created_by_id
  end

  class LegacyPublicBeanShare < ActiveRecord::Base
    self.table_name = "public_bean_shares"
    belongs_to :creator, class_name: "CreateActivityEvents::LegacyUser", foreign_key: :created_by_id
  end

  class LegacyPublicRecipeShare < ActiveRecord::Base
    self.table_name = "public_recipe_shares"
    belongs_to :creator, class_name: "CreateActivityEvents::LegacyUser", foreign_key: :created_by_id
  end

  class LegacyDataImport < ActiveRecord::Base
    self.table_name = "data_imports"
    belongs_to :user, class_name: "CreateActivityEvents::LegacyUser"
  end

  def up
    create_table :activity_events do |t|
      t.references :workspace, null: true, foreign_key: { on_delete: :cascade }
      t.references :actor, null: true, foreign_key: { to_table: :users, on_delete: :nullify }
      t.string :category, null: false
      t.string :action, null: false
      t.datetime :occurred_at, null: false
      t.string :visibility, null: false
      t.string :subject_type
      t.bigint :subject_id
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end

    add_index :activity_events, [ :workspace_id, :occurred_at, :id ], name: "idx_activity_workspace_time"
    add_index :activity_events, [ :workspace_id, :category, :occurred_at, :id ], name: "idx_activity_workspace_category_time"
    add_index :activity_events, [ :workspace_id, :actor_id, :occurred_at, :id ], name: "idx_activity_workspace_actor_time"
    add_index :activity_events, [ :visibility, :workspace_id, :occurred_at, :id ], name: "idx_activity_visibility_workspace_time"
    add_index :activity_events, [ :subject_type, :subject_id ], name: "idx_activity_subject"
    add_index :activity_events, [ :occurred_at, :id ], name: "idx_activity_instance_time", where: "workspace_id IS NULL"

    add_check_constraint :activity_events,
      "(visibility = 'instance_admin' AND workspace_id IS NULL) OR " \
        "(visibility IN ('workspace', 'workspace_admin') AND workspace_id IS NOT NULL)",
      name: "activity_events_visibility_scope"
    add_check_constraint :activity_events,
      "(subject_type IS NULL AND subject_id IS NULL) OR (subject_type IS NOT NULL AND subject_id IS NOT NULL)",
      name: "activity_events_subject_pair"

    ActivityRow.reset_column_information
    @migration_time = Time.current
    backfill_brews
    backfill_external_coffees
    backfill_manual_adjustments
    backfill_equipment_events
    backfill_recipes
    backfill_public_shares
    backfill_completed_imports
  end

  def down
    drop_table :activity_events
  end

  private
    attr_reader :migration_time

    def backfill_brews
      insert_each(LegacyBrew.includes(:user, :bean)) do |brew|
        event_row(
          workspace_id: brew.workspace_id,
          actor: brew.user,
          category: "coffee",
          action: "brew.created",
          occurred_at: brew.occurred_at,
          subject_type: "Brew",
          subject_id: brew.id,
          metadata: {
            "record_kind" => "brew",
            "subject_label" => "#{brew.method == "quick_drip" ? "Quick Drip" : "Espresso"} with #{brew.bean.name}",
            "method" => brew.method
          }
        )
      end
    end

    def backfill_external_coffees
      insert_each(LegacyExternalCoffee.includes(:user)) do |coffee|
        event_row(
          workspace_id: coffee.workspace_id,
          actor: coffee.user,
          category: "coffee",
          action: "external_coffee.created",
          occurred_at: coffee.occurred_at,
          subject_type: "ExternalCoffee",
          subject_id: coffee.id,
          metadata: { "record_kind" => "external_coffee", "subject_label" => safe_label(coffee.drink_type) }
        )
      end
    end

    def backfill_manual_adjustments
      insert_each(LegacyInventoryAdjustment.where(reason: "manual").includes(:user, :bean)) do |adjustment|
        event_row(
          workspace_id: adjustment.workspace_id,
          actor: adjustment.user,
          category: "beans_inventory",
          action: "inventory_adjustment.created",
          occurred_at: adjustment.occurred_at,
          subject_type: "InventoryAdjustment",
          subject_id: adjustment.id,
          metadata: {
            "record_kind" => "inventory_adjustment",
            "subject_label" => safe_label(adjustment.bean.name),
            "amount_grams" => adjustment.delta_grams.to_s("F")
          }
        )
      end
    end

    def backfill_equipment_events
      insert_each(LegacyEquipmentEvent.includes(:user, :equipment)) do |event|
        event_types = Array(event.event_types).presence || Array(event.event_type)
        equipment_labels = event.equipment.map { |item| safe_label(item.name) }.sort.first(10)
        event_row(
          workspace_id: event.workspace_id,
          actor: event.user,
          category: "gear_maintenance",
          action: "equipment_event.created",
          occurred_at: event.occurred_at,
          subject_type: "EquipmentEvent",
          subject_id: event.id,
          metadata: {
            "record_kind" => "equipment_event",
            "subject_label" => safe_label(event_types.map(&:humanize).to_sentence),
            "event_types" => event_types.first(10),
            "equipment_labels" => equipment_labels
          }
        )
      end
    end

    def backfill_recipes
      insert_each(LegacyRecipe.includes(:creator)) do |recipe|
        event_row(
          workspace_id: recipe.workspace_id,
          actor: recipe.creator,
          category: "sharing_recipes",
          action: "recipe.created",
          occurred_at: recipe.created_at,
          subject_type: "Recipe",
          subject_id: recipe.id,
          metadata: { "record_kind" => "recipe", "subject_label" => safe_label(recipe.title) }
        )
      end
    end

    def backfill_public_shares
      backfill_share(LegacyPublicBrewShare.includes(:creator), "public_brew_share", "PublicBrewShare")
      backfill_share(LegacyPublicBeanShare.includes(:creator), "public_bean_share", "PublicBeanShare")
      backfill_share(LegacyPublicRecipeShare.includes(:creator), "public_recipe_share", "PublicRecipeShare")
    end

    def backfill_share(scope, kind, subject_type)
      insert_each(scope) do |share|
        event_row(
          workspace_id: share.workspace_id,
          actor: share.creator,
          category: "sharing_recipes",
          action: "#{kind}.created",
          occurred_at: share.created_at,
          subject_type:,
          subject_id: share.id,
          metadata: {
            "record_kind" => kind,
            "subject_label" => safe_label(share.title.presence || kind.humanize),
            "enabled" => share.enabled
          }
        )
      end
    end

    def backfill_completed_imports
      scope = LegacyDataImport.where(status: "completed").where.not(summary: {})
      insert_each(scope.includes(:user)) do |data_import|
        summary = data_import.summary.to_h
        event_row(
          workspace_id: data_import.workspace_id,
          actor: data_import.user,
          category: "system_security",
          action: "data_import.completed",
          occurred_at: data_import.updated_at,
          visibility: "workspace_admin",
          subject_type: "DataImport",
          subject_id: data_import.id,
          metadata: {
            "record_kind" => "data_import",
            "subject_label" => safe_label("#{data_import.source.to_s.humanize} import"),
            "source" => data_import.source.to_s,
            "created_count" => summary_count(summary, "created"),
            "skipped_count" => summary_count(summary, "skipped")
          }
        )
      end
    end

    def summary_count(summary, key)
      summary.values.sum { |value| value.is_a?(Hash) ? value[key].to_i : 0 }
    end

    def insert_each(scope)
      rows = []
      scope.find_each do |record|
        rows << yield(record)
        if rows.size >= 500
          ActivityRow.insert_all!(rows)
          rows.clear
        end
      end
      ActivityRow.insert_all!(rows) if rows.any?
    end

    def event_row(workspace_id:, actor:, category:, action:, occurred_at:, subject_type:, subject_id:, metadata:, visibility: "workspace")
      {
        workspace_id:,
        actor_id: actor&.id,
        category:,
        action:,
        occurred_at:,
        visibility:,
        subject_type:,
        subject_id:,
        metadata: sanitized_metadata(actor_metadata(actor).merge(metadata)),
        created_at: migration_time,
        updated_at: migration_time
      }
    end

    def actor_metadata(actor)
      if actor
        { "actor_kind" => "user", "actor_label" => safe_label(actor.display_name.presence || "unknown username") }
      else
        { "actor_kind" => "system", "actor_label" => "System" }
      end
    end

    def sanitized_metadata(metadata)
      metadata.to_h.transform_values { |value| safe_value(value) }.compact
    end

    def safe_value(value)
      case value
      when String, Symbol then safe_label(value)
      when Numeric, TrueClass, FalseClass, NilClass then value
      when Array then value.first(MAX_ARRAY).map { |item| safe_label(item) }
      else "[redacted]"
      end
    end

    def safe_label(value)
      text = value.to_s.strip.squish
      return "[redacted]" if text.match?(SENSITIVE) || text.start_with?("/", "../")

      text.first(MAX_TEXT).presence || "Unknown"
    end
end
~~~

Compose labels from the raw legacy fields and sanitize the finished metadata value only in `event_row`; pre-sanitizing an embedded Bean name would turn a hostile label into `Espresso with [redacted]` and no longer match runtime whole-label redaction.

The historical Share action is deliberately `*.created` even when the current row is enabled: the migration can truthfully reconstruct creation, not the separate time at which it may have been published.

- [ ] **Step 4: Add the append-only model and associations**

Create `app/models/activity_event.rb`:

~~~ruby
class ActivityEvent < ApplicationRecord
  CATEGORIES = %w[
    coffee
    beans_inventory
    gear_maintenance
    sharing_recipes
    household_administration
    system_security
  ].freeze
  VISIBILITIES = %w[workspace workspace_admin instance_admin].freeze

  belongs_to :workspace, optional: true
  belongs_to :actor, class_name: "User", optional: true
  belongs_to :subject, polymorphic: true, optional: true

  validates :category, presence: true, inclusion: { in: CATEGORIES }
  validates :action, presence: true
  validates :occurred_at, presence: true
  validates :visibility, presence: true, inclusion: { in: VISIBILITIES }
  validate :metadata_is_a_hash
  validate :visibility_matches_workspace_scope

  scope :recent, -> { order(occurred_at: :desc, id: :desc) }

  def readonly?
    persisted?
  end

  private
    def metadata_is_a_hash
      errors.add(:metadata, "must be a JSON object") unless metadata.is_a?(Hash)
    end

    def visibility_matches_workspace_scope
      if visibility == "instance_admin"
        errors.add(:workspace, "must be blank for instance activity") if workspace_id.present?
      elsif visibility.present?
        errors.add(:workspace, "must be present for workspace activity") if workspace_id.blank?
      end
    end
end
~~~

Add to `Workspace` without `dependent:`; the database cascade avoids calling immutable model destroy hooks:

~~~ruby
has_many :activity_events
~~~

Add to `User`; the database foreign key owns actor nullification if account deletion is added later:

~~~ruby
has_many :activity_events, foreign_key: :actor_id, inverse_of: :actor
~~~

- [ ] **Step 5: Add deterministic ledger fixtures**

Create `test/fixtures/activity_events.yml`:

~~~yaml
morning_brew_created:
  workspace: household
  actor: one
  category: coffee
  action: brew.created
  occurred_at: 2026-06-01 08:00:00
  visibility: workspace
  subject: morning_espresso (Brew)
  metadata:
    actor_kind: user
    actor_label: Jens
    record_kind: brew
    subject_label: Espresso with House Espresso
    method: espresso

quick_drip_created:
  workspace: household
  actor: one
  category: coffee
  action: brew.created
  occurred_at: 2026-06-01 09:00:00
  visibility: workspace
  metadata:
    actor_kind: user
    actor_label: Jens
    record_kind: brew
    subject_label: Quick Drip with Filter Beans
    method: quick_drip

workspace_invite_created:
  workspace: household
  actor: one
  category: household_administration
  action: workspace_invite.created
  occurred_at: 2026-06-01 10:00:00
  visibility: workspace_admin
  metadata:
    actor_kind: user
    actor_label: Jens
    record_kind: workspace_invite
    subject_label: Member invite
    role: member

other_workspace_brew:
  workspace: other_household
  actor: two
  category: coffee
  action: brew.created
  occurred_at: 2026-06-01 11:00:00
  visibility: workspace
  subject: other_workspace_brew (Brew)
  metadata:
    actor_kind: user
    actor_label: Petra
    record_kind: brew
    subject_label: Espresso with Other Beans
    method: espresso

scheduled_backup_succeeded:
  category: system_security
  action: instance_backup_run.succeeded
  occurred_at: 2026-06-01 12:00:00
  visibility: instance_admin
  metadata:
    actor_kind: system
    actor_label: System
    record_kind: instance_backup_run
    subject_label: Full instance archive
    backup_kind: full_archive
    status: succeeded
~~~

- [ ] **Step 6: Write the failing historical migration coverage**

Create `test/migrations/create_activity_events_test.rb`:

~~~ruby
require "test_helper"
require Rails.root.join("db/migrate/20260821120000_create_activity_events")

class CreateActivityEventsTest < ActiveSupport::TestCase
  test "backfill includes only reconstructable rows with truthful actors and times" do
    recipe = recipes(:household_recipe)
    external_coffee = ExternalCoffee.create!(
      workspace: workspaces(:household), user: users(:one), drink_type: "Flat White",
      occurred_at: Time.zone.local(2026, 8, 20, 9)
    )
    manual_adjustment = InventoryAdjustment.create!(
      workspace: workspaces(:household), bean: beans(:open_household), user: users(:one),
      reason: "manual", delta_grams: 5, occurred_at: Time.zone.local(2026, 8, 20, 10)
    )
    brew_share = PublicBrewShare.create!(
      workspace: workspaces(:household), brew: brews(:morning_espresso), created_by: users(:two), updated_by: users(:two),
      title: "Historical brew share", enabled: true, snapshot: {},
      created_at: Time.zone.local(2026, 8, 20, 11), updated_at: Time.zone.local(2026, 8, 20, 11)
    )
    bean_share = PublicBeanShare.create!(
      workspace: workspaces(:household), bean: beans(:open_household), created_by: users(:two), updated_by: users(:two),
      title: "Historical bean share", enabled: false, snapshot: {},
      created_at: Time.zone.local(2026, 8, 20, 11, 15), updated_at: Time.zone.local(2026, 8, 20, 11, 15)
    )
    recipe_share = PublicRecipeShare.create!(
      workspace: workspaces(:household), recipe:, created_by: users(:two), updated_by: users(:two),
      title: "Historical recipe share", enabled: true, snapshot: {},
      created_at: Time.zone.local(2026, 8, 20, 11, 30), updated_at: Time.zone.local(2026, 8, 20, 11, 30)
    )
    completed_import = DataImport.create!(
      workspace: workspaces(:household),
      user: users(:one),
      source: "beanconqueror",
      status: "completed",
      summary: { "beans" => { "created" => 1, "skipped" => 2 }, "brews" => { "created" => 3, "skipped" => 4 } },
      created_at: Time.zone.local(2026, 8, 20, 12), updated_at: Time.zone.local(2026, 8, 20, 12, 30)
    )
    failed_import = DataImport.create!(
      workspace: workspaces(:household),
      user: users(:one),
      source: "beanconqueror",
      status: "failed",
      summary: { "beans" => { "created" => 0 } }
    )
    ActivityEvent.delete_all

    migration = CreateActivityEvents.new
    migration.instance_variable_set(:@migration_time, Time.zone.local(2026, 8, 21, 12))
    migration.send(:backfill_brews)
    migration.send(:backfill_external_coffees)
    migration.send(:backfill_manual_adjustments)
    migration.send(:backfill_equipment_events)
    migration.send(:backfill_recipes)
    migration.send(:backfill_public_shares)
    migration.send(:backfill_completed_imports)

    brew_event = assert_backfill(
      action: "brew.created", subject: brews(:morning_espresso), actor: users(:one),
      occurred_at: brews(:morning_espresso).occurred_at
    )
    assert_equal "Jens", brew_event.metadata.fetch("actor_label")
    assert_backfill(action: "external_coffee.created", subject: external_coffee, actor: users(:one), occurred_at: external_coffee.occurred_at)
    assert_backfill(action: "inventory_adjustment.created", subject: manual_adjustment, actor: users(:one), occurred_at: manual_adjustment.occurred_at)
    assert_backfill(
      action: "equipment_event.created", subject: equipment_events(:grinder_cleaning), actor: users(:one),
      occurred_at: equipment_events(:grinder_cleaning).occurred_at
    )
    assert_backfill(action: "recipe.created", subject: recipe, actor: recipe.created_by, occurred_at: recipe.created_at)
    assert_backfill(action: "public_brew_share.created", subject: brew_share, actor: users(:two), occurred_at: brew_share.created_at)
    assert_backfill(action: "public_bean_share.created", subject: bean_share, actor: users(:two), occurred_at: bean_share.created_at)
    assert_backfill(action: "public_recipe_share.created", subject: recipe_share, actor: users(:two), occurred_at: recipe_share.created_at)
    import_event = assert_backfill(
      action: "data_import.completed", subject: completed_import, actor: users(:one), occurred_at: completed_import.updated_at
    )
    assert_equal 4, import_event.metadata.fetch("created_count")
    assert_equal 6, import_event.metadata.fetch("skipped_count")
    assert_not ActivityEvent.exists?(
      subject_type: "InventoryAdjustment", subject_id: inventory_adjustments(:morning_espresso_consumption).id
    ), "reason:brew inventory rows are implementation details, not manual activity"
    assert_not ActivityEvent.exists?(subject_type: "DataImport", subject_id: failed_import.id)
  end

  test "backfill sanitizes every scalar and array element from hostile fixture-backed legacy rows" do
    user = users(:one)
    brew = brews(:morning_espresso)
    bean = brew.bean
    equipment = equipment(:household_grinder)
    maintenance = equipment_events(:grinder_cleaning)
    user.update_column(:display_name, "token=legacy-actor-secret")
    bean.update_column(:name, "https://private.example/bean")
    brew.update_column(:method, "file_path=/private/brew")
    equipment.update_column(:name, "filename=legacy-photo.jpg")
    maintenance.update_columns(event_type: "other", event_types: [ "error=database details", "/private/equipment" ])
    ActivityEvent.delete_all

    migration = CreateActivityEvents.new
    migration.instance_variable_set(:@migration_time, Time.current)
    migration.send(:backfill_brews)
    migration.send(:backfill_equipment_events)

    brew_metadata = ActivityEvent.find_by!(action: "brew.created", subject_id: brew.id).metadata
    assert_equal "[redacted]", brew_metadata.fetch("actor_label")
    assert_equal "[redacted]", brew_metadata.fetch("subject_label")
    assert_equal "[redacted]", brew_metadata.fetch("method")
    maintenance_metadata = ActivityEvent.find_by!(action: "equipment_event.created", subject_id: maintenance.id).metadata
    assert_equal [ "[redacted]", "[redacted]" ], maintenance_metadata.fetch("event_types")
    assert_includes maintenance_metadata.fetch("equipment_labels"), "[redacted]"
    assert_no_match(
      /legacy-actor-secret|private\.example|private\/brew|database details|private\/equipment|legacy-photo/i,
      ActivityEvent.pluck(:metadata).to_json
    )
  end

  test "backfill does not invent history and metadata contains no secrets" do
    ActivityEvent.delete_all
    migration = CreateActivityEvents.new
    migration.instance_variable_set(:@migration_time, Time.current)
    migration.send(:backfill_brews)
    migration.send(:backfill_external_coffees)
    migration.send(:backfill_manual_adjustments)
    migration.send(:backfill_equipment_events)
    migration.send(:backfill_recipes)
    migration.send(:backfill_public_shares)
    migration.send(:backfill_completed_imports)

    assert_not ActivityEvent.exists?(subject_type: "Bean")
    assert_not ActivityEvent.exists?(subject_type: "Equipment")
    assert_not ActivityEvent.exists?(subject_type: "PreparationTool")
    assert_not ActivityEvent.exists?(subject_type: "Membership")
    payload = ActivityEvent.pluck(:metadata).to_json
    assert_no_match(/@/, payload)
    assert_no_match(/password|digest|token|session|signed_id|attachment|filename|https?:\/\/|\/storage\//i, payload)
    assert_no_match(/Found extra beans|Private/i, payload)
  end

  private
    def assert_backfill(action:, subject:, actor:, occurred_at:)
      event = ActivityEvent.find_by!(action:, subject_type: subject.class.base_class.name, subject_id: subject.id)
      assert_equal actor, event.actor
      assert_equal occurred_at.to_i, event.occurred_at.to_i
      event
    end
end
~~~

- [ ] **Step 7: Run the migration and ledger suites**

Run:

~~~bash
bin/rails db:migrate
bin/rails test test/models/activity_event_test.rb test/migrations/create_activity_events_test.rb
~~~

Expected: migration succeeds and both test files PASS.

- [ ] **Step 8: Commit the ledger**

~~~bash
git add db/migrate/20260821120000_create_activity_events.rb db/schema.rb app/models/activity_event.rb app/models/workspace.rb app/models/user.rb test/fixtures/activity_events.yml test/models/activity_event_test.rb test/migrations/create_activity_events_test.rb
git commit -m "Add append-only activity event ledger"
~~~


---

### Task 2: Centralize The Action Contract, Safe Snapshots, And Transaction Wrapper

**Files:**

- Create: `test/services/activity/emitter_test.rb`
- Create: `app/services/activity/event_contract.rb`
- Create: `app/services/activity/metadata.rb`
- Create: `app/services/activity/emitter.rb`
- Modify: `app/models/activity_event.rb`
- Modify: `app/controllers/application_controller.rb`
- Create: `test/test_helpers/activity_event_test_helper.rb`
- Modify: `test/test_helper.rb`

**Interfaces:**

- `Activity::Emitter.record!(action:, workspace:, actor: nil, subject: nil, occurred_at: Time.current, visibility: nil, details: {}) -> ActivityEvent`.
- Category, normal visibility, expected subject type, icon, summary key, caller detail keys, and per-action automatic metadata keys come from `Activity::EventContract.fetch(action)`; there is no global automatic-key allowlist.
- `ActivityEvent` mirrors the contract for direct writes and restore: category must equal the action category, visibility must be permitted for the action, and any resolved subject must have the expected type and compatible workspace; a nil subject remains a valid tombstone.
- Direct-write/restore validation calls `Activity::Metadata.unsafe_text?` for every scalar and array element, rejects leading `/` or `../`, and applies `MAX_TEXT = 160` to every string element as well as `MAX_ARRAY = 10` to arrays.
- `visibility:` may override only an action whose registry explicitly permits both workspace and instance placement; current callers need this only for account events without an active workspace.
- `Activity::Metadata.build(action:, actor:, subject:, details:) -> Hash<String, JSON scalar | Array<String>>`.
- Both caller details and action-allowlisted automatic details pass through `safe_value`; subject-derived arrays such as equipment labels never bypass redaction, length, or array-count limits.
- `with_workspace_activity(action:, subject:, occurred_at: nil, details: {}, visibility: nil) { mutation } -> mutation result | false` records only a truthy mutation result in the same transaction.
- `with_account_activity(action:, user:, subject: user, details: {}) { mutation }` uses `user.active_workspace`/`workspace_admin`, otherwise nil workspace/`instance_admin`.
- `assert_activity_event(action:, workspace:, actor:, subject: nil, additional_actions: []) { request } -> ActivityEvent` asserts the exact new-action multiset; `additional_actions` accepts only `bean.used_up`.

- [ ] **Step 1: Write failing contract/emitter tests**

Create `test/services/activity/emitter_test.rb`:

~~~ruby
require "test_helper"

class Activity::EmitterTest < ActiveSupport::TestCase
  test "derives category visibility icon and safe actor subject snapshots" do
    users(:one).update!(display_name: "Jens")
    brew = brews(:morning_espresso)

    event = Activity::Emitter.record!(
      action: "brew.created",
      workspace: workspaces(:household),
      actor: users(:one),
      subject: brew,
      occurred_at: brew.occurred_at
    )

    assert_equal "coffee", event.category
    assert_equal "workspace", event.visibility
    assert_equal "Jens", event.metadata.fetch("actor_label")
    assert_equal "user", event.metadata.fetch("actor_kind")
    assert_equal "Espresso with #{brew.bean.name}", event.metadata.fetch("subject_label")
    assert_equal "espresso", event.metadata.fetch("method")
    assert_equal "local_cafe", Activity::EventContract.fetch("brew.created").fetch(:icon)
  end

  test "uses Quick Drip copy and System actor snapshots" do
    brew = workspaces(:household).brews.new(method: "quick_drip", bean: beans(:open_household))
    metadata = Activity::Metadata.build(action: "brew.created", actor: nil, subject: brew)

    assert_equal "Quick Drip with #{brew.bean.name}", metadata.fetch("subject_label")
    assert_equal "System", metadata.fetch("actor_label")
    assert_equal "system", metadata.fetch("actor_kind")
  end

  test "rejects unknown actions cross-workspace subjects and unexpected details" do
    assert_raises(KeyError) do
      Activity::Emitter.record!(action: "future.unknown", workspace: workspaces(:household))
    end
    assert_raises(ArgumentError) do
      Activity::Emitter.record!(
        action: "brew.created", workspace: workspaces(:household), actor: users(:one),
        subject: brews(:other_workspace_brew)
      )
    end
    assert_raises(ArgumentError) do
      Activity::Emitter.record!(
        action: "brew.created", workspace: workspaces(:household), actor: users(:one),
        subject: beans(:open_household)
      )
    end
    assert_raises(ArgumentError) do
      Activity::Emitter.record!(
        action: "brew.created", workspace: workspaces(:household), actor: users(:one),
        subject: brews(:morning_espresso), details: { "token" => "bearer-secret" }
      )
    end
    assert_raises(ArgumentError) do
      Activity::Emitter.record!(
        action: "brew.created", workspace: workspaces(:household), actor: users(:one),
        subject: brews(:morning_espresso), details: { "backup_kind" => "full_archive" }
      )
    end
    assert_raises(ArgumentError) do
      Activity::Emitter.record!(
        action: "brew.created", workspace: workspaces(:household),
        actor: users(:one), visibility: "workspace_admin"
      )
    end
  end

  test "redacts path url and secret-shaped label text" do
    users(:one).update!(display_name: "https://private.example/token=abc")

    event = Activity::Emitter.record!(
      action: "profile.updated",
      workspace: workspaces(:household), actor: users(:one), subject: users(:one)
    )

    assert_equal "[redacted]", event.metadata.fetch("actor_label")
    assert_no_match(/https|token|abc/i, event.metadata.to_json)
  end

  test "sanitizes every item in automatic subject-derived arrays" do
    grinder = equipment(:household_grinder)
    grinder.update_column(:name, "../private/grinder")

    metadata = Activity::Metadata.build(
      action: "equipment_event.created", actor: users(:one),
      subject: equipment_events(:grinder_cleaning)
    )

    assert_equal [ "[redacted]" ], metadata.fetch("equipment_labels")
    assert_no_match(/private|\.\./i, metadata.to_json)
  end

  test "system instance events have no workspace and actor snapshots survive actor changes" do
    event = Activity::Emitter.record!(
      action: "instance_backup_run.succeeded",
      workspace: nil,
      details: { "backup_kind" => "full_archive", "status" => "succeeded" }
    )
    users(:one).update!(display_name: "Changed later")
    actor_event = Activity::Emitter.record!(
      action: "workspace.updated", workspace: workspaces(:household), actor: users(:one),
      subject: workspaces(:household)
    )
    users(:one).update!(display_name: "Changed again")

    assert_nil event.workspace
    assert_equal "instance_admin", event.visibility
    assert_equal "System", event.metadata.fetch("actor_label")
    assert_equal "Changed later", actor_event.reload.metadata.fetch("actor_label")
  end

  test "a surrounding rollback leaves no event" do
    assert_no_difference -> { ActivityEvent.count } do
      ActivityEvent.transaction do
        Activity::Emitter.record!(
          action: "bean.updated", workspace: workspaces(:household), actor: users(:one), subject: beans(:open_household)
        )
        raise ActiveRecord::Rollback
      end
    end
  end

  test "model validation rejects unsafe and action-incompatible metadata from direct callers" do
    unsafe_event = ActivityEvent.new(
      workspace: workspaces(:household), actor: users(:one), category: "coffee",
      action: "brew.created", occurred_at: Time.current, visibility: "workspace",
      metadata: { "actor_kind" => "user", "actor_label" => "https://private.example/token=abc" }
    )
    wrong_key_event = ActivityEvent.new(
      workspace: workspaces(:household), actor: users(:one), category: "coffee",
      action: "brew.created", occurred_at: Time.current, visibility: "workspace",
      metadata: { "actor_kind" => "user", "actor_label" => "Jens", "backup_kind" => "full_archive" }
    )
    unsafe_array_event = ActivityEvent.new(
      workspace: workspaces(:household), actor: users(:one), category: "gear_maintenance",
      action: "equipment_event.created", occurred_at: Time.current, visibility: "workspace",
      subject: equipment_events(:grinder_cleaning),
      metadata: {
        "actor_kind" => "user", "actor_label" => "Jens", "record_kind" => "equipment_event",
        "subject_label" => "Grinder cleaning", "event_types" => [ "../private/event", "x" * 161 ]
      }
    )

    assert_not unsafe_event.valid?
    assert_includes unsafe_event.errors[:metadata], "contains unsafe text"
    assert_not wrong_key_event.valid?
    assert_includes wrong_key_event.errors[:metadata], "contains unsupported keys"
    assert_not unsafe_array_event.valid?
    assert_includes unsafe_array_event.errors[:metadata], "contains unsafe text"
    assert_includes unsafe_array_event.errors[:metadata], "contains overlong text"
    assert_raises(ActiveRecord::RecordInvalid) { wrong_key_event.save! }
    assert_raises(ActiveRecord::RecordInvalid) { unsafe_array_event.save! }
  end

  test "direct model writes enforce action category visibility subject type and workspace" do
    attributes = {
      workspace: workspaces(:household), actor: users(:one), category: "coffee",
      action: "brew.created", occurred_at: Time.current, visibility: "workspace",
      subject: brews(:morning_espresso), metadata: { "actor_kind" => "user", "actor_label" => "Jens" }
    }
    wrong_category = ActivityEvent.new(attributes.merge(category: "system_security"))
    wrong_visibility = ActivityEvent.new(attributes.merge(visibility: "workspace_admin"))
    wrong_type = ActivityEvent.new(attributes.merge(subject: beans(:open_household)))
    wrong_workspace = ActivityEvent.new(attributes.merge(subject: brews(:other_workspace_brew)))
    tombstone = ActivityEvent.new(attributes.merge(action: "brew.deleted", subject: nil))

    assert_not wrong_category.valid?
    assert_includes wrong_category.errors[:category], "does not match action"
    assert_not wrong_visibility.valid?
    assert_includes wrong_visibility.errors[:visibility], "is not permitted for action"
    assert_not wrong_type.valid?
    assert_includes wrong_type.errors[:subject], "type does not match action"
    assert_not wrong_workspace.valid?
    assert_includes wrong_workspace.errors[:subject], "belongs to another workspace"
    assert_predicate tombstone, :valid?
    [ wrong_category, wrong_visibility, wrong_type, wrong_workspace ].each do |event|
      assert_raises(ActiveRecord::RecordInvalid) { event.save! }
    end
  end
end
~~~

Run:

~~~bash
bin/rails test test/services/activity/emitter_test.rb
~~~

Expected: ERROR with `uninitialized constant Activity::Emitter`.

- [ ] **Step 2: Implement the registry from the canonical matrix**

Create `app/services/activity/event_contract.rb`. This compact representation is the executable equivalent of every row in the canonical matrix; do not add actions outside these arrays:

~~~ruby
module Activity
  module EventContract
    ACTIONS = {
      "coffee" => %w[
        brew.created brew.updated brew.taste_changed brew.serving_changed brew.deleted brew.media_updated
        external_coffee.created external_coffee.updated external_coffee.deleted external_coffee.media_updated
      ],
      "beans_inventory" => %w[
        bean.created bean.updated bean.duplicated bean.opened bean.finished bean.used_up bean.archived bean.reopened
        bean.deleted bean.media_updated inventory_adjustment.created
      ],
      "gear_maintenance" => %w[
        equipment.created equipment.updated equipment.archived equipment.reopened equipment.deleted equipment.media_updated
        preparation_tool.created preparation_tool.updated preparation_tool.archived preparation_tool.reopened
        preparation_tool.deleted preparation_tool.media_updated equipment_event.created equipment_event.updated
        equipment_event.deleted equipment_event.media_updated
      ],
      "sharing_recipes" => %w[
        recipe.created recipe.imported recipe.updated recipe.exported recipe.deleted recipe.media_updated
        public_brew_share.created public_brew_share.published public_brew_share.updated public_brew_share.disabled public_brew_share.deleted
        public_bean_share.created public_bean_share.published public_bean_share.updated public_bean_share.disabled public_bean_share.deleted
        public_recipe_share.created public_recipe_share.published public_recipe_share.updated public_recipe_share.disabled public_recipe_share.deleted
      ],
      "household_administration" => %w[
        workspace.created workspace.updated workspace.media_updated workspace.deleted
        workspace_invite.created workspace_invite.accepted workspace_invite.revoked workspace_invite.resent workspace_invite.reinvited
        membership.role_changed membership.removed membership.ownership_transferred
        household_invite.created household_invite.accepted household_invite.revoked household_invite.resent household_invite.reinvited
      ],
      "system_security" => %w[
        profile.updated profile.media_updated password.changed password.reset
        passkey.created passkey.renamed passkey.deleted passkey.second_factor_enabled passkey.second_factor_disabled
        session.signed_in session.signed_out data_import.completed data_import.failed workspace_export.generated
        instance_backup_profile.created instance_backup_profile.updated instance_backup_run.queued
        instance_backup_run.succeeded instance_backup_run.failed instance.first_user_created
      ]
    }.freeze

    WORKSPACE_ADMIN_ACTIONS = %w[
      workspace.created workspace.updated workspace.media_updated
      workspace_invite.created workspace_invite.accepted workspace_invite.revoked workspace_invite.resent workspace_invite.reinvited
      membership.role_changed membership.removed membership.ownership_transferred household_invite.accepted
      profile.updated profile.media_updated password.changed password.reset
      passkey.created passkey.renamed passkey.deleted passkey.second_factor_enabled passkey.second_factor_disabled
      session.signed_in session.signed_out data_import.completed data_import.failed workspace_export.generated
    ].freeze

    INSTANCE_ADMIN_ACTIONS = %w[
      workspace.deleted household_invite.created household_invite.revoked household_invite.resent household_invite.reinvited
      instance_backup_profile.created instance_backup_profile.updated instance_backup_run.queued
      instance_backup_run.succeeded instance_backup_run.failed instance.first_user_created
    ].freeze

    ACCOUNT_ACTIONS = %w[
      profile.updated profile.media_updated password.changed password.reset
      passkey.created passkey.renamed passkey.deleted passkey.second_factor_enabled passkey.second_factor_disabled
      session.signed_in session.signed_out
    ].freeze

    SUBJECT_TYPES_BY_PREFIX = {
      "brew" => "Brew", "external_coffee" => "ExternalCoffee", "bean" => "Bean",
      "inventory_adjustment" => "InventoryAdjustment", "equipment" => "Equipment",
      "preparation_tool" => "PreparationTool", "equipment_event" => "EquipmentEvent", "recipe" => "Recipe",
      "public_brew_share" => "PublicBrewShare", "public_bean_share" => "PublicBeanShare",
      "public_recipe_share" => "PublicRecipeShare", "workspace" => "Workspace",
      "workspace_invite" => "WorkspaceInvite", "membership" => "Membership",
      "household_invite" => "HouseholdInvite", "profile" => "User", "password" => "User",
      "passkey" => "PasskeyCredential", "session" => "User", "data_import" => "DataImport",
      "workspace_export" => "Workspace", "instance_backup_profile" => "InstanceBackupProfile",
      "instance_backup_run" => "InstanceBackupRun", "instance" => "User"
    }.freeze

    SUBJECT_TYPE_OVERRIDES = {
      "passkey.second_factor_enabled" => "User",
      "passkey.second_factor_disabled" => "User"
    }.freeze

    ICONS_BY_SUFFIX = {
      "created" => "inventory_2", "updated" => "edit", "deleted" => "delete", "media_updated" => "photo",
      "archived" => "archive", "reopened" => "refresh", "published" => "public", "disabled" => "visibility_off",
      "imported" => "upload_file", "exported" => "file_download", "accepted" => "check_circle",
      "revoked" => "link_off", "resent" => "ios_share", "reinvited" => "refresh", "signed_in" => "login",
      "signed_out" => "logout", "queued" => "backup", "succeeded" => "check_circle", "failed" => "backup"
    }.freeze

    ICON_OVERRIDES = {
      "brew.created" => "local_cafe", "brew.taste_changed" => "local_cafe", "brew.serving_changed" => "group",
      "external_coffee.created" => "local_cafe", "bean.duplicated" => "content_copy", "bean.opened" => "inventory_2",
      "bean.finished" => "check_circle", "bean.used_up" => "check_circle", "inventory_adjustment.created" => "scale",
      "equipment.created" => "build", "preparation_tool.created" => "build", "equipment_event.created" => "build",
      "recipe.created" => "bookmark_add", "public_brew_share.created" => "ios_share",
      "public_bean_share.created" => "ios_share", "public_recipe_share.created" => "ios_share",
      "public_brew_share.deleted" => "link_off", "public_bean_share.deleted" => "link_off", "public_recipe_share.deleted" => "link_off",
      "workspace.created" => "group", "workspace_invite.created" => "group", "membership.role_changed" => "group",
      "membership.ownership_transferred" => "group", "household_invite.created" => "group",
      "password.changed" => "key", "password.reset" => "key", "passkey.created" => "key",
      "passkey.second_factor_enabled" => "security", "passkey.second_factor_disabled" => "security",
      "data_import.completed" => "upload_file", "data_import.failed" => "upload_file",
      "workspace_export.generated" => "file_download", "instance.first_user_created" => "security"
    }.freeze

    SUMMARY_OVERRIDES = {
      "brew.created" => "logged", "brew.updated" => "corrected", "brew.taste_changed" => "taste_changed",
      "brew.serving_changed" => "serving_changed", "external_coffee.created" => "logged",
      "external_coffee.updated" => "corrected", "bean.duplicated" => "duplicated", "bean.opened" => "opened",
      "bean.finished" => "finished", "bean.used_up" => "used_up", "inventory_adjustment.created" => "adjusted",
      "equipment_event.created" => "maintenance_logged", "equipment_event.updated" => "maintenance_corrected",
      "recipe.imported" => "imported", "recipe.exported" => "exported", "membership.role_changed" => "role_changed",
      "membership.removed" => "member_removed", "membership.ownership_transferred" => "ownership_transferred",
      "password.changed" => "password_changed", "password.reset" => "password_reset",
      "passkey.created" => "passkey_added", "passkey.renamed" => "passkey_renamed", "passkey.deleted" => "passkey_removed",
      "passkey.second_factor_enabled" => "second_factor_enabled", "passkey.second_factor_disabled" => "second_factor_disabled",
      "session.signed_in" => "signed_in", "session.signed_out" => "signed_out",
      "data_import.completed" => "import_completed", "data_import.failed" => "import_failed",
      "workspace_export.generated" => "export_generated", "instance_backup_run.queued" => "backup_queued",
      "instance_backup_run.succeeded" => "backup_succeeded", "instance_backup_run.failed" => "backup_failed",
      "instance.first_user_created" => "first_user_created"
    }.freeze

    DETAIL_KEYS = {
      "bean.duplicated" => %w[source_label], "membership.role_changed" => %w[from_role to_role],
      "membership.ownership_transferred" => %w[from_role to_role], "workspace_export.generated" => %w[export_kind],
      "session.signed_in" => %w[authentication_method], "data_import.completed" => %w[source created_count skipped_count],
      "data_import.failed" => %w[source], "instance_backup_profile.created" => %w[backup_kind],
      "instance_backup_profile.updated" => %w[backup_kind], "instance_backup_run.queued" => %w[backup_kind status],
      "instance_backup_run.succeeded" => %w[backup_kind status file_size_bytes],
      "instance_backup_run.failed" => %w[backup_kind status]
    }.freeze

    AUTOMATIC_METADATA_ACTIONS = {
      "method" => %w[brew.created brew.updated brew.taste_changed brew.serving_changed brew.deleted brew.media_updated],
      "status" => %w[
        bean.created bean.updated bean.duplicated bean.opened bean.finished bean.used_up bean.archived bean.reopened
        bean.deleted bean.media_updated instance_backup_run.queued instance_backup_run.succeeded instance_backup_run.failed
      ],
      "amount_grams" => %w[inventory_adjustment.created],
      "event_types" => %w[equipment_event.created equipment_event.updated equipment_event.deleted equipment_event.media_updated],
      "equipment_labels" => %w[equipment_event.created equipment_event.updated equipment_event.deleted equipment_event.media_updated],
      "enabled" => %w[
        public_brew_share.created public_brew_share.published public_brew_share.updated public_brew_share.disabled public_brew_share.deleted
        public_bean_share.created public_bean_share.published public_bean_share.updated public_bean_share.disabled public_bean_share.deleted
        public_recipe_share.created public_recipe_share.published public_recipe_share.updated public_recipe_share.disabled public_recipe_share.deleted
      ],
      "role" => %w[
        workspace_invite.created workspace_invite.accepted workspace_invite.revoked workspace_invite.resent workspace_invite.reinvited
        membership.role_changed membership.removed membership.ownership_transferred
      ],
      "source" => %w[data_import.completed data_import.failed],
      "backup_kind" => %w[
        instance_backup_profile.created instance_backup_profile.updated instance_backup_run.queued
        instance_backup_run.succeeded instance_backup_run.failed
      ],
      "file_size_bytes" => %w[instance_backup_run.succeeded]
    }.freeze

    DETAIL_VALUES = {
      "session.signed_in" => { "authentication_method" => %w[password passkey passkey_second_factor invited_signup] },
      "workspace_export.generated" => { "export_kind" => %w[json beans_csv brews_csv external_coffees_csv media_zip] },
      "data_import.completed" => { "source" => %w[beanconqueror] },
      "data_import.failed" => { "source" => %w[beanconqueror] },
      "instance_backup_profile.created" => { "backup_kind" => %w[full_archive readable_json] },
      "instance_backup_profile.updated" => { "backup_kind" => %w[full_archive readable_json] },
      "instance_backup_run.queued" => { "backup_kind" => %w[full_archive readable_json], "status" => %w[queued] },
      "instance_backup_run.succeeded" => { "backup_kind" => %w[full_archive readable_json], "status" => %w[succeeded] },
      "instance_backup_run.failed" => { "backup_kind" => %w[full_archive readable_json], "status" => %w[failed] }
    }.freeze

    module_function

    def fetch(action)
      action = action.to_s
      category = ACTIONS.find { |_category, actions| actions.include?(action) }&.first
      raise KeyError, "unknown activity action: #{action}" unless category

      suffix = action.split(".").last
      automatic_metadata_keys = AUTOMATIC_METADATA_ACTIONS.filter_map do |key, actions|
        key if actions.include?(action)
      end
      {
        category:,
        visibility: visibility_for(action),
        visibilities: ACCOUNT_ACTIONS.include?(action) ? %w[workspace_admin instance_admin] : [ visibility_for(action) ],
        subject_type: SUBJECT_TYPE_OVERRIDES.fetch(action, SUBJECT_TYPES_BY_PREFIX.fetch(action.split(".").first)),
        icon: ICON_OVERRIDES.fetch(action, ICONS_BY_SUFFIX.fetch(suffix, "more_vert")),
        summary: SUMMARY_OVERRIDES.fetch(action, suffix),
        detail_keys: DETAIL_KEYS.fetch(action, []),
        automatic_metadata_keys:,
        metadata_keys: (automatic_metadata_keys + DETAIL_KEYS.fetch(action, [])).uniq,
        detail_values: DETAIL_VALUES.fetch(action, {})
      }
    end

    def visibility_for(action)
      return "instance_admin" if INSTANCE_ADMIN_ACTIONS.include?(action)
      return "workspace_admin" if WORKSPACE_ADMIN_ACTIONS.include?(action)

      "workspace"
    end

    def actions
      ACTIONS.values.flatten.freeze
    end
  end
end
~~~

- [ ] **Step 3: Implement flat safe metadata and the emitter**

Create `app/services/activity/metadata.rb` and `app/services/activity/emitter.rb`:

~~~ruby
module Activity
  module Metadata
    MAX_TEXT = 160
    MAX_ARRAY = 10
    SENSITIVE = %r{https?://|rails/active_storage|[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}|(?:password|digest|token|secret|session|signed_id|attachment|filename|ip_address|file_path|error)\s*[:=]}i

    module_function

    def build(action:, actor:, subject:, details: {})
      definition = EventContract.fetch(action)
      details = details.to_h.stringify_keys
      unexpected = details.keys - definition.fetch(:detail_keys)
      raise ArgumentError, "unsupported activity details: #{unexpected.join(', ')}" if unexpected.any?
      definition.fetch(:detail_values).each do |key, allowed|
        next unless details.key?(key)
        raise ArgumentError, "unsupported #{key} for #{action}" unless allowed.include?(details.fetch(key).to_s)
      end

      automatic_details = auto_details(subject).slice(*definition.fetch(:automatic_metadata_keys))

      actor_payload(actor)
        .merge(subject_payload(subject))
        .merge(automatic_details.transform_values { |value| safe_value(value) })
        .merge(details.transform_values { |value| safe_value(value) })
        .compact
    end

    def actor_payload(actor)
      return { "actor_kind" => "system", "actor_label" => "System" } unless actor

      { "actor_kind" => "user", "actor_label" => safe_text(actor.display_label) }
    end

    def subject_payload(subject)
      return {} unless subject

      { "record_kind" => subject.class.model_name.singular, "subject_label" => safe_text(subject_label(subject)) }
    end

    def subject_label(subject)
      case subject
      when Brew
        "#{subject.method == "quick_drip" ? "Quick Drip" : "Espresso"} with #{subject.bean&.name || "deleted bean"}"
      when Bean then subject.display_name
      when ExternalCoffee then subject.drink_type
      when Equipment, PreparationTool then subject.name
      when EquipmentEvent then subject.event_type_summary
      when InventoryAdjustment then subject.bean&.display_name || "Inventory adjustment"
      when Recipe then subject.title
      when PublicBrewShare, PublicBeanShare, PublicRecipeShare then subject.title.presence || subject.class.model_name.human
      when Workspace then subject.name
      when WorkspaceInvite then "#{subject.role.to_s.humanize} invite"
      when HouseholdInvite then "Household invite"
      when Membership then subject.user&.display_label || "Former member"
      when DataImport then "#{subject.source.to_s.humanize} import"
      when User then subject.display_label
      when InstanceBackupProfile then subject.name
      when InstanceBackupRun then subject.instance_backup_profile&.name || "Instance backup"
      when PasskeyCredential then "Passkey"
      else subject.class.model_name.human
      end
    end

    def auto_details(subject)
      case subject
      when Brew then { "method" => subject.method }
      when Bean then { "status" => subject.bag_status }
      when InventoryAdjustment then { "amount_grams" => subject.delta_grams&.to_s("F") }
      when EquipmentEvent
        { "event_types" => subject.event_type_names.first(MAX_ARRAY), "equipment_labels" => subject.equipment.map(&:name).sort.first(MAX_ARRAY) }
      when PublicBrewShare, PublicBeanShare, PublicRecipeShare then { "enabled" => subject.enabled? }
      when WorkspaceInvite, Membership then { "role" => subject.role }
      when DataImport then { "source" => subject.source }
      when InstanceBackupProfile then { "backup_kind" => subject.backup_kind }
      when InstanceBackupRun
        { "backup_kind" => subject.backup_kind, "status" => subject.status, "file_size_bytes" => subject.file_size_bytes }
      else {}
      end
    end

    def safe_value(value)
      case value
      when String, Symbol then safe_text(value)
      when Numeric, TrueClass, FalseClass, NilClass then value
      when Array then value.first(MAX_ARRAY).map { |item| safe_text(item) }
      else raise ArgumentError, "activity metadata must be flat JSON scalars"
      end
    end

    def safe_text(value)
      text = value.to_s.strip.squish
      return "[redacted]" if unsafe_text?(text)

      text.first(MAX_TEXT).presence || "Unknown"
    end

    def unsafe_text?(value)
      text = value.to_s.strip.squish
      text.match?(SENSITIVE) || text.start_with?("/", "../")
    end
  end
end
~~~

~~~ruby
module Activity
  module Emitter
    module_function

    def record!(action:, workspace:, actor: nil, subject: nil, occurred_at: Time.current, visibility: nil, details: {})
      definition = EventContract.fetch(action)
      visibility ||= definition.fetch(:visibility)
      unless definition.fetch(:visibilities).include?(visibility)
        raise ArgumentError, "visibility is not permitted for #{action}"
      end
      validate_scope!(workspace:, visibility:, subject:, expected_subject_type: definition.fetch(:subject_type))

      ActivityEvent.create!(
        workspace:,
        actor:,
        category: definition.fetch(:category),
        action: action.to_s,
        occurred_at:,
        visibility:,
        subject:,
        metadata: Metadata.build(action:, actor:, subject:, details:)
      )
    end

    def validate_scope!(workspace:, visibility:, subject:, expected_subject_type:)
      if visibility == "instance_admin"
        raise ArgumentError, "instance activity cannot have a workspace" if workspace
      else
        raise ArgumentError, "workspace activity requires a workspace" unless workspace
      end
      if subject && subject.class.base_class.name != expected_subject_type
        raise ArgumentError, "activity subject type does not match action"
      end
      return unless workspace && subject
      subject_workspace_id = subject.is_a?(Workspace) ? subject.id : subject.workspace_id if subject.respond_to?(:workspace_id) || subject.is_a?(Workspace)
      return if subject_workspace_id.nil? || subject_workspace_id == workspace.id

      raise ArgumentError, "activity subject belongs to another workspace"
    end
  end
end
~~~

Extend `ActivityEvent`:

~~~ruby
validates :action, inclusion: { in: Activity::EventContract.actions }
validate :event_contract_matches

def event_contract_matches
  return if action.blank?

  definition = Activity::EventContract.fetch(action)
  errors.add(:category, "does not match action") unless category == definition.fetch(:category)
  errors.add(:visibility, "is not permitted for action") unless definition.fetch(:visibilities).include?(visibility)
  validate_activity_subject_contract(definition) if subject
  return unless metadata.is_a?(Hash)

  allowed = %w[actor_kind actor_label record_kind subject_label] + definition.fetch(:metadata_keys)
  errors.add(:metadata, "contains unsupported keys") if metadata.keys.map(&:to_s).difference(allowed).any?
  errors.add(:metadata, "is too large") if metadata.to_json.bytesize > 2.kilobytes
  errors.add(:metadata, "has an invalid actor kind") unless %w[user system].include?(metadata["actor_kind"])
  metadata.each_value do |value|
    valid_value = value.is_a?(String) || value.is_a?(Numeric) || value == true || value == false || value.nil? ||
      (value.is_a?(Array) && value.all? { |item| item.is_a?(String) })
    errors.add(:metadata, "must stay flat") unless valid_value
    text_values = value.is_a?(Array) ? value : [ value ]
    if text_values.any? { |item| item.is_a?(String) && Activity::Metadata.unsafe_text?(item) }
      errors.add(:metadata, "contains unsafe text")
    end
    if text_values.any? { |item| item.is_a?(String) && item.length > Activity::Metadata::MAX_TEXT }
      errors.add(:metadata, "contains overlong text")
    end
    errors.add(:metadata, "contains too many values") if value.is_a?(Array) && value.length > Activity::Metadata::MAX_ARRAY
  end
  definition.fetch(:detail_values).each do |key, values|
    errors.add(:metadata, "contains an unsupported #{key}") if metadata.key?(key) && !values.include?(metadata[key].to_s)
  end
rescue KeyError
  errors.add(:action, "is not supported")
end

def validate_activity_subject_contract(definition)
  unless subject.class.base_class.name == definition.fetch(:subject_type)
    errors.add(:subject, "type does not match action")
    return
  end

  subject_workspace_id = if subject.is_a?(Workspace)
    subject.id
  elsif subject.respond_to?(:workspace_id)
    subject.workspace_id
  end
  if workspace_id.present? && subject_workspace_id.present? && subject_workspace_id != workspace_id
    errors.add(:subject, "belongs to another workspace")
  elsif workspace_id.blank? && subject_workspace_id.present? && !subject.is_a?(Workspace)
    errors.add(:subject, "cannot be workspace-scoped for instance activity")
  end
end
~~~

- [ ] **Step 4: Add transaction wrappers and integration assertions**

Add these private helpers to `ApplicationController`:

~~~ruby
def with_workspace_activity(action:, subject:, occurred_at: nil, details: {}, visibility: nil)
  result = false
  ActiveRecord::Base.transaction do
    result = yield
    raise ActiveRecord::Rollback unless result

    Activity::Emitter.record!(
      action: resolve_activity_value(action),
      workspace: current_workspace,
      actor: Current.user,
      subject: resolve_activity_value(subject),
      occurred_at: resolve_activity_value(occurred_at) || Time.current,
      visibility:,
      details: resolve_activity_value(details)
    )
  end
  result
end

def with_account_activity(action:, user:, subject: user, details: {})
  result = false
  ActiveRecord::Base.transaction do
    result = yield
    raise ActiveRecord::Rollback unless result

    workspace = user.active_workspace
    Activity::Emitter.record!(
      action:,
      workspace:,
      actor: user,
      subject:,
      visibility: workspace ? "workspace_admin" : "instance_admin",
      details:
    )
  end
  result
end

def resolve_activity_value(value)
  value.respond_to?(:call) ? value.call : value
end
~~~

Create `test/test_helpers/activity_event_test_helper.rb`:

~~~ruby
module ActivityEventTestHelper
  def assert_activity_event(action:, workspace:, actor:, subject: nil, additional_actions: [])
    unknown_secondary_actions = Array(additional_actions) - [ "bean.used_up" ]
    assert_empty unknown_secondary_actions, "only bean.used_up is an approved secondary activity action"
    before_ids = ActivityEvent.pluck(:id)
    yield
    events = ActivityEvent.where.not(id: before_ids).order(:id).to_a
    expected_actions = [ action, *Array(additional_actions) ].sort
    assert_equal expected_actions, events.map(&:action).sort,
      "expected exact new activity action multiset #{expected_actions.inspect}"
    events.each do |new_event|
      assert_equal workspace, new_event.workspace
      assert_equal actor, new_event.actor
    end
    event = events.find { |new_event| new_event.action == action }
    assert_equal subject, event.subject if subject
    event
  end
end

ActiveSupport::TestCase.include ActivityEventTestHelper
~~~

Require it from `test/test_helper.rb` immediately after `session_test_helper`:

~~~ruby
require_relative "test_helpers/activity_event_test_helper"
~~~

- [ ] **Step 5: Run and commit the emission foundation**

Run:

~~~bash
bin/rails test test/services/activity/emitter_test.rb test/models/activity_event_test.rb
~~~

Expected: PASS. Then commit:

~~~bash
git add app/services/activity app/models/activity_event.rb app/controllers/application_controller.rb test/services/activity test/test_helpers/activity_event_test_helper.rb test/test_helper.rb
git commit -m "Centralize safe activity emission"
~~~

---

### Task 3: Build The Authorized, Filterable Activity Query

**Files:**

- Create: `test/services/activity/query_test.rb`
- Create: `app/services/activity/query.rb`

**Interfaces:**

- `Activity::Query.new(workspace:, membership:, user:, category: nil, actor: nil, start_date: nil, end_date: nil)` accepts only the four public filters plus authorization context.
- `#events -> ActiveRecord::Relation<ActivityEvent>` remains a relation for `HistoryPaginator` and orders by `occurred_at DESC, id DESC`.
- `#actor_options -> Array<Activity::Query::ActorOption>` is derived from the unfiltered authorized scope; values are `system`, `user:<id>`, or a URL-safe Base64 `former:<label>` selector encoded from the safe snapshot label, and no email is read.
- Invalid category, actor, or ISO date input returns an empty/ignored safe result and never broadens authorization.

- [ ] **Step 1: Write failing query tests for role and tenant boundaries**

Create `test/services/activity/query_test.rb`:

~~~ruby
require "test_helper"

class Activity::QueryTest < ActiveSupport::TestCase
  def query(user: users(:one), membership: memberships(:owner), **filters)
    Activity::Query.new(workspace: workspaces(:household), membership:, user:, **filters)
  end

  test "viewer sees workspace rows but neither workspace-admin nor other-workspace rows" do
    membership = memberships(:owner)
    membership.update!(role: "viewer")

    actions = query(membership:).events.pluck(:action)

    assert_includes actions, "brew.created"
    assert_not_includes actions, "workspace_invite.created"
    assert_not ActivityEvent.where(id: query(membership:).events).exists?(workspace: workspaces(:other_household))
  end

  test "workspace admin sees workspace-admin rows" do
    memberships(:owner).update!(role: "admin")
    assert_includes query.events.pluck(:action), "workspace_invite.created"
  end

  test "instance admin receives instance rows but status alone never grants workspace-admin rows" do
    user = users(:one)
    user.update!(instance_admin: true)
    membership = memberships(:owner)
    membership.update!(role: "member")

    actions = query(user:, membership:).events.pluck(:action)

    assert_includes actions, "instance_backup_run.succeeded"
    assert_not_includes actions, "workspace_invite.created"
  end

  test "category actor and inclusive local dates combine without changing scope" do
    user = users(:one)
    user.update!(time_zone: "Europe/Berlin")
    event = Activity::Emitter.record!(
      action: "brew.created", workspace: workspaces(:household), actor: user,
      subject: brews(:morning_espresso), occurred_at: Time.utc(2026, 8, 20, 22)
    )
    excluded = Activity::Emitter.record!(
      action: "bean.created", workspace: workspaces(:household), actor: user,
      subject: beans(:open_household), occurred_at: Time.utc(2026, 8, 21, 22)
    )

    Time.use_zone(user.time_zone) do
      ids = query(
        user:, category: "coffee", actor: "user:#{user.id}",
        start_date: "2026-08-21", end_date: "2026-08-21"
      ).events.pluck(:id)
      assert_includes ids, event.id
      assert_not_includes ids, excluded.id
    end
  end

  test "actor options include former snapshots and system from authorized rows only" do
    former = ActivityEvent.create!(
      workspace: workspaces(:household), category: "coffee", action: "brew.updated",
      occurred_at: Time.current, visibility: "workspace",
      metadata: { "actor_kind" => "user", "actor_label" => "Former member" }
    )
    ActivityEvent.create!(
      workspace: workspaces(:household), category: "coffee", action: "brew.updated",
      occurred_at: Time.current, visibility: "workspace",
      metadata: { "actor_kind" => "system", "actor_label" => "System" }
    )

    options = query.actor_options.index_by(&:value)

    assert_equal "Jens", options.fetch("user:#{users(:one).id}").label
    former_value = "former:#{Base64.urlsafe_encode64('Former member', padding: false)}"
    assert_equal "Former member", options.fetch(former_value).label
    assert_equal "System", options.fetch("system").label
    assert_not_includes options.values.map(&:label), users(:two).email_address
  end

  test "invalid filter values fail closed or are ignored without raising" do
    assert_empty query(category: "not-a-category").events
    assert_empty query(actor: "user:not-an-id").events
    assert query(start_date: "31/31/2026", end_date: "bad").events.exists?
  end

  test "missing or cross-workspace membership grants no workspace rows" do
    assert_empty query(membership: nil).events
    assert_empty query(membership: memberships(:other_owner)).events
  end
end
~~~

Run:

~~~bash
bin/rails test test/services/activity/query_test.rb
~~~

Expected: ERROR with `uninitialized constant Activity::Query`.

- [ ] **Step 2: Implement one authorization-first relation**

Create `app/services/activity/query.rb`:

~~~ruby
require "base64"

module Activity
  class Query
    ActorOption = Data.define(:value, :label)

    def initialize(workspace:, membership:, user:, category: nil, actor: nil, start_date: nil, end_date: nil)
      @workspace = workspace
      @membership = membership
      @user = user
      @category = category.to_s.presence
      @actor_filter = actor.to_s.presence
      @start_date = parse_date(start_date)
      @end_date = parse_date(end_date)
    end

    def events
      @events ||= apply_filters(authorized_scope).recent
    end

    def actor_options
      seen = {}
      authorized_scope.reorder(occurred_at: :desc, id: :desc).pluck(:id, :actor_id, :metadata).each do |_id, actor_id, metadata|
        kind = metadata.fetch("actor_kind", actor_id ? "user" : "system")
        value = if kind == "system"
          "system"
        elsif actor_id
          "user:#{actor_id}"
        else
          "former:#{Base64.urlsafe_encode64(metadata.fetch('actor_label'), padding: false)}"
        end
        seen[value] ||= metadata.fetch("actor_label", kind == "system" ? "System" : "Former member")
      end
      seen.map { |value, label| ActorOption.new(value:, label:) }.sort_by { |option| option.label.downcase }
    end

    private
      attr_reader :workspace, :membership, :user, :category, :actor_filter, :start_date, :end_date

      def authorized_scope
        visibilities = membership&.can_manage_workspace? ? %w[workspace workspace_admin] : %w[workspace]
        authorized_membership = membership && workspace && membership.workspace_id == workspace.id
        workspace_rows = authorized_membership ? ActivityEvent.where(workspace:, visibility: visibilities) : ActivityEvent.none
        return workspace_rows unless user&.instance_admin?

        workspace_rows.or(ActivityEvent.where(workspace_id: nil, visibility: "instance_admin"))
      end

      def apply_filters(scope)
        if category
          return scope.none unless ActivityEvent::CATEGORIES.include?(category)
          scope = scope.where(category:)
        end
        scope = filter_actor(scope)
        scope = scope.where("occurred_at >= ?", start_date.beginning_of_day) if start_date
        scope = scope.where("occurred_at <= ?", end_date.end_of_day) if end_date
        scope
      end

      def filter_actor(scope)
        return scope unless actor_filter
        return scope.where("metadata ->> 'actor_kind' = ?", "system") if actor_filter == "system"

        kind, id = actor_filter.split(":", 2)
        integer_id = Integer(id, exception: false)
        return scope.where(actor_id: integer_id) if kind == "user" && integer_id
        if kind == "former"
          label = Base64.urlsafe_decode64(id.to_s)
          return scope.where(actor_id: nil).where("metadata ->> 'actor_label' = ?", label)
        end

        scope.none
      rescue ArgumentError
        scope.none
      end

      def parse_date(value)
        Date.iso8601(value.to_s) if value.present?
      rescue Date::Error
        nil
      end
  end
end
~~~

- [ ] **Step 3: Run the query and model suites**

~~~bash
bin/rails test test/services/activity/query_test.rb test/models/activity_event_test.rb
~~~

Expected: PASS; the SQL log shows workspace/visibility predicates applied before all filters.

- [ ] **Step 4: Commit the query**

~~~bash
git add app/services/activity/query.rb test/services/activity/query_test.rb
git commit -m "Add authorized activity query and filters"
~~~

---

### Task 4: Present One Safe Feed On Dashboard And Activity History

**Files:**

- Create: `test/presenters/activity/presenter_test.rb`
- Create: `app/presenters/activity/presenter.rb`
- Modify: `test/controllers/activity_controller_test.rb`
- Modify: `test/controllers/home_controller_test.rb`
- Modify: `app/controllers/activity_controller.rb`
- Modify: `app/controllers/home_controller.rb`
- Create: `app/views/activity/_event.html.erb`
- Modify: `app/views/activity/index.html.erb`
- Modify: `app/views/workspaces/show.html.erb`
- Modify: `app/helpers/application_helper.rb`
- Modify: `config/locales/en.yml`
- Delete: `app/services/workspace_activity_feed.rb`
- Delete: `test/services/workspace_activity_feed_test.rb`

**Interfaces:**

- `Activity::Presenter.new(event, helpers:)` exposes `summary`, `actor_label`, `timestamp`, `category_label`, `icon`, `icon_container_classes`, `restricted?`, and an authorized private `path` or nil.
- `app/views/activity/_event.html.erb` is the only event-card renderer and accepts `event:`.
- Unknown actions, absent/deleted subjects, and subjects without a private route render as unlinked cards with `more_vert`; the presenter never calls `polymorphic_path` on an unrecognized type.

- [ ] **Step 1: Write failing presenter and request coverage**

Create `test/presenters/activity/presenter_test.rb`:

~~~ruby
require "test_helper"

class Activity::PresenterTest < ActiveSupport::TestCase
  include Rails.application.routes.url_helpers

  test "uses snapshotted Quick Drip copy and links a live subject" do
    event = ActivityEvent.create!(
      workspace: workspaces(:household), category: "coffee", action: "brew.created",
      occurred_at: Time.zone.local(2026, 8, 21, 9), visibility: "workspace",
      subject: brews(:morning_espresso),
      metadata: {
        "actor_kind" => "system", "actor_label" => "System", "record_kind" => "brew",
        "subject_label" => "Quick Drip with Filter Beans", "method" => "quick_drip"
      }
    )
    presenter = Activity::Presenter.new(event, helpers: self)

    assert_equal "System logged Quick Drip with Filter Beans", presenter.summary
    assert_equal "local_cafe", presenter.icon
    assert_equal brew_path(brews(:morning_espresso)), presenter.path
  end

  test "marks privileged rows and keeps deleted subjects unlinked" do
    presenter = Activity::Presenter.new(activity_events(:workspace_invite_created), helpers: self)

    assert_predicate presenter, :restricted?
    assert_nil presenter.path
  end

  test "unknown actions fail closed" do
    event = ActivityEvent.new(action: "future.unknown", metadata: { "actor_label" => "Jens" })
    presenter = Activity::Presenter.new(event, helpers: self)

    assert_equal "Unknown activity", presenter.summary
    assert_equal "more_vert", presenter.icon
    assert_nil presenter.path
  end

  test "each category has a fixed distinguishable icon container" do
    coffee = Activity::Presenter.new(activity_events(:morning_brew_created), helpers: self)
    admin = Activity::Presenter.new(activity_events(:workspace_invite_created), helpers: self)

    assert_equal "bg-amber-100 text-amber-900", coffee.icon_container_classes
    assert_equal "bg-violet-100 text-violet-900", admin.icon_container_classes
    assert_not_equal coffee.icon_container_classes, admin.icon_container_classes
    assert_equal ActivityEvent::CATEGORIES.sort, Activity::Presenter::CATEGORY_ICON_CLASSES.keys.sort
    assert_equal ActivityEvent::CATEGORIES.size, Activity::Presenter::CATEGORY_ICON_CLASSES.values.uniq.size
  end
end
~~~

Replace inferred-record setup in `test/controllers/activity_controller_test.rb` with ledger fixtures and add:

~~~ruby
test "filters authorized ledger rows and preserves filters in pagination" do
  21.times do |index|
    Activity::Emitter.record!(
      action: "brew.updated", workspace: workspaces(:household), actor: users(:one),
      subject: brews(:morning_espresso), occurred_at: Time.zone.local(2026, 8, 21, 12) - index.minutes
    )
  end
  sign_in_as(users(:one))

  get activity_path, params: {
    category: "coffee", actor: "user:#{users(:one).id}",
    start_date: "2026-08-21", end_date: "2026-08-21"
  }

  assert_response :success
  assert_select "[data-testid=activity-card]", count: 20
  assert_select "select[data-testid=activity-category] option[value=coffee][selected]"
  assert_select "[data-testid=activity-actor] option[value=?]", "user:#{users(:one).id}", text: "Jens"
  assert_select "[data-testid=history-next-page][href*=?]", "category=coffee"
  assert_select "[data-testid=history-next-page][href*=?]", "actor=user%3A#{users(:one).id}"
end

test "viewer does not receive restricted cards and anonymous public reads do not write ledger rows" do
  memberships(:member).update!(role: "viewer")
  users(:two).update!(active_workspace: workspaces(:household))
  sign_in_as(users(:two))

  get activity_path
  assert_response :success
  assert_select "[data-visibility=workspace_admin]", count: 0

  share = PublicBrewShare.create!(
    workspace: workspaces(:household), brew: brews(:morning_espresso),
    created_by: users(:one), updated_by: users(:one), title: "Public brew story",
    enabled: true, snapshot: {}
  )
  delete session_path
  assert_no_difference -> { ActivityEvent.count } do
    get public_brew_page_path(share.token)
  end
end

test "active filters with no matches render the filtered empty state" do
  sign_in_as(users(:one))

  get activity_path, params: { category: "coffee", start_date: "1900-01-01", end_date: "1900-01-01" }

  assert_response :success
  assert_select "[data-testid=activity-card]", count: 0
  assert_select "[data-testid=activity-empty]", text: I18n.t("activity.index.filtered_empty")
end
~~~

Add to `test/controllers/home_controller_test.rb`:

~~~ruby
test "dashboard and full history use the same ledger card partial" do
  sign_in_as(users(:one))

  get dashboard_path
  assert_select "[data-testid=dashboard-recent-activity] [data-testid=activity-card]", maximum: 8
  assert_select "[data-symbol=local_cafe]", minimum: 1

  get activity_path
  assert_select "[data-testid=activity-card] [data-testid=activity-summary]", minimum: 1
end
~~~

Run:

~~~bash
bin/rails test test/presenters/activity/presenter_test.rb test/controllers/activity_controller_test.rb test/controllers/home_controller_test.rb
~~~

Expected: ERROR for the missing presenter, and request assertions FAIL because controllers still use `WorkspaceActivityFeed`.

- [ ] **Step 2: Implement the fail-closed presenter**

Create `app/presenters/activity/presenter.rb`:

~~~ruby
module Activity
  class Presenter
    CATEGORY_ICON_CLASSES = {
      "coffee" => "bg-amber-100 text-amber-900",
      "beans_inventory" => "bg-emerald-100 text-emerald-900",
      "gear_maintenance" => "bg-slate-200 text-slate-900",
      "sharing_recipes" => "bg-sky-100 text-sky-900",
      "household_administration" => "bg-violet-100 text-violet-900",
      "system_security" => "bg-rose-100 text-rose-900"
    }.freeze
    NEUTRAL_ICON_CLASSES = "bg-rn-surface-muted text-rn-muted"

    def initialize(event, helpers:)
      @event = event
      @helpers = helpers
    end

    def summary
      return I18n.t("activity.events.unknown") unless definition

      variables = metadata.except("actor_label", "subject_label").symbolize_keys.merge(
        actor: actor_label,
        subject: metadata.fetch("subject_label", I18n.t("activity.events.deleted_subject"))
      )
      I18n.t("activity.events.#{definition.fetch(:summary)}", **variables)
    end

    def actor_label = metadata.fetch("actor_label", I18n.t("activity.events.system"))
    def timestamp = event.occurred_at
    def category_label = I18n.t("activity.categories.#{event.category}", default: I18n.t("activity.categories.unknown"))
    def icon = definition&.fetch(:icon) || "more_vert"
    def icon_container_classes = CATEGORY_ICON_CLASSES.fetch(event.category, NEUTRAL_ICON_CLASSES)
    def restricted? = event.visibility != "workspace"

    def path
      return unless definition && (subject = event.subject)

      case subject
      when Brew then helpers.brew_path(subject)
      when ExternalCoffee then helpers.external_coffee_path(subject)
      when Bean then helpers.bean_path(subject)
      when Equipment then helpers.equipment_path(subject)
      when PreparationTool then helpers.preparation_tool_path(subject)
      when EquipmentEvent then helpers.equipment_event_path(subject)
      when InventoryAdjustment then helpers.bean_path(subject.bean) if subject.bean
      when Recipe then helpers.recipe_path(subject)
      when PublicBrewShare then helpers.brew_path(subject.brew) if subject.brew
      when PublicBeanShare then helpers.bean_path(subject.bean) if subject.bean
      when PublicRecipeShare then helpers.recipe_path(subject.recipe) if subject.recipe
      when DataImport then helpers.beanconqueror_import_path(subject)
      end
    rescue ActiveRecord::RecordNotFound
      nil
    end

    private
      attr_reader :event, :helpers

      def metadata = event.metadata.to_h

      def definition
        @definition ||= EventContract.fetch(event.action)
      rescue KeyError
        nil
      end
  end
end
~~~

In `config/locales/en.yml`, add every summary key used by `EventContract` (identical text is deliberate, because the action remains distinct in the ledger):

~~~yaml
activity:
  index:
    all_categories: "All categories"
    all_actors: "All actors"
    filter: "Filter"
    restricted: "Restricted"
    empty: "No activity yet."
    filtered_empty: "No activity matches these filters."
  categories:
    coffee: "Coffee"
    beans_inventory: "Beans & inventory"
    gear_maintenance: "Gear & maintenance"
    sharing_recipes: "Sharing & recipes"
    household_administration: "Household administration"
    system_security: "System & security"
    unknown: "Other"
  events:
    system: "System"
    unknown: "Unknown activity"
    deleted_subject: "deleted item"
    created: "%{actor} created %{subject}"
    updated: "%{actor} updated %{subject}"
    deleted: "%{actor} deleted %{subject}"
    media_updated: "%{actor} updated media for %{subject}"
    logged: "%{actor} logged %{subject}"
    corrected: "%{actor} corrected %{subject}"
    taste_changed: "%{actor} changed the taste rating for %{subject}"
    serving_changed: "%{actor} changed serving details for %{subject}"
    duplicated: "%{actor} duplicated %{subject}"
    opened: "%{actor} opened %{subject}"
    finished: "%{actor} finished %{subject}"
    used_up: "%{actor} used up %{subject}"
    archived: "%{actor} archived %{subject}"
    reopened: "%{actor} reopened %{subject}"
    adjusted: "%{actor} adjusted %{subject} by %{amount_grams} g"
    maintenance_logged: "%{actor} logged maintenance: %{subject}"
    maintenance_corrected: "%{actor} corrected maintenance: %{subject}"
    imported: "%{actor} imported %{subject}"
    exported: "%{actor} exported %{subject}"
    published: "%{actor} published %{subject}"
    disabled: "%{actor} disabled %{subject}"
    accepted: "%{actor} accepted %{subject}"
    revoked: "%{actor} revoked %{subject}"
    resent: "%{actor} resent %{subject}"
    reinvited: "%{actor} re-invited %{subject}"
    role_changed: "%{actor} changed %{subject} from %{from_role} to %{to_role}"
    member_removed: "%{actor} removed %{subject}"
    ownership_transferred: "%{actor} transferred ownership to %{subject}"
    password_changed: "%{actor} changed a password"
    password_reset: "%{actor} reset a password"
    passkey_added: "%{actor} added a passkey"
    passkey_renamed: "%{actor} renamed a passkey"
    passkey_removed: "%{actor} removed a passkey"
    second_factor_enabled: "%{actor} enabled passkey second factor"
    second_factor_disabled: "%{actor} disabled passkey second factor"
    signed_in: "%{actor} signed in"
    signed_out: "%{actor} signed out"
    import_completed: "%{actor} completed %{subject}: %{created_count} created, %{skipped_count} skipped"
    import_failed: "%{actor} could not complete %{subject}"
    export_generated: "%{actor} generated %{subject}"
    backup_queued: "%{actor} queued %{subject}"
    backup_succeeded: "%{actor} completed %{subject}"
    backup_failed: "%{actor} could not complete %{subject}"
    first_user_created: "%{actor} created the first instance administrator"
~~~

- [ ] **Step 3: Add every registry icon to the existing SVG allowlist**

Add these literal entries to `ApplicationHelper::MATERIAL_SYMBOL_PATHS`; never render an action or metadata value as SVG/path input:

~~~ruby
{
"backup" => "M19 11H5c-1.66 0-3 1.34-3 3v4c0 1.66 1.34 3 3 3h14c1.66 0 3-1.34 3-3v-4c0-1.66-1.34-3-3-3Zm0 8H5c-.55 0-1-.45-1-1v-4c0-.55.45-1 1-1h14c.55 0 1 .45 1 1v4c0 .55-.45 1-1 1ZM18 15.01h-2V17h2v-1.99ZM17 8H7V6h10v2Zm-2-4H9V2h6v2Z",
"build" => "M22.7 19 13.6 9.9c.9-2.3.4-5-1.5-6.9C10.1 1 7.1.6 4.7 1.7L9 6 6 9 1.6 4.7C.4 7.1.9 10.1 2.9 12.1c1.9 1.9 4.6 2.4 6.9 1.5l9.1 9.1c.4.4 1 .4 1.4 0l2.3-2.3c.5-.4.5-1.1.1-1.4Z",
"delete" => "M6 19c0 1.1.9 2 2 2h8c1.1 0 2-.9 2-2V7H6v12ZM8 9h8v10H8V9Zm7.5-5-1-1h-5l-1 1H5v2h14V4h-3.5Z",
"group" => "M16 11c1.66 0 2.99-1.34 2.99-3S17.66 5 16 5s-3 1.34-3 3 1.34 3 3 3Zm-8 0c1.66 0 2.99-1.34 2.99-3S9.66 5 8 5 5 6.34 5 8s1.34 3 3 3Zm0 2c-2.33 0-7 1.17-7 3.5V19h14v-2.5C15 14.17 10.33 13 8 13Zm8 0c-.29 0-.62.02-.97.05 1.16.84 1.97 1.97 1.97 3.45V19h6v-2.5c0-2.33-4.67-3.5-7-3.5Z",
"key" => "M7 14c-1.1 0-2-.9-2-2s.9-2 2-2 2 .9 2 2-.9 2-2 2Zm5.65-4A6 6 0 1 0 12.65 14H15v2h2v2h3v-3h2v-5h-9.35ZM7 16a4 4 0 1 1 3.46-6h9.54v3h-2v2h-2v-3h-5.54A4 4 0 0 1 7 16Z",
"link_off" => "M17 7h-4v2h4c1.66 0 3 1.34 3 3 0 .52-.13 1.01-.36 1.43l1.47 1.47A4.98 4.98 0 0 0 22 12c0-2.76-2.24-5-5-5ZM3.27 2 2 3.27l3.22 3.22A5 5 0 0 0 2 12c0 2.76 2.24 5 5 5h4v-2H7c-1.66 0-3-1.34-3-3 0-1.46 1.04-2.68 2.42-2.95L8.37 11H8v2h2.37l3.36 3.36A4.9 4.9 0 0 0 17 17h.73L20.46 19.73 21.73 18.46 3.27 2Z",
"login" => "M11 7 9.6 8.4l2.6 2.6H2v2h10.2l-2.6 2.6L11 17l5-5-5-5Zm9 12h-8v2h8c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2h-8v2h8v14Z",
"logout" => "M17 7 15.6 8.4l2.6 2.6H8v2h10.2l-2.6 2.6L17 17l5-5-5-5ZM4 5h8V3H4c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h8v-2H4V5Z",
"photo" => "M21 19V5c0-1.1-.9-2-2-2H5C3.9 3 3 3.9 3 5v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2ZM8.5 11.5 11 14.51 14.5 10l4.5 6H5l3.5-4.5Z",
"security" => "M12 1 3 5v6c0 5.55 3.84 10.74 9 12 5.16-1.26 9-6.45 9-12V5l-9-4Zm0 19.93C8.05 19.71 5 15.92 5 11V6.3l7-3.11 7 3.11V11c0 4.92-3.05 8.71-7 9.93Z",
"upload_file" => "M14 2H6c-1.1 0-1.99.9-1.99 2L4 20c0 1.1.89 2 1.99 2H18c1.1 0 2-.9 2-2V8l-6-6Zm2 12h-3v4h-2v-4H8l4-4 4 4Zm-3-5V3.5L18.5 9H13Z",
"visibility_off" => "M12 7c2.76 0 5 2.24 5 5 0 .65-.13 1.27-.35 1.84l2.92 2.92A11.8 11.8 0 0 0 22 12c-1.73-4.39-5.99-7.5-10.99-7.5-1.4 0-2.74.25-3.98.7l2.16 2.16C10.07 7.12 11.02 7 12 7ZM2.27 1 1 2.27l3.11 3.11A11.74 11.74 0 0 0 2 12c1.73 4.39 5.99 7.5 11 7.5 1.55 0 3.03-.3 4.38-.84L21.73 23 23 21.73 2.27 1ZM12 17c-2.76 0-5-2.24-5-5 0-.78.18-1.51.49-2.17l1.57 1.57A3 3 0 0 0 12.6 14.94l1.57 1.57A4.9 4.9 0 0 1 12 17Z",
}
~~~

- [ ] **Step 4: Wire controllers, filters, the shared partial, and pagination**

Replace `ActivityController#index` with:

~~~ruby
def index
  @activity_query = Activity::Query.new(
    workspace: current_workspace, membership: current_membership, user: Current.user,
    category: params[:category], actor: params[:actor],
    start_date: params[:start_date], end_date: params[:end_date]
  )
  @actor_options = @activity_query.actor_options
  @activity = HistoryPaginator.new(@activity_query.events, page: params[:page])
  @activity_filters_active = params.values_at(:category, :actor, :start_date, :end_date).any?(&:present?)
end
~~~

In `HomeController#load_dashboard`, replace the inferred feed assignment with:

~~~ruby
@recent_activity = Activity::Query.new(
  workspace: current_workspace, membership: current_membership, user: Current.user
).events.limit(8)
~~~

Create `app/views/activity/_event.html.erb`:

~~~erb
<% presenter = Activity::Presenter.new(event, helpers: self) %>
<% card = capture do %>
  <span data-testid="activity-icon-container" class="mt-0.5 flex h-9 w-9 shrink-0 items-center justify-center rounded-full <%= presenter.icon_container_classes %>"><%= material_symbol(presenter.icon) %></span>
  <span class="min-w-0">
    <span data-testid="activity-summary" class="block break-words font-extrabold text-rn-ink"><%= presenter.summary %></span>
    <span class="mt-1 block text-sm text-rn-muted">
      <%= profile_timestamp(presenter.timestamp) %> · <%= presenter.category_label %>
      <% if presenter.restricted? %><span data-testid="activity-restricted"><%= t("activity.index.restricted") %></span><% end %>
    </span>
  </span>
<% end %>
<% attributes = { data: { testid: "activity-card", visibility: event.visibility }, class: "flex gap-3 border-b border-rn-line p-4 last:border-b-0" } %>
<% if presenter.path %>
  <%= link_to presenter.path, **attributes.merge(class: "#{attributes[:class]} hover:bg-[var(--rn-surface-muted)]") do %><%= card %><% end %>
<% else %>
  <%= tag.div(card, **attributes) %>
<% end %>
~~~

In `app/views/activity/index.html.erb`, render a GET form with exactly these controls before the cards:

~~~erb
<%= form_with url: activity_path, method: :get, class: "mt-6 grid gap-3 md:grid-cols-5" do |form| %>
  <%= form.select :category, options_for_select(ActivityEvent::CATEGORIES.map { |value| [t("activity.categories.#{value}"), value] }, params[:category]), { include_blank: t("activity.index.all_categories") }, data: { testid: "activity-category" } %>
  <%= form.select :actor, options_for_select(@actor_options.map { |option| [option.label, option.value] }, params[:actor]), { include_blank: t("activity.index.all_actors") }, data: { testid: "activity-actor" } %>
  <%= form.date_field :start_date, value: params[:start_date], data: { testid: "activity-start-date" } %>
  <%= form.date_field :end_date, value: params[:end_date], data: { testid: "activity-end-date" } %>
  <%= form.submit t("activity.index.filter") %>
<% end %>

<% if @activity.any? %>
  <div class="mt-8 overflow-hidden rounded-2xl border border-rn-line bg-rn-surface shadow-sm">
    <%= render partial: "activity/event", collection: @activity.records, as: :event %>
  </div>
  <%= render "shared/history_pagination", paginator: @activity, params: request.query_parameters.except("page") %>
<% else %>
  <p data-testid="activity-empty" class="mt-8 rounded-2xl border border-rn-line bg-rn-surface p-5 text-sm font-semibold text-rn-ink">
    <%= t(@activity_filters_active ? ".filtered_empty" : ".empty") %>
  </p>
<% end %>
~~~

Replace the case statement in the dashboard recent-activity section with:

~~~erb
<%= render partial: "activity/event", collection: @recent_activity, as: :event %>
~~~

- [ ] **Step 5: Prove both surfaces pass, then remove the inferred feed**

~~~bash
bin/rails test test/presenters/activity/presenter_test.rb test/controllers/activity_controller_test.rb test/controllers/home_controller_test.rb
~~~

Expected: PASS. Now delete only `app/services/workspace_activity_feed.rb` and `test/services/workspace_activity_feed_test.rb`, then run:

~~~bash
bin/rails test test/controllers/activity_controller_test.rb test/controllers/home_controller_test.rb
rg -n "WorkspaceActivityFeed" app test
~~~

Expected: controller tests PASS; `rg` exits 1 with no matches.

- [ ] **Step 6: Commit the feed replacement**

~~~bash
git add app/presenters/activity/presenter.rb app/controllers/activity_controller.rb app/controllers/home_controller.rb app/views/activity app/views/workspaces/show.html.erb app/helpers/application_helper.rb config/locales/en.yml test/presenters/activity/presenter_test.rb test/controllers/activity_controller_test.rb test/controllers/home_controller_test.rb app/services/workspace_activity_feed.rb test/services/workspace_activity_feed_test.rb
git commit -m "Render authorized activity ledger feeds"
~~~

---

### Task 5: Emit Coffee, Bean, And Inventory Mutations Atomically

**Files:**

- Modify: `test/controllers/brews_controller_test.rb`
- Modify: `test/controllers/external_coffees_controller_test.rb`
- Modify: `test/controllers/beans_controller_test.rb`
- Modify: `test/controllers/inventory_adjustments_controller_test.rb`
- Modify: `app/controllers/brews_controller.rb`
- Modify: `app/controllers/external_coffees_controller.rb`
- Modify: `app/controllers/beans_controller.rb`
- Modify: `app/controllers/inventory_adjustments_controller.rb`

**Interfaces:**

- Successful explicit mutations produce exactly these actions:

| Controller action | Ledger action | Event time |
|---|---|---|
| `BrewsController#create/update/taste/serving/destroy` | `brew.created/updated/taste_changed/serving_changed/deleted` | create uses `@brew.occurred_at`; others commit time |
| `ExternalCoffeesController#create/update/destroy` | `external_coffee.created/updated/deleted` | create uses `@external_coffee.occurred_at`; others commit time |
| `BeansController#create/update/duplicate/open_bag/finish/close/reopen/destroy` | `bean.created`, resolved update lifecycle or `bean.updated`, `bean.duplicated`, `bean.opened`, `bean.finished`, `bean.archived`, `bean.reopened`, `bean.deleted` | commit time |
| Brew/manual inventory depletion | additional `bean.used_up` only when the same successful transaction changes the bean from non-`used_up` to `used_up` | commit time |
| `InventoryAdjustmentsController#create` | `inventory_adjustment.created` | `@inventory_adjustment.occurred_at` |

- Cascading Brew/adjustment removal in `Bean#destroy_with_history!` produces only `bean.deleted`; those are implementation children, not separate authenticated mutations.
- Photos and record-link nested attributes submitted in a parent create/update are represented by that one parent action and do not expose their values.

- [ ] **Step 1: Add one-event, lifecycle, failure, and rollback assertions**

Wrap the existing successful request in each controller test with `assert_activity_event`. Add this focused coverage to `test/controllers/brews_controller_test.rb`:

~~~ruby
test "create records domain occurrence and taste serving update and delete use explicit actions" do
  sign_in_as(users(:one))
  occurred_at = Time.zone.local(2026, 8, 20, 7, 15)

  event = assert_activity_event(action: "brew.created", workspace: workspaces(:household), actor: users(:one)) do
    post brews_path, params: { brew: {
      method: "espresso", bean_id: beans(:open_household).id,
      grinder_id: equipment(:household_grinder).id, machine_id: equipment(:household_machine).id,
      occurred_at:, bean_weight_grams: "1", ground_weight_grams: "1",
      dose_grams: "1", beverage_grams: "2", taste_balance: "neutral"
    } }
  end
  assert_equal occurred_at, event.occurred_at

  brew = event.subject
  assert_activity_event(action: "brew.taste_changed", workspace: workspaces(:household), actor: users(:one), subject: brew) do
    patch taste_brew_path(brew), params: { brew: { rating: 5, taste_balance: "bitter" } }
  end
  assert_activity_event(action: "brew.serving_changed", workspace: workspaces(:household), actor: users(:one), subject: brew) do
    patch serving_brew_path(brew), params: { brew: { served_for_guest: "1", guest_name: "Guest" } }
  end
  assert_activity_event(action: "brew.deleted", workspace: workspaces(:household), actor: users(:one)) do
    delete brew_path(brew)
  end
  assert_equal event.metadata.fetch("subject_label"), ActivityEvent.where(action: "brew.deleted").order(:id).last.metadata.fetch("subject_label")
end

test "invalid create emits nothing" do
  sign_in_as(users(:one))
  assert_no_difference -> { ActivityEvent.count } do
    post brews_path, params: { brew: { method: "espresso", bean_weight_grams: "" } }
  end
  assert_response :unprocessable_entity
end

test "bean depletion emits only brew created plus the documented used up transition" do
  sign_in_as(users(:one))
  bean = beans(:open_household)
  bean.update!(remaining_grams: 1)

  event = assert_activity_event(
    action: "brew.created", workspace: bean.workspace, actor: users(:one),
    additional_actions: [ "bean.used_up" ]
  ) do
    post brews_path, params: { brew: {
      method: "espresso", bean_id: bean.id, grinder_id: equipment(:household_grinder).id,
      machine_id: equipment(:household_machine).id, bean_weight_grams: "1", dose_grams: "1",
      beverage_grams: "2", taste_balance: "neutral"
    } }
  end

  assert_predicate bean.reload, :used_up?
  assert_equal "brew.created", event.action
end

test "create rolls back brew inventory activity and refreshed snapshots when a refresher fails" do
  sign_in_as(users(:one))
  bean = beans(:second_open_household)
  share = create_public_bean_share_for(bean)
  original_snapshot = share.snapshot.deep_dup
  original_remaining = bean.remaining_grams
  failing_refresh = lambda do |_record|
    share.update!(snapshot: share.snapshot.merge("rollback_marker" => true))
    raise "public snapshot refresh failed"
  end

  assert_no_difference -> { ActivityEvent.count } do
    assert_no_difference -> { Brew.count } do
      PublicBeanShareRefresher.stub(:refresh_comparisons_for, failing_refresh) do
        assert_raises(RuntimeError) do
          post brews_path, params: { brew: {
            method: "espresso", bean_id: bean.id, grinder_id: equipment(:household_grinder).id,
            machine_id: equipment(:household_machine).id, bean_weight_grams: "18", dose_grams: "18",
            beverage_grams: "40", taste_balance: "neutral"
          } }
        end
      end
    end
  end
  assert_equal original_remaining, bean.reload.remaining_grams
  assert_equal original_snapshot, share.reload.snapshot
end
~~~

Add to `test/controllers/beans_controller_test.rb`:

~~~ruby
test "bean lifecycle routes emit the specific action rather than bean updated" do
  sign_in_as(users(:one))
  bean = beans(:second_open_household)
  bean.apply_bag_status("stock")
  bean.save!

  assert_activity_event(action: "bean.opened", workspace: bean.workspace, actor: users(:one), subject: bean) do
    patch open_bag_bean_path(bean)
  end
  assert_activity_event(action: "bean.finished", workspace: bean.workspace, actor: users(:one), subject: bean) do
    patch finish_bean_path(bean)
  end
  assert_activity_event(action: "bean.reopened", workspace: bean.workspace, actor: users(:one), subject: bean) do
    patch reopen_bean_path(bean)
  end
  assert_activity_event(action: "bean.archived", workspace: bean.workspace, actor: users(:one), subject: bean) do
    patch close_bean_path(bean)
  end
  assert_equal 0, ActivityEvent.where(action: "bean.updated", subject: bean).count
end

test "emitter failure rolls back the domain mutation" do
  sign_in_as(users(:one))
  bean = beans(:open_household)
  old_name = bean.name

  Activity::Emitter.stub(:record!, ->(**) { raise "activity write failed" }) do
    assert_raises(RuntimeError) do
      patch bean_path(bean), params: { bean: { name: "Must roll back", bag_size_grams: bean.bag_size_grams } }
    end
  end

  assert_equal old_name, bean.reload.name
end
~~~

For the other actions, add the same helper around their existing valid-request tests and assert this exact action set:

~~~ruby
assert_equal %w[
  brew.created brew.updated brew.taste_changed brew.serving_changed brew.deleted brew.media_updated
  external_coffee.created external_coffee.updated external_coffee.deleted external_coffee.media_updated
  bean.created bean.updated bean.duplicated bean.opened bean.finished bean.used_up bean.archived bean.reopened bean.deleted bean.media_updated
  inventory_adjustment.created
].sort, Activity::EventContract.actions.grep(/\A(?:brew|external_coffee|bean|inventory_adjustment)\./).sort
~~~

Because `assert_activity_event` compares every new row by ID, each wrapped request now fails on a second generic or lifecycle action even when that action differs from the expected one. Pass `additional_actions: [ "bean.used_up" ]` only in the Brew and manual-adjustment depletion examples; every other focused request must add exactly one row.

Run:

~~~bash
bin/rails test test/controllers/brews_controller_test.rb test/controllers/external_coffees_controller_test.rb test/controllers/beans_controller_test.rb test/controllers/inventory_adjustments_controller_test.rb
~~~

Expected: FAIL because no requests emit the expected actions and the emitter-failure request leaves the bean changed.

- [ ] **Step 2: Wrap Brew and External Coffee writes**

Use the controller helper around each existing mutation. The Brew create shape is:

~~~ruby
previous_status = @brew.bean.bag_status
created = with_workspace_activity(
  action: "brew.created", subject: -> { @brew }, occurred_at: -> { @brew.occurred_at }
) do
  saved = save_brew_with_preparation_tools
  if saved
    refresh_public_shares_for(@brew, comparisons: true)
    record_used_up_transition!(@brew.bean, previous_status:)
  end
  saved
end

if created
  redirect_to @brew, notice: t(".created")
else
  prepare_record_links(@brew)
  render :new, status: :unprocessable_entity
end
~~~

For Brew update, keep `update_with_inventory_correction!`, share refresh, and event creation inside one explicit transaction because the domain helper raises on failure:

~~~ruby
ActiveRecord::Base.transaction do
  target_bean_id = attributes[:bean_id].presence || @brew.bean_id
  target_bean = current_workspace.beans.find(target_bean_id)
  previous_status = target_bean.bag_status
  @brew.update_with_inventory_correction!(attributes, preparation_tools: @selected_preparation_tools)
  refresh_public_shares_for(@brew, comparisons: comparison_inputs_changed?(@brew))
  Activity::Emitter.record!(
    action: "brew.updated", workspace: current_workspace, actor: Current.user, subject: @brew
  )
  record_used_up_transition!(target_bean, previous_status:)
end
~~~

Implement `taste` and `serving` through `with_workspace_activity` with their explicit actions. Capture `subject_label = Activity::Metadata.subject_label(@brew)` before `destroy_with_inventory_reversal!`; pass the destroyed Brew as subject and `{}` details to the emitter in the same transaction so its retained ID and safe snapshot become the tombstone. Apply the identical wrapper pattern to External Coffee create/update/delete, using `@external_coffee.occurred_at` only for create.

- [ ] **Step 3: Resolve Bean lifecycle actions and depletion in the transaction**

In `BeansController#update`, capture `previous_status = @bean.bag_status` before assignment and use this resolver only after a successful save:

~~~ruby
def bean_update_activity_action(previous_status)
  current_status = @bean.bag_status
  return "bean.updated" if current_status == previous_status

  return "bean.opened" if previous_status == "stock" && current_status == "open"
  return "bean.reopened" if current_status == "open" && previous_status.in?(%w[finished used_up archived])
  return "bean.finished" if current_status == "finished"
  return "bean.used_up" if current_status == "used_up"
  return "bean.archived" if current_status == "archived"

  "bean.updated"
end
~~~

Wrap `create`, `update`, `open_bag`, `finish`, `close`, and `reopen` with the matching table action. Wrap `duplicate_for_new_bag!` with subject `-> { duplicate }`, action `bean.duplicated`, and `details: -> { { source_label: @bean.display_name } }`. Wrap `destroy_with_history!` with `bean.deleted`; do not emit child Brew deletions.

Add this private helper to both `BrewsController` and `InventoryAdjustmentsController` and call it inside their already-open mutation transaction after inventory changes:

~~~ruby
def record_used_up_transition!(bean, previous_status:)
  bean.reload
  return unless previous_status != "used_up" && bean.used_up?

  Activity::Emitter.record!(
    action: "bean.used_up", workspace: current_workspace, actor: Current.user, subject: bean
  )
end
~~~

In `InventoryAdjustmentsController#create`, capture the previous bean status, call `save_with_inventory_update`, emit `inventory_adjustment.created` at its `occurred_at`, then call `record_used_up_transition!` within one outer `ActiveRecord::Base.transaction`. A failed `save_with_inventory_update` rolls the outer transaction back and emits neither event.

- [ ] **Step 4: Run focused coverage and check accidental duplicate noise**

~~~bash
bin/rails test test/controllers/brews_controller_test.rb test/controllers/external_coffees_controller_test.rb test/controllers/beans_controller_test.rb test/controllers/inventory_adjustments_controller_test.rb
~~~

Expected: tests PASS; every focused request's helper assertion proves the exact new-action multiset, including the one explicitly allowed `brew.created` plus `bean.used_up` case.

- [ ] **Step 5: Commit coffee and inventory emission**

~~~bash
git add app/controllers/brews_controller.rb app/controllers/external_coffees_controller.rb app/controllers/beans_controller.rb app/controllers/inventory_adjustments_controller.rb test/controllers/brews_controller_test.rb test/controllers/external_coffees_controller_test.rb test/controllers/beans_controller_test.rb test/controllers/inventory_adjustments_controller_test.rb
git commit -m "Audit coffee bean and inventory mutations"
~~~

---

### Task 6: Emit Gear, Recipe, Share, And Media Mutations

**Files:**

- Modify: `test/controllers/equipment_controller_test.rb`
- Modify: `test/controllers/preparation_tools_controller_test.rb`
- Modify: `test/controllers/equipment_events_controller_test.rb`
- Modify: `test/controllers/recipes_controller_test.rb`
- Modify: `test/controllers/public_brew_shares_controller_test.rb`
- Modify: `test/controllers/public_bean_shares_controller_test.rb`
- Modify: `test/controllers/public_recipe_shares_controller_test.rb`
- Modify: `test/controllers/media_attachments_controller_test.rb`
- Modify: `test/controllers/public_brew_media_controller_test.rb`
- Modify: `test/controllers/public_bean_media_controller_test.rb`
- Modify: `test/controllers/public_recipe_media_controller_test.rb`
- Modify: `test/controllers/public_bean_pages_controller_test.rb`
- Modify: `test/controllers/public_recipe_pages_controller_test.rb`
- Modify: `app/controllers/equipment_controller.rb`
- Modify: `app/controllers/preparation_tools_controller.rb`
- Modify: `app/controllers/equipment_events_controller.rb`
- Modify: `app/controllers/recipes_controller.rb`
- Modify: `app/controllers/public_brew_shares_controller.rb`
- Modify: `app/controllers/public_bean_shares_controller.rb`
- Modify: `app/controllers/public_recipe_shares_controller.rb`
- Modify: `app/controllers/media_attachments_controller.rb`

**Interfaces:**

| Family | Exact action selection |
|---|---|
| Equipment | `create -> equipment.created`, `update -> equipment.updated`, `archive -> equipment.archived`, `reopen -> equipment.reopened`, `destroy -> equipment.deleted` |
| Preparation Tool | `create -> preparation_tool.created`, `update -> preparation_tool.updated`, `archive -> preparation_tool.archived`, `reopen -> preparation_tool.reopened`, `destroy -> preparation_tool.deleted` |
| Equipment Event | `create -> equipment_event.created` at domain occurrence; `update -> equipment_event.updated`; `destroy -> equipment_event.deleted` |
| Recipe | `create -> recipe.created`, `import -> recipe.imported`, `update -> recipe.updated`, `export -> recipe.exported`, `destroy -> recipe.deleted` |
| Each public Brew/Bean/Recipe share | create disabled draft -> `.created`; create enabled or disabled-to-enabled -> `.published`; enabled-to-disabled -> `.disabled`; other update -> `.updated`; destroy -> `.deleted` |
| Standalone crop/primary/remove | parent-specific `brew`, `external_coffee`, `bean`, `equipment`, `preparation_tool`, `equipment_event`, or `recipe` `.media_updated`; Workspace -> `workspace.media_updated`; User -> `profile.media_updated` |

- Direct GETs/downloads of private media and all anonymous public page/media routes never emit activity.
- A share event stores its title/enabled boolean snapshot only; it never stores the token, password digest, selected attachment IDs, snapshot, or public URL.

- [ ] **Step 1: Add failing family matrix and transaction tests**

Add to the named controller tests around their existing successful requests. Keep this contract assertion in `test/controllers/equipment_controller_test.rb` so a missing family action is immediately visible:

~~~ruby
test "gear recipe share and media action registry is complete" do
  expected = %w[
    equipment.created equipment.updated equipment.archived equipment.reopened equipment.deleted equipment.media_updated
    preparation_tool.created preparation_tool.updated preparation_tool.archived preparation_tool.reopened
    preparation_tool.deleted preparation_tool.media_updated equipment_event.created equipment_event.updated
    equipment_event.deleted equipment_event.media_updated recipe.created recipe.imported recipe.updated recipe.exported
    recipe.deleted recipe.media_updated public_brew_share.created public_brew_share.published
    public_brew_share.updated public_brew_share.disabled public_brew_share.deleted public_bean_share.created
    public_bean_share.published public_bean_share.updated public_bean_share.disabled public_bean_share.deleted
    public_recipe_share.created public_recipe_share.published public_recipe_share.updated
    public_recipe_share.disabled public_recipe_share.deleted
  ]

  assert_equal expected.sort, Activity::EventContract.actions.grep(
    /\A(?:equipment|preparation_tool|equipment_event|recipe|public_brew_share|public_bean_share|public_recipe_share)\./
  ).sort
end
~~~

Add a public-share transition test to each of the three share-controller suites; this Brew version is the exact pattern:

~~~ruby
test "share draft publish edit disable and delete emit one safe action each" do
  sign_in_as(users(:one))
  brew = brews(:morning_espresso)

  assert_activity_event(action: "public_brew_share.created", workspace: brew.workspace, actor: users(:one)) do
    post brew_public_brew_share_path(brew), params: {
      public_brew_share: { title: "House recipe", enabled: "0", password: "secret-share-password" }
    }
  end
  share = brew.reload.public_brew_share
  assert_activity_event(action: "public_brew_share.published", workspace: brew.workspace, actor: users(:one), subject: share) do
    patch brew_public_brew_share_path(brew), params: { public_brew_share: { title: "House recipe", enabled: "1" } }
  end
  assert_activity_event(action: "public_brew_share.updated", workspace: brew.workspace, actor: users(:one), subject: share) do
    patch brew_public_brew_share_path(brew), params: { public_brew_share: { title: "New safe title", enabled: "1" } }
  end
  assert_activity_event(action: "public_brew_share.disabled", workspace: brew.workspace, actor: users(:one), subject: share) do
    patch brew_public_brew_share_path(brew), params: { public_brew_share: { title: "New safe title", enabled: "0" } }
  end
  event = assert_activity_event(action: "public_brew_share.deleted", workspace: brew.workspace, actor: users(:one)) do
    delete brew_public_brew_share_path(brew)
  end
  assert_no_match(/secret-share-password|token|digest|attachment|https?:\/\//i, event.metadata.to_json)
end
~~~

Also add these transaction-boundary regressions to `test/controllers/public_brew_shares_controller_test.rb`:

~~~ruby
test "bean-share refresher failure rolls back public brew share creation activity and snapshot writes" do
  sign_in_as(users(:one))
  brew = brews(:morning_espresso)
  bean_share = create_public_bean_share_for(brew.bean, user: users(:one))
  original_bean_snapshot = bean_share.snapshot.deep_dup
  failing_refresh = lambda do |_record|
    bean_share.update!(snapshot: bean_share.snapshot.merge("rollback_marker" => "create"))
    raise "public bean refresh failed"
  end

  assert_no_difference -> { ActivityEvent.count } do
    assert_no_difference -> { PublicBrewShare.count } do
      PublicBeanShareRefresher.stub(:refresh_for, failing_refresh) do
        assert_raises(RuntimeError) do
          post brew_public_brew_share_path(brew), params: {
            public_brew_share: { title: "Must roll back", enabled: "1" }
          }
        end
      end
    end
  end
  assert_equal original_bean_snapshot, bean_share.reload.snapshot
end

test "bean-share refresher failure rolls back public brew share update and destroy with no activity" do
  sign_in_as(users(:one))
  brew = brews(:morning_espresso)
  share = create_share_for(brew, user: users(:one), enabled: false, title: "Original title")
  bean_share = create_public_bean_share_for(brew.bean, user: users(:one))
  original_share_snapshot = share.snapshot.deep_dup
  original_bean_snapshot = bean_share.snapshot.deep_dup
  failing_refresh = lambda do |_record|
    bean_share.update!(snapshot: bean_share.snapshot.merge("rollback_marker" => "mutation"))
    raise "public bean refresh failed"
  end

  assert_no_difference -> { ActivityEvent.count } do
    PublicBeanShareRefresher.stub(:refresh_for, failing_refresh) do
      assert_raises(RuntimeError) do
        patch brew_public_brew_share_path(brew), params: {
          public_brew_share: { title: "Changed title", enabled: "1" }
        }
      end
    end
  end
  assert_equal "Original title", share.reload.title
  assert_not share.enabled?
  assert_equal original_share_snapshot, share.snapshot
  assert_equal original_bean_snapshot, bean_share.reload.snapshot

  assert_no_difference -> { ActivityEvent.count } do
    assert_no_difference -> { PublicBrewShare.count } do
      PublicBeanShareRefresher.stub(:refresh_for, failing_refresh) do
        assert_raises(RuntimeError) { delete brew_public_brew_share_path(brew) }
      end
    end
  end
  assert PublicBrewShare.exists?(share.id)
  assert_equal original_bean_snapshot, bean_share.reload.snapshot
end
~~~

Add to `test/controllers/media_attachments_controller_test.rb`:

~~~ruby
test "primary crop and remove emit one parent media event without attachment internals" do
  sign_in_as(users(:one))
  bean = beans(:open_household)
  attachment = attach_photo(bean)

  event = assert_activity_event(action: "bean.media_updated", workspace: bean.workspace, actor: users(:one), subject: bean) do
    patch primary_media_attachment_path(attachment)
  end

  assert_equal %w[actor_kind actor_label record_kind subject_label status].sort, event.metadata.keys.sort
  assert_no_match(/attachment|filename|rails\/active_storage|media_attachments/i, event.metadata.to_json)
end

test "media reads and anonymous public media reads do not emit" do
  sign_in_as(users(:one))
  attachment = attach_photo(beans(:open_household))
  assert_no_difference -> { ActivityEvent.count } do
    get media_attachment_path(attachment)
  end
end
~~~

In the first successful-stream test of each public media controller, wrap the existing GET exactly the same way. For example, in `PublicBeanMediaControllerTest`:

~~~ruby
assert_no_difference -> { ActivityEvent.count } do
  get public_bean_media_path(share.token, handle)
end
assert_response :success
~~~

Apply that assertion to `public_media_path_for(share, photo)` in the Brew test and `public_recipe_media_path(share.token, share.public_media_handle_for(photo.id), variant: "thumbnail")` in the Recipe test. These requests remain unauthenticated and continue to assert their safe image response.

Also wrap `get public_bean_page_path(share.token)` in the Bean page test named `hero shows the share title between the coffee name and statistic cards`, and `get public_recipe_page_path(share.token)` in the Recipe page test named `enabled share renders public snapshot without authentication`, with `assert_no_difference -> { ActivityEvent.count }`. Together with the Brew-page test in Task 4, this proves all three anonymous page families stay analytics-only.

Run:

~~~bash
bin/rails test test/controllers/equipment_controller_test.rb test/controllers/preparation_tools_controller_test.rb test/controllers/equipment_events_controller_test.rb test/controllers/recipes_controller_test.rb test/controllers/public_brew_shares_controller_test.rb test/controllers/public_bean_shares_controller_test.rb test/controllers/public_recipe_shares_controller_test.rb test/controllers/media_attachments_controller_test.rb
~~~

Expected: FAIL on the first missing activity event; current domain behavior assertions remain green.

- [ ] **Step 2: Wrap gear and maintenance mutations**

For Equipment and Preparation Tool, use `with_workspace_activity` around each successful save/lifecycle helper and keep share refresh inside the wrapper. For deletion, compute affected share IDs first, then run domain deletion, share refresh, and the tombstone event inside the same outer transaction. For Equipment Event create, the exact shape is:

~~~ruby
created = with_workspace_activity(
  action: "equipment_event.created",
  subject: -> { @equipment_event },
  occurred_at: -> { @equipment_event.occurred_at }
) do
  saved = @equipment_event.save
  @equipment_event.photos.attach(photos) if saved && photos.any?
  saved
end
~~~

Use `equipment_event.updated` at commit time for update and `equipment_event.deleted` for destroy. Parent form photo/link changes remain part of the create/update event.

- [ ] **Step 3: Wrap Recipe create/import/update/export/delete**

Keep `RecipeImporter#call` unchanged and put its transaction inside the controller's outer activity transaction:

~~~ruby
recipe = nil
with_workspace_activity(action: "recipe.imported", subject: -> { recipe }) do
  recipe = RecipeImporter.new(
    workspace: current_workspace, user: Current.user, json: uploaded_file.read
  ).call
end
redirect_to recipe, notice: t(".created")
~~~

Invalid JSON continues through `RecipeImporter::ImportError` and emits no event. Wrap create/update/delete with `recipe.created/updated/deleted`. In `export`, generate the payload before recording, then record in a transaction and call `send_data` with that already-generated payload:

~~~ruby
payload = JSON.pretty_generate(RecipeExporter.new(@recipe).call)
ActivityEvent.transaction do
  Activity::Emitter.record!(
    action: "recipe.exported", workspace: current_workspace, actor: Current.user, subject: @recipe
  )
end
send_data payload, filename: @recipe.export_filename, type: "application/json", disposition: "attachment"
~~~

- [ ] **Step 4: Resolve public-share transitions after successful snapshot refresh**

In each share controller, capture `was_new = @share.new_record?` and `was_enabled = @share.enabled?` before assignment. Inside the existing `Public*Share.transaction`, run `refresh_snapshot!`, then emit exactly one result from:

~~~ruby
def share_activity_action(prefix:, was_new:, was_enabled:)
  if was_new
    @share.enabled? ? "#{prefix}.published" : "#{prefix}.created"
  elsif !was_enabled && @share.enabled?
    "#{prefix}.published"
  elsif was_enabled && !@share.enabled?
    "#{prefix}.disabled"
  else
    "#{prefix}.updated"
  end
end
~~~

Call the resolver with `public_brew_share`, `public_bean_share`, or `public_recipe_share`. Emit after snapshot validation so a failed refresh produces no event. For destroy, emit `.deleted` in the same transaction as `destroy!` and retain only the safe title tombstone.

`PublicBrewSharesController` also refreshes the directly affected public Bean snapshot. Keep that refresher inside the same outer transaction for create/update and destroy; replace `save_share!` and the mutation portion of `destroy` with these exact boundaries:

~~~ruby
def save_share!
  was_new = @share.new_record?
  was_enabled = @share.enabled?
  PublicBrewShare.transaction do
    @share.assign_attributes(title: share_params[:title], enabled: share_params[:enabled] == "1")
    @share.created_by ||= Current.user
    @share.updated_by = Current.user
    apply_password_changes
    @share.refresh_snapshot!(
      title: share_params[:title],
      selected_photo_attachment_ids: permitted_selected_photo_attachment_ids,
      updated_by: Current.user
    )
    PublicBeanShareRefresher.refresh_for(@brew)
    Activity::Emitter.record!(
      action: share_activity_action(prefix: "public_brew_share", was_new:, was_enabled:),
      workspace: current_workspace, actor: Current.user, subject: @share
    )
  end
end

PublicBrewShare.transaction do
  @share.destroy!
  PublicBeanShareRefresher.refresh_for(@brew)
  Activity::Emitter.record!(
    action: "public_brew_share.deleted", workspace: current_workspace,
    actor: Current.user, subject: @share
  )
end
~~~

Do not leave a `PublicBeanShareRefresher.refresh_for(@brew)` call after either transaction. The stubbed tests deliberately persist a snapshot marker and then raise, proving the enclosing transaction restores the Brew share, public Bean snapshot, and event count together.

- [ ] **Step 5: Emit one parent action for standalone media writes**

Add this class-to-action map to `MediaAttachmentsController`; `fetch` intentionally fails closed for a future record type:

~~~ruby
MEDIA_ACTIVITY_ACTIONS = {
  "Bean" => "bean.media_updated",
  "Brew" => "brew.media_updated",
  "ExternalCoffee" => "external_coffee.media_updated",
  "Recipe" => "recipe.media_updated",
  "Equipment" => "equipment.media_updated",
  "PreparationTool" => "preparation_tool.media_updated",
  "EquipmentEvent" => "equipment_event.media_updated",
  "Workspace" => "workspace.media_updated",
  "User" => "profile.media_updated"
}.freeze

def record_media_activity!(record)
  action = MEDIA_ACTIVITY_ACTIONS.fetch(record.class.base_class.name)
  Activity::Emitter.record!(
    action:, workspace: current_workspace, actor: Current.user, subject: record
  )
end
~~~

Place `set_primary_photo!` plus `record_media_activity!`, attachment `destroy!` plus emission, and the complete crop transaction plus emission in one outer `record.transaction`. Keep `refresh_public_shares_for(record)` inside that transaction. Do not call the emitter from `show`, `download`, public media controllers, or view recorders.

- [ ] **Step 6: Run focused and public-read regression suites**

~~~bash
bin/rails test test/controllers/equipment_controller_test.rb test/controllers/preparation_tools_controller_test.rb test/controllers/equipment_events_controller_test.rb test/controllers/recipes_controller_test.rb test/controllers/public_brew_shares_controller_test.rb test/controllers/public_bean_shares_controller_test.rb test/controllers/public_recipe_shares_controller_test.rb test/controllers/media_attachments_controller_test.rb test/controllers/public_brew_pages_controller_test.rb test/controllers/public_bean_pages_controller_test.rb test/controllers/public_recipe_pages_controller_test.rb test/controllers/public_brew_media_controller_test.rb test/controllers/public_bean_media_controller_test.rb test/controllers/public_recipe_media_controller_test.rb
~~~

Expected: PASS; existing view-counter assertions still change only their analytics tables, never `ActivityEvent`.

- [ ] **Step 7: Commit gear, sharing, and media emission**

~~~bash
git add app/controllers/equipment_controller.rb app/controllers/preparation_tools_controller.rb app/controllers/equipment_events_controller.rb app/controllers/recipes_controller.rb app/controllers/public_brew_shares_controller.rb app/controllers/public_bean_shares_controller.rb app/controllers/public_recipe_shares_controller.rb app/controllers/media_attachments_controller.rb test/controllers/equipment_controller_test.rb test/controllers/preparation_tools_controller_test.rb test/controllers/equipment_events_controller_test.rb test/controllers/recipes_controller_test.rb test/controllers/public_brew_shares_controller_test.rb test/controllers/public_bean_shares_controller_test.rb test/controllers/public_recipe_shares_controller_test.rb test/controllers/media_attachments_controller_test.rb test/controllers/public_brew_media_controller_test.rb test/controllers/public_bean_media_controller_test.rb test/controllers/public_recipe_media_controller_test.rb test/controllers/public_bean_pages_controller_test.rb test/controllers/public_recipe_pages_controller_test.rb
git commit -m "Audit gear recipe sharing and media mutations"
~~~

---

### Task 7: Emit Household Administration And Account Security Mutations

**Files:**

- Modify: `test/controllers/workspace_onboardings_controller_test.rb`
- Modify: `test/controllers/workspaces_controller_test.rb`
- Modify: `test/controllers/workspace_invites_controller_test.rb`
- Modify: `test/controllers/household_invites_controller_test.rb`
- Modify: `test/controllers/instance_admin_household_invites_controller_test.rb`
- Modify: `test/controllers/memberships_controller_test.rb`
- Modify: `test/services/workspace_membership_manager_test.rb`
- Modify: `test/controllers/profiles_controller_test.rb`
- Modify: `test/controllers/password_changes_controller_test.rb`
- Modify: `test/controllers/passwords_controller_test.rb`
- Modify: `test/controllers/passkey_credentials_controller_test.rb`
- Modify: `test/controllers/passkey_second_factors_controller_test.rb`
- Modify: `test/controllers/sessions_controller_test.rb`
- Modify: `test/controllers/passkey_sessions_controller_test.rb`
- Modify: `test/controllers/first_user_setups_controller_test.rb`
- Modify: `test/controllers/concerns/authentication_test.rb`
- Modify: `app/controllers/workspace_onboardings_controller.rb`
- Modify: `app/controllers/workspaces_controller.rb`
- Modify: `app/controllers/workspace_invites_controller.rb`
- Modify: `app/controllers/household_invites_controller.rb`
- Modify: `app/controllers/instance_admin/household_invites_controller.rb`
- Modify: `app/controllers/memberships_controller.rb`
- Modify: `app/controllers/profiles_controller.rb`
- Modify: `app/controllers/password_changes_controller.rb`
- Modify: `app/controllers/passwords_controller.rb`
- Modify: `app/controllers/passkey_credentials_controller.rb`
- Modify: `app/controllers/passkey_second_factors_controller.rb`
- Modify: `app/controllers/sessions_controller.rb`
- Modify: `app/controllers/passkey_sessions_controller.rb`
- Modify: `app/controllers/first_user_setups_controller.rb`
- Modify: `app/controllers/concerns/authentication.rb`
- Modify: `app/services/workspace_membership_manager.rb`

**Interfaces:**

- Workspace and workspace-invite actions are `workspace_admin`; workspace deletion and instance household-invite management are `instance_admin`; household-invite acceptance is attached to the newly created workspace as `workspace_admin`.
- Membership emission lives in `WorkspaceMembershipManager`, the shared mutation boundary, not in both callers.
- `start_new_session_for(user, authentication_method:)` and `terminate_session` own `session.signed_in/out`; authentication methods are allowlisted short values `password`, `passkey`, `passkey_second_factor`, or `invited_signup`.
- Password-reset requests and failed password/passkey/session attempts emit nothing, avoiding account-discovery and credential-guess noise.

- [ ] **Step 1: Add failing authorization, secret, and session assertions**

Add this registry contract test to `test/controllers/workspaces_controller_test.rb`:

~~~ruby
test "household and security action registry is complete" do
  expected = %w[
    workspace.created workspace.updated workspace.media_updated workspace.deleted
    workspace_invite.created workspace_invite.accepted workspace_invite.revoked workspace_invite.resent workspace_invite.reinvited
    membership.role_changed membership.removed membership.ownership_transferred
    household_invite.created household_invite.accepted household_invite.revoked household_invite.resent household_invite.reinvited
    profile.updated profile.media_updated password.changed password.reset passkey.created passkey.renamed passkey.deleted
    passkey.second_factor_enabled passkey.second_factor_disabled session.signed_in session.signed_out instance.first_user_created
  ]
  assert_equal expected.sort, Activity::EventContract.actions.grep(
    /\A(?:workspace\.|workspace_invite\.|membership\.|household_invite\.|profile\.|password\.|passkey\.|session\.|instance\.first_user_created\z)/
  ).sort
end
~~~

Add to `test/controllers/workspace_invites_controller_test.rb`:

~~~ruby
test "invite lifecycle is admin-visible and stores neither email nor token" do
  sign_in_as(users(:one))
  event = assert_activity_event(action: "workspace_invite.created", workspace: workspaces(:household), actor: users(:one)) do
    post workspace_invites_path, params: { workspace_invite: { email_address: "invitee@example.test", role: "member" } }
  end

  assert_equal "workspace_admin", event.visibility
  assert_equal "member", event.metadata.fetch("role")
  assert_no_match(/invitee@example|token|http/i, event.metadata.to_json)
end
~~~

Add to `test/controllers/sessions_controller_test.rb`:

~~~ruby
test "successful password sign in and sign out emit safe account events" do
  user = users(:one)
  event = assert_activity_event(action: "session.signed_in", workspace: user.active_workspace, actor: user, subject: user) do
    post session_path, params: { email_address: user.email_address, password: "password" }
  end
  assert_equal "password", event.metadata.fetch("authentication_method")
  assert_no_match(/#{Regexp.escape(user.email_address)}|password|session|ip_address/i, event.metadata.except("authentication_method").to_json)

  assert_activity_event(action: "session.signed_out", workspace: user.active_workspace, actor: user, subject: user) do
    delete session_path
  end
end

test "failed sign in and reset request emit nothing" do
  assert_no_difference -> { ActivityEvent.count } do
    post session_path, params: { email_address: users(:one).email_address, password: "wrong" }
  end
  assert_no_difference -> { ActivityEvent.count } do
    post password_path, params: { email_address: users(:one).email_address }
  end
end
~~~

Add a visibility assertion to the instance household-invite test:

~~~ruby
event = assert_activity_event(action: "household_invite.created", workspace: nil, actor: users(:one)) do
  post instance_admin_household_invites_path, params: { household_invite: { email_address: "new-household@example.test" } }
end
assert_equal "instance_admin", event.visibility
assert_no_match(/new-household@example|token/i, event.metadata.to_json)
~~~

Run all files listed for this task. Expected: FAIL because the successful operations add no ledger rows.

- [ ] **Step 2: Emit workspace creation, update, acceptance, and deletion**

Wrap `WorkspaceOnboardingsController#create` save, owner membership creation, active-workspace update, and `workspace.created` emission in one `Workspace.transaction`.

For both authenticated and signup Household Invite acceptance, retain the existing outer transaction and emit both meaningful results after `accept!` succeeds:

~~~ruby
Activity::Emitter.record!(
  action: "workspace.created", workspace: @workspace, actor: user, subject: @workspace
)
Activity::Emitter.record!(
  action: "household_invite.accepted", workspace: @workspace, actor: user, subject: @household_invite
)
~~~

In `WorkspacesController#update`, keep settings update and public-share refresh inside `with_workspace_activity(action: "workspace.updated", subject: @workspace)`. In destroy, use one outer transaction and deliberately move the tombstone outside the deleted workspace scope:

~~~ruby
Workspace.transaction do
  @workspace.destroy_with_history!
  Activity::Emitter.record!(
    action: "workspace.deleted", workspace: nil, actor: Current.user, subject: @workspace
  )
end
~~~

This database order lets the workspace cascade remove its private history before inserting the surviving `instance_admin` tombstone.

- [ ] **Step 3: Emit invite and membership lifecycle actions**

In Workspace Invite create/accept/signup/revoke/resend/reinvite, wrap only the successful persisted/enqueued operation and emit the matching `workspace_invite.*` action. Resend uses the existing invite as subject; reinvite uses the fresh invite. Acceptance uses the accepted workspace as scope even though it becomes active during that transaction. Delivery failure emits no `.resent`, but an already-persisted newly created invite still receives `.created` because the durable mutation exists. Never pass email or token as details.

In the instance-admin household-invite controller, call `Activity::Emitter.record!` with `workspace: nil` after successful create/revoke/mail enqueue/reinvite, within the same transaction. Household acceptance is handled by the public acceptance controllers and uses the new workspace as described above.

Move the shared membership events into `WorkspaceMembershipManager`. The role-change implementation is:

~~~ruby
old_role = target_membership.role
Membership.transaction do
  target_membership.update!(role:)
  Activity::Emitter.record!(
    action: "membership.role_changed", workspace:, actor: actor_membership.user,
    subject: target_membership, details: { from_role: old_role, to_role: role }
  )
end
~~~

Apply the same transaction to `remove` (`membership.removed`, subject is the destroyed membership tombstone) and `transfer_ownership` (`membership.ownership_transferred`, subject is the new owner, details `from_role: old_actor_role`, `to_role: "owner"`). Failed `Result`s return before any transaction/event.

- [ ] **Step 4: Emit profile, password, passkey, and first-user actions**

Use `with_account_activity` around profile update/refresh, password change plus session reset, and successful password reset. `PasswordsController#create` remains untouched. Map passkey controller successes exactly:

~~~text
create        -> passkey.created
update        -> passkey.renamed
destroy       -> passkey.deleted
second_factor -> passkey.second_factor_enabled or passkey.second_factor_disabled from the persisted boolean
~~~

Keep WebAuthn challenge generation/assertion failures outside emission. For credential deletion, emit after `destroy!` in the same transaction so metadata is captured from the in-memory tombstone. Wrap first-user save and `instance.first_user_created` in one transaction with `workspace: nil`; its automatic initial session event is a separate authenticated security fact.

- [ ] **Step 5: Centralize safe session success emission in Authentication**

Change the concern signatures and all callers:

~~~ruby
def start_new_session_for(user, authentication_method: "password")
  session_record = nil
  ActivityEvent.transaction do
    session_record = user.sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip)
    workspace = user.active_workspace
    Activity::Emitter.record!(
      action: "session.signed_in", workspace:, actor: user, subject: user,
      visibility: workspace ? "workspace_admin" : "instance_admin",
      details: { authentication_method: }
    )
  end
  ActiveRecord.after_all_transactions_commit do
    Current.session = session_record
    cookies.signed.permanent[:session_id] = {
      value: session_record.id, httponly: true, same_site: :lax
    }
  end
end

def terminate_session
  session_record = Current.session
  user = session_record.user
  ActivityEvent.transaction do
    session_record.destroy!
    workspace = user.active_workspace
    Activity::Emitter.record!(
      action: "session.signed_out", workspace:, actor: user, subject: user,
      visibility: workspace ? "workspace_admin" : "instance_admin"
    )
  end
  cookies.delete(:session_id)
end
~~~

Pass `authentication_method: "passkey"` from `PasskeySessionsController`, `"passkey_second_factor"` from `PasskeySecondFactorsController`, and `"invited_signup"` from both invite signup flows. Do not put user agent, remote IP, cookie/session ID, challenge, or credential ID in event metadata.

- [ ] **Step 6: Run household/security tests and secret scan**

~~~bash
bin/rails test test/controllers/workspace_onboardings_controller_test.rb test/controllers/workspaces_controller_test.rb test/controllers/workspace_invites_controller_test.rb test/controllers/household_invites_controller_test.rb test/controllers/instance_admin_household_invites_controller_test.rb test/controllers/memberships_controller_test.rb test/services/workspace_membership_manager_test.rb test/controllers/profiles_controller_test.rb test/controllers/password_changes_controller_test.rb test/controllers/passwords_controller_test.rb test/controllers/passkey_credentials_controller_test.rb test/controllers/passkey_second_factors_controller_test.rb test/controllers/sessions_controller_test.rb test/controllers/passkey_sessions_controller_test.rb test/controllers/first_user_setups_controller_test.rb test/controllers/concerns/authentication_test.rb
bin/rails runner 'payload = ActivityEvent.where(category: %w[household_administration system_security]).pluck(:metadata).to_json; abort(payload) if payload.match?(/@|password_digest|token\s*[:=]|secret\s*[:=]|session_id|ip_address|https?:\/\//i); puts "safe"'
~~~

Expected: all tests PASS and runner prints `safe`.

- [ ] **Step 7: Commit household and security emission**

~~~bash
git add app/controllers/workspace_onboardings_controller.rb app/controllers/workspaces_controller.rb app/controllers/workspace_invites_controller.rb app/controllers/household_invites_controller.rb app/controllers/instance_admin/household_invites_controller.rb app/controllers/memberships_controller.rb app/controllers/profiles_controller.rb app/controllers/password_changes_controller.rb app/controllers/passwords_controller.rb app/controllers/passkey_credentials_controller.rb app/controllers/passkey_second_factors_controller.rb app/controllers/sessions_controller.rb app/controllers/passkey_sessions_controller.rb app/controllers/first_user_setups_controller.rb app/controllers/concerns/authentication.rb app/services/workspace_membership_manager.rb test/controllers/workspace_onboardings_controller_test.rb test/controllers/workspaces_controller_test.rb test/controllers/workspace_invites_controller_test.rb test/controllers/household_invites_controller_test.rb test/controllers/instance_admin_household_invites_controller_test.rb test/controllers/memberships_controller_test.rb test/services/workspace_membership_manager_test.rb test/controllers/profiles_controller_test.rb test/controllers/password_changes_controller_test.rb test/controllers/passwords_controller_test.rb test/controllers/passkey_credentials_controller_test.rb test/controllers/passkey_second_factors_controller_test.rb test/controllers/sessions_controller_test.rb test/controllers/passkey_sessions_controller_test.rb test/controllers/first_user_setups_controller_test.rb test/controllers/concerns/authentication_test.rb
git commit -m "Audit household and account security mutations"
~~~

---

### Task 8: Audit Imports, Exports, Backups, And Preserve The Ledger In Backups

**Files:**

- Modify: `test/services/beanconqueror_import_test.rb`
- Modify: `test/controllers/beanconqueror_imports_controller_test.rb`
- Modify: `test/controllers/workspace_exports_controller_test.rb`
- Modify: `test/services/workspace_export_builder_test.rb`
- Modify: `test/services/instance_backup_builders_test.rb`
- Modify: `test/services/instance_backup_restore_test.rb`
- Create: `test/services/activity/export_serializer_test.rb`
- Modify: `test/controllers/instance_backup_profiles_controller_test.rb`
- Modify: `test/models/instance_backup_profile_test.rb`
- Modify: `test/jobs/instance_backup_jobs_test.rb`
- Modify: `app/services/beanconqueror_import.rb`
- Create: `app/services/activity/export_serializer.rb`
- Modify: `app/controllers/workspace_exports_controller.rb`
- Modify: `app/services/workspace_export_builder.rb`
- Modify: `app/services/instance_readable_export_builder.rb`
- Modify: `app/services/instance_backup_restorer.rb`
- Modify: `app/controllers/instance_admin/backup_profiles_controller.rb`
- Modify: `app/models/instance_backup_profile.rb`
- Modify: `app/models/instance_backup_run.rb`

**Interfaces:**

- A completed Beanconqueror import emits `data_import.completed` at commit time with `source`, total `created_count`, and total `skipped_count`; invalid JSON creates a failed DataImport and one `data_import.failed` with `source` only.
- Imported Brews additionally get truthful `brew.created` events at each imported `occurred_at`; imported Bean/Gear rows do not create per-row feed noise. The pending import, imported records, Brew events, directly caused public-Bean comparison refreshes, and completion event share one outer transaction.
- `ActiveRecord::RecordInvalid` raised for an `ActivityEvent` during Brew import is infrastructure failure, never a skippable malformed-Brew warning: it propagates and rolls back the entire import.
- Each workspace export endpoint emits one `workspace_export.generated` with `export_kind` from `json|beans_csv|brews_csv|external_coffees_csv|media_zip` after payload generation succeeds.
- Backup profile create/update and run queued/succeeded/failed are instance-wide. Manual queue uses the current admin actor; scheduled queue and completion use `System`.
- Workspace/readable/full-archive exports preserve activity rows. Restores remap actors/live supported subjects, retain safe metadata/timestamps, degrade missing/unexported subjects to tombstones, and reject action/type mismatches, disallowed metadata keys, or resolved subjects from the wrong workspace.
- Adding `activity_events` is backward-compatible within format version 1: restore uses `Array(payload["activity_events"])` and accepts old archives with the field absent.

- [ ] **Step 1: Write failing import, operations, and persistence tests**

Add to `test/services/beanconqueror_import_test.rb`:

~~~ruby
test "completed import emits one safe summary and historical brew events" do
  json = file_fixture("beanconqueror_export.json").read

  event = assert_difference -> { ActivityEvent.where(action: "data_import.completed").count }, 1 do
    @data_import = BeanconquerorImport.new(
      workspace: workspaces(:household), user: users(:one), json:
    ).call
  end

  event = ActivityEvent.where(action: "data_import.completed", subject: @data_import).last
  assert_equal @data_import.summary.values.sum { |part| part.fetch("created", 0) }, event.metadata.fetch("created_count")
  assert_equal @data_import.summary.values.sum { |part| part.fetch("skipped", 0) }, event.metadata.fetch("skipped_count")
  imported_brew = @data_import.brews.first!
  brew_event = ActivityEvent.find_by!(action: "brew.created", subject: imported_brew)
  assert_equal imported_brew.occurred_at, brew_event.occurred_at
  assert_no_match(/warning|raw_payload|uuid|note/i, event.metadata.to_json)
end

test "failed import logs status without raw parser error" do
  data_import = BeanconquerorImport.new(
    workspace: workspaces(:household), user: users(:one), json: "{token=secret"
  ).call

  event = ActivityEvent.find_by!(action: "data_import.failed", subject: data_import)
  assert_equal({ "source" => "beanconqueror" }, event.metadata.slice("source"))
  assert_no_match(/token|secret|parser|warning|\{/i, event.metadata.to_json)
end

test "activity persistence failure propagates instead of counting an imported Brew as skipped" do
  workspace = workspaces(:household)
  counts = lambda do
    [ DataImport.count, workspace.beans.count, workspace.equipment.count,
      workspace.preparation_tools.count, workspace.brews.count,
      InventoryAdjustment.where(workspace:).count, ActivityEvent.count ]
  end
  before_counts = counts.call
  original_record = Activity::Emitter.method(:record!)
  failing_record = lambda do |**attributes|
    if attributes.fetch(:action) == "brew.created"
      raise ActiveRecord::RecordInvalid.new(ActivityEvent.new)
    end

    original_record.call(**attributes)
  end

  Activity::Emitter.stub(:record!, failing_record) do
    error = assert_raises(ActiveRecord::RecordInvalid) do
      BeanconquerorImport.new(workspace:, user: users(:one), json: beanconqueror_json).call
    end
    assert_instance_of ActivityEvent, error.record
  end

  assert_equal before_counts, counts.call
  assert_not workspace.brews.exists?(import_source: "beanconqueror", import_source_id: "bc-brew-1")
end

test "public comparison refresh failure rolls back import rows activity and snapshots" do
  workspace = workspaces(:household)
  share = create_public_bean_share(beans(:open_household), user: users(:one))
  original_snapshot = share.snapshot.deep_dup
  counts = lambda do
    [ DataImport.count, workspace.beans.count, workspace.equipment.count,
      workspace.preparation_tools.count, workspace.brews.count,
      InventoryAdjustment.where(workspace:).count, ActivityEvent.count ]
  end
  before_counts = counts.call
  failing_refresh = lambda do |_workspace|
    share.update!(snapshot: share.snapshot.merge("rollback_marker" => true))
    raise "comparison refresh failed"
  end

  PublicBeanShareRefresher.stub(:refresh_comparisons_for, failing_refresh) do
    assert_raises(RuntimeError) do
      BeanconquerorImport.new(workspace:, user: users(:one), json: beanconqueror_json).call
    end
  end

  assert_equal before_counts, counts.call
  assert_equal original_snapshot, share.reload.snapshot
  assert_not workspace.beans.exists?(import_source: "beanconqueror", import_source_id: "bc-bean-1")
  assert_not workspace.brews.exists?(import_source: "beanconqueror", import_source_id: "bc-brew-1")
end
~~~

Include `ActivityEventTestHelper` in `ActiveSupport::TestCase` as well as integration tests so the first test can use the shared helper if desired.

Add to `test/services/workspace_export_builder_test.rb`:

~~~ruby
test "workspace export contains only that workspace ledger and preserves safe snapshots" do
  payload = WorkspaceExportBuilder.new(workspaces(:household)).call

  ids = payload.fetch(:activity_events).map { |row| row.fetch(:id) }
  assert_includes ids, activity_events(:morning_brew_created).id
  assert_not_includes ids, activity_events(:other_workspace_brew).id
  assert payload.fetch(:activity_events).all? { |row| row.fetch(:workspace_id) == workspaces(:household).id }
  assert_no_match(/password|digest|token|signed_id|attachment|filename|https?:\/\//i, payload.fetch(:activity_events).to_json)
end
~~~

Add to `test/controllers/workspace_exports_controller_test.rb`; the matrix deliberately includes the previously uncovered External Coffees endpoint:

~~~ruby
test "each successful workspace export emits exactly its allowlisted kind" do
  sign_in_as(users(:one))
  cases = [
    [ workspace_export_path, "json" ],
    [ workspace_export_beans_path, "beans_csv" ],
    [ workspace_export_brews_path, "brews_csv" ],
    [ workspace_export_external_coffees_path, "external_coffees_csv" ],
    [ workspace_export_media_path, "media_zip" ]
  ]

  cases.each do |path, export_kind|
    event = assert_activity_event(
      action: "workspace_export.generated", workspace: workspaces(:household),
      actor: users(:one), subject: workspaces(:household)
    ) do
      get path
    end
    assert_response :success
    assert_equal export_kind, event.metadata.fetch("export_kind")
  end
end

test "external coffees generation exception emits no export activity" do
  sign_in_as(users(:one))
  failing_export = Object.new
  failing_export.define_singleton_method(:external_coffees_csv) { raise "csv generation failed" }

  assert_no_difference -> { ActivityEvent.count } do
    WorkspaceCsvExportBuilder.stub(:new, failing_export) do
      assert_raises(RuntimeError) { get workspace_export_external_coffees_path }
    end
  end
end
~~~

In `test/services/instance_backup_restore_test.rb`, set `exported_activity_count = ActivityEvent.count` immediately before building the archive. Add these assertions after the existing archive round trip:

~~~ruby
restored_event = ActivityEvent.find_by!(
  workspace: restored_workspace,
  action: "brew.created",
  subject_type: "Brew",
  subject_id: restored_espresso_brew.id
)
assert_equal "Jens", restored_event.metadata.fetch("actor_label")
assert_equal restored_event.workspace, restored_event.subject.workspace
assert ActivityEvent.exists?(workspace_id: nil, action: "instance_backup_run.succeeded")
assert_equal exported_activity_count, ActivityEvent.count
~~~

Add the target-state and hostile-archive tests beside that round trip. Invalid archives must fail closed and prove the restore transaction leaves the target empty:

~~~ruby
test "restorer rejects a target containing only a backup profile" do
  archive_bytes = InstanceBackupArchiveBuilder.new(
    generated_at: Time.zone.parse("2026-08-21 12:00:00")
  ).call
  empty_instance!
  InstanceBackupProfile.create!(
    name: "Residual profile", backup_kind: "full_archive", enabled: false, schedule: "manual",
    storage_path: "storage/instance_backups", retention_count: 7
  )

  error = assert_raises(InstanceBackupRestorer::RestoreError) do
    InstanceBackupRestorer.new(archive_bytes).call
  end

  assert_equal "Target instance must be empty before restore.", error.message
  assert_equal 0, User.count
  assert_equal 0, Workspace.count
  assert_equal 1, InstanceBackupProfile.count
end

test "restorer rejects activity metadata keys not permitted for the archived action" do
  archive_bytes = InstanceBackupArchiveBuilder.new(
    generated_at: Time.zone.parse("2026-08-21 12:00:00")
  ).call
  tampered_archive = mutate_backup_payload(archive_bytes) do |payload|
    household = payload.fetch("workspaces").find do |workspace_payload|
      workspace_payload.dig("workspace", "name") == workspaces(:household).name
    end
    event = household.fetch("activity_events").find { |row| row.fetch("action") == "brew.created" }
    event.fetch("metadata")["backup_kind"] = "full_archive"
  end

  empty_instance!
  error = assert_raises(InstanceBackupRestorer::RestoreError) do
    InstanceBackupRestorer.new(tampered_archive).call
  end

  assert_equal "Archive contains an invalid activity event.", error.message
  assert_equal 0, ActivityEvent.count
  assert_equal 0, Workspace.count
end

test "restorer rejects leading paths and overlong strings inside metadata arrays" do
  source_event = Activity::Emitter.record!(
    action: "equipment_event.created", workspace: workspaces(:household), actor: users(:one),
    subject: equipment_events(:grinder_cleaning), occurred_at: equipment_events(:grinder_cleaning).occurred_at
  )
  archive_bytes = InstanceBackupArchiveBuilder.new(
    generated_at: Time.zone.parse("2026-08-21 12:00:00")
  ).call
  tampered_archive = mutate_backup_payload(archive_bytes) do |payload|
    household = payload.fetch("workspaces").find do |workspace_payload|
      workspace_payload.dig("workspace", "name") == workspaces(:household).name
    end
    event = household.fetch("activity_events").find { |row| row.fetch("id") == source_event.id }
    event.fetch("metadata")["event_types"] = [ "../private/event", "x" * 161 ]
  end

  empty_instance!
  error = assert_raises(InstanceBackupRestorer::RestoreError) do
    InstanceBackupRestorer.new(tampered_archive).call
  end

  assert_equal "Archive contains an invalid activity event.", error.message
  assert_equal 0, ActivityEvent.count
  assert_equal 0, Workspace.count
end

test "restorer rejects category and visibility that do not match the archived action" do
  archive_bytes = InstanceBackupArchiveBuilder.new(
    generated_at: Time.zone.parse("2026-08-21 12:00:00")
  ).call
  tampered_archives = [
    [ "category", "system_security" ],
    [ "visibility", "workspace_admin" ]
  ].map do |key, value|
    mutate_backup_payload(archive_bytes) do |payload|
      household = payload.fetch("workspaces").find do |workspace_payload|
        workspace_payload.dig("workspace", "name") == workspaces(:household).name
      end
      event = household.fetch("activity_events").find { |row| row.fetch("action") == "brew.created" }
      event[key] = value
    end
  end

  tampered_archives.each do |tampered_archive|
    empty_instance!
    error = assert_raises(InstanceBackupRestorer::RestoreError) do
      InstanceBackupRestorer.new(tampered_archive).call
    end
    assert_equal "Archive contains an invalid activity event.", error.message
    assert_equal 0, ActivityEvent.count
    assert_equal 0, Workspace.count
  end
end

test "restorer rejects a remapped activity subject from another workspace" do
  household_event_id = activity_events(:morning_brew_created).id
  foreign_brew_id = brews(:other_workspace_brew).id
  archive_bytes = InstanceBackupArchiveBuilder.new(
    generated_at: Time.zone.parse("2026-08-21 12:00:00")
  ).call
  tampered_archive = mutate_backup_payload(archive_bytes) do |payload|
    household = payload.fetch("workspaces").find do |workspace_payload|
      workspace_payload.dig("workspace", "name") == workspaces(:household).name
    end
    event = household.fetch("activity_events").find { |row| row.fetch("id") == household_event_id }
    event["subject_id"] = foreign_brew_id
  end

  empty_instance!
  error = assert_raises(InstanceBackupRestorer::RestoreError) do
    InstanceBackupRestorer.new(tampered_archive).call
  end

  assert_equal "Archive activity subject belongs to another workspace.", error.message
  assert_equal 0, ActivityEvent.count
  assert_equal 0, Workspace.count
end
~~~

Make `ActivityEvent.delete_all` the first line of the existing test helper so immutable ledger rows never survive into the supposedly empty target:

~~~ruby
def empty_instance!
  ActivityEvent.delete_all
  InstanceBackupRun.delete_all
  InstanceBackupProfile.delete_all
  ActiveStorage::VariantRecord.delete_all
  ActiveStorage::Attachment.delete_all
  ActiveStorage::Blob.delete_all
  Session.delete_all
  WorkspaceInvite.delete_all
  HouseholdInvite.delete_all
  InventoryAdjustment.delete_all
  BrewPreparationTool.delete_all
  EquipmentEventItem.delete_all
  EquipmentEvent.delete_all
  PublicRecipeShare.delete_all
  Recipe.delete_all
  Brew.delete_all
  ExternalCoffee.delete_all
  PreparationTool.delete_all
  Equipment.delete_all
  Bean.delete_all
  DataImport.delete_all
  Membership.delete_all
  PasskeyCredential.delete_all
  User.update_all(active_workspace_id: nil)
  Workspace.delete_all
  User.delete_all
end
~~~

Add backup event assertions to `test/jobs/instance_backup_jobs_test.rb`:

~~~ruby
test "successful and failed runs emit safe instance events" do
  profile = InstanceBackupProfile.create!(
    name: "Full archive", backup_kind: "full_archive", enabled: true, schedule: "manual",
    storage_path: @backup_root.relative_path_from(Rails.root).to_s, retention_count: 7
  )
  run = profile.instance_backup_runs.create!(backup_kind: "full_archive")

  assert_difference -> { ActivityEvent.where(action: "instance_backup_run.succeeded").count }, 1 do
    InstanceBackupArchiveBuilder.stub(:new, -> { Struct.new(:call).new("zip-bytes") }) do
      InstanceBackupJob.perform_now(run)
    end
  end
  event = ActivityEvent.where(action: "instance_backup_run.succeeded").last
  assert_nil event.workspace
  assert_equal "System", event.metadata.fetch("actor_label")
  assert_no_match(/file_path|checksum|storage\//i, event.metadata.to_json)

  failed_run = profile.instance_backup_runs.create!(backup_kind: "full_archive")
  assert_difference -> { ActivityEvent.where(action: "instance_backup_run.failed").count }, 1 do
    assert_raises(RuntimeError) do
      InstanceBackupArchiveBuilder.stub(:new, -> { raise "storage_path=/private/secret token=abc" }) do
        InstanceBackupJob.perform_now(failed_run)
      end
    end
  end
  failed_event = ActivityEvent.where(action: "instance_backup_run.failed").last
  assert_equal "failed", failed_event.metadata.fetch("status")
  assert_no_match(/storage|private|secret|token|abc/i, failed_event.metadata.to_json)
end
~~~

Run:

~~~bash
bin/rails test test/services/beanconqueror_import_test.rb test/controllers/beanconqueror_imports_controller_test.rb test/controllers/workspace_exports_controller_test.rb test/services/activity/export_serializer_test.rb test/services/workspace_export_builder_test.rb test/services/instance_backup_builders_test.rb test/services/instance_backup_restore_test.rb test/controllers/instance_backup_profiles_controller_test.rb test/models/instance_backup_profile_test.rb test/jobs/instance_backup_jobs_test.rb
~~~

Expected: FAIL for absent events and absent `activity_events` payloads.

- [ ] **Step 2: Emit import summary and historical Brew events in the importer transaction**

Replace `call` so the pending DataImport is created inside the same transaction as every imported row, activity event, and directly caused public comparison refresh:

~~~ruby
def call
  parsed = parse_payload
  return failed_import(parsed[:warning]) if parsed[:error]

  @payload = parsed.fetch(:data)
  ActiveRecord::Base.transaction do
    @data_import = DataImport.create!(
      workspace:, user:, source: SOURCE, status: "pending", raw_payload: payload,
      summary:, warnings:
    )
    import_beans
    import_mills
    import_preparations
    import_brews
    data_import.update!(status: "completed", summary:, warnings:)
    PublicBeanShareRefresher.refresh_comparisons_for(workspace) if summary.dig("brews", "created").to_i.positive?

    created_count = summary.values.sum { |part| part.fetch("created", 0).to_i }
    skipped_count = summary.values.sum { |part| part.fetch("skipped", 0).to_i }
    Activity::Emitter.record!(
      action: "data_import.completed", workspace:, actor: user, subject: data_import,
      details: { source: SOURCE, created_count:, skipped_count: }
    )
  end

  data_import
end
~~~

Remove the post-transaction `PublicBeanShareRefresher.refresh_comparisons_for` call. In `import_brews`, emit immediately after the Brew and its preparation-tool snapshot succeed, then explicitly propagate ledger validation failure rather than converting it to a skipped-row warning:

~~~ruby
def import_brews
  each_record("BREWS") do |raw|
    source_id = source_id(raw)
    next skip("brews", "Brew without source UUID skipped.") if source_id.blank?
    next skip("brews", "Brew #{source_id} already imported.") if find_existing(Brew, source_id)
    next skip("brews", "Unsupported brew #{source_id} skipped.") unless supported_brew?(raw)

    bean = @beans_by_source_id[raw["bean"]]
    next skip("brews", "Brew #{source_id} skipped because bean #{raw["bean"]} was not imported.") unless bean

    bean_weight = positive_decimal(raw["bean_weight_in"]) || positive_decimal(raw["grind_weight"])
    next skip("brews", "Brew #{source_id} skipped because bean weight was missing.") unless bean_weight

    brew = workspace.brews.create!(brew_attributes(raw, source_id, bean, bean_weight))
    brew.snapshot_preparation_tools!(preparation_tools_for(raw))
    Activity::Emitter.record!(
      action: "brew.created", workspace:, actor: user, subject: brew, occurred_at: brew.occurred_at
    )
    created("brews")
  rescue ActiveRecord::RecordInvalid => error
    raise if error.record.is_a?(ActivityEvent)

    skip("brews", "Brew #{source_id || "unknown"} skipped: #{error.record.errors.full_messages.to_sentence}.")
  end
end
~~~

Replace `failed_import` so the failed row and its safe event are atomic; the warning remains on the private DataImport and is never passed to metadata:

~~~ruby
def failed_import(warning)
  DataImport.transaction do
    @data_import = DataImport.create!(
      workspace:, user:, source: SOURCE, status: "failed", summary:,
      warnings: [ warning ], raw_payload: {}
    )
    Activity::Emitter.record!(
      action: "data_import.failed", workspace:, actor: user, subject: data_import,
      details: { source: SOURCE }
    )
    data_import
  end
end
~~~

Unexpected exceptions—including the propagated activity error and public refresher failures—continue to roll back and propagate rather than forging a failed event without a durable failed row.

- [ ] **Step 3: Emit successful workspace exports after generation**

Add a controller helper and call it after each builder returns but before `send_data`:

~~~ruby
def record_export!(export_kind)
  Activity::Emitter.record!(
    action: "workspace_export.generated", workspace: current_workspace,
    actor: Current.user, subject: current_workspace, details: { export_kind: }
  )
end
~~~

Wrap generation—not `send_data`—with this helper so the event is written only after the complete JSON/CSV/ZIP artifact exists:

~~~ruby
def audited_export(export_kind)
  artifact = yield
  record_export!(export_kind)
  artifact
end
~~~

Use these exact expressions in the five actions before their existing `send_data` calls:

~~~ruby
payload = audited_export("json") { JSON.pretty_generate(WorkspaceExportBuilder.new(current_workspace).call) }
payload = audited_export("beans_csv") { csv_export.beans_csv }
payload = audited_export("brews_csv") { csv_export.brews_csv }
payload = audited_export("external_coffees_csv") { csv_export.external_coffees_csv }
payload = audited_export("media_zip") { WorkspaceMediaArchiveBuilder.new(current_workspace).call }
~~~

Pass the resulting local `payload` to the action's existing `send_data`. A builder/serialization exception exits before `record_export!`, so it emits nothing. The generated artifact intentionally does not contain the event describing its own later successful generation.

- [ ] **Step 4: Serialize workspace and instance activity safely**

Create `app/services/activity/export_serializer.rb`:

~~~ruby
module Activity
  module ExportSerializer
    module_function

    def call(event)
      {
        id: event.id,
        workspace_id: event.workspace_id,
        actor_id: event.actor_id,
        category: event.category,
        action: event.action,
        occurred_at: event.occurred_at&.iso8601,
        visibility: event.visibility,
        subject_type: event.subject_type,
        subject_id: event.subject_id,
        metadata: event.metadata.deep_dup,
        created_at: event.created_at&.iso8601,
        updated_at: event.updated_at&.iso8601
      }
    end
  end
end
~~~

Create `test/services/activity/export_serializer_test.rb`:

~~~ruby
require "test_helper"

class Activity::ExportSerializerTest < ActiveSupport::TestCase
  test "serializes the complete safe restore contract" do
    event = activity_events(:morning_brew_created)
    payload = Activity::ExportSerializer.call(event)

    assert_equal %i[action actor_id category created_at id metadata occurred_at subject_id subject_type updated_at visibility workspace_id], payload.keys.sort
    assert_equal event.occurred_at.iso8601, payload.fetch(:occurred_at)
    assert_equal event.metadata, payload.fetch(:metadata)
    assert_not_same event.metadata, payload.fetch(:metadata)
    assert_no_match(/password|digest|token|signed_id|attachment|filename|file_path|https?:\/\//i, payload.fetch(:metadata).to_json)
  end
end
~~~

Add `activity_events: workspace.activity_events.reorder(:id).map { |event| Activity::ExportSerializer.call(event) }` to `WorkspaceExportBuilder#call`. Add top-level `instance_activity_events: ActivityEvent.where(workspace_id: nil).order(:id).map { |event| Activity::ExportSerializer.call(event) }` to `InstanceReadableExportBuilder#call`. Workspace payloads already inherit their rows from `WorkspaceExportBuilder`.

- [ ] **Step 5: Restore actors, supported live subjects, and tombstones**

Initialize `@workspace_invite_map` and `@inventory_adjustment_map`, then populate them while restoring invites and adjustments. Replace the empty-instance model list with the same list plus `ActivityEvent` as its first entry:

~~~ruby
def empty_instance?
  [
    ActivityEvent,
    InstanceBackupRun,
    InstanceBackupProfile,
    User,
    Workspace,
    Membership,
    WorkspaceInvite,
    DataImport,
    Bean,
    Equipment,
    PreparationTool,
    Brew,
    ExternalCoffee,
    BrewPreparationTool,
    EquipmentEvent,
    EquipmentEventItem,
    InventoryAdjustment,
    PasskeyCredential,
    ActiveStorage::Attachment,
    ActiveStorage::Blob
  ].none?(&:exists?)
end
~~~

After domain records, primary photos, and active workspaces, call `restore_activity_events` before inventory reset:

~~~ruby
ACTIVITY_SUBJECT_MAPS = {
  "User" => :@user_map,
  "Workspace" => :@workspace_map,
  "Membership" => :@membership_map,
  "WorkspaceInvite" => :@workspace_invite_map,
  "DataImport" => :@data_import_map,
  "Bean" => :@bean_map,
  "Equipment" => :@equipment_map,
  "PreparationTool" => :@preparation_tool_map,
  "Brew" => :@brew_map,
  "ExternalCoffee" => :@external_coffee_map,
  "EquipmentEvent" => :@equipment_event_map,
  "InventoryAdjustment" => :@inventory_adjustment_map
}.freeze

def restore_activity_events
  workspace_payloads.each do |workspace_payload|
    workspace = @workspace_map.fetch(old_id(workspace_payload.fetch("workspace")))
    Array(workspace_payload["activity_events"]).each { |row| restore_activity_event(row, workspace:) }
  end
  Array(payload["instance_activity_events"]).each { |row| restore_activity_event(row, workspace: nil) }
end

def restore_activity_event(row, workspace:)
  action = row.fetch("action")
  definition = Activity::EventContract.fetch(action)
  unless row.fetch("category") == definition.fetch(:category) &&
      definition.fetch(:visibilities).include?(row.fetch("visibility"))
    raise RestoreError, "Archive contains an invalid activity event."
  end
  archived_subject_type = row["subject_type"]
  archived_subject_id = row["subject_id"]
  unless archived_subject_type.present? == archived_subject_id.present?
    raise RestoreError, "Archive contains an invalid activity event."
  end
  if archived_subject_type.present? && archived_subject_type != definition.fetch(:subject_type)
    raise RestoreError, "Archive activity subject type does not match its action."
  end

  subject_map = ACTIVITY_SUBJECT_MAPS[archived_subject_type]
  subject = subject_map && instance_variable_get(subject_map)[archived_subject_id]
  validate_restored_activity_subject!(subject, workspace:)
  ActivityEvent.create!(
    workspace:,
    actor: @user_map[row["actor_id"]],
    category: row.fetch("category"),
    action:,
    occurred_at: time(row.fetch("occurred_at")),
    visibility: row.fetch("visibility"),
    subject:,
    metadata: row.fetch("metadata").deep_dup,
    created_at: time(row.fetch("created_at")),
    updated_at: time(row.fetch("updated_at"))
  )
rescue ActiveRecord::RecordInvalid, KeyError, ArgumentError
  raise RestoreError, "Archive contains an invalid activity event."
end

def validate_restored_activity_subject!(subject, workspace:)
  return unless subject

  subject_workspace_id = if subject.is_a?(Workspace)
    subject.id
  elsif subject.respond_to?(:workspace_id)
    subject.workspace_id
  end
  if workspace && subject_workspace_id.present? && subject_workspace_id != workspace.id
    raise RestoreError, "Archive activity subject belongs to another workspace."
  end
  if workspace.nil? && subject_workspace_id.present? && !subject.is_a?(Workspace)
    raise RestoreError, "Archive instance activity subject cannot be workspace-scoped."
  end
end
~~~

The archived action's registry subject type must match before lookup; a resolved workspace-owned subject must match the enclosing remapped workspace, and an instance event cannot resolve to a workspace-owned subject. Model validation then enforces the per-action metadata-key contract, unsafe-text rules, category/action allowlist, and visibility scope. Any violation raises the stable safe `RestoreError` and rolls the whole restore back without echoing hostile archive content. Recipe/public-share/backup-profile/run subjects are not currently in the backup domain payload, so valid rows of those types restore as safe unlinked tombstones. Add `activity_events: ActivityEvent.count` to the restore summary.

- [ ] **Step 6: Emit backup profile and run state at the shared boundaries**

Wrap backup profile controller create/update with `instance_backup_profile.created/updated`, `workspace: nil`, actor `Current.user`, and subject profile. Do not pass `storage_path`.

Change `InstanceBackupProfile#enqueue_run!` to accept `actor: nil`; within its existing transaction, after run creation and enqueue, emit `instance_backup_run.queued` with nil workspace, the optional actor, run subject, and `{ backup_kind:, status: "queued" }`. Manual controller passes `Current.user`; scheduler leaves actor nil.

In `InstanceBackupRun#perform!`, build/write bytes, then atomically update success and emit:

~~~ruby
transaction do
  update!(status: "succeeded", finished_at: Time.current, file_path: path.to_s,
    file_size_bytes: bytes.bytesize, checksum_sha256: Digest::SHA256.hexdigest(bytes))
  Activity::Emitter.record!(
    action: "instance_backup_run.succeeded", workspace: nil, subject: self,
    details: { backup_kind:, status: "succeeded", file_size_bytes: bytes.bytesize }
  )
end

begin
  instance_backup_profile.enforce_retention!
rescue StandardError => cleanup_error
  Rails.logger.warn("Backup retention cleanup failed: #{cleanup_error.class}")
end
~~~

In the outer rescue, atomically update failed and emit `instance_backup_run.failed` with only `{ backup_kind:, status: "failed" }`, then re-raise. The inner cleanup rescue prevents a retention-only failure from rewriting a completed backup or adding a contradictory failed event. Never include `file_path`, storage root, checksum, or exception class/message in metadata; retention file deletion remains unlogged implementation cleanup.

- [ ] **Step 7: Run operations, round-trip, and secret-regression tests**

~~~bash
bin/rails test test/services/beanconqueror_import_test.rb test/controllers/beanconqueror_imports_controller_test.rb test/controllers/workspace_exports_controller_test.rb test/services/activity/export_serializer_test.rb test/services/workspace_export_builder_test.rb test/services/instance_backup_builders_test.rb test/services/instance_backup_restore_test.rb test/controllers/instance_backup_profiles_controller_test.rb test/models/instance_backup_profile_test.rb test/jobs/instance_backup_jobs_test.rb
bin/rails runner 'payload = ActivityEvent.pluck(:metadata).to_json; abort(payload) if payload.match?(/password_digest|token\s*[:=]|signed_id|attachment_id|filename|file_path|checksum|https?:\/\//i); puts "activity metadata safe"'
~~~

Expected: all tests PASS; archive round trip preserves the event count/snapshots; runner prints `activity metadata safe`.

- [ ] **Step 8: Commit operations and backup persistence**

~~~bash
git add app/services/beanconqueror_import.rb app/controllers/workspace_exports_controller.rb app/services/activity/export_serializer.rb app/services/workspace_export_builder.rb app/services/instance_readable_export_builder.rb app/services/instance_backup_restorer.rb app/controllers/instance_admin/backup_profiles_controller.rb app/models/instance_backup_profile.rb app/models/instance_backup_run.rb test/services/beanconqueror_import_test.rb test/controllers/beanconqueror_imports_controller_test.rb test/controllers/workspace_exports_controller_test.rb test/services/activity/export_serializer_test.rb test/services/workspace_export_builder_test.rb test/services/instance_backup_builders_test.rb test/services/instance_backup_restore_test.rb test/controllers/instance_backup_profiles_controller_test.rb test/models/instance_backup_profile_test.rb test/jobs/instance_backup_jobs_test.rb
git commit -m "Audit operations and preserve activity backups"
~~~

---

### Task 9: Document The Audit Contract And Run Final Verification

**Files:**

- Create: test/services/activity/event_contract_test.rb
- Create: docs/activity-audit.md
- Modify: docs/README.md
- Modify: docs/coffee-core.md
- Modify: docs/equipment-events.md
- Modify: docs/navigation.md
- Modify: docs/workspace-core.md
- Modify: docs/instance-admin.md
- Modify: docs/backup-system.md
- Modify: docs/status.md

**Interfaces:**

- docs/activity-audit.md is the durable product/security contract; implementation details stay in this plan and the executable registry.
- The registry verification requires every action to have one valid category/default visibility, an allowlisted SVG icon, a translated summary key, and only permitted visibility overrides.
- Final acceptance requires focused tests, the complete Rails suite, RuboCop, Brakeman, migration status, privacy scans, and a reachable local server on port 3001.

- [ ] **Step 1: Add a complete executable registry check**

Create test/services/activity/event_contract_test.rb:

~~~ruby
require "test_helper"

class Activity::EventContractTest < ActiveSupport::TestCase
  test "every action has one valid category visibility icon summary and override policy" do
    assert_equal Activity::EventContract.actions.uniq.sort, Activity::EventContract.actions.sort

    Activity::EventContract.actions.each do |action|
      definition = Activity::EventContract.fetch(action)
      assert_includes ActivityEvent::CATEGORIES, definition.fetch(:category), action
      assert_includes ActivityEvent::VISIBILITIES, definition.fetch(:visibility), action
      assert_includes definition.fetch(:visibilities), definition.fetch(:visibility), action
      assert definition.fetch(:visibilities).all? { |value| ActivityEvent::VISIBILITIES.include?(value) }, action
      assert definition.fetch(:subject_type).present?, action
      assert_equal(
        (definition.fetch(:automatic_metadata_keys) + definition.fetch(:detail_keys)).uniq.sort,
        definition.fetch(:metadata_keys).sort,
        action
      )
      assert ApplicationHelper::MATERIAL_SYMBOL_PATHS.key?(definition.fetch(:icon)), action
      assert I18n.exists?("activity.events.#{definition.fetch(:summary)}"), action
    end
  end

  test "only account actions can cross workspace-admin and instance-admin scope" do
    overridable = Activity::EventContract.actions.select do |action|
      Activity::EventContract.fetch(action).fetch(:visibilities).many?
    end

    assert_equal Activity::EventContract::ACCOUNT_ACTIONS.sort, overridable.sort
    assert overridable.all? do |action|
      Activity::EventContract.fetch(action).fetch(:visibilities).sort == %w[instance_admin workspace_admin]
    end
  end

  test "every registered action has focused mutation or operation test coverage" do
    test_source = Dir[Rails.root.join("test/{controllers,services,jobs}/**/*_test.rb")].sort.filter_map do |path|
      next if path.end_with?("event_contract_test.rb")
      File.read(path)
    end.join("\n")

    Activity::EventContract.actions.each do |action|
      assert_includes test_source, %("#{action}"), "add a focused assertion for #{action}"
    end
  end
end
~~~

Run:

~~~bash
bin/rails test test/services/activity/event_contract_test.rb
~~~

Expected: initially FAIL for any action whose icon, translation, or focused test assertion was missed. Add the missing focused assertion to the owning test file; do not satisfy this guard with a disconnected list.

- [ ] **Step 2: Write the durable activity documentation**

Create docs/activity-audit.md with this complete content:

~~~markdown
# Activity audit

Roastnode keeps a durable, append-only ActivityEvent ledger for successful authenticated changes and scheduled/system operations. Dashboard Recent Activity and /activity read this ledger; they do not infer history from current domain rows.

## Ownership and visibility

Workspace activity belongs to one Workspace. Ordinary workspace rows are visible to every current member, including viewers. workspace_admin rows are visible only to that workspace's owner and admins. Rows with instance_admin visibility have no workspace and are visible only to instance administrators. Instance-admin status does not reveal another workspace's administrative rows.

Account/security actions attach to the user's active workspace at commit time. If no active workspace exists, the permitted account actions become instance-wide. Workspace deletion removes its private history and leaves one instance-admin tombstone describing the deletion.

## Recorded scope

The six categories are Coffee; Beans & inventory; Gear & maintenance; Sharing & recipes; Household administration; and System & security. The ledger records explicit create, correction, lifecycle, delete, share-management, media-management, membership/invite, account-security, import/export, and backup results from Activity::EventContract.

Anonymous public Brew, Bean, and Recipe page views and public media reads stay only in share analytics. Failed authorization, failed sign-in, password-reset requests, page visits, active-workspace switches, automatic Brew inventory rows, public snapshot refreshes, and backup-retention cleanup are not activity events.

## Safety and immutability

An event and every directly caused public-snapshot refresh are inserted in the same database transaction as the successful mutation. Failed validation, refresher exceptions, and rollbacks preserve the prior domain/snapshot state and create no event. Persisted events cannot be edited, touched, or destroyed through the model. Deleting a subject leaves an unlinked event with a safe display snapshot.

Metadata is a small flat object whose automatic and caller-supplied keys are allowlisted per action. It may contain safe display labels, record kind, short enum values, and bounded numeric summaries. It never contains passwords, password digests, invite/share/reset tokens, session or WebAuthn challenge identifiers, emails, IP addresses, private notes, costs, raw import payloads, raw errors, attachment/blob identifiers, filenames, signed/private media URLs, backup paths, checksums, environment variables, or infrastructure secrets. Actor labels are snapshotted from User#display_label; later profile or membership changes do not rewrite history.

## Timing, filtering, and presentation

Brew, External Coffee, manual Inventory Adjustment, and Equipment Event creation uses the domain occurrence time. Imported Brew history keeps its original occurrence time. Other events use commit time. /activity filters by category, actor, inclusive start date, and inclusive end date in the signed-in user's timezone, and pagination preserves the filters.

Each action has fixed copy, a self-hosted Material-symbol SVG, and a category-colored icon container. Quick Drip remains distinct from Espresso, and External Coffee remains distinct from a Brew. Unknown rows fail closed to neutral unlinked presentation.

## Historical seed, export, and restore

Migration 20260821120000 seeds only reconstructable historical Brew, External Coffee, manual Inventory Adjustment, Equipment Event, Recipe/public-share creation, and completed import rows. It does not invent prior Bean, Gear, workspace-setting, membership, edit, transition, or deletion history.

Workspace JSON and instance backup exports include their authorized ledger rows. Full restore remaps actors and supported live subjects, preserves occurrence times and safe snapshots, and keeps an event unlinked when its original subject is absent from the backup domain. Restore rejects invalid per-action metadata, mismatched action categories/visibilities/subject types, and subjects that remap into the wrong workspace. A backup archive cannot include the later event that reports that same archive's completion.
~~~

Add Activity audit: docs/activity-audit.md to docs/README.md. Add short cross-links rather than duplicating the full contract:

- docs/coffee-core.md: Brew/External Coffee/Bean/manual-inventory actions and domain occurrence time.
- docs/equipment-events.md: gear/maintenance actions and Equipment Event occurrence time.
- docs/navigation.md: shared dashboard/history cards, four filters, preserved pagination, category colors, and Quick Drip wording.
- docs/workspace-core.md: workspace ownership, role visibility, invite/membership events, and workspace-deletion cascade/tombstone.
- docs/instance-admin.md: instance-only events and no cross-workspace administrative escalation.
- docs/backup-system.md: queued/success/failure safety plus ledger export/restore behavior.
- docs/status.md: mark the durable audit ledger, filters, visibility, and backup preservation as shipped on 2026-08-21.

- [ ] **Step 3: Run focused activity and mutation suites**

~~~bash
bin/rails test test/models/activity_event_test.rb test/migrations/create_activity_events_test.rb test/services/activity test/presenters/activity
bin/rails test test/controllers/activity_controller_test.rb test/controllers/home_controller_test.rb test/controllers/brews_controller_test.rb test/controllers/external_coffees_controller_test.rb test/controllers/beans_controller_test.rb test/controllers/inventory_adjustments_controller_test.rb
bin/rails test test/controllers/equipment_controller_test.rb test/controllers/preparation_tools_controller_test.rb test/controllers/equipment_events_controller_test.rb test/controllers/recipes_controller_test.rb test/controllers/public_brew_shares_controller_test.rb test/controllers/public_bean_shares_controller_test.rb test/controllers/public_recipe_shares_controller_test.rb test/controllers/media_attachments_controller_test.rb
bin/rails test test/controllers/workspace_onboardings_controller_test.rb test/controllers/workspaces_controller_test.rb test/controllers/workspace_invites_controller_test.rb test/controllers/household_invites_controller_test.rb test/controllers/instance_admin_household_invites_controller_test.rb test/controllers/memberships_controller_test.rb test/controllers/profiles_controller_test.rb test/controllers/password_changes_controller_test.rb test/controllers/passwords_controller_test.rb test/controllers/passkey_credentials_controller_test.rb test/controllers/passkey_second_factors_controller_test.rb test/controllers/sessions_controller_test.rb test/controllers/passkey_sessions_controller_test.rb test/controllers/first_user_setups_controller_test.rb
bin/rails test test/services/beanconqueror_import_test.rb test/controllers/workspace_exports_controller_test.rb test/services/activity/export_serializer_test.rb test/services/workspace_export_builder_test.rb test/services/instance_backup_builders_test.rb test/services/instance_backup_restore_test.rb test/controllers/instance_backup_profiles_controller_test.rb test/models/instance_backup_profile_test.rb test/jobs/instance_backup_jobs_test.rb
~~~

Expected: every command exits 0 with no failures or errors.

- [ ] **Step 4: Run full static, security, migration, and privacy verification**

~~~bash
bin/rails db:migrate:status
bin/rails test
bin/rubocop
bin/brakeman -q
bin/rails runner 'bad = ActivityEvent.where.not(category: ActivityEvent::CATEGORIES).or(ActivityEvent.where.not(visibility: ActivityEvent::VISIBILITIES)); abort("invalid registry rows") if bad.exists?; puts "activity rows valid"'
bin/rails runner 'payload = ActivityEvent.pluck(:metadata).to_json; abort(payload) if payload.match?(/@|password_digest|token\s*[:=]|secret\s*[:=]|session_id|ip_address|signed_id|attachment_id|filename|file_path|checksum|https?:\/\//i); puts "activity metadata safe"'
git diff --check
~~~

Expected: migration 20260821120000 is up; full test suite, RuboCop, and Brakeman exit 0; runners print activity rows valid and activity metadata safe; git diff --check prints nothing.

- [ ] **Step 5: Review the complete action/visibility map manually**

Compare Activity::EventContract::ACTIONS to the Canonical Event Registry in this plan. For every row, verify its owning successful request/job test asserts exactly one event; its failed-path test asserts no event; its default visibility matches the table; delete tests preserve safe tombstones; and the anonymous public page/media tests assert ActivityEvent.count does not change. Verify every restricted card is absent for member/viewer requests and every subject link resolves only inside the active workspace.

- [ ] **Step 6: Commit documentation and final verification coverage**

~~~bash
git add test/services/activity/event_contract_test.rb docs/activity-audit.md docs/README.md docs/coffee-core.md docs/equipment-events.md docs/navigation.md docs/workspace-core.md docs/instance-admin.md docs/backup-system.md docs/status.md
git commit -m "Document and verify the activity audit ledger"
~~~

- [ ] **Step 7: Start the local app for user verification**

~~~bash
tmux has-session -t roastnode-dev 2>/dev/null || tmux new-session -d -s roastnode-dev
tmux send-keys -t roastnode-dev C-c
tmux send-keys -t roastnode-dev 'cd /Users/d33pjs/Documents/developing/roastnode && bin/dev' Enter
tmux capture-pane -pt roastnode-dev -S -80
curl -I http://localhost:3001/activity
~~~

Expected: the tmux pane shows Rails listening on 0.0.0.0:3001; the unauthenticated request returns a 302 redirect to sign-in. Sign in as an owner/admin/member/viewer and visually verify category colors, icons, restricted-row visibility, combined filters, tombstone links, and dashboard/full-history parity.
