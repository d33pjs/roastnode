# Instance Admin

Roastnode has an instance-level admin surface at `/instance_admin`.

## Scope

The page is intentionally small. It shows private-install status, read-only health checks, mail delivery diagnostics, backup profile controls, aggregate counts, and a read-only account list for private hosting. It also reminds admins that optional demo data is loaded explicitly with:

```sh
bin/rails roastnode:demo:load
```

Do not put user secrets, password digests, session details, invite tokens, or signed media URLs on this page.

## Backups

Instance admins can activate and configure backup profiles from the dashboard. Profiles can produce either a full media ZIP archive or a readable all-households JSON file. Runs are executed by `InstanceBackupJob`, and the production recurring schedule uses `InstanceBackupSchedulerJob` through Solid Queue.

Backup files stay on server storage under the configured relative path. The admin surface may show file paths and run status, but must not expose backup file contents or signed media URLs.

## Authorization

Instance admin is controlled by `User#instance_admin?`. This is separate from workspace membership roles:

- `owner` and `admin` are workspace roles for household data and invites.
- `instance_admin` is an application-level flag for private hosting and future maintenance tools.

The first account created through first-run setup is automatically marked `instance_admin` so a fresh private instance has an initial operator. Later account role changes remain out of scope until a dedicated user-management design exists.

Controllers that expose instance-wide data should use `authorize_instance_admin!`. Workspace-scoped controllers should continue to use `current_workspace`, `current_membership`, and `current_workspace_policy`.

## Health Checks

`InstanceHealthSnapshot` builds the health rows rendered on the page:

- database connectivity and adapter
- Active Storage service name
- storage usage from Active Storage blob count and byte size
- Active Job queue adapter
- Rails version and environment

These checks are read-only. Keep them safe to run during normal page loads. Do not add checks that enqueue jobs, write files, mutate records, call external services, or expose infrastructure secrets.

## Mail Diagnostics

The operations section shows whether SMTP appears enabled from runtime settings and lists recent mail delivery failures recorded by Solid Queue. This is meant for private operators debugging password reset or invite email delivery.

Mail diagnostics must remain read-only. They may show the mailer job class, queue, failure time, and a short redacted error message. They must not render job arguments, invite tokens, raw email payloads, SMTP passwords, session data, signed media URLs, or environment variables.

## Account List

`InstanceUserSnapshot` builds the account rows rendered on the page:

- profile display label
- account email address
- workspace membership count
- instance-admin versus normal-user badge

This is visibility only, not user management. Do not add role changes, password resets, deletion, impersonation, or invite actions to the account list without a dedicated design, authorization tests, audit trail decisions, and careful copy.

## Navigation

The dashboard shows an "Instance admin" link only when `Current.user.instance_admin?` is true. Normal workspace users should not see the link and should be redirected away from `/instance_admin` with the standard authorization alert.

## Future Ideas

Good next additions would be broader background job status, production backup/restore operations guidance, and carefully audited user management. Any destructive, restore, or account-mutating instance-wide action needs a dedicated design, authorization tests, audit trail decisions, and careful copy before implementation.
