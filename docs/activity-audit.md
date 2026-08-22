# Activity audit

Roastnode keeps a durable, append-only `ActivityEvent` ledger for successful authenticated changes and scheduled/system operations. Dashboard Recent Activity and `/activity` read this ledger; they do not infer history from current domain rows.

## Ownership and visibility

Workspace activity belongs to one `Workspace`. Ordinary workspace rows are visible to every current member, including viewers. `workspace_admin` rows are visible only to that workspace's owner and admins. Rows with `instance_admin` visibility have no workspace and are visible only to instance administrators. Instance-admin status does not reveal another workspace's administrative rows.

Account/security actions attach to the user's active workspace at commit time. If no active workspace exists, the permitted account actions become instance-wide. Workspace deletion removes its private history and leaves one instance-admin tombstone describing the deletion.

## Recorded scope

The six categories are Coffee; Beans & inventory; Gear & maintenance; Sharing & recipes; Household administration; and System & security. The ledger records explicit create, correction, lifecycle, delete, share-management, media-management, membership/invite, account-security, import/export, and backup results from `Activity::EventContract`.

Anonymous public Brew, Bean, and Recipe page views and public media reads stay only in share analytics. Failed authorization, failed sign-in, password-reset requests, page visits, active-workspace switches, automatic Brew inventory rows, public snapshot refreshes, and backup-retention cleanup are not activity events.

## Safety and immutability

An event and every directly caused public-snapshot refresh are inserted in the same database transaction as the successful mutation. Failed validation, refresher exceptions, and rollbacks preserve the prior domain/snapshot state and create no event. Persisted events cannot be edited, touched, or destroyed through the model. Deleting a subject leaves an unlinked event with a safe display snapshot.

Metadata is a small flat object whose automatic and caller-supplied keys are allowlisted per action. It may contain safe display labels, record kind, short enum values, and bounded numeric summaries. It never contains passwords, password digests, invite/share/reset tokens, session or WebAuthn challenge identifiers, emails, IP addresses, private notes, costs, raw import payloads, raw errors, attachment/blob identifiers, filenames, signed/private media URLs, backup paths, checksums, environment variables, or infrastructure secrets. Actor labels are snapshotted from `User#display_label`; later profile or membership changes do not rewrite history.

## Timing, filtering, and presentation

Brew, External Coffee, manual Inventory Adjustment, and Equipment Event creation uses the domain occurrence time. Imported Brew history keeps its original occurrence time. Other events use commit time. `/activity` filters by category, actor, inclusive start date, and inclusive end date in the signed-in user's timezone, and pagination preserves the filters.

Each action has fixed copy, a self-hosted Material-symbol SVG, and a category-colored icon container. Quick Drip remains distinct from Espresso, and External Coffee remains distinct from a Brew. Unknown rows fail closed to neutral unlinked presentation.

## Historical seed, export, and restore

Migration `20260821120000` seeds only reconstructable historical Brew, External Coffee, manual Inventory Adjustment, Equipment Event, Recipe/public-share creation, and completed import rows. It does not invent prior Bean, Gear, workspace-setting, membership, edit, transition, or deletion history.

Workspace JSON and instance backup exports include their authorized ledger rows. Full restore remaps actors and supported live subjects, preserves occurrence times and safe snapshots, and keeps an event unlinked when its original subject is absent from the backup domain. Restore rejects invalid per-action metadata, mismatched action categories/visibilities/subject types, and subjects that remap into the wrong workspace. A backup archive cannot include the later event that reports that same archive's completion.
