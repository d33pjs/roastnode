# Production Self-Hosting

Roastnode v1 is a private household app. Production installs should optimize for boring operations: one trusted Rails app, one PostgreSQL server, durable file storage, regular backup verification, and no public registration.

## Assumptions

- Run the Rails app from the production `Dockerfile` or an equivalent Ruby 3.3.7 host.
- Run PostgreSQL 17 or another PostgreSQL version supported by Rails 8.1.
- Terminate TLS at a reverse proxy or a Kamal proxy in front of the Rails container.
- Keep Active Storage on a durable mounted volume unless you explicitly configure object storage in `config/storage.yml`.
- Run Solid Queue in production. The default Kamal config sets `SOLID_QUEUE_IN_PUMA=true` for a single-server install; split job processing into `bin/jobs` when the install grows beyond one host.

The repository `compose.yaml` is intentionally a local-development database file. Do not treat its default credentials or database name as production defaults.

## Required Secrets

Set these outside git:

- `RAILS_MASTER_KEY`: decrypts Rails credentials.
- `SECRET_KEY_BASE`: Rails session and signing secret if not supplied through credentials.
- `ROASTNODE_DATABASE_PASSWORD`: PostgreSQL password used by `config/database.yml` in production.
- `POSTGRES_USER`, `POSTGRES_DB`, `POSTGRES_HOST`, and `POSTGRES_PORT`: database connection details when they differ from defaults.

Recommended production clear env:

```bash
RAILS_ENV=production
RAILS_LOG_LEVEL=info
SOLID_QUEUE_IN_PUMA=true
```

If you enable outbound password reset mail, configure SMTP through encrypted Rails credentials or host-level secrets. Do not put SMTP passwords, database passwords, backup files, `config/master.key`, or generated `.env` files into git.

## Storage Volumes

Preserve these across deploys and host restarts:

- PostgreSQL data directory.
- `/rails/storage` when using local Active Storage.
- Backup storage path, defaulting to `storage/instance_backups` inside the Rails app volume.

With the current Kamal config, the app volume is:

```yaml
volumes:
  - "roastnode_storage:/rails/storage"
```

If you run backups to the default path, the backup files live under that same mounted storage volume. Keep a host-level copy or offsite sync of this volume; an in-app backup stored only on the same disk is not disaster recovery by itself.

## Docker Compose Shape

For a single-host Compose install, use separate services for `web`, `jobs`, and `postgres`, and mount persistent volumes for database and Rails storage. A production Compose file should look like this shape, with real image tags and real secrets supplied by your host:

```yaml
services:
  postgres:
    image: postgres:17.5
    environment:
      POSTGRES_USER: roastnode
      POSTGRES_PASSWORD: ${ROASTNODE_DATABASE_PASSWORD}
      POSTGRES_DB: roastnode_production
    volumes:
      - postgres_data:/var/lib/postgresql/data

  web:
    image: ghcr.io/OWNER/roastnode@sha256:REPLACE_WITH_RELEASE_DIGEST
    depends_on:
      - postgres
    environment:
      RAILS_ENV: production
      RAILS_MASTER_KEY: ${RAILS_MASTER_KEY}
      ROASTNODE_DATABASE_PASSWORD: ${ROASTNODE_DATABASE_PASSWORD}
      POSTGRES_HOST: postgres
      POSTGRES_DB: roastnode_production
      POSTGRES_USER: roastnode
      SOLID_QUEUE_IN_PUMA: "false"
    ports:
      - "127.0.0.1:3001:80"
    volumes:
      - roastnode_storage:/rails/storage

  jobs:
    image: ghcr.io/OWNER/roastnode@sha256:REPLACE_WITH_RELEASE_DIGEST
    command: bin/jobs
    depends_on:
      - postgres
    environment:
      RAILS_ENV: production
      RAILS_MASTER_KEY: ${RAILS_MASTER_KEY}
      ROASTNODE_DATABASE_PASSWORD: ${ROASTNODE_DATABASE_PASSWORD}
      POSTGRES_HOST: postgres
      POSTGRES_DB: roastnode_production
      POSTGRES_USER: roastnode
    volumes:
      - roastnode_storage:/rails/storage

volumes:
  postgres_data:
  roastnode_storage:
```

Put a TLS reverse proxy in front of `web`. Keep the app bound to localhost or a private Docker network unless the reverse proxy is the intended public entry point.

## First Deploy

Pull and boot the production image with real secrets. Prefer the immutable digest from the GitHub Release asset over mutable tags:

```bash
export ROASTNODE_IMAGE="ghcr.io/OWNER/roastnode@sha256:REPLACE_WITH_RELEASE_DIGEST"
docker pull "$ROASTNODE_IMAGE"
docker compose up -d postgres
docker compose run --rm web bin/rails db:prepare
docker compose up -d web jobs
```

Then check:

```bash
curl -fsS http://127.0.0.1:3001/up
docker compose logs --tail=100 web
docker compose logs --tail=100 jobs
```

Create the first account through the normal private onboarding flow, then mark the hosting admin from a trusted shell:

```bash
docker compose exec web bin/rails runner 'User.find_by!(email_address: "admin@example.com").update!(instance_admin: true)'
```

## Backup Verification

Use the instance-admin UI to activate backup profiles. For a manual command-line run, create or find the profile and enqueue it from a trusted shell:

```bash
docker compose exec web bin/rails runner 'profile = InstanceBackupProfile.find_by!(backup_kind: "full_archive"); profile.enqueue_run!(track_schedule: false)'
```

Watch job logs and confirm the latest run succeeded:

```bash
docker compose logs -f jobs
docker compose exec web bin/rails runner 'puts InstanceBackupRun.order(created_at: :desc).limit(5).pluck(:status, :file_path, :checksum_sha256)'
```

Validate the archive before trusting it:

```bash
docker compose exec web bin/rails 'roastnode:backup:validate[/rails/storage/instance_backups/roastnode-full-archive-example.zip]'
```

Copy at least one validated archive off the server or to a separately backed-up host volume. Keep the readable JSON export for inspection, but treat the full archive plus media files as the restore source.

## Restore Drill

Run restore drills on a fresh disposable server or empty database/storage volume, never on a live populated install.

1. Copy a validated full archive to the restore target.
2. Boot an empty Roastnode app with the same app version or a tested compatible version.
3. Confirm the target is empty:

```bash
docker compose exec web bin/rails runner 'puts({users: User.count, workspaces: Workspace.count, blobs: ActiveStorage::Blob.count}.inspect)'
```

4. Restore:

```bash
docker compose exec web bin/rails 'roastnode:backup:restore[/rails/storage/restore/roastnode-full-archive-example.zip]'
```

5. Run database prep and a health check:

```bash
docker compose exec web bin/rails db:prepare
curl -fsS http://127.0.0.1:3001/up
```

6. Sign in flow after restore: restored users receive new random password digests because password digests are intentionally excluded from backups. Use the password reset flow or a trusted production shell to set a new password for the restored instance admin.

## Routine Operations

- Before deploying a new app image, make sure the latest backup run succeeded and validates.
- After deploying, run `/up`, check `web` and `jobs` logs, and verify the instance admin page still shows queue/storage health.
- Keep PostgreSQL backups or volume snapshots in addition to Roastnode archives if your host platform offers them.
- Test restore periodically, especially before changing storage layout, database hosting, or backup retention.
- Rotate `RAILS_MASTER_KEY`, `SECRET_KEY_BASE`, and database passwords only with a planned maintenance window and a fresh backup.
- Do not enable public registration or public media routes for v1 private installs.

## Upgrade Checklist

For each production upgrade:

1. Validate the most recent full archive.
2. Read the release asset `roastnode-image-vX.Y.Z.txt` and copy the immutable image digest.
3. Optionally verify the image signature and GitHub attestations before pulling:

   ```bash
   IMAGE="ghcr.io/OWNER/roastnode@sha256:REPLACE_WITH_RELEASE_DIGEST"
   REPO="OWNER/roastnode"
   TAG="vX.Y.Z"

   cosign verify \
     --certificate-identity "https://github.com/${REPO}/.github/workflows/release-container.yml@refs/tags/${TAG}" \
     --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
     "${IMAGE}"

   gh attestation verify "oci://${IMAGE}" -R "${REPO}"
   ```

4. Update the `web` and `jobs` image reference to the new digest.
5. Pull the new image.
6. Run `bin/rails db:prepare`.
7. Start `web` and `jobs`.
8. Check `/up`.
9. Confirm a backup profile can enqueue and complete.
10. Record the app version, image digest, backup file path, checksum, and restore-drill date in your host operations notes.

See `docs/releasing.md` for maintainer-side release automation, SBOM upload, signatures, and attestations.
