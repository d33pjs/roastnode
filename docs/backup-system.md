# Instance Backup System

The instance backup system is v1 operational scope. It is separate from active-workspace export: workspace export is owner-facing portability for one household, while instance backup is instance-admin-only disaster recovery for the whole server.

## Product Intent

- Instance admins can activate and configure backup profiles inside the app.
- Backup jobs run manually or on a schedule through Solid Queue.
- Backups are configurable by profile, starting with a full media archive and a readable all-households JSON export.
- A full backup is complete only when the archive validates and the restore path proves it can reconstruct a new Roastnode server.

## Implemented Surface

- `/instance_admin` shows backup profile activation cards, profile configuration, recent run history, and manual run buttons.
- `InstanceBackupProfile` stores the backup kind, enabled state, schedule, storage path, retention count, and last scheduled enqueue time.
- `InstanceBackupSchedulerJob` is configured in `config/recurring.yml` for production and enqueues due enabled profiles through Solid Queue.
- `InstanceBackupJob` runs a queued `InstanceBackupRun`, writes the backup file, records file size, SHA-256 checksum, timestamps, success/failure status, and error message.
- Retention is enforced per profile by keeping the newest successful files and deleting older retained file paths.
- `InstanceBackupArchiveValidator` checks archive format/version, readable JSON format/version, media file presence, and SHA-256 integrity.
- `InstanceBackupRestorer` imports a full archive into an empty database/storage area, creates fresh database IDs, remaps relationships, restores media files, preserves primary-photo relationships where exported, and gives restored users new random passwords so password digests are never imported.
- `bin/rails roastnode:backup:validate[path/to/archive.zip]` validates an archive.
- `bin/rails roastnode:backup:restore[path/to/archive.zip]` restores an archive into an empty server.

The [Activity audit](activity-audit.md) records queued, successful, and failed backup operations only after their respective state changes. A generated archive is kept only when the successful state and its Activity event commit together; a failed success audit removes that run's candidate file without touching unrelated storage files. If the failure Activity transaction itself cannot persist, the run still reaches the failed terminal state, the original backup exception remains the job error, and only generic persistence-failure classes are written to the server log. Retention cleanup is deliberately not an event. Authorized workspace and instance exports preserve ledger rows; restore validates each row against the action contract, remaps actors and supported subjects, and keeps absent subjects safely unlinked. The archive cannot contain the later success event for that same archive.

## Full Reconstructable Export

The full archive currently includes a manifest, a readable instance JSON export, and every original Active Storage attachment in the archive:

- all users and account profile metadata needed for restore
- all workspaces/households
- all memberships and roles
- all beans, equipment, preparation tools, brews, External Coffees, equipment events, inventory adjustments, statistics source records, and import metadata
- each Bean's private Purchase Website (`purchase_url`) and Coffee Origin Website (`coffee_origin_url`)
- each Brew's recipient kind, mapped recipient User reference and safe inspection labels, private Guest name, and Cup style
- all workspace media and account media, including originals
- a manifest with format version, generated time, file checksums, and relationships between JSON records and media files

The full export must not include password digests, sessions, invite tokens, signed media URLs, environment variables, infrastructure secrets, or anything that can impersonate a live login.

## Readable JSON Export

The readable export is for humans and inspection. It produces one JSON file with every household/workspace and its data in a clear nested structure. Media bytes may stay in files beside the JSON, but the JSON includes stable paths, checksums, content types, filenames, and ownership metadata.

The readable export is embedded inside the full archive and is the data source used by restore tests. Bean Purchase Website and Coffee Origin Website are therefore present in both readable and full backup data.

## Restore Contract

The restore workflow deliberately runs as a Rails task instead of an app UI. It is destructive operational work and refuses to run unless the target app data is empty.

Restore verification covers:

- format version checks
- validation before import
- relationship remapping from exported IDs to new database IDs
- media integrity checks
- tests that export a populated instance and restore it into a clean database/storage area

Recipient restore keeps archive format/version `1` compatible across the schema change. New Brew rows use the same ordered six-field contract as workspace export: `recipient_kind`, `recipient_user_id`, `recipient_user_display_name`, `recipient_user_email_address`, `recipient_name`, and `cup_style`. An exact, nonblank `recipient_kind` is authoritative even when contradictory legacy keys also exist; padded nonblank values fail closed, while blank or null uses the legacy fallback. An explicit new `recipient_name: null` is authoritative over a stale legacy Guest name.

For a household recipient, restore resolves only `recipient_user_id` through the archive's old-to-new User ID map. It never selects a User by email or display label, never permits the logger as a distinct household recipient, and does not require restored current membership; this preserves a truthful former-member relationship. Self and Guest clear the recipient User, and only Guest may retain the optional private name. Cup style restores independently for all three kinds.

Older version-1 rows without the new recipient fields use only a literal legacy boolean: `true` becomes Guest and may consume the legacy Guest-name value, while `false`, `null`, or a missing flag becomes Self. Missing legacy Cup remains empty. Unsupported kinds, non-boolean legacy flags, missing/unknown User IDs, logger-as-recipient rows, non-string names/Cup values, and values longer than 120 characters raise the sanitized `InstanceBackupRestorer::RestoreError` and roll back the complete restore transaction.

Bean website restore remains compatible with archive format/version `1`. Purchase Website and Coffee Origin Website are restored independently only when the stored value is an HTTP or HTTPS URL with a host; an unsafe value is dropped without discarding a safe value in the other field. Older version-1 archives that do not contain `coffee_origin_url` remain valid and restore it as blank.

Cupping-request restore accepts only the exact public Brew snapshot structure emitted for Guest Espresso cupping pages. The root and every nested object must have the expected keys and renderable scalar types; private or unknown fields, malformed attachment references, and non-object roots fail validation before import. Cupping identity media may reference only the archived workspace logo and logger avatar. The readable payload and manifest media catalogs must agree exactly on attachment identity, ownership, paths, and metadata before either catalog is trusted for authorization or ID remapping.

Expiration queue state is operational rather than durable backup data. Restore preserves the request's open/deadline/closed state but clears archived enqueue markers and leases because Solid Queue jobs are not part of the archive. An open request with a future deadline is scheduled from clean dispatch state after the restore transaction; a failed immediate enqueue remains marker-free so recurring expiration recovery can retry it.

## Open Design Decisions

- whether production installs should keep the env-configurable default `storage/instance_backups` location and retention count of 7, or use host-specific defaults
- whether backup files are encrypted by the app or by the host environment
- whether offsite upload is built in v1 or documented as host-level setup
- whether restore should remain task-only or gain a carefully audited UI later
