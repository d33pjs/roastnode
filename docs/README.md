# Roastnode Documentation

This folder is the durable project memory for humans and AI agents.

## Start Here

- `docs/superpowers/specs/2026-05-25-foundation-design.md` describes the first implementation slice.
- `docs/workspace-core.md` describes workspaces, roles, invites, and the workspace-scoping rule for future product data.
- `docs/workspace-settings.md` describes active-workspace settings for household name and currency.
- `docs/landing-preferences.md` describes preferred start screens and the stable dashboard route.
- `docs/brew-form-preferences.md` describes per-user espresso form focus behavior.
- `docs/brew-draft-recovery.md` describes browser-local unsaved espresso draft recovery.
- `docs/coffee-core.md` describes beans, equipment, required-bean espresso logging, inventory deduction, and deferred recipe scope.
- `docs/bean-analytics.md` describes the bean detail drill-down analytics slice.
- `docs/bean-danger-zone.md` describes destructive bean deletion and dependent brew/inventory cleanup.
- `docs/brew-corrections.md` describes brew edits/deletes and inventory correction rules.
- `docs/brew-card.md` describes the compact screenshot-worthy brew detail card.
- `docs/beanconqueror-import.md` describes practical Beanconqueror JSON import.
- `docs/equipment-events.md` describes maintenance events, equipment detail pages, and timeline activity rules.
- `docs/preparation-tools.md` describes method-scoped brew checklist tools and brew snapshots.
- `docs/private-media.md` describes private photo upload, display, and scoped media delivery.
- `docs/workspace-export.md` describes owner-only JSON and CSV workspace exports.
- `docs/demo-data.md` describes the optional demo household loader.
- `docs/statistics.md` describes the first private workspace analytics page.
- `docs/typography.md` describes the self-hosted Elms Sans font setup and license note.
- `docs/branding.md` describes logo files, current placements, and browser icon usage.
- `docs/setup.md` describes local Rails and Docker Compose setup.
- `AGENTS.md` contains repository-wide guidance for AI coding agents.

## Documentation Expectations

- Add or update docs when a decision affects setup, architecture, data ownership, security, or deployment.
- Prefer short, linked Markdown files over large catch-all documents.
- Capture trade-offs and rejected options so future agents do not reopen settled decisions without cause.
