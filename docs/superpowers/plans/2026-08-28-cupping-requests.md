# Cupping Requests Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use exodos-dev:subagent-driven-development (recommended) or exodos-dev:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Espresso-only sharing that copies a private Brew URL for household recipients and gives Guests a public-safe 24-hour taste, rating, and internal-comment page with complete activity auditing.

**Architecture:** A one-per-Brew `CuppingRequest` stores the guest bearer capability, curated `PublicBrewShareSnapshotBuilder` snapshot, activation/expiry state, private feedback comment, and last guest IP. Focused services activate and mutate requests under row locks; a Solid Queue job closes them idempotently. Existing public Brew rendering is shared through polymorphic media helpers, while ordinary `PublicBrewShare` configuration remains independent.

**Tech Stack:** Rails 8.1, PostgreSQL, Active Record, Hotwire/Stimulus, I18n, Active Job/Solid Queue, Minitest, Tailwind CSS.

## Global Constraints

- Espresso only; Quick Drip never exposes a cupping-share action.
- A self-recipient Espresso never exposes a cupping-share action.
- Household-recipient sharing uses the normal authenticated private Brew URL and creates no public capability.
- Guest feedback lasts exactly 24 hours from first successful access and never extends on later access.
- Taste, rating, and the 2,000-character private guest comment lock together at expiry; the page remains readable.
- Guest pages render only a stored public-safe snapshot and automatically select no private record photos.
- Cupping bearer tokens and media handles are redacted from logs and excluded from workspace export.
- Every accepted guest mutation and first access is atomic with its Activity event; automatic closure is idempotent.
- Public cupping copy is complete in English and German, selected from `Accept-Language`, with English fallback.
- Keep work on `main`; do not create a branch or worktree.

---

### Task 1: Persist and synchronize cupping capabilities

**Files:**
- Create: `db/migrate/20260828120000_create_cupping_requests.rb`
- Create: `app/models/cupping_request.rb`
- Create: `app/services/cupping_requests/synchronize.rb`
- Create: `test/models/cupping_request_test.rb`
- Create: `test/services/cupping_requests/synchronize_test.rb`
- Create: `test/migrations/create_cupping_requests_test.rb`
- Modify: `app/models/brew.rb`
- Modify: `app/models/workspace.rb`
- Modify: `test/fixtures/brews.yml`
- Create: `test/fixtures/cupping_requests.yml`

**Interfaces:**
- Produces: `CuppingRequest.find_by_token!(token)`, `#eligible?`, `#feedback_open?(at: Time.current)`, `#guest_label`, `#refresh_snapshot!`, and `CuppingRequests::Synchronize.call(brew)`.
- Produces schema: `workspace_id`, unique `brew_id`, unique `token`, unique `token_digest`, `snapshot`, `feedback_comment`, `opened_at`, `feedback_expires_at`, `closed_at`, `last_guest_ip`, timestamps.
- Consumes: `PublicBrewShareSnapshotBuilder.new(brew:, title:, selected_photo_attachment_ids: []).call`.

- [ ] **Step 1: Write failing model, lifecycle, and migration tests**

```ruby
test "only guest espresso requests are valid" do
  request = CuppingRequest.new(brew: brews(:morning_espresso), workspace: workspaces(:household))
  request.brew.update!(recipient_kind: "guest", recipient_name: "Alex")
  assert request.valid?

  request.brew.update!(method: "quick_drip")
  assert_not request.valid?
end

test "synchronize creates for guest espresso and revokes after recipient change" do
  brew = brews(:morning_espresso)
  brew.update!(recipient_kind: "guest", recipient_name: "Alex")
  assert_difference -> { CuppingRequest.count }, 1 do
    CuppingRequests::Synchronize.call(brew)
  end
  brew.update!(recipient_kind: "self", recipient_name: nil)
  assert_difference -> { CuppingRequest.count }, -1 do
    CuppingRequests::Synchronize.call(brew)
  end
end
```

- [ ] **Step 2: Run the focused tests and verify RED**

Run: `bin/rails test test/models/cupping_request_test.rb test/services/cupping_requests/synchronize_test.rb test/migrations/create_cupping_requests_test.rb`

Expected: failures for the missing table, model, service, and associations.

- [ ] **Step 3: Add the migration and minimal model/service implementation**

```ruby
class CreateCuppingRequests < ActiveRecord::Migration[8.1]
  CuppingRequestRow = Class.new(ActiveRecord::Base) do
    self.table_name = "cupping_requests"
  end

  def up
    create_table :cupping_requests do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :brew, null: false, foreign_key: true, index: { unique: true }
      t.string :token, null: false
      t.string :token_digest, null: false
      t.jsonb :snapshot, null: false, default: {}
      t.text :feedback_comment
      t.datetime :opened_at
      t.datetime :feedback_expires_at
      t.datetime :closed_at
      t.string :last_guest_ip
      t.timestamps
    end
    add_index :cupping_requests, :token, unique: true
    add_index :cupping_requests, :token_digest, unique: true
    add_check_constraint :cupping_requests,
      "char_length(feedback_comment) <= 2000", name: "cupping_requests_comment_length"
    backfill_guest_espressos
  end

  def down
    drop_table :cupping_requests
  end

  private
    def backfill_guest_espressos
      now = Time.current
      rows = select_all(<<~SQL).map do |brew|
        SELECT id, workspace_id FROM brews
        WHERE method = 'espresso' AND recipient_kind = 'guest'
      SQL
        token = SecureRandom.urlsafe_base64(24)
        {
          brew_id: brew.fetch("id"), workspace_id: brew.fetch("workspace_id"), token:,
          token_digest: Digest::SHA256.hexdigest(token), snapshot: {}, created_at: now, updated_at: now
        }
      end
      CuppingRequestRow.insert_all!(rows) if rows.any?
    end
end
```

```ruby
module CuppingRequests
  class Synchronize
    def self.call(brew)
      eligible = brew.persisted? && brew.espresso? && brew.recipient_guest?
      return brew.cupping_request&.destroy! unless eligible

      brew.cupping_request || brew.create_cupping_request!(
        workspace: brew.workspace,
        snapshot: PublicBrewShareSnapshotBuilder.new(
          brew:, title: PublicBrewShare.default_title_for(brew), selected_photo_attachment_ids: []
        ).call
      )
    end
  end
end
```

Wire synchronization into successful Brew create/update/serving transactions rather than a generic callback so snapshot refresh failures roll back the user action.

- [ ] **Step 4: Run migrations and focused tests and verify GREEN**

Run: `bin/rails db:migrate && bin/rails test test/models/cupping_request_test.rb test/services/cupping_requests/synchronize_test.rb test/migrations/create_cupping_requests_test.rb`

Expected: migration succeeds and all focused tests pass.

- [ ] **Step 5: Commit the capability foundation**

```bash
git add db/migrate/20260828120000_create_cupping_requests.rb db/schema.rb app/models/cupping_request.rb app/models/brew.rb app/models/workspace.rb app/services/cupping_requests/synchronize.rb test/models/cupping_request_test.rb test/services/cupping_requests/synchronize_test.rb test/migrations/create_cupping_requests_test.rb test/fixtures/brews.yml test/fixtures/cupping_requests.yml
git commit -m "Add cupping request capabilities"
```

### Task 2: Extend Activity for private guest audit actors

**Files:**
- Modify: `app/services/activity/emitter.rb`
- Modify: `app/services/activity/metadata.rb`
- Modify: `app/services/activity/event_contract.rb`
- Modify: `app/presenters/activity/presenter.rb`
- Modify: `app/views/activity/_event.html.erb`
- Modify: `app/services/activity/export_serializer.rb`
- Modify: `config/locales/en.yml`
- Modify: `test/services/activity/emitter_test.rb`
- Modify: `test/services/activity/event_contract_test.rb`
- Modify: `test/presenters/activity/presenter_test.rb`

**Interfaces:**
- Produces: `Activity::Emitter.record!(..., actor_kind: "guest", actor_label: "Alex", details: { ip_address: "203.0.113.4", ... })` with `actor_id == nil`.
- Produces actions: `brew.cupping_accessed`, `brew.cupping_taste_set`, `brew.cupping_taste_changed`, `brew.cupping_rating_set`, `brew.cupping_rating_changed`, `brew.cupping_comment_added`, `brew.cupping_comment_updated`, `brew.cupping_closed`.
- Produces recipient-aware future Brew `subject_label` snapshots.

- [ ] **Step 1: Write failing Activity contract/emitter/presenter tests**

```ruby
event = Activity::Emitter.record!(
  action: "brew.cupping_taste_changed", workspace: brew.workspace, subject: brew,
  actor_kind: "guest", actor_label: "Alex",
  details: { ip_address: "203.0.113.4", from_taste: "neutral", to_taste: "sour" }
)
assert_nil event.actor
assert_equal "guest", event.metadata.fetch("actor_kind")
assert_equal "203.0.113.4", event.metadata.fetch("ip_address")
assert_equal brew_path(brew), Activity::Presenter.new(event, helpers: self).path
assert_no_match(/feedback text/, event.metadata.to_json)
```

- [ ] **Step 2: Run tests and verify RED**

Run: `bin/rails test test/services/activity/emitter_test.rb test/services/activity/event_contract_test.rb test/presenters/activity/presenter_test.rb`

Expected: missing actor identity arguments and unknown cupping actions.

- [ ] **Step 3: Implement the strict guest action schemas**

Add explicit actor overrides to `Activity::Metadata.build`, rejecting `guest` when an actor user is present and permitting `guest` only when both `actor_kind` and `actor_label` are supplied. Add exact schemas for `ip_address`, `from_taste`, `to_taste`, `from_rating`, and `to_rating`; make `ip_address` required for every cupping action. Map taste values to `very_sour`, `sour`, `neutral`, `bitter`, and `very_bitter`, and ratings to integers 1–5.

```ruby
BASE_METADATA_SCHEMA = {
  "actor_kind" => { type: :string, values: %w[user system guest] },
  "actor_label" => { type: :string },
  "record_kind" => { type: :string },
  "subject_label" => { type: :string }
}.freeze
```

Render the IP in the Activity card's metadata row, never as an unvalidated HTML fragment. Update `Activity::Metadata.subject_label(Brew)` to append the current recipient label for newly emitted events.

- [ ] **Step 4: Run focused Activity tests and verify GREEN**

Run: `bin/rails test test/services/activity/emitter_test.rb test/services/activity/event_contract_test.rb test/presenters/activity/presenter_test.rb`

Expected: all focused tests pass, including action-coverage enforcement.

- [ ] **Step 5: Commit the Activity contract**

```bash
git add app/services/activity app/presenters/activity/presenter.rb app/views/activity/_event.html.erb config/locales/en.yml test/services/activity test/presenters/activity/presenter_test.rb
git commit -m "Audit guest cupping activity"
```

### Task 3: Activate, update, and close feedback transactionally

**Files:**
- Create: `app/services/cupping_requests/activate.rb`
- Create: `app/services/cupping_requests/update_feedback.rb`
- Create: `app/jobs/cupping_request_expiration_job.rb`
- Create: `test/services/cupping_requests/activate_test.rb`
- Create: `test/services/cupping_requests/update_feedback_test.rb`
- Create: `test/jobs/cupping_request_expiration_job_test.rb`

**Interfaces:**
- Produces: `CuppingRequests::Activate.call(request:, ip_address:, now: Time.current) -> CuppingRequest`.
- Produces: `CuppingRequests::UpdateFeedback.call(request:, attributes:, ip_address:, now: Time.current) -> CuppingRequest` and raises `CuppingRequests::FeedbackClosed` after expiry.
- Produces: `CuppingRequestExpirationJob.perform(request_id, expected_deadline_iso8601)`.
- Consumes: Task 1 request model and Task 2 Activity actions.

- [ ] **Step 1: Write failing activation, feedback, rollback, and job tests**

Cover one deadline/event/job on first access, no extension on later access, last-IP refresh, taste/rating set vs changed, comment added vs updated, unchanged submission silence, 2,000-character validation, snapshot refresh rollback, expiry rejection, and stale/duplicate close jobs.

```ruby
travel_to Time.zone.parse("2026-08-28 12:00:00") do
  assert_activity_event(action: "brew.cupping_accessed", workspace: request.workspace) do
    assert_enqueued_with(job: CuppingRequestExpirationJob) do
      CuppingRequests::Activate.call(request:, ip_address: "203.0.113.4")
    end
  end
  assert_equal 24.hours.from_now, request.reload.feedback_expires_at
end
```

- [ ] **Step 2: Run focused service/job tests and verify RED**

Run: `bin/rails test test/services/cupping_requests/activate_test.rb test/services/cupping_requests/update_feedback_test.rb test/jobs/cupping_request_expiration_job_test.rb`

Expected: missing services/job and no guest mutation events.

- [ ] **Step 3: Implement locked services and idempotent job**

```ruby
request.with_lock do
  raise FeedbackClosed unless request.feedback_open?(at: now)
  old = { taste: request.brew.taste_balance, rating: request.brew.rating, comment: request.feedback_comment }
  request.brew.update!(attributes.slice(:taste_balance, :rating))
  request.update!(feedback_comment: attributes[:feedback_comment], last_guest_ip: normalized_ip)
  request.refresh_snapshot!
  PublicBrewShareRefresher.refresh_for(request.brew)
  PublicBeanShareRefresher.refresh_comparisons_for(request.brew)
  emit_changed_events(old:, request:, ip_address: normalized_ip)
end
```

The close job compares the parsed expected deadline to the locked row, sets `closed_at`, and emits `brew.cupping_closed` at the deadline. A mismatch or existing `closed_at` returns without writes.

- [ ] **Step 4: Run focused tests and verify GREEN**

Run: `bin/rails test test/services/cupping_requests/activate_test.rb test/services/cupping_requests/update_feedback_test.rb test/jobs/cupping_request_expiration_job_test.rb`

Expected: all focused tests pass.

- [ ] **Step 5: Commit feedback orchestration**

```bash
git add app/services/cupping_requests app/jobs/cupping_request_expiration_job.rb test/services/cupping_requests test/jobs/cupping_request_expiration_job_test.rb
git commit -m "Process cupping feedback safely"
```

### Task 4: Add the public cupping page, media, localization, and countdown

**Files:**
- Modify: `config/routes.rb`
- Create: `app/controllers/public_cupping_requests_controller.rb`
- Create: `app/controllers/public_cupping_media_controller.rb`
- Create: `app/helpers/public_cupping_requests_helper.rb`
- Create: `app/views/public_cupping_requests/show.html.erb`
- Create: `app/views/public_cupping_requests/_feedback_form.html.erb`
- Modify: `app/views/public_brew_pages/_hero_card.html.erb`
- Modify: `app/helpers/public_brew_shares_helper.rb`
- Create: `app/javascript/controllers/cupping_countdown_controller.js`
- Create: `config/locales/de.yml`
- Modify: `config/locales/en.yml`
- Modify: `config/initializers/filter_parameter_logging.rb`
- Create: `test/controllers/public_cupping_requests_controller_test.rb`
- Create: `test/controllers/public_cupping_media_controller_test.rb`
- Create: `test/helpers/public_cupping_requests_helper_test.rb`
- Create: `test/assets/cupping_countdown_controller_test.rb`

**Interfaces:**
- Produces routes: `GET /c/:token`, `PATCH /c/:token/feedback`, `GET /c/:token/media/:media_id`.
- Produces browser locale choice `de` for German preferences and `en` otherwise.
- Consumes Task 3 activation/update services.

- [ ] **Step 1: Write failing public-page, privacy, locale, expiry, rate-limit, media, and asset tests**

Assert German and English copy, snapshot-only values, `data-cupping-countdown-deadline-value`, accepted updates, expired form replacement, 20-per-10-minute limiting, 404 behavior, safe-raster media, and absence of private notes/links/cost/email/guest name/token/raw IDs/filenames/Active Storage URLs.

- [ ] **Step 2: Run public-focused tests and verify RED**

Run: `bin/rails test test/controllers/public_cupping_requests_controller_test.rb test/controllers/public_cupping_media_controller_test.rb test/helpers/public_cupping_requests_helper_test.rb test/assets/cupping_countdown_controller_test.rb`

Expected: missing routes, controllers, templates, locale, and JavaScript controller.

- [ ] **Step 3: Implement public controllers and views**

```ruby
class PublicCuppingRequestsController < ApplicationController
  allow_unauthenticated_access
  around_action :use_browser_locale
  before_action :set_cupping_request
  rate_limit to: 20, within: 10.minutes, only: :update,
    by: -> { "#{request.remote_ip}:#{CuppingRequest.token_digest_for(params[:token])}" }

  def show
    CuppingRequests::Activate.call(request: @cupping_request, ip_address: request.remote_ip)
    @snapshot = @cupping_request.reload.snapshot
  end

  def update
    CuppingRequests::UpdateFeedback.call(
      request: @cupping_request, attributes: feedback_params, ip_address: request.remote_ip
    )
    redirect_to public_cupping_request_path(@cupping_request.token), notice: t(".saved")
  end
end
```

Extract the public Hero partial's dependency from a concrete `PublicBrewShare` to a `shareable` that responds to `token` and media helpers. Implement request-specific opaque HMAC handles and `SafeImageMedia` streaming. Add the countdown controller with a one-second interval, zero clamping, disconnect cleanup, and expiry message/form swap.

- [ ] **Step 4: Run public-focused tests and verify GREEN**

Run: `bin/rails test test/controllers/public_cupping_requests_controller_test.rb test/controllers/public_cupping_media_controller_test.rb test/helpers/public_cupping_requests_helper_test.rb test/assets/cupping_countdown_controller_test.rb`

Expected: all focused tests pass in English and German.

- [ ] **Step 5: Commit the public feedback page**

```bash
git add config/routes.rb config/locales config/initializers/filter_parameter_logging.rb app/controllers/public_cupping_requests_controller.rb app/controllers/public_cupping_media_controller.rb app/helpers app/views/public_cupping_requests app/views/public_brew_pages/_hero_card.html.erb app/javascript/controllers/cupping_countdown_controller.js test/controllers/public_cupping_requests_controller_test.rb test/controllers/public_cupping_media_controller_test.rb test/helpers/public_cupping_requests_helper_test.rb test/assets/cupping_countdown_controller_test.rb
git commit -m "Add public cupping feedback page"
```

### Task 5: Add the saved-Brew sharing experience

**Files:**
- Modify: `app/controllers/brews_controller.rb`
- Modify: `app/views/brews/show.html.erb`
- Modify: `app/views/shared/_detail_actions.html.erb`
- Modify: `app/views/shared/_detail_action.html.erb`
- Create: `app/javascript/controllers/cupping_share_controller.js`
- Modify: `config/locales/en.yml`
- Modify: `test/controllers/brews_controller_test.rb`
- Create: `test/assets/cupping_share_controller_test.rb`
- Modify: `test/models/brew_test.rb`

**Interfaces:**
- Produces a mobile-pinned cupping action immediately before Edit.
- Household member URL: `brew_url(@brew)`.
- Guest URL: `public_cupping_request_url(@brew.cupping_request.token)`.

- [ ] **Step 1: Write failing visibility, ordering, clipboard/native-share, private-comment, and serving-transition tests**

Assert no action for self/Quick Drip, private URL for household member, public cupping URL for Guest, mobile action order Share then Edit, native share only for coarse pointers with `navigator.share`, desktop clipboard use, private guest comment display, and request create/revoke during serving corrections.

- [ ] **Step 2: Run focused tests and verify RED**

Run: `bin/rails test test/controllers/brews_controller_test.rb test/models/brew_test.rb test/assets/cupping_share_controller_test.rb`

Expected: missing action/controller/comment presentation and lifecycle calls.

- [ ] **Step 3: Implement the action and client behavior**

Add `mobile_pinned: true` to both cupping and Edit actions and update `_detail_actions` to render all pinned actions before the overflow button on mobile. The new Stimulus controller uses:

```javascript
const mobile = window.matchMedia("(pointer: coarse)").matches
if (mobile && navigator.share) await navigator.share(this.shareData)
else await navigator.clipboard.writeText(this.urlValue)
```

Display `@brew.cupping_request.feedback_comment` only inside the authenticated private Brew detail page. Synchronize the request inside Brew create, full update, and serving update transactions.

- [ ] **Step 4: Run focused tests and verify GREEN**

Run: `bin/rails test test/controllers/brews_controller_test.rb test/models/brew_test.rb test/assets/cupping_share_controller_test.rb`

Expected: all focused tests pass.

- [ ] **Step 5: Commit the private sharing UI**

```bash
git add app/controllers/brews_controller.rb app/views/brews/show.html.erb app/views/shared/_detail_actions.html.erb app/views/shared/_detail_action.html.erb app/javascript/controllers/cupping_share_controller.js config/locales/en.yml test/controllers/brews_controller_test.rb test/models/brew_test.rb test/assets/cupping_share_controller_test.rb
git commit -m "Share saved espressos for cupping"
```

### Task 6: Preserve private feedback and request state in export and backup

**Files:**
- Modify: `app/services/workspace_export_builder.rb`
- Modify: `app/services/instance_readable_export_builder.rb`
- Modify: `app/services/instance_backup_archive_builder.rb`
- Modify: `app/services/instance_backup_archive_validator.rb`
- Modify: `app/services/instance_backup_restorer.rb`
- Modify: `test/services/workspace_export_builder_test.rb`
- Modify: `test/services/instance_backup_builders_test.rb`
- Modify: `test/services/instance_backup_restore_test.rb`

**Interfaces:**
- Workspace JSON produces `cupping_feedback_comment` on Brew rows but no token/request payload.
- Instance readable/full backups produce workspace-scoped `cupping_requests` rows and restore links/state safely.

- [ ] **Step 1: Write failing workspace export and backup round-trip tests**

Assert comment inclusion in workspace JSON, token exclusion from workspace JSON/CSV/media archive, request inclusion in instance formats, token/link preservation after restore, ownership validation, and rescheduling only for restored open future deadlines.

- [ ] **Step 2: Run export/backup tests and verify RED**

Run: `bin/rails test test/services/workspace_export_builder_test.rb test/services/instance_backup_builders_test.rb test/services/instance_backup_restore_test.rb`

Expected: missing comment and request payloads.

- [ ] **Step 3: Implement exact payload and restore mappings**

Add `cupping_feedback_comment` to Brew JSON rows. Add a separate instance-only `cupping_requests` array containing IDs, mapped workspace/Brew IDs, token/digest, snapshot, comment, timestamps, deadline, close time, and last IP. Restore after Brews and before Activity events, validating that each mapped Brew is Guest Espresso and belongs to the mapped workspace. Schedule only `opened_at.present? && closed_at.blank? && feedback_expires_at.future?` rows.

- [ ] **Step 4: Run export/backup tests and verify GREEN**

Run: `bin/rails test test/services/workspace_export_builder_test.rb test/services/instance_backup_builders_test.rb test/services/instance_backup_restore_test.rb`

Expected: all focused tests pass.

- [ ] **Step 5: Commit persistence coverage**

```bash
git add app/services/workspace_export_builder.rb app/services/instance_readable_export_builder.rb app/services/instance_backup_archive_builder.rb app/services/instance_backup_archive_validator.rb app/services/instance_backup_restorer.rb test/services/workspace_export_builder_test.rb test/services/instance_backup_builders_test.rb test/services/instance_backup_restore_test.rb
git commit -m "Preserve cupping feedback in backups"
```

### Task 7: Document and verify the complete feature

**Files:**
- Create: `docs/cupping-requests.md`
- Modify: `docs/README.md`
- Modify: `docs/status.md`
- Modify: `docs/coffee-core.md`
- Modify: `docs/public-brew-sharing.md`
- Modify: `docs/activity-audit.md`
- Modify: `docs/workspace-export.md`
- Modify: `docs/backup-system.md`
- Modify: `AGENTS.md`

**Interfaces:**
- Produces durable product/security/operations guidance matching the approved design and implementation.

- [ ] **Step 1: Update the product documentation**

Document eligibility, first-access expiry, guest controls, private comments, public snapshot/media boundary, Activity IP exception, localization, request revocation, export exclusion, backup preservation, and testing guidance. Add `docs/cupping-requests.md` to both `docs/README.md` and the AGENTS product-doc map.

- [ ] **Step 2: Run focused and full verification**

```bash
bin/rails test test/models/cupping_request_test.rb test/services/cupping_requests test/jobs/cupping_request_expiration_job_test.rb test/controllers/public_cupping_requests_controller_test.rb test/controllers/public_cupping_media_controller_test.rb test/controllers/brews_controller_test.rb test/services/activity test/presenters/activity/presenter_test.rb test/services/workspace_export_builder_test.rb test/services/instance_backup_builders_test.rb test/services/instance_backup_restore_test.rb
bin/rails test
bin/rubocop
bin/brakeman --no-pager
bin/rails zeitwerk:check
git diff --check
```

Expected: zero test failures/errors, zero RuboCop offenses, zero Brakeman warnings, successful Zeitwerk check, and no whitespace errors.

- [ ] **Step 3: Inspect the final requirements checklist and working tree**

Run: `git status --short && git diff --stat && git log -8 --oneline`

Expected: only intended cupping/docs changes remain uncommitted, with the preceding task commits present.

- [ ] **Step 4: Commit documentation and any final verified adjustments**

```bash
git add AGENTS.md docs app test config db
git commit -m "Document cupping requests"
```

- [ ] **Step 5: Start the network-accessible local server**

Run `bin/dev` inside the `roastnode-dev` tmux session, confirm it binds for LAN access on port `3001`, and verify the health endpoint from the host before handing control to the user.
