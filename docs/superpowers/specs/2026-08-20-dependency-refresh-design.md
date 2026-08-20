# Dependency Refresh Design

Date: 2026-08-20

## Goal

Bring every resolvable Roastnode dependency to its current compatible release, refresh security evidence, and leave an auditable account of current, constrained, and intentionally deferred packages.

## Current Inventory

Roastnode uses Bundler for direct and transitive Ruby dependencies, importmap with a locally vendored Chart.js distribution for JavaScript, SHA-pinned GitHub/Gitea workflow dependencies, Ruby and PostgreSQL container/runtime versions, and downloaded SBOM tools in CI.

At design time, `bundle outdated --strict` reports compatible updates for Rails 8.1.3.1 and additional direct or transitive gems. The checked-out RubySec database reports no vulnerabilities but was last updated on 2026-07-22, so that result is not sufficient final evidence. Chart.js 4.5.1 and Ruby 3.3.12 are already current for their selected lines, while PostgreSQL 17 requires the available 17.11 patch update.

## Upgrade Policy

- Run a full Bundler update so direct and transitive gems move to the newest versions permitted by the existing Gemfile constraints.
- Accept compatible minor and patch updates, including Rails 8.1.3.1.
- Review release notes or changelogs for changed direct dependencies and any transitive update that produces a compatibility failure or security finding.
- Keep explicit compatibility constraints that encode a current architecture decision.
- Do not turn routine maintenance into a Ruby 4, PostgreSQL 18, Rails-next, or other major-platform migration.
- Do not add a Node package manager solely to manage the one vendored browser dependency.

## JavaScript, Runtime, and CI Dependencies

Run the importmap audit and outdated checks. Compare the locally vendored Chart.js version with its official stable release. Replace the vendored file, version comment, and third-party license metadata only if a newer stable release exists.

Verify Ruby, PostgreSQL, Bundler, GitHub Actions, Gitea workflow actions, and downloaded CI tooling against their official release sources or package metadata. Update patch/minor references and reviewed immutable checksums or action SHAs when newer compatible releases exist. Preserve full-SHA pinning for workflow actions and checksum verification for downloaded executables.

Ruby 3.3.12 and PostgreSQL 17.11 remain selected unless a newer patch in those same release lines appears during implementation. Major runtime upgrades require separate compatibility, deployment, backup, restore, and rollback designs.

## Security Verification

Refresh the Ruby advisory database before the final audit. Run Bundler Audit, the importmap audit, and Brakeman after dependency resolution. Any detected advisory must be remediated when a compatible fixed release exists. If no compatible fix exists, document the exact advisory, affected path, exposure analysis, temporary mitigation, and follow-up requirement instead of silently ignoring it.

Preserve the single trusted RubyGems source, Gemfile.lock checksums, immutable CI references, and existing supply-chain controls.

## Compatibility Verification

Run dependency installation/checks, the complete Rails test suite, RuboCop, Brakeman, Bundler Audit with a freshly updated advisory database, importmap audit/outdated checks, workflow syntax validation, and a production asset build. Build the production container when the changed dependency surface affects native gems, runtime packages, or container inputs.

Failures are handled one dependency group at a time. Identify the failing update from the lockfile diff or targeted resolution, consult the dependency's current official documentation, add or use an existing regression test, and make the smallest compatible application change. Do not mask failures by pinning back without recording why.

## Audit Record

Update `security-report/dependency-audit.md` with the verification date, before/after package versions, refreshed advisory result, residual constrained dependencies, official-source checks, and commands actually run. Update setup, production, release, or status documentation only when a selected runtime, image, build requirement, or operational procedure changes.

## Expected Outcome

The lockfile contains all currently resolvable compatible upgrades; vendored and runtime dependencies are current for their selected lines; fresh security scanners report their actual results; tests and production-oriented checks establish compatibility; and any unavoidable residual item is explicit rather than hidden.
