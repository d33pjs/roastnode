# Roastnode Current Status

Last reviewed: 2026-05-27

This is the compact status ledger for humans and AI agents. It distills the original product context plus the slice docs in this repository. Update it whenever a slice changes what is done, intentionally deferred, or next.

## Built Now

- Rails 8.1 monolith at the repository root, with PostgreSQL, Hotwire, Turbo, Tailwind CSS, Active Storage, Solid Queue, Docker Compose, and local defaults for web port `3001` and PostgreSQL host port `5433`.
- Rails-native authentication, password reset flow, private-by-default app shell, and a small read-only instance admin dashboard.
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
- Private media: app photos are served through `MediaAttachmentsController`, with active-workspace checks, view/download/crop/primary/remove controls, and related photo groups.
- Workspace export: owner-only structured JSON, beans CSV, brews CSV, and media ZIP with manifest for workspace-owned media.
- Beanconqueror import: conservative JSON subset, raw import preservation, supported bean/equipment/preparation/brew metadata mapping, source UUID duplicate handling, warnings, and import reports.
- Analytics: workspace statistics with relative/manual/all-time ranges, bean detail analytics, equipment detail analytics, and preparation tool detail analytics, all workspace scoped and query backed.
- Presentation and setup polish: self-hosted Elms Sans, Roastnode brand assets, mobile-friendly back links, cross-links between domain records, optional demo data, and documentation for each shipped slice.

## Changed From The Initial Idea

- Recipes were in the original v1 idea, but are now deliberately deferred. Do not introduce recipe tables, recipe snapshots, or recipe defaults until a dedicated recipes slice is chosen.
- Last-brew defaults were narrowed after product testing. The current contract copies only setup fields: bean, grinder, machine, preparation tools, grind setting, temperature, and pre-infusion seconds.
- Beanconqueror compatibility means practical import first, not round-trip parity.
- The first analytics implementation is server-rendered/query-backed. ECharts/Stimulus interactivity remains optional future work.
- User public banner is a product concept, but uploaded files remain private behind authenticated media routes.

## Still Open From The Initial Idea

- Recipes and recipe snapshots: target definitions for espresso and other methods, default preparation tools, target dose/yield/time ranges, and brew-time snapshots.
- Non-espresso method templates: the app is espresso-first; other methods are not yet first-class logging flows.
- Workspace administration depth: workspace deletion, ownership transfer, richer member management, and public/private registration settings are not built.
- Full i18n: English UI exists with metric storage; complete locale files, German UI, and broader unit preferences are still open.
- Beanconqueror depth: media import, settings, waters, green beans, pressure profiles, graph/device data, background import processing, possible duplicate review, and full round-trip export are open.
- Analytics depth: interactive charting, richer correlations/recommendations, equipment event markers inside charts, and materialized summaries for large data sets are open.
- Maintenance automation: reminders, notification schedules, and recurring service suggestions are not built.
- Media infrastructure: generated thumbnails/variants, direct-upload progress, S3-compatible storage hardening, object lifecycle cleanup, and account-data media export are open.
- Self-hosting operations: backups, restore flow, production hardening guides, background job monitoring, and health checks beyond the current instance dashboard are open.
- Public future: public profiles, public brew sharing links, roaster catalog publishing, public/private coffee profile split, federation, billing/subscriptions, marketplace checkout, native mobile apps, offline mode, and device/smart-scale integrations remain outside current v1.

## Good Next Slices

- Thumbnail/variant generation for media-heavy pages.
- Recipe target definitions and brew-time recipe snapshots.
- Interactive analytics charts, starting with workspace and bean detail screens.
- Maintenance reminders based on equipment events and usage counters.
- Production self-hosting guide with backup and restore checks.

## Source Files

- Original product context: `/Users/d33pjs/Documents/Codex/2026-05-24/grill-me-i-want-to-have/CONTEXT.md`
- Repository-wide agent rules: `AGENTS.md`
- Documentation index: `docs/README.md`
- Slice specs and implementation plans: `docs/superpowers/`
