# Instance Backup System

The instance backup system is v1 operational scope. It is separate from active-workspace export: workspace export is owner-facing portability for one household, while instance backup is instance-admin-only disaster recovery for the whole server.

## Product Intent

- Instance admins can activate and configure backup profiles inside the app.
- Backup jobs run manually or on a schedule through Solid Queue.
- Backups are configurable by profile, starting with a full media archive and a readable all-households JSON export.
- A full backup is not complete until an empty-server restore path verifies it can reconstruct a new Roastnode server.

## Implemented Surface

- `/instance_admin` shows backup profile activation cards, profile configuration, recent run history, and manual run buttons.
- `InstanceBackupProfile` stores the backup kind, enabled state, schedule, storage path, retention count, and last scheduled enqueue time.
- `InstanceBackupSchedulerJob` is configured in `config/recurring.yml` for production and enqueues due enabled profiles through Solid Queue.
- `InstanceBackupJob` runs a queued `InstanceBackupRun`, writes the backup file, records file size, SHA-256 checksum, timestamps, success/failure status, and error message.
- Retention is enforced per profile by keeping the newest successful files and deleting older retained file paths.

## Full Reconstructable Export

The full archive currently includes a manifest, a readable instance JSON export, and every original Active Storage attachment in the archive:

- all users and account profile metadata needed for restore
- all workspaces/households
- all memberships and roles
- all beans, equipment, preparation tools, brews, equipment events, inventory adjustments, statistics source records, and import metadata
- all workspace media and account media, including originals
- a manifest with format version, generated time, file checksums, and relationships between JSON records and media files

The full export must not include password digests, sessions, invite tokens, signed media URLs, environment variables, infrastructure secrets, or anything that can impersonate a live login.

## Readable JSON Export

The readable export is for humans and inspection. It produces one JSON file with every household/workspace and its data in a clear nested structure. Media bytes may stay in files beside the JSON, but the JSON includes stable paths, checksums, content types, filenames, and ownership metadata.

This export is not a replacement for the full restore archive unless restore tests explicitly prove it can rebuild an empty server.

## Restore Contract

Backups are not complete until restore is verified. The next v1 slice should include:

- an empty-server restore/import workflow
- format version checks
- validation before import
- relationship remapping from exported IDs to new database IDs
- media integrity checks
- tests that export a populated instance and restore it into a clean database/storage area

## Open Design Decisions

- whether the default `storage/instance_backups` location and retention count of 7 should change for production installs
- whether backup files are encrypted by the app or by the host environment
- whether offsite upload is built in v1 or documented as host-level setup
- whether restore is a UI action, a Rails task, or both
