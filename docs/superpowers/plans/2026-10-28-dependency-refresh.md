# Dependency Refresh and Release Plan

**Goal:** Refresh all compatible stable dependencies, commit/push on main, publish the next patch release with an approved public changelog, and deploy via Santiago's Roastnode Ansible playbook.

**Architecture:** Preserve the Rails monolith, workspace boundaries, public snapshots, existing PostgreSQL 17 data volume, and digest-pinned production deployment. Use official registry/release metadata and preserve lockfile checksums and immutable workflow pins.

**Execution:** Inline in the current session. User instructions authorize commit, push, release and Ansible deployment. AGENTS.md requires approval of the concrete public changelog before tagging.

## Tasks

- [x] Inspect clean main checkout, current release, maintenance/deployment docs, all gem/npm/runtime/action/scanner releases and Santiago infrastructure guidance.
- [x] Update Gemfile.lock, Ruby version/Docker/setup docs, Node CI version, vendored Chart.js plus version assertion/license, immutable action pins and checksum-pinned scanner/build tools. Keep upstream-constrained packages documented.
- [x] Run full Rails, browser and JavaScript suites, release configuration checks, RuboCop, fresh RubySec/importmap/Brakeman audits, production assets and available image/config validation. Review the final diff independently.
- [ ] Update dependency audit/status documentation; commit/push and confirm Gitea CI and GitHub mirror.
- [ ] Present public changelog since v0.9.33 for approval; only then annotate/push v0.9.34 and verify mirror, release workflow/assets/signatures/provenance.
- [ ] Validate production backup; pull infrastructure image update on Santiago, syntax-check and execute `ansible-playbook local.yml --limit roastnode --tags roastnode`; verify exact image/version, health, migrations, jobs and fresh backup.
- [ ] Record release/deployment evidence and commit/push; restart the local tmux preview and verify LAN DNS health.
