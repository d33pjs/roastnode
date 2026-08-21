# Activity Audit Design

## Goal

Turn Dashboard Recent Activity and `/activity` into a durable, filterable audit history that records every meaningful Roastnode change without exposing secrets or overwhelming the feed with anonymous page traffic.

## Approved Direction

Use a purpose-built append-only `ActivityEvent` ledger. The existing feed infers activity from live Brew, External Coffee, manual Inventory Adjustment, and Equipment Event rows. That approach cannot retain edits, state transitions, or deletions and cannot safely grow into a complete audit trail.

The ledger becomes the single source for Dashboard Recent Activity and the full Activity page. No generic model-versioning dependency is added, and full record diffs are not stored.

## Event Contract

Each event records:

- a required workspace for workspace-scoped events, or no workspace for an instance-wide event;
- an optional actor user for scheduled or system actions;
- a whitelisted category and action;
- the event occurrence time;
- visibility of `workspace`, `workspace_admin`, or `instance_admin`;
- an optional polymorphic subject reference; and
- a small JSON metadata payload containing only presentation-safe snapshot values.

The metadata payload may preserve a deleted subject's safe display label, record kind, and action-specific numeric summary. It must not contain passwords, password digests, invite/share/reset tokens, session identifiers, signed or private media URLs, raw attachment identifiers, original filenames, viewer IP addresses, full backup paths, environment variables, infrastructure secrets, or unfiltered exception text.

Events are immutable after creation. Corrections create another event instead of rewriting history. Deleting a subject leaves its event and safe summary in place; its card becomes non-linked.

## Scope And Categories

The ledger records successful authenticated mutations and scheduled/system operations across the application:

- Coffee: Brew and External Coffee create, correction, taste/serving change, and deletion.
- Beans and inventory: Bean create/edit/duplicate/open/finish/use-up/archive/reopen/delete and manual inventory adjustments.
- Gear and maintenance: Equipment, Preparation Tool, and Equipment Event create/edit/lifecycle/delete operations.
- Sharing and recipes: Recipe create/import/edit/delete; public Brew, Bean, and Recipe share create/publish/edit/disable/delete; and public/private record-link or media-management changes represented as concise parent-record updates.
- Household administration: workspace creation/settings, invites, membership acceptance/removal, role changes, and ownership transfer.
- System and security: imports, exports, backup runs, profile/security changes, and instance-admin operations.

High-volume anonymous public share views remain exclusively in their existing share analytics. Activity records authenticated share management, not read traffic.

The six user-facing category filters are Coffee; Beans & inventory; Gear & maintenance; Sharing & recipes; Household administration; and System & security. Individual actions use more specific copy and Material-symbol icons within those categories.

## Visibility

Readers continue to see ordinary workspace activity. Events marked `workspace_admin` are visible only to the active workspace's owner or admins. Instance-wide operational events are visible only to instance admins.

The Activity query returns authorized events for the active workspace. An instance admin additionally sees authorized instance-wide events. Account/security actions are attached to the user's active workspace at commit time; instance-level actions such as scheduled whole-instance backups remain instance-wide.

Administrative visibility does not permit secret storage. For example, the feed may say that an invite was created, revoked, or accepted, but it never stores or renders the bearer token. Backup events show safe status and profile labels, not storage paths or raw errors.

Dashboard Recent Activity and `/activity` use the same authorization-aware query so the dashboard cannot leak events hidden on the full page.

## Timing And Historical Migration

Create/log events use the domain occurrence time when that time is meaningful, such as `Brew#occurred_at`, `ExternalCoffee#occurred_at`, a manual inventory adjustment, or an Equipment Event. Edits, state transitions, share actions, security actions, exports, and backups use the time the action committed.

The migration seeds historical events only where actor, time, category, and subject can be reconstructed truthfully. Existing Brews, External Coffees, manual Inventory Adjustments, and Equipment Events qualify. Recipes and public shares receive creation events when their existing creator fields are authoritative; completed Data Imports receive one summary event when their user and stored summary are present. Beans, Equipment, Preparation Tools, workspace settings, and membership history are not backfilled because their prior actors or transitions cannot be recovered safely. Unknown edits, transitions, and deleted history are not invented.

Imports produce one current import-summary event. Imported domain records may retain their own historical occurrence events without being moved to the import time.

## Transaction Rules

An activity event is created in the same database transaction as its successful mutation. A rolled-back save produces no event. Delete flows capture the safe subject summary before deletion and commit both the deletion and event atomically.

Shared emission helpers centralize category/action allowlists and safe metadata construction. Controllers and domain services provide explicit actions; callbacks do not attempt to infer arbitrary field-level changes. Meaningful lifecycle transitions take precedence over generic “updated” events so one operation does not create noisy duplicates.

## Activity Presentation

Dashboard and full history share one activity-card partial and presenter. Each row has:

- a category-colored icon container;
- a specific action summary;
- timestamp and safe actor display label;
- an optional subject link when the subject still exists and is authorized; and
- a visible restricted marker for administrative events when useful.

Quick Drip is labeled Quick Drip rather than Espresso. Unknown event types fail closed to neutral copy and icon treatment rather than being rendered as Inventory Adjustment.

`/activity` supports category, actor, inclusive start date, and inclusive end date. Dates use the signed-in user's timezone. Actor options include current and former actors represented in authorized history, plus System when authorized system events are present, and use safe display labels rather than email. Pagination preserves every active filter. Empty filtered results explain that no matching activity exists.

## Verification

Automated coverage includes:

- model validation, immutability, visibility, and safe metadata;
- transactional emission and no events for failed mutations;
- every action family and meaningful lifecycle transition;
- deletion tombstones and absent links;
- workspace and instance isolation;
- owner/admin/member/viewer visibility;
- category, actor, timezone-boundary date, and combined filters;
- pagination parameter preservation;
- Quick Drip and External Coffee copy;
- dashboard/full-page presenter parity; and
- negative assertions for secrets, emails on coffee-facing rows, tokens, raw media identifiers, private URLs, viewer IPs, backup paths, and raw errors.

## Documentation

Implementation updates `docs/coffee-core.md`, `docs/equipment-events.md`, `docs/navigation.md`, `docs/workspace-core.md`, `docs/instance-admin.md`, `docs/backup-system.md`, and `docs/status.md` to describe the durable ledger, visibility boundary, and filters.
