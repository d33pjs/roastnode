# Roastnode Security Audit Mitigation Plan

Verified on 2026-06-10. Scope was limited to the supplied findings; no application code was changed.

## Ranked Findings

### 1. High - Same-origin third-party script on public pages

Status: confirmed.

Evidence:
- `app/views/shared/_site_footer.html.erb:21-37` renders `https://cdnjs.buymeacoffee.com/1.0.0/button.prod.min.js` for `official_badge`.
- `app/controllers/public_brew_pages_controller.rb:24-27` and `app/controllers/public_recipe_pages_controller.rb:23-26` load the workspace footer config on public pages.
- `config/initializers/content_security_policy.rb` is fully commented out.

Risk:
- A compromised Buy Me a Coffee CDN script runs in the Roastnode origin on `/s/:token` and `/r/:token`.
- Authenticated users can visit public pages while holding Roastnode session cookies. The script cannot read `HttpOnly` cookie values, but it can issue same-origin authenticated `fetch` requests and read responses.
- This breaks the private-by-default model even though public pages render curated snapshots.

Mitigation:
- Remove the remote script path. Render a local static footer link/button for both `link` and `official_badge` modes.
- For `official_badge`, derive `https://www.buymeacoffee.com/<slug>` from the validated slug and reuse the existing local SVG-style button. Alternatively remove `official_badge` support and migrate settings back to `link`.
- Add a CSP after the script removal as defense in depth, but do not rely on CSP while still trusting that remote script.

Likely files:
- `app/views/shared/_site_footer.html.erb`
- `app/models/workspace.rb`
- `app/views/workspaces/edit.html.erb`
- `config/locales/en.yml`
- `docs/workspace-settings.md`
- Public page and workspace settings tests listed below.

Tests:
- Update `test/controllers/public_brew_pages_controller_test.rb` and `test/controllers/public_recipe_pages_controller_test.rb` to assert `official_badge` renders a normal `buymeacoffee.com` link and no `script[src]`.
- Update `test/models/workspace_test.rb` for `site_footer_buy_me_a_coffee` output.
- Update `test/controllers/workspaces_controller_test.rb` if display mode copy/options change.

### 2. High - Bearer credential URL and SQL logging gaps

Status: confirmed, with one nuance.

Evidence:
- `config/initializers/public_brew_share_log_filter.rb:1-16` only redacts `/s/...` and `/r/...`.
- Routes include bearer paths for `resources :passwords, param: :token`, `resources :workspace_invites, param: :token`, and `resources :household_invites, param: :token`.
- `app/controllers/passwords_controller.rb:20-26` redirects back to `edit_password_path(params[:token])` on failed reset update.
- `app/controllers/workspace_invites_controller.rb:12-50,109-123` and `app/controllers/household_invites_controller.rb:4-39,71-74` find and redirect with raw invite tokens.
- `app/models/workspace_invite.rb:20-25` and `app/models/household_invite.rb:6-11` store/query raw `token`.
- I verified a raw-token lookup logs the token in SQL debug output: `WorkspaceInvite.find_by(token: "sample-secret-token")` emitted the literal token in the SQL statement.

Risk:
- Password reset, workspace invite, and household invite URLs can appear in request paths and filtered redirect locations unless explicitly redacted.
- Invite token lookups by raw `token` leak bearer credentials in verbose SQL logs.
- Public shares already use `token_digest`; invite links do not.

Mitigation:
- Replace the narrow public-share-only initializer with a generic sensitive bearer URL log filter.
- Redact request paths and redirect locations for:
  - `/passwords/:token` and `/passwords/:token/edit`
  - `/workspace_invites/:token` and member action suffixes
  - `/household_invites/:token` and member action suffixes
  - keep the existing `/s/:token`, `/s/:token/media/:media_id`, `/r/:token`, `/r/:token/media/:media_id`
- Add `token_digest` to `workspace_invites` and `household_invites`, backfill with `Digest::SHA256.hexdigest(token)`, add unique indexes, and update controller/model lookups to query by digest.
- Preferred stronger design: do not persist reusable raw invite tokens, or encrypt the raw token if the UI must show/resend existing links. Keeping a raw `token` column only fixes lookup SQL leakage, not raw database exposure or token values in insert/update SQL logs.
- For password reset, use path/redirect redaction. There is no raw database token lookup because Rails signed reset tokens are verified through `User.find_by_password_reset_token!`.
- Consider rendering the password reset edit form on mismatch instead of redirecting to a token-bearing URL, but keep log filtering either way.

Likely files:
- `config/initializers/public_brew_share_log_filter.rb` or a renamed replacement initializer
- `app/models/workspace_invite.rb`
- `app/models/household_invite.rb`
- `app/controllers/workspace_invites_controller.rb`
- `app/controllers/household_invites_controller.rb`
- `app/controllers/passwords_controller.rb`
- New migration and `db/schema.rb`
- `docs/workspace-core.md`

Tests:
- Add request/filter tests for `ActionDispatch::Request#filtered_path` on password, workspace invite, household invite, and existing public share/media URLs.
- Add redirect filtering assertions for failed password reset update and unavailable invite accept/signup redirects.
- Add model tests that `WorkspaceInvite` and `HouseholdInvite` populate `token_digest`.
- Add controller tests proving valid invite show/accept/signup still work via raw URL token while SQL lookup code uses digest helper/finder methods.

### 3. Medium - Missing throttles on password checks

Status: confirmed.

Evidence:
- `SessionsController#create`, `PasswordsController#create`, `PasskeySessionsController`, and `PasskeySecondFactorsController` already use `rate_limit`.
- `PublicBrewPagesController#unlock` and `PublicRecipePagesController#unlock` call `authenticate_password` without `rate_limit`.
- `PasswordChangesController#update` and `PasskeyCredentialsController#options/#destroy/#second_factor` call `Current.user.authenticate(...)` without `rate_limit`.
- Rails 8.1 `rate_limit` defaults to `request.remote_ip`, can take a custom `by:` identity, supports custom response callbacks, and relies on the configured cache store.

Risk:
- Public share passwords are anonymously brute-forceable once an attacker has a share token.
- Authenticated password-confirmation endpoints are lower risk because they require an active session, but throttling still limits local/session abuse and online guessing.

Mitigation:
- Add `rate_limit` to:
  - `PublicBrewPagesController#unlock`
  - `PublicRecipePagesController#unlock`
  - `PasswordChangesController#update`
  - `PasskeyCredentialsController#options`
  - `PasskeyCredentialsController#destroy` for the last-passkey password-confirmation branch, or the whole `destroy` action if simpler
  - `PasskeyCredentialsController#second_factor`
- Use identities that do not put raw bearer tokens in cache keys. For public unlocks, key by remote IP plus token digest, not raw token. For authenticated checks, key by user id plus remote IP.
- Match response shapes:
  - public unlock: render password page with `:too_many_requests`
  - password change and second-factor form: render the existing form with `:too_many_requests`
  - passkey JSON options: JSON `429`
  - passkey destroy redirect flow: redirect to profile with a generic "Try again later" alert

Likely files:
- `app/controllers/public_brew_pages_controller.rb`
- `app/controllers/public_recipe_pages_controller.rb`
- `app/controllers/password_changes_controller.rb`
- `app/controllers/passkey_credentials_controller.rb`
- `config/locales/en.yml`

Tests:
- Add controller/integration tests that the 11th attempt within 3 minutes returns `429` or the expected redirect.
- In tests, use a real memory cache store for rate-limit assertions because `test.rb` currently sets `config.cache_store = :null_store`.
- Keep existing invalid-password behavior tests for pre-limit attempts.

### 4. Low/maintenance - Dependency and runtime posture

Status: mostly confirmed; no direct application vulnerability found from the supplied tool output.

Confirmed local state:
- Runtime is Ruby 3.3.7 in `.ruby-version` and `Dockerfile`.
- Production Postgres default is `postgres:17.5` in `deploy/compose.production.yml` and `deploy/production.env.example`.
- No `package.json` or JS package lockfiles are present; `config/importmap.rb` pins local Rails JS assets.
- Lockfile versions match the listed `bundle outdated` candidates.

Upstream verification:
- Ruby lists Ruby 3.3.11 released on 2026-03-26 and says 3.3 enters security maintenance after that release.
- Ruby branches list 3.3 as security maintenance, with 3.4 and 4.0 in normal maintenance.
- PostgreSQL versioning lists 17.10 as the current supported minor for major 17.
- PostgreSQL 17.10 release notes include security fixes and say no dump/restore is required for 17.x. Because this app defaults to 17.5, also read 17.6 notes; they advise reindexing only for BRIN `numeric_minmax_multi_ops` indexes. Roastnode schema does not define BRIN indexes.

Mitigation:
- Do now:
  - Update Ruby 3.3.7 to 3.3.11 in `.ruby-version`, `Dockerfile`, deployment docs, and setup docs.
  - Update Postgres image defaults from `postgres:17.5` to `postgres:17.10` in deploy examples and docs.
  - Apply explicit patch-level gem updates: `bootsnap`, `rubyzip`, and safe transitive patches from the supplied outdated list.
- Defer:
  - Ruby 3.4 or 4.0 migration. Plan separately because Ruby 3.3 is still supported for security fixes until the expected 2027-03-31 EOL.
  - PostgreSQL 18 major upgrade. Major DB upgrades need a separate operational plan.
  - `image_processing` 2.x until the `~> 1.2` constraint is intentionally revisited.
  - RuboCop minor updates unless useful for routine maintenance.

Tests/checks:
- `bin/brakeman --no-pager`
- `bundle exec bundle-audit check --update`
- `bin/rails test`
- For runtime updates, rebuild the Docker image and smoke test boot against Postgres 17.10.

## Rejected Or Downgraded Items

- Dependency audit finding is downgraded to Low/maintenance: supplied Brakeman and bundle-audit results were clean, and local dependency state matches the reported outdated list.
- "Upgrade to Ruby 3.4/4.0 now" is rejected for this mitigation batch. The conservative security update is Ruby 3.3.11.
- "Upgrade to PostgreSQL 18 now" is rejected for this mitigation batch. The conservative security update is PostgreSQL 17.10.
- CSP alone is rejected as the primary fix for the Buy Me a Coffee issue. If the policy allows the remote script, the app still trusts third-party JavaScript in its own origin.
