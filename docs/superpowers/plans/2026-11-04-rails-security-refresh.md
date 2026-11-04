# Rails security refresh — 2026-11-04

The user authorizes dependency updates, commits, push, release and deployment through Santiago. Stay on main and preserve unrelated work. Planned patch release: v0.9.35.

- [x] Verify current compatible releases and today's official Rails 8.1.4.1 announcement, release notes and all 13 gem checksums. Record RubySec's advisory-index lag.
- [x] Update the full compatible gem graph and security floor; verify unchanged runtime/tool pins. Review media, sessions, headers and serialization compatibility without weakening the new protections.
- [x] Run full Rails/JavaScript/browser tests, lint, security scans, seeds and production assets. Force the release base-stage package refresh and prove its configuration regression. Obtain independent review.
- [x] Commit and push the final changes; require green Gitea CI. Publish v0.9.35 and confirm exact tag/source mirroring and successful GitHub release workflow.
- [x] Verify asset hashes, notes, both image architectures, runtime/framework versions, Cosign, source-bound provenance and the exact published SBOM attestation.
- [x] Validate a recent full backup, pull the synchronized role/catalogue image pins on Santiago and run only the Roastnode play with normal maintenance gates. Verify exact running image, Rails/Ruby/gems, migrations, fresh queue heartbeats, proxy/auth health, startup logs and a fresh validated backup. Restart the LAN preview in tmux and record/push the outcome.

Result: [v0.9.35 release and deployment verification](../../status.md#rails-security-release-verification--2026-11-04). Production web/jobs run the verified image and Rails 8.1.4.1; the postdeployment full archive and checksum validated. Localhost and LAN preview health checks return 200.
