# Roastnode Foundation Design

Date: 2026-05-25

## Goal

Create the first Roastnode repository foundation in the current root directory. The result should be a modern Rails app scaffold with documentation, Git history, and local development defaults that can coexist with the existing local project using PostgreSQL on host port `5432`.

## Approaches Considered

### Recommended: Rails 8.1 on Ruby 3.3.7

Use the latest stable Rails 8.1 line and the locally installed Ruby 3.3.7 runtime. This matches current Rails support requirements, keeps the project in the active release stream, and avoids the broken global Rails executable tied to Ruby 3.1.2.

### Conservative: Rails 7.2 on Ruby 3.1.2

This would fit the currently selected global Ruby, but it starts a brand-new app behind the current Rails generation and would require a near-term upgrade. It also ignores that Ruby 3.3.7 is already installed locally.

### Container-only Scaffold

Generate and run everything inside Docker. This improves environment isolation but slows initial iteration and adds complexity before the app has any domain behavior.

## Chosen Design

Use Rails 8.1.3 with Ruby 3.3.7, PostgreSQL, Hotwire/Turbo/Stimulus, and Tailwind CSS. Generate the Rails application into the repository root with `rails new .`, not into a nested folder.

The initial slice includes:

- Git repository initialization.
- Foundation docs under `docs/`.
- AI-agent guidance in `AGENTS.md`.
- Rails app scaffold in the repository root.
- PostgreSQL configuration for local development and test.
- Docker Compose defaults that avoid host port `5432` by publishing Postgres on `5433`.
- Web server defaults that avoid host port `3000` by documenting and using `3001`.
- Rails-native authentication generator if available in the generated Rails version.
- A minimal home route that proves the app boots.
- Initial verification through bundle install, database setup where possible, and Rails tests.

## Constraints

- Do not create `/roastnode/roastnode`.
- Do not stop or disturb the existing Postgres container on host port `5432`.
- Keep private household data and future public data boundaries explicit in docs and model design.
- Prefer Rails defaults unless Roastnode's self-hosting requirements justify configuration.

## Data And Service Defaults

Local Compose should use:

- App HTTP host port: `3001`.
- Postgres host port: `5433`.
- Postgres container port: `5432`.
- Database user: `roastnode`.
- Development database: `roastnode_development`.
- Test database: `roastnode_test`.

## Error Handling And Setup

The app should fail loudly on missing database credentials in production but be simple locally. Development and test should work from checked-in defaults and optional `.env` overrides.

## Testing And Verification

For the foundation slice, verification is:

- `bundle exec rails test`.
- `bundle exec rails db:prepare` or equivalent if PostgreSQL is reachable.
- A boot check for the Rails server when dependencies and database are available.

Later slices must add targeted tests for authentication, workspace isolation, authorization, invites, imports, inventory, media access, and export.

## Documentation Follow-up

After scaffolding, add setup documentation for:

- Native local development.
- Docker Compose development.
- Port choices and how to change them.
- Common troubleshooting for Ruby, Bundler, Rails, and PostgreSQL.

