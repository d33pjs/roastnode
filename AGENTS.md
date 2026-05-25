# Roastnode Agent Guide

Roastnode is a private, self-hostable coffee tracking app for shared household workspaces. Treat the workspace as the ownership and authorization boundary.

## Current Direction

- Build a Rails monolith with Hotwire, Turbo, Stimulus, Tailwind CSS, PostgreSQL, Active Storage, and Solid Queue.
- Keep v1 private by default. Public and federation features are future work and must not leak household data.
- Prefer Rails-native, boring security patterns over custom cleverness.
- Store measurements in canonical metric units: grams, seconds, Celsius.
- Keep documentation in `docs/` current as decisions land.

## Working Rules

- Do not create a nested `roastnode/` app directory. The Rails app lives at the repository root.
- Commit often with small, descriptive commits.
- Protect user changes. Do not revert unrelated local edits.
- Scope early implementation to foundation, authentication, workspaces, memberships, and private household flows.
- Add tests for authorization and workspace isolation whenever adding workspace-scoped behavior.

## Local Development Intent

- Web server: prefer host port `3001`.
- PostgreSQL: prefer host port `5433` because another local project already owns `5432`.
- Docker Compose should run alongside other local projects without taking common host ports unnecessarily.
- The current Compose image is `postgres:17.5`, chosen because it is already available locally and avoids blocking setup on a Docker image pull.
