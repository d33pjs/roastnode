# Roastnode Current Status

Last reviewed: 2026-06-03

This is the compact public status ledger for humans and AI agents. It distills the original product context plus the slice docs in this repository. Update it whenever a slice changes what is done or intentionally deferred.

## Built Now

- Rails 8.1 monolith at the repository root, with PostgreSQL, Hotwire, Turbo, Tailwind CSS, Active Storage, Solid Queue, Docker Compose, and local defaults for web port `3001` and PostgreSQL host port `5433`.
- Rails-native authentication, first-user setup for empty installs, password reset, signed-in password change flows, optional user passkeys with browser-picker login and passkey second factor, private-by-default app shell, and an instance admin dashboard with safe read-only checks plus backup controls.
- Workspace core: household onboarding, active workspace switching, owner/admin/member/viewer roles, invite links with optional email delivery and optional username capture during invite signup, resend/re-invite for email-bound invites, private invite-only account creation, instance-admin email invites for creating separate new households while public registration remains disabled, member role management/removal, owner-only ownership transfer, owner-only workspace deletion, and workspace-scoped controller patterns.
- Profile settings: display name, username-style display label, avatar, public banner, preferred landing screen, espresso focus field, hidden espresso fields, number format, and time format.
- Workspace settings: household name, currency, logo, banner, and public brew-share management with URLs, linked brews, edit/remove actions, view counts, and retained recent viewer IP history.
- Coffee core: rich beans, equipment, espresso brews, inventory adjustments, retention markers, dashboard activity, and required-open-bean espresso logging.
- Beans: rich metadata, variety information, additive photos, primary photo, crop/download/remove media controls, derived bag statuses (`stock`, `open`, `finished`, transitional `used_up`, `archived`), newest-used-first overview sorting, normal finished-bag lifecycle with `finished_at` and used/days/grams-per-day stats, exceptional issue/archive card, duplicate-as-new-bag, duplicate-label disambiguation, manual inventory adjustment UI, compact overview/detail remaining cards with rating and color-coded remaining bars, and danger-zone delete with dependent brew/inventory cleanup.
- Bean grinder tendencies: bean detail pages always show a grinder tendency card. After a non-duplicated bag has its first brew, the app can suggest a same-grinder adjustment from that first brew's setting, ratio, and total time toward the current espresso target of `1:2.5` in `25-30s`. Suggestions use workspace brew history as comparable context, safe auto-detection for Eureka-style `turn/dial` strings and plain numeric settings, and small relative moves instead of jumping to one absolute historical setting. Blank, inconsistent, or unknown setting strings are skipped instead of raising errors. The card also shows per-bean grinder-setting distribution. New duplicated bags record their source bag, automatic suggestions are suppressed for those bags, and a manual in-card calculation remains available.
- Espresso logging: curated last-brew defaults for bean, grinder, machine, active preparation tools, grind setting, brew temperature, and pre-infusion seconds only, using the user's last active-workspace brew or the workspace's last brew for users without household brew history. Bean weights, dose, yield, total time, first drip, rating, channeling, notes, taste, and photos stay fresh. Ground out can prefill dose one way while logging.
- Recipe profiles: workspace-private espresso recipes can be created from existing brews, preserve public-safe source brew snapshots, expose editable exact targets, structured finish ingredients, finish notes, and one optional private finished-drink photo, and show prominent target markers for grinder, dose, timing, yield, temperature, and watch notes. Creating from a source brew can explicitly reuse the brew's primary photo without auto-selecting it. Recipe-guided logging keeps normal brew defaults unchanged, stores `recipe_id` plus a brew-time `recipe_snapshot`, and renders a subtle Hero Brew Card target ghost. Portable recipe JSON export/import creates unlinked private snapshots with finish ingredients and finish notes, without auto-creating beans, equipment, tools, brews, or media. Public recipe sharing uses unlisted, optionally password-protected token pages with curated snapshots, public finish details, public source notes, public recipe links, and explicitly selected recipe photos served through opaque media handles. Viewers can read recipes but cannot create, edit, delete, export, import, share, or start recipe-guided logging.
- Brew corrections: edit and delete flows keep bean inventory consistent through correction/reversal helpers, while saved taste balance and rating can be adjusted from brew detail with an explicit save.
- Hero Brew Card: dense screenshot-friendly brew card on dashboard and brew details, with safe user labels, avatar/household/equipment marks, bean photo, ratio, rating, balance, retention, SVG brew chart, first drip, pre-infusion, total time, and vertical temperature label.
- Brew detail pages: full log details below the card plus related bean/equipment/preparation-tool photos and cross-links.
- Public brew sharing: workspace writers can publish their own brews through curated, optionally password-protected token pages with a snapshot-driven Hero Brew Card that mirrors the private graph treatment without recipe ghosts, selected non-cropped photos with a mobile-friendly next/previous/swipe fullscreen viewer, public notes, visible public links, prominent buy/affiliate links, bean public purchase/opening details when available, and refreshed snapshots after public-safe linked data changes. Owners/admins can manage any workspace share; viewers cannot. Public media is served only through the public share whitelist. Workspace settings show public share URLs, linked brews, edit/remove actions, total page views, and a capped recent full-IP view history.
- Preparation tools: method-scoped checklist records with ordering, owner/admin-only lifecycle and media management, member-visible tool use in brew logging, brew snapshots, and detail analytics.
- Equipment: owner/admin-only edit/archive/reopen/delete lifecycle and media management, member-visible gear details, list photos, detail analytics, and historical brew safety when equipment is deleted.
- Equipment events: first-class maintenance logs with multiple event types, multiple affected equipment records, photos, edit/delete, Gear overview logging entry point, equipment detail history, and dashboard activity.
- Private media: app photos are served through `MediaAttachmentsController`, with active-workspace checks, private thumbnail variants, view/download/crop/primary/remove controls, and related photo groups, including private recipe finished-drink photos.
- Active-workspace export: owner-only structured JSON, beans CSV, brews CSV, and media ZIP with manifest for workspace-owned media.
- Instance backups: instance-admin-only backup profiles can be activated/configured in the app, scheduled through Solid Queue, run manually, tracked with run history/error metadata, retained by profile policy, written as either full media ZIP archives or readable all-households JSON, validated, and restored into an empty server through Rails tasks with ID remapping and media integrity checks.
- Instance admin operations: read-only backup coverage/status, SMTP status, recent mail delivery failures, Solid Queue job counts, failed-job/failure surfacing, worker visibility, and workspace export availability with redacted operational errors.
- Beanconqueror import: conservative JSON subset, raw import preservation, supported bean/equipment/preparation/brew metadata mapping, source UUID duplicate handling, warnings, and import reports.
- Analytics: workspace statistics with relative/manual/all-time ranges, all-time bean detail analytics, equipment detail analytics, and preparation tool detail analytics, all workspace scoped and query backed.
- Production self-hosting guide: deployment assumptions, environment/secrets handling, SMTP sender configuration, storage volume guidance, Ansible-friendly Compose/env examples, digest-based image upgrades, backup validation, empty-server restore drills, and upgrade checks.
- Presentation and setup polish: self-hosted Elms Sans, Roastnode brand assets, mobile-friendly back links, cross-links between domain records, optional demo data, and documentation for each shipped slice.

## Changed From The Initial Idea

- Recipes were narrowed from the original broad v1 idea. The current implementation starts with exact-target recipe profiles, guided logging overlays, Hero Card ghost comparison, JSON portability, and curated public recipe pages. Machine-readable profile files remain a separate follow-up slice.
- Backups were originally framed as documentation plus workspace export. The current v1 direction now needs an in-app, instance-admin-only backup system with scheduled jobs, full reconstructable archives, and readable all-households JSON.
- Last-brew defaults were narrowed after product testing. The current contract copies only setup fields: bean, grinder, machine, preparation tools, grind setting, temperature, and pre-infusion seconds.
- Beanconqueror compatibility means practical import first, not round-trip parity.
- The first analytics implementation is server-rendered/query-backed. ECharts/Stimulus interactivity remains optional future work.
- Public identity images are now split by context: normal app media stays private behind authenticated routes, while workspace logos and user avatars referenced by enabled public brew-share snapshots can render through the public share media whitelist.

## Private Open Topics

Current roadmap and open-topic notes are intentionally kept out of the public repository.

## Source Files

- Original product context: private planning notes outside this repository.
- Repository-wide agent rules: `AGENTS.md`
- Backup system note: `docs/backup-system.md`
- Production self-hosting guide: `docs/production-self-hosting.md`
- Documentation index: `docs/README.md`
- Public brew sharing contract: `docs/public-brew-sharing.md`
- Slice specs and implementation plans: `docs/superpowers/`
