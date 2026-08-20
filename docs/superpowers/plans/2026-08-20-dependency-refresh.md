# Dependency Refresh Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use exodos-dev:subagent-driven-development (recommended) or exodos-dev:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Update all compatible direct and transitive dependencies, refresh vulnerability evidence, and document any constrained residual packages.

**Architecture:** Bundler remains the Ruby dependency authority, importmap remains the JavaScript authority, and immutable/checksummed CI references remain intact. Updates stay inside the selected Rails, Ruby, and PostgreSQL lines; any compatibility regression is isolated by dependency group and protected with a failing application test before code changes.

**Tech Stack:** Bundler 4, RubyGems, Rails 8.1, importmap-rails, RubySec/bundler-audit, Brakeman, RuboCop, Chart.js, GitHub/Gitea Actions, Docker.

## Global Constraints

- Update every gem resolvable under the existing Gemfile constraints, including transitive gems.
- Preserve Rails `~> 8.1.3`, image_processing `~> 2.0`, and other intentional compatibility constraints unless current official documentation proves a constraint is obsolete and the change remains non-major.
- Keep Ruby on the current 3.3 security-patch line and PostgreSQL on the current 17 minor line.
- Keep Chart.js locally vendored and do not add npm/package-lock infrastructure.
- Keep workflow actions pinned to reviewed full commit SHAs and downloaded binaries pinned by version plus SHA-256.
- Never ignore a vulnerability silently; fix it or document the exact residual risk and mitigation.
- Do not modify application behavior merely to accommodate a failing update without a regression test that first reproduces the incompatibility.

---

### Task 1: Compatible Ruby Dependency Resolution

**Files:**
- Modify: `Gemfile.lock`
- Modify only if required by a documented incompatibility: `Gemfile`
- Test only if a compatibility regression appears: the narrow existing test file for the failing behavior

**Interfaces:**
- Consumes: current `Gemfile`, RubyGems metadata, and official changelogs for changed direct dependencies.
- Produces: a checksummed lockfile at the newest fully compatible resolution.

- [ ] **Step 1: Capture the pre-update resolver result**

Run: `bundle outdated --strict`

Expected before the update: exit 1 with Rails 8.1.3.1 plus compatible updates including Bootsnap, Brakeman, CSV, image_processing, RubyZip, Solid Queue, Thruster, and transitive gems.

- [ ] **Step 2: Resolve every compatible gem update**

Run: `bundle update`

Expected: exit 0 and a changed `Gemfile.lock`; Rails resolves to 8.1.3.1 and all compatible direct/transitive packages move to current versions available from the single configured RubyGems source.

- [ ] **Step 3: Inspect the dependency diff and official release notes**

Run:

```bash
git diff -- Gemfile Gemfile.lock
bundle check
bundle outdated --strict
```

Expected: `bundle check` succeeds. `bundle outdated --strict` reports no newer version permitted by the current dependency graph. Review official release notes for every changed direct dependency and for transitive packages implicated by any warning or test failure.

- [ ] **Step 4: Run the high-risk focused regression suites**

Run:

```bash
bin/rails test test/controllers/media_attachments_controller_test.rb test/services/workspace_media_archive_builder_test.rb test/jobs/backup_run_job_test.rb
bin/rails test test/controllers/public_bean_pages_controller_test.rb test/controllers/public_brew_pages_controller_test.rb test/controllers/public_recipe_pages_controller_test.rb
```

Expected: all tests PASS, covering image processing, ZIP/media work, backup jobs, sanitization, and public rendering.

- [ ] **Step 5: Handle any compatibility failure test-first**

For each failure, identify the changed gem responsible from `Gemfile.lock`, consult its current official documentation, write or isolate one failing regression test in the closest existing test file, verify that test fails for the observed reason, then make the smallest application/configuration change and rerun the focused suite. If the only safe resolution is a temporary pin, add an exact Gemfile comment naming the upstream constraint or issue and record it in the audit report.

- [ ] **Step 6: Commit the resolved dependency graph**

After focused tests pass:

```bash
git add Gemfile Gemfile.lock
git commit -m "Update compatible Ruby dependencies"
```

If `Gemfile` is unchanged, stage only `Gemfile.lock`.

### Task 2: JavaScript, Runtime, Container, and Workflow Inventory

**Files:**
- Modify only when a newer compatible release exists: `config/importmap.rb`
- Modify only when Chart.js changes: `vendor/javascript/chart.js.js`
- Modify only when Chart.js changes: `vendor/javascript/THIRD_PARTY_LICENSES.md`
- Modify only when a same-line runtime patch exists: `.ruby-version`, `Dockerfile`, `compose.yaml`, `deploy/compose.production.yml`, `deploy/production.env.example`, `config/deploy.yml`
- Modify only when official releases changed: `.github/workflows/*.yml`, `.gitea/workflows/*.yml`

**Interfaces:**
- Consumes: importmap registry metadata and official stable release pages.
- Produces: current selected-line versions without mutable workflow references.

- [ ] **Step 1: Verify importmap and Chart.js**

Run:

```bash
bin/importmap outdated
bin/importmap audit
```

Expected at plan time: `No outdated packages found` and `No vulnerable packages found`. Confirm the local header, importmap comment, and license record all say Chart.js 4.5.1; compare against the official Chart.js stable release page.

- [ ] **Step 2: Verify runtime and database patch lines**

Compare `.ruby-version`/Dockerfile with the official Ruby 3.3 release list and all PostgreSQL image references with the official PostgreSQL 17 version policy. Ruby 3.3.12 remains current; update PostgreSQL from 17.10 to the current 17.11 patch in every runtime and CI image reference.

- [ ] **Step 3: Verify immutable workflow dependencies**

Review each `uses:` line for a full 40-character SHA and retained version comment. Compare action versions and downloaded CI tool versions/checksums with official release metadata. Update only newer compatible stable releases, preserving immutable pins and checksum verification.

- [ ] **Step 4: Validate any inventory changes and commit if needed**

If files changed, run YAML parsing/workflow shell validation already documented in `docs/releasing.md`, then commit only the verified inventory files:

```bash
git add config/importmap.rb vendor/javascript/chart.js.js vendor/javascript/THIRD_PARTY_LICENSES.md .ruby-version Dockerfile compose.yaml deploy config/deploy.yml .github/workflows .gitea/workflows
git commit -m "Refresh runtime and supply chain dependencies"
```

If official sources confirm all non-gem dependencies are current, do not create an empty commit; record the verification in Task 3 instead.

### Task 3: Fresh Security Evidence and Audit Record

**Files:**
- Modify: `security-report/dependency-audit.md`
- Modify if a runtime/build procedure changed: `docs/setup.md`
- Modify if production/release inputs changed: `docs/production-self-hosting.md`, `docs/releasing.md`
- Modify: `docs/status.md`

**Interfaces:**
- Consumes: final dependency graph and fresh scanner output.
- Produces: dated, reproducible dependency/security evidence with explicit residual items.

- [ ] **Step 1: Refresh advisories and run security scanners**

Run:

```bash
bin/bundler-audit check --update
bin/importmap audit
bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error
```

Expected: all commands exit 0. Bundler Audit reports `No vulnerabilities found`, importmap reports `No vulnerable packages found`, and Brakeman reports zero warnings.

- [ ] **Step 2: Recheck currentness**

Run:

```bash
bundle outdated --strict
bin/importmap outdated
```

Expected: no compatible Ruby or importmap updates remain. If a parent dependency still constrains a newer major/transitive release, identify the parent constraint with `bundle info`/`bundle viz` or lockfile dependency declarations and record it as residual rather than weakening the graph blindly.

- [ ] **Step 3: Update the audit record with exact evidence**

In `security-report/dependency-audit.md`:

- change the verification date to 2026-08-20;
- list the direct/transitive gems changed by the final `Gemfile.lock` diff;
- record the freshly updated RubySec result and importmap/Brakeman results;
- record that Chart.js 4.5.1, Ruby 3.3.12, and PostgreSQL 17.11 were checked against official current-release sources;
- update constrained/residual items from the final `bundle outdated` result;
- replace the verification command list with the commands actually run in this plan.

Update `docs/status.md` to state that the compatible dependency graph and security evidence were refreshed on 2026-08-20. Update setup/production/release docs only for actual operational changes.

- [ ] **Step 4: Commit the audit evidence**

```bash
git add security-report/dependency-audit.md docs/status.md docs/setup.md docs/production-self-hosting.md docs/releasing.md
git commit -m "Refresh dependency security evidence"
```

Stage only files that actually changed.

### Task 4: Full Compatibility and Production Verification

**Files:**
- No planned source changes; failures route back to the owning task and require test-first correction.

**Interfaces:**
- Produces fresh proof that the final dependency graph is compatible with the whole application and production build path.

- [ ] **Step 1: Run style and full application tests**

Run:

```bash
bin/rubocop
bin/rails test
```

Expected: RuboCop reports no offenses; Rails reports zero failures and zero errors.

- [ ] **Step 2: Run production asset compilation**

Run:

```bash
SECRET_KEY_BASE_DUMMY=1 ROASTNODE_WEBAUTHN_ORIGIN=https://build.roastnode.invalid bin/rails assets:precompile
```

Expected: exit 0 with assets compiled successfully.

- [ ] **Step 3: Build the production container when native/runtime inputs changed**

If `Gemfile.lock`, native gems, Dockerfile, or runtime inputs changed, run:

```bash
docker build -t roastnode:dependency-refresh .
```

Expected: exit 0 through dependency installation, Bootsnap precompile, asset precompile, and final image assembly.

- [ ] **Step 4: Re-run final security/currentness commands after all fixes**

Run:

```bash
bin/bundler-audit check
bin/importmap audit
bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error
bundle outdated --strict
bin/importmap outdated
git diff --check
git status --short
```

Expected: security tools exit 0, no compatible updates remain, diff check is clean, and status contains only intentional uncommitted work (ideally none after the planned commits).
