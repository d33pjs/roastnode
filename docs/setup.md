# Roastnode Setup

Roastnode is a Rails 8.1 app generated in the repository root.

## Requirements

- Ruby 3.3.12 through rbenv or another Ruby version manager
- Bundler 4.0.17
- Docker Desktop with Docker Compose
- PostgreSQL 17.10 is the default Compose image
- libvips for Active Storage image variants (`brew install vips` on macOS or `apt install libvips` on Debian/Ubuntu)
- PostgreSQL client tools are useful but not required if you use Compose

## Local Ports

Roastnode avoids the common defaults because another local project already uses PostgreSQL on host port `5432`.

- Rails web: `3001`
- Roastnode PostgreSQL host port: `5433`
- PostgreSQL container port: `5432`

Change these with environment variables from `.env` or your shell.

## LAN Access

Start the development server through tmux so it survives agent command-session cleanup and can be stopped consistently:

```bash
tmux new-session -d -s roastnode-dev -c "$PWD" 'bin/dev'
```

Attach to inspect logs:

```bash
tmux attach -t roastnode-dev
```

Stop it with Ctrl-C inside the attached tmux session, or send Ctrl-C from another shell:

```bash
tmux send-keys -t roastnode-dev C-c
```

When testing from another host on the network, keep `BINDING=0.0.0.0` and add named LAN hosts through `ROASTNODE_DEV_HOSTS` before starting `bin/dev`. The project `.env` can hold those defaults:

```bash
BINDING=0.0.0.0
ROASTNODE_DEV_HOSTS=coffee-box.local,coffee-box.local:3001
```

### Local Passkey Origin

Passkey development defaults to `http://localhost:3001`, matching the preferred local Rails port. If you use a different local hostname or port, set `ROASTNODE_WEBAUTHN_ORIGIN` before starting Rails.

Browser passkey APIs require a secure context. `http://localhost:3001` works for local development, but an HTTP LAN hostname such as `http://coffee-box.local:3001` will not expose passkeys unless you serve it over HTTPS.

## First Setup

```bash
cp .env.example .env
rbenv local 3.3.12
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

## Local Git Hooks

`bin/setup` configures this checkout to use the versioned hooks in `.githooks`.
The pre-commit hook runs `bin/rubocop` with the same repo-local cache path used by
CI, so style failures are caught before a commit is created. CI still runs RuboCop
as the authoritative gate because local hooks can be skipped or missing on another
machine.

If you need to bypass the local hook deliberately, use Git's `--no-verify` flag or
set `SKIP_RUBOCOP_PRE_COMMIT=1` for that commit.

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
