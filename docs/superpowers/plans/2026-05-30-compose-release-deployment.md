# Compose Release Deployment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Roastnode deployable for v1 with an Ansible-friendly Docker Compose stack, documented env settings, SMTP configuration, backup defaults, and explicit HTTP/TLS modes.

**Architecture:** Add a small `Roastnode::RuntimeSettings` object for env parsing and reuse it from Rails production config, Puma config, and backup defaults. Keep the runtime default as `Thruster HTTP -> Puma`; provide a direct Puma HTTPS mode only when certificate paths are supplied. Add production Compose/env examples under `deploy/` and update the self-hosting docs.

**Tech Stack:** Rails 8.1, Puma, Thruster, Docker Compose, PostgreSQL 17, Minitest.

---

### Task 1: Runtime Settings

**Files:**
- Create: `lib/roastnode/runtime_settings.rb`
- Create: `test/lib/roastnode/runtime_settings_test.rb`

- [ ] **Step 1: Write failing tests for runtime env parsing**

```ruby
require "test_helper"
require "roastnode/runtime_settings"

class Roastnode::RuntimeSettingsTest < ActiveSupport::TestCase
  test "builds public url options from roastnode host protocol and port" do
    settings = Roastnode::RuntimeSettings.new(
      "ROASTNODE_HOST" => "coffee.example.test",
      "ROASTNODE_PROTOCOL" => "https",
      "ROASTNODE_PORT" => "8443"
    )

    assert_equal({ host: "coffee.example.test", protocol: "https", port: 8443 }, settings.default_url_options)
  end

  test "combines explicit allowed hosts with public host" do
    settings = Roastnode::RuntimeSettings.new(
      "ROASTNODE_HOST" => "coffee.example.test",
      "ROASTNODE_ALLOWED_HOSTS" => "coffee.lan, roastnode.local"
    )

    assert_equal [ "coffee.example.test", "coffee.lan", "roastnode.local" ], settings.allowed_hosts
  end

  test "parses ssl and smtp settings" do
    settings = Roastnode::RuntimeSettings.new(
      "RAILS_ASSUME_SSL" => "true",
      "RAILS_FORCE_SSL" => "1",
      "SMTP_ENABLED" => "true",
      "SMTP_ADDRESS" => "smtp.example.test",
      "SMTP_PORT" => "587",
      "SMTP_DOMAIN" => "example.test",
      "SMTP_USER_NAME" => "mailer",
      "SMTP_PASSWORD" => "secret",
      "SMTP_AUTHENTICATION" => "plain",
      "SMTP_ENABLE_STARTTLS_AUTO" => "false"
    )

    assert settings.assume_ssl?
    assert settings.force_ssl?
    assert_equal(
      {
        address: "smtp.example.test",
        port: 587,
        domain: "example.test",
        user_name: "mailer",
        password: "secret",
        authentication: :plain,
        enable_starttls_auto: false
      },
      settings.smtp_settings
    )
  end

  test "exposes optional puma ssl settings" do
    settings = Roastnode::RuntimeSettings.new(
      "PUMA_SSL_CERT_PATH" => "/run/secrets/roastnode.crt",
      "PUMA_SSL_KEY_PATH" => "/run/secrets/roastnode.key",
      "PUMA_BIND_HOST" => "0.0.0.0",
      "PORT" => "3443"
    )

    assert settings.puma_ssl?
    assert_equal "/run/secrets/roastnode.crt", settings.puma_ssl_cert_path
    assert_equal "/run/secrets/roastnode.key", settings.puma_ssl_key_path
    assert_equal "0.0.0.0", settings.puma_bind_host
    assert_equal 3443, settings.puma_port
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/lib/roastnode/runtime_settings_test.rb`

Expected: FAIL because `Roastnode::RuntimeSettings` does not exist.

- [ ] **Step 3: Implement runtime settings**

Create `Roastnode::RuntimeSettings` with methods for boolean parsing, comma-separated hosts, default URL options, SMTP settings, Puma SSL settings, and backup defaults.

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/lib/roastnode/runtime_settings_test.rb`

Expected: PASS.

### Task 2: Production Rails, Puma, And Backup Wiring

**Files:**
- Modify: `config/environments/production.rb`
- Modify: `config/puma.rb`
- Modify: `app/models/instance_backup_profile.rb`
- Modify: `app/views/instance_admin/index.html.erb`
- Modify: `test/models/instance_backup_profile_test.rb`

- [ ] **Step 1: Write failing test for backup env defaults**

Add a test that sets `ROASTNODE_BACKUP_STORAGE_PATH` and `ROASTNODE_BACKUP_RETENTION_COUNT`, then asserts `InstanceBackupProfile.default_storage_path` and `.default_retention_count`.

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/models/instance_backup_profile_test.rb`

Expected: FAIL because the default methods do not exist.

- [ ] **Step 3: Wire runtime settings**

Use `Roastnode::RuntimeSettings` in production config for mailer URL options, host authorization, SSL flags, and SMTP. Use it in Puma to switch between `port` and `ssl_bind`. Use it in backup profile defaults and the instance admin form.

- [ ] **Step 4: Run focused tests**

Run: `bin/rails test test/lib/roastnode/runtime_settings_test.rb test/models/instance_backup_profile_test.rb`

Expected: PASS.

### Task 3: Compose And Env Examples

**Files:**
- Create: `deploy/compose.production.yml`
- Create: `deploy/production.env.example`

- [ ] **Step 1: Add production Compose example**

Create a Compose stack with `postgres`, `web`, and `jobs`; use `ROASTNODE_IMAGE` for both app services; mount `postgres_data`, `roastnode_storage`, and optional certificate mounts.

- [ ] **Step 2: Add production env example**

Document every operator-facing env setting used by the stack and runtime settings object, grouped by image, Rails secrets, database, URLs/hosts, SMTP, jobs, backups, Thruster, and optional direct Puma TLS.

- [ ] **Step 3: Verify examples reference real settings**

Run: `rg "ROASTNODE_IMAGE|SMTP_ENABLED|PUMA_SSL_CERT_PATH|THRUSTER_TLS_DOMAIN|ROASTNODE_BACKUP_STORAGE_PATH" deploy`

Expected: all settings appear in the production deployment examples.

### Task 4: Documentation

**Files:**
- Modify: `docs/production-self-hosting.md`
- Modify: `docs/setup.md`
- Modify: `docs/status.md`
- Modify: `docs/README.md`

- [ ] **Step 1: Update production guide**

Replace the inline Compose sketch with references to `deploy/compose.production.yml` and `deploy/production.env.example`. Document the default HTTP path, Thruster ACME path, direct Puma HTTPS path, Ansible flow, SMTP, backups, digest upgrades, and health checks.

- [ ] **Step 2: Update setup and status docs**

Keep local setup pointing at `compose.yaml` and production setup pointing at `deploy/`. Update the status ledger to mention the release deployment bundle.

- [ ] **Step 3: Verify docs references**

Run: `rg "deploy/compose.production.yml|deploy/production.env.example|Puma HTTPS|Thruster" docs`

Expected: production docs describe the release deployment bundle and TLS modes.

### Task 5: Final Verification

**Files:**
- All changed files.

- [ ] **Step 1: Run focused Rails tests**

Run: `bin/rails test test/lib/roastnode/runtime_settings_test.rb test/models/instance_backup_profile_test.rb`

Expected: PASS.

- [ ] **Step 2: Run repository checks if time permits**

Run: `bin/rails test`

Expected: PASS.

- [ ] **Step 3: Review git diff**

Run: `git diff --check` and `git status --short`

Expected: no whitespace errors; only intended release deployment files changed.
