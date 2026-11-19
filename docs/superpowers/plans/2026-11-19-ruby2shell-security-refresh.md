# Ruby2Shell Security Refresh Implementation Plan

**Goal:** Replace the exposed Ruby runtime with the latest fixed stable release and refresh compatible dependencies, then release and deploy through Santiago.

**Architecture:** Keep the Rails monolith and existing release pipeline. Rebuild both application services from an immutable release image and verify the running runtime rather than trusting configuration alone.

**Tech Stack:** Ruby, Rails, Bundler, importmap, GitHub Actions/GHCR, Docker Compose and Santiago's existing Ansible deployment.

## Constraints

- Work on the existing `main` checkout; preserve user changes.
- Ruby must be at least 4.0.10 for GHSA-34m4-m9fh-gqp5.
- Keep parent-gem compatibility constraints and the existing PostgreSQL major version.
- Do not expose secrets or private application data in logs or release notes.
- Commit, push, release and deploy without another approval, as explicitly authorized.

## Tasks

- [x] Add a regression gate rejecting the vulnerable runtime pin; run it against 4.0.9 and observe failure.
- [x] Pin Ruby 4.0.10 consistently; resolve all gems and check official upstream versions for runtime, JavaScript, CI actions and release tools.
- [x] Update dependency/security/setup documentation; run full Rails and JavaScript suites, browser smoke tests, lint, fresh advisory scans and production asset compilation.
- [ ] Review the final diff, commit on `main`, push through Gitea and verify CI and GitHub synchronization.
- [ ] Publish the next patch release with a sanitized public changelog; verify its immutable image and supply-chain artifacts.
- [ ] Deploy that digest through Santiago with the existing backup and health gates; verify web/jobs Ruby versions, release version, health, migrations and workers.
- [ ] Record the verified release/deployment results, commit and push the final documentation, and leave the local preview running.
