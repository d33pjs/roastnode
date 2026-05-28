# Roastnode

Roastnode is a Rails-first, self-hostable coffee tracking app for private household workspaces.

The first slices are a Rails 8.1 foundation, Rails-native authentication, and Workspace Core: private household onboarding, member roles, workspace switching, and invite links.

## License

Copyright (C) 2026 Roastnode contributors.

Roastnode is licensed under `AGPL-3.0-only`. See `LICENSE`.

## Quick Start

```bash
cp .env.example .env
bundle install
docker compose up -d postgres
bin/rails db:prepare
bin/dev
```

Open `http://localhost:3001`.

## Local Defaults

- Rails web port: `3001`
- Roastnode PostgreSQL host port: `5433`
- PostgreSQL container port: `5432`
- Compose image: `postgres:17.5`

The non-default host ports are intentional so Roastnode can run beside another project already using PostgreSQL on `5432`.

## Documentation

- Setup: `docs/setup.md`
- Production self-hosting: `docs/production-self-hosting.md`
- Releasing: `docs/releasing.md`
- Workspace Core: `docs/workspace-core.md`
- Agent guidance: `AGENTS.md`
- Design specs and implementation plans: `docs/superpowers/`
