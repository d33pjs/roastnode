# Production Self-Hosting

Roastnode v1 is a private household app. Production installs should optimize for boring operations: one trusted Rails app, one PostgreSQL server, durable file storage, regular backup verification, and no public registration.

## Assumptions

- Run the Rails app from the production `Dockerfile` or an equivalent Ruby 3.3.11 host.
- Run PostgreSQL 17 or another PostgreSQL version supported by Rails 8.1.
- Deploy the first release with Docker Compose, normally rendered and invoked by Ansible.
- Terminate public TLS at a reverse proxy such as Nginx Proxy Manager, Traefik, Caddy, or another host-managed proxy.
- Keep Active Storage on a durable mounted volume unless you explicitly configure object storage in `config/storage.yml`.
- Run Solid Queue in production. The release Compose stack runs a dedicated `jobs` service, so `SOLID_QUEUE_IN_PUMA=false` is the default.

The repository `compose.yaml` is intentionally a local-development database file. Do not treat its default credentials or database name as production defaults.

## Required Secrets

Set these outside git:

- `RAILS_MASTER_KEY`: decrypts Rails credentials.
- `SECRET_KEY_BASE`: Rails session and signing secret if not supplied through credentials.
- `ROASTNODE_DATABASE_PASSWORD`: PostgreSQL password used by `config/database.yml` in production.
- `POSTGRES_USER`, `POSTGRES_DB`, `POSTGRES_HOST`, and `POSTGRES_PORT`: database connection details when they differ from defaults.
- SMTP credentials and a verified sender address if password reset or invite mail is enabled.

Recommended production clear env:

```bash
RAILS_ENV=production
RAILS_LOG_LEVEL=info
SOLID_QUEUE_IN_PUMA=false
ROASTNODE_HOST=coffee.example.com
ROASTNODE_PROTOCOL=https
```

If you enable outbound password reset or invite mail, configure SMTP through host-level secrets or the rendered env file. `SMTP_FROM_ADDRESS` controls the message `From:` header and should use a domain verified with your SMTP provider, such as Resend. When `SMTP_FROM_ADDRESS` is blank, Roastnode falls back to `no-reply@SMTP_DOMAIN`. Do not put SMTP passwords, database passwords, backup files, `config/master.key`, or generated `.env` files into git.

### Passkey Origin

Set `ROASTNODE_WEBAUTHN_ORIGIN` to the public HTTPS origin users open in their browser, for example `https://coffee.example.com`. Set `ROASTNODE_WEBAUTHN_RP_ID` only when you intentionally want credentials scoped to a parent domain such as `example.com`.

Passkeys are bound to the WebAuthn origin/RP ID. Changing the public hostname or RP ID can make existing passkeys unusable, so treat these values as stable production identity settings.

## Storage Volumes

Preserve these across deploys and host restarts:

- PostgreSQL data directory.
- `/rails/storage` when using local Active Storage.
- Backup storage path, defaulting to `storage/instance_backups` inside the Rails app volume.

With the release Compose stack, the app volume is:

```yaml
volumes:
  - "roastnode_storage:/rails/storage"
```

If you run backups to the default path, the backup files live under that same mounted storage volume. Keep a host-level copy or offsite sync of this volume; an in-app backup stored only on the same disk is not disaster recovery by itself.

## Docker Compose Bundle

The production examples live in:

- `deploy/compose.production.yml`: `postgres`, `web`, and `jobs` services.
- `deploy/production.env.example`: documented operator-facing environment variables.

Ansible should render the env file on the host and keep it out of git. A typical host layout is:

```text
/opt/roastnode/compose.yml
/opt/roastnode/.env
/opt/roastnode/certs/
```

Copy `deploy/compose.production.yml` to `compose.yml`, render `deploy/production.env.example` to `.env`, and set `ROASTNODE_IMAGE` to the immutable release digest from the GitHub Release asset. The Compose file uses separate durable volumes for PostgreSQL and `/rails/storage`.

Keep the app bound to localhost or a private Docker network unless the reverse proxy is the intended public entry point.

## HTTP And TLS Modes

Default mode is plain HTTP inside the host or Docker network:

```text
reverse proxy or private network -> Thruster HTTP -> Puma
```

Use this for the normal Ansible + Compose setup. Thruster listens on container port `80`, forwards to Puma, and provides HTTP/2, public asset caching, compression, and X-Sendfile support.

For direct public exposure without another reverse proxy, let Thruster manage ACME certificates:

```env
THRUSTER_TLS_DOMAIN=coffee.example.com
THRUSTER_STORAGE_PATH=/rails/storage/thruster
```

For encrypted reverse-proxy-to-app traffic with self-signed or private-CA certificates, bypass Thruster and run Puma HTTPS directly:

```env
ROASTNODE_CERTS_PATH=/opt/roastnode/certs
ROASTNODE_WEB_COMMAND=./bin/rails server
ROASTNODE_CONTAINER_PORT=3443
PORT=3443
PUMA_SSL_CERT_PATH=/rails/certs/roastnode.crt
PUMA_SSL_KEY_PATH=/rails/certs/roastnode.key
```

That mode changes the chain to:

```text
reverse proxy -> Puma HTTPS
```

Use direct Puma HTTPS only when you specifically need encrypted proxy-to-app traffic. Enabling Puma TLS behind Thruster would encrypt the wrong hop and would not protect the reverse proxy's connection to the app container.

## Environment Settings

The production env example documents the supported settings. Important groups:

- Image: `ROASTNODE_IMAGE`, plus optional `POSTGRES_IMAGE`.
- Rails secrets: `RAILS_MASTER_KEY`, optional `SECRET_KEY_BASE`.
- Database: `POSTGRES_HOST`, `POSTGRES_PORT`, `POSTGRES_USER`, `POSTGRES_DB`, `ROASTNODE_DATABASE_PASSWORD`.
- URLs and host authorization: `ROASTNODE_HOST`, `ROASTNODE_PROTOCOL`, optional `ROASTNODE_PORT`, `ROASTNODE_ALLOWED_HOSTS`.
- SSL headers and redirects: `RAILS_ASSUME_SSL`, `RAILS_FORCE_SSL`.
- SMTP: `SMTP_ENABLED`, `SMTP_ADDRESS`, `SMTP_PORT`, `SMTP_DOMAIN`, `SMTP_FROM_ADDRESS`, `SMTP_USER_NAME`, `SMTP_PASSWORD`, `SMTP_AUTHENTICATION`, `SMTP_ENABLE_STARTTLS_AUTO`, `SMTP_OPENSSL_VERIFY_MODE`, `SMTP_RAISE_DELIVERY_ERRORS`.
- Jobs and concurrency: `SOLID_QUEUE_IN_PUMA`, `RAILS_MAX_THREADS`, `WEB_CONCURRENCY`.
- Footer metadata: release images bake `ROASTNODE_VERSION` from the release tag for the signed-in footer version label. Set `ROASTNODE_VERSION` only when you need an explicit override. Local checkouts fall back to the latest git tag when `.git` is present, then `development`. `ROASTNODE_GITHUB_URL` optionally overrides the global source link.
- Backup defaults: `ROASTNODE_BACKUP_STORAGE_PATH`, `ROASTNODE_BACKUP_RETENTION_COUNT`.
- Thruster: `THRUSTER_TLS_DOMAIN`, `THRUSTER_STORAGE_PATH`, `THRUSTER_GZIP_COMPRESSION_DISABLE_ON_AUTH`.
- Direct Puma HTTPS: `ROASTNODE_WEB_COMMAND`, `ROASTNODE_CONTAINER_PORT`, `PORT`, `PUMA_SSL_CERT_PATH`, `PUMA_SSL_KEY_PATH`, `PUMA_BIND_HOST`.

## First Deploy

Pull and boot the production image with real secrets. Prefer the immutable digest from the GitHub Release asset over mutable tags:

```bash
cd /opt/roastnode
docker compose pull
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

4. Update `ROASTNODE_IMAGE` in the rendered `.env` file to the new digest.
5. Pull the new image.
6. Run `bin/rails db:prepare`.
7. Start `web` and `jobs`.
8. Check `/up`.
9. Confirm a backup profile can enqueue and complete.
10. Record the app version, image digest, backup file path, checksum, and restore-drill date in your host operations notes.

See `docs/releasing.md` for maintainer-side release automation, SBOM upload, signatures, and attestations.
