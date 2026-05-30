# Roastnode Setup

Roastnode is a Rails 8.1 app generated in the repository root.

## Requirements

- Ruby 3.3.7 through rbenv or another Ruby version manager
- Bundler
- Docker Desktop with Docker Compose
- PostgreSQL 17.5 is the default Compose image because it is already present locally
- PostgreSQL client tools are useful but not required if you use Compose

## Local Ports

Roastnode avoids the common defaults because another local project already uses PostgreSQL on host port `5432`.

- Rails web: `3001`
- Roastnode PostgreSQL host port: `5433`
- PostgreSQL container port: `5432`

Change these with environment variables from `.env` or your shell.

## LAN Access

Start Rails on all interfaces when testing from another host on the network:

```bash
bin/rails server -p 3001 -b 0.0.0.0
```

For named LAN hosts, set a comma-separated allowlist before starting Rails:

```bash
ROASTNODE_DEV_HOSTS=coffee-box.local bin/rails server -p 3001 -b 0.0.0.0
```

## First Setup

```bash
cp .env.example .env
rbenv local 3.3.7
bundle install
docker compose up -d postgres
bin/rails db:prepare
bin/dev
```

Open `http://localhost:3001`.

On a fresh instance with no users, open `http://localhost:3001` and choose first account setup. That creates the initial user account, signs it in, and marks it as the instance admin. The existing household onboarding screen then creates the first private workspace. After that, additional users can join only from valid workspace invite links.

## Optional Demo Data

Load a sample household for local exploration:

```bash
bin/rails roastnode:demo:load
```

Demo login:

- Email: `demo@roastnode.local`
- Password: `roastnode-demo`

The task is idempotent. It refuses to run in production unless `ROASTNODE_ALLOW_DEMO_DATA=1` is set.

## Native Rails Commands

```bash
bin/rails test
bin/rails routes
bin/rails console
```

## Docker Compose Database

Start only the database:

```bash
docker compose up -d postgres
```

Stop it without deleting data:

```bash
docker compose stop postgres
```

Delete the local database volume:

```bash
docker compose down -v
```

## Troubleshooting

If Rails cannot connect to PostgreSQL, confirm the Compose database is healthy:

```bash
docker compose ps postgres
```

If port `5433` is already taken, set another host port:

```bash
POSTGRES_PORT=55433 docker compose up -d postgres
POSTGRES_PORT=55433 bin/rails db:prepare
```

If `rails` resolves to an older global executable, use the app binstub:

```bash
bin/rails --version
```

If Bundler warns that your home directory is not writable inside a sandboxed tool, it can still complete by using a temporary home directory. On a normal shell, Bundler should use your regular user gem paths.

## Production

For production deployment, backup verification, restore drills, storage volumes, and the Ansible-friendly Compose bundle, see `docs/production-self-hosting.md`.

Production examples live under `deploy/`:

- `deploy/compose.production.yml`
- `deploy/production.env.example`
