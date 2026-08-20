# Roastnode Dependency Audit

Verified on 2026-07-23 after a full compatible dependency upgrade.

## Result

- Status: clean after remediation.
- Ecosystems reviewed: Ruby/RubyGems, importmap-vendored JavaScript, GitHub Actions, Gitea Actions, Docker/runtime images, and downloaded CI security tools.
- Ruby packages: 138 package names before the upgrade (27 direct, 111 transitive); 136 after it (28 direct, 108 transitive).
- Published Ruby advisories: 22 matches before the upgrade; 0 after it.
- Post-upgrade checks: `bundle outdated --strict`, Bundler Audit, importmap audit, Brakeman, RuboCop, application tests, workflow YAML/shell validation, and a production Docker build.

## Remediated Findings

### DEP-001 — Vulnerable transitive Ruby packages

Severity before remediation: High.

The old lockfile matched 22 RubySec advisories across seven transitive packages:

- `concurrent-ruby`: CVE-2026-54904, CVE-2026-54905, and CVE-2026-54906.
- `crass`: GHSA-6jxj-px6v-747w, GHSA-6wmf-3r64-vcwv, GHSA-8vfg-2r28-hvhj, and GHSA-wwpr-jff3-395c.
- `json`: CVE-2026-54696.
- `loofah`: GHSA-5qhf-9phg-95m2, GHSA-8whx-365g-h9vv, and GHSA-9wjq-cp2p-hrgf.
- `nokogiri`: GHSA-5prr-v3j2-97mh, GHSA-5v8h-3h3q-446p, GHSA-8678-w3jw-xfc2, GHSA-9cv2-cfxc-v4v2, GHSA-g9g8-vgvw-g3vf, GHSA-p67v-3w7g-wjg7, GHSA-phwj-rprq-35pp, GHSA-wfpw-mmfh-qq69, and GHSA-wjv4-x9w8-wm3h.
- `rails-html-sanitizer`: GHSA-cj75-f6xr-r4g7.
- `websocket-driver`: CVE-2026-61666.

The distribution reported by the advisory metadata was 0 Critical, 1 High, 2 Medium, 2 Low, and 17 without a severity rating. Updating the dependency graph moved all affected packages to fixed versions. A fresh RubySec database scan now reports no vulnerabilities.

### DEP-002 — Runtime and Ruby toolchain patches

Severity before remediation: Medium.

- Ruby was updated from 3.3.11 to the supported security patch 3.3.12.
- Bundler was updated from 4.0.9 to 4.0.17.
- Compatible direct and transitive gems were updated, including Kamal, Selenium, Solid Cable, Solid Queue, Tailwind CSS, Thruster, RuboCop, Nokogiri, JSON, and Rails HTML Sanitizer.

Rails remains at the current compatible 8.1.3 release.

### DEP-003 — Image processing major upgrade

Severity before remediation: Low.

`image_processing` was intentionally upgraded from 1.14.0 to 2.0.2. `ruby-vips` is now an explicit direct dependency at 2.3.0 so the production image processor is declared instead of arriving only transitively. A regression test processes a real image and verifies the transformed dimensions and bytes instead of accepting the controller's fallback-to-original path.

### DEP-004 — Dependabot upgrades skipped after closed pull requests

Severity before remediation: Low.

The Dependabot Actions run succeeded, but it skipped six GitHub Actions updates because matching pull requests had previously been closed without merging. The workflows were updated manually:

- `actions/checkout` 6 to 7.
- `docker/setup-qemu-action` 3 to 4.
- `docker/setup-buildx-action` 3 to 4.
- `docker/login-action` 3 to 4.
- `docker/build-push-action` 6 to 7.
- `sigstore/cosign-installer` 4.1.0 to 4.1.2.

Dependabot is also configured to consider indirect dependencies explicitly.

### DEP-005 — Mutable and obsolete CI tool downloads

Severity before remediation: Medium.

The Gitea workflow downloaded release binaries without verifying their contents, and its `mikebom` source had been renamed upstream. The workflow now pins both the version and SHA-256 checksum for:

- cdxgen 12.8.1.
- Waybill 0.1.0-alpha.67.

The existing `MIKEBOM` environment-variable names remain as compatibility aliases for existing deployment configuration, but the installed and invoked tool is Waybill. The Gitea PostgreSQL service image was also updated from 17.5 to the current 17.11 patch.

All third-party workflow actions are pinned to reviewed full commit SHAs, with their release versions retained as comments so Dependabot can continue proposing updates. Downloaded scanner archives and extraction directories are staged outside the source tree so they do not contaminate the generated source SBOM.

## Residual and Deferred Items

### `bindata` 3.x

`bundle outdated` without strict compatibility filtering reports `bindata` 3.0.0, but the installed WebAuthn and TPM key-attestation dependency constraints require the 2.x line. Version 2.5.1 has no matching RubySec advisory, so this is accepted until its parents widen their constraints.

### Ruby 4 and PostgreSQL 18

Ruby 4 and PostgreSQL 18 are separate major-runtime migrations, not routine dependency updates. Roastnode stays on Ruby 3.3.12 and PostgreSQL 17.11 for this maintenance change. Both are current supported patch releases for their selected branches; major upgrades should receive dedicated compatibility, data-migration, rollback, and deployment testing.

## Supply-Chain and License Review

- The Gemfile and lockfile use a single RubyGems source.
- The lockfile contains checksums for all locked gems.
- No likely typo-squatted or dependency-confusion package names were identified.
- All reviewed Ruby packages declare a license. Brakeman's custom public-use license is retained as an informational note; no new license conflict was introduced.
- Chart.js 4.5.1 and its bundled `@kurkle/color` 0.3.2 dependency are current for the vendored asset.
- Elms Sans remains pinned to the selected upstream source revision.

## Verification Commands

```text
bundle check
bundle outdated --strict
bin/bundler-audit check --update
bin/importmap audit
bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error
bin/rubocop
bin/rails test
docker build .
```
