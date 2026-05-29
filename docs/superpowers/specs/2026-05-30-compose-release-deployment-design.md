# Compose Release Deployment Design

## Purpose

Prepare Roastnode for a first self-hosted release that can be deployed by Ansible with Docker Compose and an immutable container image digest. The release path should let an operator render one environment file, render or copy one Compose file, pull `ghcr.io/...@sha256:...`, run database preparation, and start the app with durable storage and clear operational settings.

## Deployment Shape

The official v1 deployment example is a single-host Docker Compose stack with separate `web`, `jobs`, and `postgres` services. The `web` and `jobs` services use the same immutable image reference through `ROASTNODE_IMAGE`, which should be set to a release digest rather than a mutable tag. PostgreSQL is bundled for the simple path, but the Rails environment variables remain compatible with an externally managed database by changing `POSTGRES_HOST`, `POSTGRES_PORT`, `POSTGRES_USER`, `POSTGRES_DB`, and `ROASTNODE_DATABASE_PASSWORD`.

The app volume mounted at `/rails/storage` is durable and stores Active Storage files, local backup files, and Thruster state. PostgreSQL data uses a separate durable volume. Backup files still need host-level or offsite copying; storing backups only in the app volume is operational convenience, not disaster recovery.

## HTTP And TLS

Default production traffic is:

```text
reverse proxy or private network -> Thruster HTTP -> Puma
```

This stays unencrypted inside the Docker/private network by default. That matches the easiest Ansible + Compose deployment and preserves Thruster's Rails-friendly proxy features: HTTP/2 support, asset caching, compression, X-Sendfile, and normal container process supervision for Puma.

For direct public exposure without another reverse proxy, operators can enable Thruster's own ACME support with `THRUSTER_TLS_DOMAIN`. This is not the default because many self-hosters already terminate TLS in Nginx Proxy Manager, Traefik, Caddy, a NAS proxy, or another edge service.

For encrypted communication between a reverse proxy and the app container with self-signed or private-CA certificates, the stack provides an explicit alternate command that bypasses Thruster and starts Puma with an SSL bind:

```text
reverse proxy -> Puma HTTPS
```

This mode is opt-in through mounted certificate and key paths. It intentionally trades away Thruster's front-door features for encrypted proxy-to-app traffic. Puma TLS is not enabled behind Thruster because that would encrypt the wrong hop.

## Runtime Settings

Operator-facing environment settings are documented in a production env example and the production guide. The first release should cover:

- image digest and Rails secrets
- database connection settings
- public host/default URL settings for generated links and host authorization
- logging level and Rails concurrency
- Solid Queue behavior for split `web` and `jobs`
- SMTP settings for password reset email
- backup storage path and retention defaults
- optional Thruster ACME settings
- optional direct Puma self-signed TLS settings

Rails production config should read safe env values directly for host, mailer URL, host authorization, SSL assumptions, forced SSL, and SMTP. Secrets remain outside git. The env example documents values without providing real credentials.

## Ansible Contract

Ansible should template the env file and deploy the Compose file. The normal flow is:

1. Put the image digest into `ROASTNODE_IMAGE`.
2. Render secrets and clear settings into the env file on the host.
3. Start PostgreSQL.
4. Run `bin/rails db:prepare` in a one-off `web` container.
5. Start `web` and `jobs`.
6. Check `/up`, logs, and the instance admin operations page.

Ansible does not need to understand Rails internals beyond the database preparation command and the immutable image reference.

## Testing

Add focused tests for production environment parsing where practical, especially mailer defaults, host authorization, SSL flags, and SMTP settings. Verify the Compose and env examples are internally consistent through text checks and Rails tests. The implementation should not add object storage, offsite backup upload, public registration, or a new deployment framework.
