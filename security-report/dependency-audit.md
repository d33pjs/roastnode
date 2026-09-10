# Roastnode Dependency Audit

Verified on 2026-09-10 after refreshing compatible dependencies and the
RubySec advisory database.

## Result

- Status: no known vulnerabilities after the 2026-09-10 maintenance refresh.
- Ecosystems reviewed: Ruby/RubyGems, importmap-vendored JavaScript, GitHub Actions, Gitea Actions, Docker/runtime images, and downloaded CI security tools.
- Ruby packages: 135 unique locked specs: 29 Gemfile declarations, 28 locked direct specs, and 107 transitive specs. `tzinfo-data` is declared but not locked for the selected platforms.
- RubySec evidence: database commit `93b32f641f84282183ce58ab1d7204bee50885bd`, containing 1,242 advisories and last updated at 2026-09-08 15:34:44 -0400; 0 vulnerabilities matched.
- Advisory policy: `config/bundler-audit.yml` has no ignored advisories; any future exception requires documented evidence.
- JavaScript and static analysis: importmap reported no vulnerable or outdated packages; Brakeman 8.0.6 scanned Rails 8.1.3.1 with 0 errors and 0 warnings.
- Currentness: `bundle outdated --strict` reported `Bundle up to date!`; non-strict residuals are the constrained `bindata` 3.x, `marcel` 2.x, and incompatible `json` 3.x releases described below.

## 2026-09-10 Compatible Refresh

- Bootsnap 1.25.0 → 1.26.0; image_processing 2.0.3 → 2.1.0; RubyZip 3.5.0 → 3.6.0; Selenium WebDriver 4.47.0 → 4.49.0; Solid Queue 1.6.0 → 1.7.0; Thruster 0.1.25 → 0.1.26 across all locked platforms.
- Transitive gems: et-orbi 1.4.1 → 1.4.2; net-imap 0.6.6 → 0.6.7; net-protocol 0.2.2 → 0.3.0; parallel 2.1.0 → 2.2.0; RBS 4.1.3 → 4.2.0; RuboCop 1.89.0 → 1.91.0.
- JSON 3.0.2 was evaluated and fails `ActiveSupport::JSON.decode` on Rails 8.1.3.1 because it removes positional parser options. The Gemfile now declares `json >= 2.21.2, < 3`, resolving to the current compatible 2.21.2. No framework monkey patch or ignored advisory was added.
- Workflow actions: anchore/sbom-action 0.24.0 → 0.24.2 and docker/setup-qemu-action 4.2.0 → 4.3.0, both pinned to verified immutable commits. Other existing actions were already current. Node.js 24 LTS with SHA-pinned actions/setup-node 7.0.0 runs the new chart controller tests in Gitea CI; `bin/ci` runs those tests too.
- CI scanners: cdxgen 12.8.4 → 13.1.0 and Waybill 0.2.0 → 0.7.0, with updated release SHA-256 checksums. cdxgen explicitly generates CycloneDX 1.6 and disables dependency installation, preserving the existing ingestion format across its major upgrade. Waybill retains offline dual-format CycloneDX/SPDX generation.
- Rails 8.1.3.1, Bundler 4.0.17, and vendored Chart.js 4.5.1 were already current. Ruby 3.3.12 and PostgreSQL 17.11 remain current patches on the selected runtime branches; newer major migrations are listed below.
- GitHub's Dependabot alerts API returned a token-scope restriction, and the available browser is not signed in to GitHub. Therefore no claim is made about the remote alert count or closure. Fresh RubySec and npm audits verify the local dependency graph instead.

Official sources: [Ruby releases](https://www.ruby-lang.org/en/downloads/), [PostgreSQL releases](https://www.postgresql.org/docs/release/), [Chart.js releases](https://github.com/chartjs/Chart.js/releases), [cdxgen 13.1.0](https://github.com/cdxgen/cdxgen/releases/tag/v13.1.0), [Waybill 0.7.0](https://github.com/kusari-oss/waybill/releases/tag/v0.7.0), [SBOM action 0.24.2](https://github.com/anchore/sbom-action/releases/tag/v0.24.2), and [QEMU action 4.3.0](https://github.com/docker/setup-qemu-action/releases/tag/v4.3.0).

## Verification — 2026-09-10

- `env POSTGRES_PORT=55433 PARALLEL_WORKERS=1 bin/rails test`: 1,450 tests, 14,865 assertions, no failures, errors, or skips. Single-process execution avoids the existing native PostgreSQL adapter crash during macOS fork-based parallel runs. Two backup-restore assertions now use their fixture clock explicitly instead of the wall clock.
- `node --test test/javascript/*.mjs`: 7 chart configuration, lifecycle, tooltip, and fallback tests passed.
- `bin/rubocop`: 402 files inspected with RuboCop 1.91.0, no offenses.
- Fresh `bin/bundler-audit check --update` and `bin/importmap audit`: no known vulnerabilities. Brakeman: no errors or warnings.
- Production `assets:precompile` with a dummy secret and build-only WebAuthn origin: passed, including the new statistics controller. Generated assets were cleaned afterward.
- Verified official macOS scanner binaries against their release checksums and smoke-tested a temporary fixture containing only the committed dependency manifests. cdxgen 13.1.0 and Waybill 0.7.0 each emitted CycloneDX 1.6 with 168 components; Waybill also emitted a nonempty SPDX 3 graph. Linux CI execution and remote Dependabot alert closure have not been verified.
- Independent visual review passed at desktop, tablet, and mobile widths in light/dark modes, including chart rendering, long names, larger datasets, keyboard focus, and empty filters.

## 2026-08-20 Compatible Refresh (Historical)

The final `Gemfile.lock` diff updated these direct dependencies:

- Rails 8.1.3 to 8.1.3.1.
- Bootsnap 1.24.6 to 1.25.0.
- Brakeman 8.0.5 to 8.0.6.
- CSV 3.3.5 to 3.3.6.
- image_processing 2.0.2 to 2.0.3.
- RubyZip 3.4.1 to 3.5.0.
- Selenium WebDriver 4.46.0 to 4.47.0.
- Solid Queue 1.5.0 to 1.6.0.
- Thruster 0.1.23 to 0.1.25, including all locked native platforms.

It also updated these transitive dependencies:

- Action Cable, Action Mailbox, Action Mailer, Action Pack, Action Text, Action View, Active Job, Active Model, Active Record, Active Storage, Active Support, and Railties from 8.1.3 to 8.1.3.1.
- ERB 6.0.6 to 6.0.7; et-orbi 1.4.0 to 1.4.1; io-console 0.8.2 to 0.9.2; JSON 2.21.1 to 2.21.2; Msgpack 1.8.3 to 1.8.4; net-imap 0.6.4.1 to 0.6.6; and Rack 3.2.6 to 3.2.7.
- RBS 4.0.3 to 4.1.3; Reline 0.6.3 to 0.7.0; RuboCop 1.88.2 to 1.89.0; RuboCop Performance 1.26.1 to 1.27.0; and RuboCop Rails 2.36.0 to 2.37.0.
- SSHKit 1.25.0 to 1.25.1; TPM Key Attestation 0.14.1 to 0.14.2; and Zeitwerk 2.8.2 to 2.8.3.

The non-gem inventory refresh updated PostgreSQL 17.10 to 17.11, cdxgen
12.8.1 to 12.8.4, Waybill 0.1.0-alpha.67 to 0.2.0, and compatible
full-SHA-pinned workflow actions. Official current-release sources were checked
on 2026-08-20: Ruby 3.3.12, PostgreSQL 17.11, and Chart.js 4.5.1 are current for
their selected release lines.

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

Rails is now at the current compatible 8.1.3.1 release.

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

- cdxgen 12.8.4.
- Waybill 0.2.0.

The existing `MIKEBOM` environment-variable names remain as compatibility aliases for existing deployment configuration, but the installed and invoked tool is Waybill. The Gitea PostgreSQL service image was also updated from 17.5 to the current 17.11 patch.

All third-party workflow actions are pinned to reviewed full commit SHAs, with their release versions retained as comments so Dependabot can continue proposing updates. Downloaded scanner archives and extraction directories are staged outside the source tree so they do not contaminate the generated source SBOM.

## Residual and Deferred Items

### `bindata` 3.x

`bundle outdated` without strict compatibility filtering reports `bindata` 3.0.0, but WebAuthn 3.4.3 and TPM Key Attestation 0.14.2 both require `bindata ~> 2.4`. Version 2.5.1 has no matching RubySec advisory, so this is accepted until both parents widen their constraints.

### JSON 3.x

JSON 3.0.2 removes positional parser options still passed by Active Support 8.1.3.1. The isolated reproducer `ActiveSupport::JSON.decode('{"a":1}')` raises `ArgumentError` and the full test suite confirms broad application breakage. Keep the latest 2.x release until Rails supports the new API. The 2.21.2 release has no matching advisory in the refreshed RubySec database.

### Marcel 2.x

Marcel 2.1.0 is available, but Active Storage 8.1.3.1 requires `marcel ~> 1.0`. The lockfile retains the latest compatible 1.2.1, which has no matching advisory in the refreshed RubySec database.

### Ruby 4 and PostgreSQL 18

Ruby 4.0.6 and PostgreSQL 18.6 are newer major releases. Roastnode remains on the current supported patches Ruby 3.3.12 and PostgreSQL 17.11. Installing Ruby 4 could not complete through the available local permission flow, so an untested runtime requirement was not committed. PostgreSQL 18 requires a data migration; the existing PostgreSQL 17 volume was retained. These two major migrations remain outstanding.

## Supply-Chain and License Review

- The Gemfile and lockfile use a single RubyGems source.
- The lockfile contains checksums for all locked gems.
- No likely typo-squatted or dependency-confusion package names were identified.
- All reviewed Ruby packages declare a license. Brakeman's custom public-use license is retained as an informational note; no new license conflict was introduced.
- Chart.js 4.5.1 and its bundled `@kurkle/color` 0.3.2 dependency are current for the vendored asset.
- Elms Sans remains pinned to the selected upstream source revision.

## Historical Verification — 2026-08-20

The final compatibility run on 2026-08-20 used these commands:

```text
/usr/bin/time -p bundle check
# PASS: Gemfile dependencies satisfied.

/usr/bin/time -p env RUBOCOP_CACHE_ROOT=tmp/rubocop bin/rubocop
# PASS: 333 files inspected, no offenses.

/usr/bin/time -p env POSTGRES_PORT=55433 PARALLEL_WORKERS=1 bin/rails test
# PASS: 1,004 runs, 8,318 assertions, 0 failures, 0 errors, 0 skips.

/usr/bin/time -p ruby test/services/release_version_configuration_test.rb
# PASS on the final reviewed head: 4 runs, 54 assertions, 0 failures, 0 errors, 0 skips.

/usr/bin/time -p env PATH=/Users/d33pjs/.rbenv/versions/3.3.12/bin:/usr/local/bin:/usr/bin:/bin RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 ROASTNODE_WEBAUTHN_ORIGIN=https://build.roastnode.invalid bin/rails assets:precompile
# PASS on the final reviewed head: Ruby 3.3.12, Tailwind CSS 4.3.3, and Propshaft completed successfully.

/usr/bin/time -p docker build -t roastnode:dependency-refresh .
# PASS: linux/arm64 image sha256:adc7087d16a219f4c08a9aa4e557778a9900bd6c762a9b70be3d3ec6c69f0f3a, 695,866,433 bytes.

/usr/bin/time -p docker compose -f compose.yaml config --quiet
# PASS: development Compose configuration valid.

/usr/bin/time -p env ROASTNODE_ENV_FILE=production.env.example docker compose --env-file deploy/production.env.example -f deploy/compose.production.yml config --quiet
# PASS: production Compose configuration valid with the committed example environment.

/usr/bin/time -p bin/bundler-audit check --update
# PASS: RubySec commit 2faad0ccdfa19c7c57f965b90af99dd774eb0085; no vulnerabilities.

/usr/bin/time -p bin/bundler-audit check
# PASS: no vulnerabilities.

/usr/bin/time -p bin/importmap audit
# PASS: no vulnerable packages.

/usr/bin/time -p bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error
# PASS: 0 errors and 0 security warnings.

/usr/bin/time -p bundle outdated --strict
# PASS: Bundle up to date.

/usr/bin/time -p bin/importmap outdated
# PASS: no outdated packages.

bundle outdated
# Expected exit 1 during the residual review: only bindata 2.5.1 -> 3.0.0, constrained as documented above.

git diff --check
# PASS.

git status --short
# Clean after the completed Task 4 verification.
```
