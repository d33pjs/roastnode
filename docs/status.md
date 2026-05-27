# Roastnode Current Status

Last reviewed: 2026-05-28

This is the compact status ledger for humans and AI agents. It distills the original product context plus the slice docs in this repository. Update it whenever a slice changes what is done, intentionally deferred, or next.

## Built Now

- Rails 8.1 monolith at the repository root, with PostgreSQL, Hotwire, Turbo, Tailwind CSS, Active Storage, Solid Queue, Docker Compose, and local defaults for web port `3001` and PostgreSQL host port `5433`.
- Rails-native authentication, password reset flow, private-by-default app shell, and an instance admin dashboard with safe read-only checks plus backup controls.
- Workspace core: household onboarding, active workspace switching, owner/admin/member/viewer roles, invite links with private invite-only account creation, memberships page, and workspace-scoped controller patterns.
- Profile settings: display name, username-style display label, avatar, public banner, preferred landing screen, espresso focus field, hidden espresso fields, number format, and time format.
- Workspace settings: household name, currency, logo, and banner.
- Coffee core: rich beans, equipment, espresso brews, inventory adjustments, retention markers, dashboard activity, and required-open-bean espresso logging.
- Beans: rich metadata, variety information, additive photos, primary photo, crop/download/remove media controls, derived bag statuses (`stock`, `open`, `used_up`, `archived`), edit/reopen/archive-style lifecycle, duplicate-as-new-bag, duplicate-label disambiguation, manual inventory adjustment UI, and danger-zone delete with dependent brew/inventory cleanup.
- Espresso logging: curated last-brew defaults for bean, grinder, machine, active preparation tools, grind setting, brew temperature, and pre-infusion seconds only. Bean weights, dose, yield, total time, first drip, rating, channeling, notes, taste, and photos stay fresh.
- Brew corrections: edit and delete flows keep bean inventory consistent through correction/reversal helpers.
- Hero Brew Card: dense screenshot-friendly brew card on dashboard and brew details, with safe user labels, avatar/household/equipment marks, bean photo, ratio, rating, balance, retention, SVG brew chart, first drip, pre-infusion, total time, and vertical temperature label.
- Brew detail pages: full log details below the card plus related bean/equipment/preparation-tool photos and cross-links.
- Preparation tools: method-scoped checklist records with ordering, archive/reopen, edit/delete, additive photos, primary/crop/download/remove media, brew snapshots, and detail analytics.
- Equipment: edit/archive/reopen/delete lifecycle, additive photos, primary/crop/download/remove media, list photos, detail analytics, and historical brew safety when equipment is deleted.
- Equipment events: first-class maintenance logs with multiple event types, multiple affected equipment records, photos, edit/delete, equipment detail history, and dashboard activity.
- Private media: app photos are served through `MediaAttachmentsController`, with active-workspace checks, private thumbnail variants, view/download/crop/primary/remove controls, and related photo groups.
- Active-workspace export: owner-only structured JSON, beans CSV, brews CSV, and media ZIP with manifest for workspace-owned media.
- Instance backups: instance-admin-only backup profiles can be activated/configured in the app, scheduled through Solid Queue, run manually, tracked with run history/error metadata, retained by profile policy, written as either full media ZIP archives or readable all-households JSON, validated, and restored into an empty server through Rails tasks with ID remapping and media integrity checks.
- Beanconqueror import: conservative JSON subset, raw import preservation, supported bean/equipment/preparation/brew metadata mapping, source UUID duplicate handling, warnings, and import reports.
- Analytics: workspace statistics with relative/manual/all-time ranges, bean detail analytics, equipment detail analytics, and preparation tool detail analytics, all workspace scoped and query backed.
- Presentation and setup polish: self-hosted Elms Sans, Roastnode brand assets, mobile-friendly back links, cross-links between domain records, optional demo data, and documentation for each shipped slice.

## Changed From The Initial Idea

- Recipes were in the original v1 idea, but are now deliberately deferred. Do not introduce recipe tables, recipe snapshots, or recipe defaults until a dedicated recipes slice is chosen.
- Backups were originally framed as documentation plus workspace export. The current v1 direction now needs an in-app, instance-admin-only backup system with scheduled jobs, full reconstructable archives, and readable all-households JSON.
- Last-brew defaults were narrowed after product testing. The current contract copies only setup fields: bean, grinder, machine, preparation tools, grind setting, temperature, and pre-infusion seconds.
- Beanconqueror compatibility means practical import first, not round-trip parity.
- The first analytics implementation is server-rendered/query-backed. ECharts/Stimulus interactivity remains optional future work.
- User public banner is a product concept, but uploaded files remain private behind authenticated media routes.

## Still Missing For v1

- Production self-hosting guide: deployment assumptions, backup/restore verification, environment/secrets handling, storage volume guidance, and Docker Compose operations.
- Operational admin depth: background job visibility, failed-job surfacing, backup/export status, and safe health checks beyond the current read-only instance dashboard.
- Workspace administration polish: workspace deletion, ownership transfer, richer member management, and any public/private registration settings chosen for private installs.

## Later Versions / v2+

- Recipes and recipe snapshots: target definitions for espresso and other methods, default preparation tools, target dose/yield/time ranges, and brew-time snapshots.
- Non-espresso method templates beyond the espresso-first household workflow.
- Full i18n: complete locale files, German UI, and broader unit preferences beyond the current metric storage and comma-friendly number parsing.
- Beanconqueror depth: media import, settings, waters, green beans, pressure profiles, graph/device data, duplicate review, and full round-trip export.
- Analytics depth: interactive ECharts/Stimulus charting, richer correlations/recommendations, equipment event markers inside charts, and materialized summaries for large data sets.
- Maintenance automation: reminders, notification schedules, and recurring service suggestions.
- Media infrastructure: direct-upload progress, S3-compatible storage hardening, object lifecycle cleanup, and more advanced storage policies.
- Brew-card sharing: generated image export, public share links, and any social/comment/reaction surface.
- Public and roaster future: public profiles, public brew sharing, roaster catalog publishing, public/private coffee profile split, roaster workspaces, verification, marketplace checkout, billing/subscriptions, and moderation tools.
- Federation and wider app surfaces: ActivityPub or other federation for public content only, native mobile apps, offline mode, device/smart-scale integrations, cafe workflows, and full custom form builder.

## Good Next Slices

- Production self-hosting guide with backup and restore checks.
- Instance admin operations: backup status, job status, and failure visibility.
- Workspace administration polish: deletion, ownership transfer, and richer member management.

## Source Files

- Original product context: `/Users/d33pjs/Documents/Codex/2026-05-24/grill-me-i-want-to-have/CONTEXT.md`
- Repository-wide agent rules: `AGENTS.md`
- Backup system note: `docs/backup-system.md`
- Documentation index: `docs/README.md`
- Slice specs and implementation plans: `docs/superpowers/`
