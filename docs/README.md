# Roastnode Documentation

This folder is the durable project memory for humans and AI agents.

## Start Here

- `docs/superpowers/specs/2026-05-25-foundation-design.md` describes the first implementation slice.
- `docs/status.md` summarizes what is built and what changed from the initial idea.
- `docs/workspace-core.md` describes workspaces, roles, invites, and the workspace-scoping rule for future product data.
- `docs/workspace-settings.md` describes active-workspace settings for household name and currency.
- `docs/landing-preferences.md` describes preferred start screens and the stable dashboard route.
- `docs/account-privacy.md` describes where to use display labels instead of email addresses.
- `docs/brew-form-preferences.md` describes per-user brew-method, spoon estimate, and espresso form focus behavior.
- `docs/brew-draft-recovery.md` describes browser-local unsaved method-aware brew draft recovery.
- `docs/formatting.md` describes comma-friendly decimal entry and pending profile-formatting decisions.
- `docs/coffee-core.md` describes beans, equipment, espresso and Quick Drip logging, inventory deduction, and current coffee workflow scope.
- `docs/external-coffees.md` describes planned purchased/out-of-home coffee logging, comparison, sharing, and privacy rules.
- `docs/recipe-profiles.md` describes workspace recipe profiles, exact brew targets, guided logging, public recipe sharing, and snapshot privacy.
- `docs/inventory-adjustments.md` describes manual bean inventory corrections.
- `docs/bean-analytics.md` describes the bean detail drill-down analytics slice.
- `docs/bean-danger-zone.md` describes destructive bean deletion and dependent brew/inventory cleanup.
- `docs/brew-corrections.md` describes brew edits/deletes and inventory correction rules.
- `docs/brew-card.md` describes the compact screenshot-worthy brew detail card.
- `docs/public-brew-sharing.md` describes curated public brew pages, public notes, affiliate links, password gates, and public media privacy rules.
- `docs/public-bean-sharing.md` describes curated public bean bag pages, all-brew summaries, password gates, and selected bean package photo privacy rules.
- `docs/beanconqueror-import.md` describes practical Beanconqueror JSON import.
- `docs/equipment-events.md` describes maintenance events, equipment detail pages, and timeline activity rules.
- `docs/equipment-lifecycle.md` describes equipment edit, archive, reopen, delete, and historical-reference behavior.
- `docs/preparation-tools.md` describes method-scoped brew checklist tools and brew snapshots.
- `docs/private-media.md` describes private photo upload, display, and scoped media delivery.
- `docs/workspace-export.md` describes owner-only JSON and CSV workspace exports.
- `docs/backup-system.md` describes the instance-admin backup and empty-server restore contract.
- `docs/demo-data.md` describes the optional demo household loader.
- `docs/statistics.md` describes the first private workspace analytics page.
- `docs/typography.md` describes the self-hosted Elms Sans font setup and license note.
- `docs/branding.md` describes logo files, current placements, and browser icon usage.
- `docs/navigation.md` describes cross-links between beans, brews, equipment, preparation tools, and shared back-link UI.
- `docs/instance-admin.md` describes the private instance admin dashboard and the `User#instance_admin` boundary.
- `docs/setup.md` describes local Rails and Docker Compose setup.
- `docs/production-self-hosting.md` describes production deployment assumptions, storage, backups, restore drills, and Docker Compose operations.
- `deploy/compose.production.yml` and `deploy/production.env.example` are the Ansible-friendly production Compose/env examples.
- `AGENTS.md` contains repository-wide guidance for AI coding agents.

## Documentation Expectations

- Add or update docs when a decision affects setup, architecture, data ownership, security, or deployment.
- Prefer short, linked Markdown files over large catch-all documents.
- Capture trade-offs and rejected options so future agents do not reopen settled decisions without cause.
- Keep `AGENTS.md` as a compact operating guide. Move durable product and implementation rules into the relevant docs here, then link to them from `AGENTS.md`.
