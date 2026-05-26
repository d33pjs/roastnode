# Instance Admin

Roastnode now has a minimal instance-level admin surface at `/instance_admin`.

## Scope

The page is intentionally small. It shows private-install status, read-only health checks, and aggregate counts for users, workspaces, beans, brews, and equipment. It also reminds admins that optional demo data is loaded explicitly with:

```sh
bin/rails roastnode:demo:load
```

Do not put user secrets, password digests, session details, invite tokens, or signed media URLs on this page.

## Authorization

Instance admin is controlled by `User#instance_admin?`. This is separate from workspace membership roles:

- `owner` and `admin` are workspace roles for household data and invites.
- `instance_admin` is an application-level flag for private hosting and future maintenance tools.

Controllers that expose instance-wide data should use `authorize_instance_admin!`. Workspace-scoped controllers should continue to use `current_workspace`, `current_membership`, and `current_workspace_policy`.

## Health Checks

`InstanceHealthSnapshot` builds the health rows rendered on the page:

- database connectivity and adapter
- Active Storage service name
- storage usage from Active Storage blob count and byte size
- Active Job queue adapter
- Rails version and environment

These checks are read-only. Keep them safe to run during normal page loads. Do not add checks that enqueue jobs, write files, mutate records, call external services, or expose infrastructure secrets.

## Navigation

The dashboard shows an "Instance admin" link only when `Current.user.instance_admin?` is true. Normal workspace users should not see the link and should be redirected away from `/instance_admin` with the standard authorization alert.

## Future Ideas

Good next additions would be background job status, backup/export status, and carefully audited user management. Any destructive instance-wide action needs a dedicated design and tests before implementation.
