# Roastnode Agent Guide

Roastnode is a private, self-hostable coffee tracking app for shared household workspaces. Treat `Workspace` as the ownership and authorization boundary.

This file is the short operating guide for coding agents. Durable product decisions live in `docs/`; keep this file compact and link to the relevant docs instead of copying slice-level detail here.

## Start Here

- Read `docs/README.md` for the documentation map.
- Read `docs/status.md` for what is built and what changed.
- Read the specific docs for the area you are touching before editing code.
- Update docs when a decision affects setup, architecture, data ownership, security, or deployment.

## Current Direction

- Build a Rails monolith with Hotwire, Turbo, Stimulus, Tailwind CSS, PostgreSQL, Active Storage, and Solid Queue.
- Prefer Rails-native, boring security patterns over custom cleverness.
- Store measurements in canonical metric units: grams, seconds, Celsius.
- Keep data private by default. Do not leak passwords, sessions, invite tokens, signed media URLs, raw private media URLs, environment variables, or infrastructure secrets.
- Keep recipes deferred until a dedicated recipes slice is explicitly chosen.

## Working Rules

- Do not create a nested `roastnode/` app directory. The Rails app lives at the repository root.
- Keep current solo development on `main`. Do not create separate Git branches or worktrees unless the user explicitly asks to re-enable branching for a specific task.
- Commit often with descriptive commit messages, especially after finishing a request.
- Protect user changes. Do not revert unrelated local edits.
- Use `current_workspace`, `current_membership`, and `current_workspace_policy` from `ApplicationController` instead of ad hoc workspace lookups in controllers.
- Add authorization and workspace-isolation tests whenever adding workspace-scoped behavior.
- Owners and admins manage workspace settings and invite links. Members can write normal workspace data. Viewers are read-only.
- Workspace settings are singleton active-workspace routes and should not accept workspace IDs.

## Product Docs By Area

- Workspace ownership, roles, invites, and active-workspace routing: `docs/workspace-core.md`
- Workspace settings, logo/banner, and currency: `docs/workspace-settings.md`
- Account labels, email placement, avatars, and public banners: `docs/account-privacy.md`
- Decimal parsing, comma-friendly measurement inputs, and user number/time formats: `docs/formatting.md`
- Espresso logging, bean/equipment basics, inventory, last-brew defaults, and recipe deferral: `docs/coffee-core.md`
- Brew form focus and hidden-field preferences: `docs/brew-form-preferences.md`
- Browser-local espresso draft recovery: `docs/brew-draft-recovery.md`
- Brew corrections and inventory-safe update/delete helpers: `docs/brew-corrections.md`
- Bean lifecycle, deletion, inventory corrections, analytics, and Beanconqueror import: `docs/coffee-core.md`, `docs/bean-danger-zone.md`, `docs/inventory-adjustments.md`, `docs/bean-analytics.md`, `docs/beanconqueror-import.md`
- Hero Brew Card, brew detail cross-links, and mobile back-link behavior: `docs/brew-card.md`, `docs/navigation.md`
- Equipment, equipment events, and preparation tools: `docs/equipment-lifecycle.md`, `docs/equipment-events.md`, `docs/preparation-tools.md`
- Workspace analytics: `docs/statistics.md`
- Private media, thumbnails, crop/primary/remove routes, and media authorization: `docs/private-media.md`
- Workspace export and media ZIPs: `docs/workspace-export.md`
- Instance admin and instance backups: `docs/instance-admin.md`, `docs/backup-system.md`
- Demo data: `docs/demo-data.md`
- Typography and branding assets: `docs/typography.md`, `docs/branding.md`
- Local setup, ports, Docker Compose, and production notes: `docs/setup.md`, `docs/production-self-hosting.md`

## Local Development

- Prefer host port `3001` for the web server.
- Prefer host port `5433` for PostgreSQL because another local project owns `5432`.
- Docker Compose should run alongside other local projects without taking common host ports unnecessarily.
- The current Compose image is `postgres:17.5`; see `docs/setup.md` for setup commands.
- After finishing user-facing product changes, start the local development server so the user can check the result. Use `bin/rails server -p 3001 -b 0.0.0.0` unless another command is specifically needed. Make sure, other clients on the network can reach the server via DNS!
- When asked to push a git tag, summarize the changes for a public changelog from the last tag and let User approve it. Then create the tag with the approved changelog. Check afterwards if the sync between gitea and github worked and let the user know, when the tag is on github as well.
