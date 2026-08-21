# Brew Recipient And Two-Photo Hero Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use exodos-dev:subagent-driven-development (recommended) or exodos-dev:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace inferred guest serving with explicit Self, household-member, and Guest recipients, then present that relationship safely on private/public cards while turning the shared Brew Hero upper section into a two-photo Bean/Brew backdrop.

**Architecture:** Put recipient invariants in `Brew`, resolve all submitted member choices through the active `Workspace`, and centralize private/public display rules in two small projection objects. Keep public pages snapshot-only: share builders copy curated recipient data and explicitly selected primary Hero attachment references, while opaque media controllers stream bounded safe-raster variants. Reuse one decorative backdrop partial across private and public Heroes without changing the existing metric/chart sections.

**Tech Stack:** Ruby 3.3.12, Rails 8.1, PostgreSQL, Active Record, Hotwire/Stimulus, ERB, Tailwind CSS, Active Storage/libvips, Minitest.

## Global Constraints

- Use exactly `recipient_kind`, optional `recipient_user_id`/`recipient_user`, and private `recipient_name`; `recipient_user` targets `users`, never `memberships`.
- Use recipient migration timestamp `20260821110000`.
- Use one-time public snapshot refresh migration timestamp `20260821113000`; it runs only after both public Brew and public Bean recipient projections exist.
- Remove `served_for_guest` and `guest_name` from the live schema and runtime API in the recipient migration. Do not add compatibility aliases; only instance-backup restore accepts those legacy payload keys.
- Backfill `served_for_guest = true` as `guest` and preserve its stripped name; backfill every other Brew as `self`. Never match a legacy name to a User.
- Enforce the structural shape in both Rails and PostgreSQL: Self has neither recipient field, household member has only `recipient_user_id`, and Guest has no `recipient_user_id` and may have `recipient_name`.
- Selecting the Brew logger as household recipient normalizes to Self. `cup_style` remains independent.
- New member assignments resolve only through `current_workspace.users`; a foreign User ID must never be assigned. An unchanged historical recipient uses the non-ID `existing_recipient` form sentinel.
- Recipe snapshots remain recipient-free.
- Private guest names may render privately. Public snapshots/HTML contain Guest kind only and must never contain `recipient_name` or its value.
- A household recipient's safe display label is projected automatically while the User exists; their avatar is projected only while private-media authorization confirms current Workspace membership. After membership removal refresh preserves the safe label and removes the avatar. Do not add a share-consent field or form control.
- Public Hero references exist only for each record's primary photo when that exact attachment was selected. Never fall back to an unselected photo.
- Public HTML/media uses opaque handles only: no raw attachment/database IDs, signed Active Storage URLs, original filenames, private media paths, emails, or raw share tokens in logs.
- The Bean Hero half uses contained fitting; the Brew half uses cover fitting. Missing halves remain black. The `hero` media variant uses `resize_to_limit`, never crop/fill transformations.
- Guest Brews do not reset the dashboard last-coffee timer; Self and household-member Brews do.
- Preserve unrelated user changes, work on `main`, and commit after every task.

## Dependency

- Execute this plan after `docs/superpowers/plans/2026-08-21-activity-audit.md` is complete.
- Consume `with_workspace_activity(action:, subject:, occurred_at: nil, details: {}, visibility: nil)`, `Activity::Emitter`, the registered `brew.serving_changed` action, and `assert_activity_event` from Activity Audit. Do not recreate or rename those interfaces.
- The focused serving mutation, public snapshot refresh, and its one `brew.serving_changed` event succeed or roll back together. It emits no generic `brew.updated` duplicate.

---

## File Map

**Schema and recipient domain**

- Create `db/migrate/20260821110000_replace_brew_guest_fields_with_recipient.rb` — columns, deterministic backfill, foreign key, and shape constraint.
- Create `test/migrations/replace_brew_guest_fields_with_recipient_test.rb` — exercise the migration backfill SQL against a temporary table.
- Modify `db/schema.rb` — generated schema only, via `bin/rails db:migrate`.
- Modify `app/models/brew.rb`, `app/models/user.rb`, `test/models/brew_test.rb` — enum, association, normalization, validation, and historical-recipient behavior.

**Serving input and private projection**

- Create `app/javascript/controllers/brew_recipient_controller.js`, `test/assets/brew_recipient_controller_test.rb` — progressive enhancement for Guest-name selection.
- Modify `app/controllers/brews_controller.rb`, `app/views/brews/_serving_form_fields.html.erb`, `app/views/brews/show.html.erb`, `test/controllers/brews_controller_test.rb` — stable recipient tokens on new/edit/focused correction and workspace-safe resolution.
- Create `app/presenters/brew_recipient_presenter.rb`, `app/views/brews/_recipient_badge.html.erb`, `app/views/brews/_recipient_byline.html.erb`, `test/presenters/brew_recipient_presenter_test.rb` — one private recipient vocabulary and authorized avatars.
- Modify `app/helpers/brews_helper.rb`, `app/views/brews/_compact_card.html.erb`, `app/views/brews/_espresso_hero_card.html.erb`, `app/views/brews/_quick_drip_hero_card.html.erb` — private badge/byline/card integration.

**Hero media**

- Create `app/views/shared/_brew_hero_backdrop.html.erb` — two fixed black halves, optional images, blend, vignette, and gradients.
- Modify `app/controllers/media_attachments_controller.rb`, `app/controllers/public_brew_media_controller.rb`, `test/controllers/media_attachments_controller_test.rb`, `test/controllers/public_brew_media_controller_test.rb` — bounded `hero` variant.
- Modify `test/controllers/home_controller_test.rb`, `test/controllers/brews_controller_test.rb` — all four image combinations and shared dashboard/detail/history coverage.

**Curated public projection**

- Create `app/services/public_brew_recipient_projection.rb`, `test/services/public_brew_recipient_projection_test.rb` — privacy-safe snapshot fragment.
- Modify `app/models/public_brew_share.rb`, `test/models/public_brew_share_test.rb` — current household-recipient avatar public-media allowlist and stale-media rejection.
- Modify `app/services/public_brew_share_snapshot_builder.rb`, `app/services/public_brew_share_refresher.rb`, `app/helpers/public_brew_shares_helper.rb`, `app/views/public_brew_pages/_hero_card.html.erb`, `test/services/public_brew_share_snapshot_builder_test.rb`, `test/services/public_brew_share_refresher_test.rb`, `test/controllers/public_brew_pages_controller_test.rb` — recipient and explicitly selected two-photo public Hero.
- Modify `app/models/public_bean_share.rb`, `app/services/public_bean_share_snapshot_builder.rb`, `app/services/public_bean_share_refresher.rb`, `app/helpers/public_bean_shares_helper.rb`, `app/views/public_bean_pages/_brew_card.html.erb`, `app/views/public_bean_pages/_timeline.html.erb`, `test/models/public_bean_share_test.rb`, `test/services/public_bean_share_snapshot_builder_test.rb`, `test/services/public_bean_share_refresher_test.rb`, `test/controllers/public_bean_pages_controller_test.rb`, `test/controllers/public_bean_media_controller_test.rb` — the same safe projection in Bean Brew summaries.
- Modify `app/services/workspace_membership_manager.rb`, `test/services/workspace_membership_manager_test.rb`, `test/controllers/profiles_controller_test.rb` — refresh recipient snapshots after membership/profile/avatar changes.
- Create `db/migrate/20260821113000_refresh_public_recipient_hero_snapshots.rb`, `test/migrations/refresh_public_recipient_hero_snapshots_test.rb` — one-time rebuild of already-published Brew/Bean snapshots after both new projections exist.

**Portability, semantics, and documentation**

- Modify `app/services/workspace_export_builder.rb`, `app/services/workspace_csv_export_builder.rb`, `test/services/workspace_export_builder_test.rb`, `test/services/workspace_csv_export_builder_test.rb`, `test/controllers/workspace_exports_controller_test.rb` — new reconstructable private fields, no legacy columns.
- Modify `app/services/instance_backup_restorer.rb`, `test/services/instance_backup_builders_test.rb`, `test/services/instance_backup_restore_test.rb` — new round trips plus legacy restore and omitted serving/cup fix.
- Modify `test/services/recipe_snapshot_builder_test.rb`, `test/services/public_recipe_share_snapshot_builder_test.rb` — negative recipient assertions.
- Modify `app/services/dashboard_metrics.rb`, `test/services/dashboard_metrics_test.rb` — timer semantics.
- Modify `config/locales/en.yml`, `docs/coffee-core.md`, `docs/brew-card.md`, `docs/brew-corrections.md`, `docs/public-brew-sharing.md`, `docs/public-bean-sharing.md`, `docs/private-media.md`, `docs/account-privacy.md`, `docs/workspace-export.md`, `docs/backup-system.md`, `docs/status.md` — copy and durable decisions.

### Task 1: Migrate And Enforce The Recipient Domain

**Files:**

- Create: `db/migrate/20260821110000_replace_brew_guest_fields_with_recipient.rb`
- Create: `test/migrations/replace_brew_guest_fields_with_recipient_test.rb`
- Modify: `db/schema.rb`
- Modify: `app/models/brew.rb`
- Modify: `app/models/user.rb`
- Modify: `test/models/brew_test.rb`

**Interfaces:**

- Produces: `Brew.recipient_kinds == { "self" => "self", "household_member" => "household_member", "guest" => "guest" }` with `recipient_self?`, `recipient_household_member?`, and `recipient_guest?` predicates.
- Produces: optional `Brew#recipient_user`, `User#received_brews`, private `Brew#recipient_name`, and transient `Brew#recipient_selection` for form redisplay.
- Produces: PostgreSQL constraint `brews_recipient_shape`.

- [ ] **Step 1: Write failing migration and model tests**

Create the migration test with a temporary legacy-shaped table and add these model cases:

```ruby
# test/migrations/replace_brew_guest_fields_with_recipient_test.rb
require "test_helper"
require Rails.root.join("db/migrate/20260821110000_replace_brew_guest_fields_with_recipient")

class ReplaceBrewGuestFieldsWithRecipientTest < ActiveSupport::TestCase
  TABLE = :recipient_migration_brews

  setup do
    connection.create_table(TABLE) do |t|
      t.boolean :served_for_guest, null: false, default: false
      t.string :guest_name
      t.string :recipient_kind, null: false, default: "self"
      t.bigint :recipient_user_id
      t.string :recipient_name
    end
  end

  teardown { connection.drop_table(TABLE, if_exists: true) }

  def connection = ActiveRecord::Base.connection

  test "backfills legacy guests without name matching and all other rows as self" do
    connection.execute("INSERT INTO #{TABLE} (served_for_guest, guest_name) VALUES (TRUE, '  Anna  '), (TRUE, ''), (FALSE, 'Ignored')")

    ReplaceBrewGuestFieldsWithRecipient.new.backfill_recipient_columns(TABLE)
    rows = connection.select_all("SELECT recipient_kind, recipient_user_id, recipient_name FROM #{TABLE} ORDER BY id").to_a

    assert_equal [
      { "recipient_kind" => "guest", "recipient_user_id" => nil, "recipient_name" => "Anna" },
      { "recipient_kind" => "guest", "recipient_user_id" => nil, "recipient_name" => nil },
      { "recipient_kind" => "self", "recipient_user_id" => nil, "recipient_name" => nil }
    ], rows
  end
end
```

```ruby
# test/models/brew_test.rb
test "normalizes logger selected as household recipient to self" do
  brew = brews(:morning_espresso)
  brew.update!(recipient_kind: "household_member", recipient_user: brew.user, recipient_name: "Ignored")
  assert_predicate brew, :recipient_self?
  assert_nil brew.recipient_user
  assert_nil brew.recipient_name
end

test "requires a current workspace user when a household recipient is newly selected" do
  outsider = User.create!(email_address: "recipient-outsider@example.test", password: "password")
  brew = brews(:morning_espresso)
  brew.assign_attributes(recipient_kind: "household_member", recipient_user: outsider)
  assert_not brew.valid?
  assert_includes brew.errors[:recipient_user], "must belong to the workspace"
end

test "preserves a former household recipient on unrelated historical edits" do
  brew = brews(:morning_espresso)
  brew.update!(recipient_kind: "household_member", recipient_user: users(:two))
  memberships(:member).destroy!
  assert brew.update(notes: "Historical correction")
  assert_equal users(:two), brew.reload.recipient_user
end

test "database rejects an impossible recipient shape" do
  brew = brews(:morning_espresso)
  assert_raises ActiveRecord::StatementInvalid do
    Brew.transaction(requires_new: true) do
      brew.update_columns(recipient_kind: "household_member", recipient_user_id: nil, recipient_name: nil)
    end
  end
end
```

- [ ] **Step 2: Run the tests and verify the missing API**

Run: `bin/rails test test/migrations/replace_brew_guest_fields_with_recipient_test.rb test/models/brew_test.rb`

Expected: FAIL because the migration class, recipient columns, enum, and association do not exist.

- [ ] **Step 3: Implement the migration exactly**

```ruby
class ReplaceBrewGuestFieldsWithRecipient < ActiveRecord::Migration[8.1]
  def up
    add_column :brews, :recipient_kind, :string, null: false, default: "self"
    add_reference :brews, :recipient_user, null: true, foreign_key: { to_table: :users }
    add_column :brews, :recipient_name, :string
    backfill_recipient_columns(:brews)
    remove_column :brews, :served_for_guest, :boolean
    remove_column :brews, :guest_name, :string
    add_check_constraint :brews, <<~SQL.squish, name: "brews_recipient_shape"
      (recipient_kind = 'self' AND recipient_user_id IS NULL AND recipient_name IS NULL) OR
      (recipient_kind = 'household_member' AND recipient_user_id IS NOT NULL AND recipient_name IS NULL) OR
      (recipient_kind = 'guest' AND recipient_user_id IS NULL)
    SQL
  end

  def down
    remove_check_constraint :brews, name: "brews_recipient_shape"
    add_column :brews, :served_for_guest, :boolean, null: false, default: false
    add_column :brews, :guest_name, :string
    execute <<~SQL.squish
      UPDATE brews
      SET served_for_guest = (recipient_kind = 'guest'),
          guest_name = CASE WHEN recipient_kind = 'guest' THEN recipient_name ELSE NULL END
    SQL
    remove_reference :brews, :recipient_user, foreign_key: { to_table: :users }
    remove_column :brews, :recipient_name, :string
    remove_column :brews, :recipient_kind, :string
  end

  def backfill_recipient_columns(table_name)
    table = connection.quote_table_name(table_name)
    execute <<~SQL.squish
      UPDATE #{table}
      SET recipient_kind = CASE WHEN served_for_guest THEN 'guest' ELSE 'self' END,
          recipient_user_id = NULL,
          recipient_name = CASE
            WHEN served_for_guest THEN NULLIF(BTRIM(guest_name), '')
            ELSE NULL
          END
    SQL
  end
end
```

Run: `bin/rails db:migrate`

Expected: migration succeeds; `db/schema.rb` contains the three new fields, foreign key, and `brews_recipient_shape`, and contains neither legacy Brew field.

- [ ] **Step 4: Implement model normalization and membership-at-selection validation**

Add/replace these exact declarations and methods in `Brew`; add the `User` association shown below:

```ruby
# app/models/brew.rb
enum :recipient_kind, {
  self: "self",
  household_member: "household_member",
  guest: "guest"
}, prefix: :recipient

attr_accessor :recipient_selection

belongs_to :recipient_user,
  class_name: "User",
  optional: true,
  inverse_of: :received_brews

before_validation :normalize_recipient
validates :recipient_name, :cup_style, length: { maximum: 120 }
validate :recipient_user_belongs_to_workspace_when_selected

def recipient_name=(value)
  super(value.to_s.strip.presence)
end

private
  def normalize_recipient
    case recipient_kind
    when "household_member"
      if recipient_user_id.present? && recipient_user_id == user_id
        self.recipient_kind = "self"
        self.recipient_user = nil
      end
      self.recipient_name = nil
    when "guest"
      self.recipient_user = nil
    else
      self.recipient_kind = "self"
      self.recipient_user = nil
      self.recipient_name = nil
    end
  end

  def recipient_user_belongs_to_workspace_when_selected
    return unless recipient_household_member?
    if recipient_user.blank?
      errors.add(:recipient_user, "must be selected")
      return
    end
    return unless new_record? || will_save_change_to_recipient_kind? || will_save_change_to_recipient_user_id?
    return if workspace&.users&.exists?(id: recipient_user_id)

    errors.add(:recipient_user, "must belong to the workspace")
  end
```

```ruby
# app/models/user.rb
has_many :received_brews,
  class_name: "Brew",
  foreign_key: :recipient_user_id,
  inverse_of: :recipient_user,
  dependent: :restrict_with_exception
```

Delete the two guest-inference callbacks/methods and the legacy setter/validation. Do not define `served_for_guest`, `served_for_guest?`, or `guest_name` aliases.

- [ ] **Step 5: Run domain tests and commit**

Run: `bin/rails test test/migrations/replace_brew_guest_fields_with_recipient_test.rb test/models/brew_test.rb`

Expected: PASS, including backfill, all three kinds, logger normalization, foreign membership, former-member edit, length, and DB-constraint cases.

```bash
git add db/migrate/20260821110000_replace_brew_guest_fields_with_recipient.rb db/schema.rb app/models/brew.rb app/models/user.rb test/migrations/replace_brew_guest_fields_with_recipient_test.rb test/models/brew_test.rb
git commit -m "feat: replace brew guest fields with recipients"
```

### Task 2: Build One Workspace-Safe Served-To Control

**Files:**

- Create: `app/javascript/controllers/brew_recipient_controller.js`
- Create: `test/assets/brew_recipient_controller_test.rb`
- Modify: `app/controllers/brews_controller.rb`
- Modify: `app/views/brews/_serving_form_fields.html.erb`
- Modify: `app/views/brews/show.html.erb`
- Modify: `config/locales/en.yml`
- Modify: `test/controllers/brews_controller_test.rb`

**Interfaces:**

- Consumes private form token `brew[recipient_selection]`: `self`, `guest`, `member:<User id>`, or `existing_recipient`.
- Consumes `brew[recipient_name]` and `brew[cup_style]`; never permits submitted `recipient_kind` or `recipient_user_id`.
- Consumes Activity Audit's `with_workspace_activity` wrapper and `assert_activity_event` integration helper.
- Produces private controller method `resolve_recipient_attributes!(attributes, existing_brew: nil)`.

- [ ] **Step 1: Replace legacy controller tests with recipient-form and mutation tests**

```ruby
test "new form offers self stable household users and guest without legacy fields" do
  users(:two).update!(display_name: "Petra")
  sign_in_as(users(:one))
  get new_brew_path(method: "espresso")
  assert_response :success
  assert_select "input[type=radio][name=?][value=self][checked]", "brew[recipient_selection]"
  assert_select "input[type=radio][name=?][value=?]", "brew[recipient_selection]", "member:#{users(:two).id}"
  assert_select "input[type=radio][name=?][value=guest]", "brew[recipient_selection]"
  assert_select "label[for=brew_recipient_name]", text: "Person name"
  assert_select "input[name=?]", "brew[recipient_name]"
  assert_select "input[name=?]", "brew[served_for_guest]", count: 0
  assert_select "input[name=?]", "brew[guest_name]", count: 0
end

test "focused correction resolves a member and cannot change inventory or unrelated fields" do
  sign_in_as(users(:one))
  brew = brews(:morning_espresso)
  weight = brew.bean_weight_grams
  adjustment = brew.inventory_adjustment.delta_grams
  event = nil
  assert_difference(-> { ActivityEvent.count }, 1) do
    event = assert_activity_event(
      action: "brew.serving_changed",
      workspace: workspaces(:household),
      actor: users(:one),
      subject: brew
    ) do
      patch serving_brew_path(brew), params: { brew: {
        recipient_selection: "member:#{users(:two).id}", recipient_name: "Ignored", cup_style: "Cortado",
        bean_weight_grams: "40", notes: "Ignored"
      } }
    end
  end
  assert_redirected_to brew_path(brew)
  assert_equal "brew.serving_changed", event.action
  brew.reload
  assert_predicate brew, :recipient_household_member?
  assert_equal users(:two), brew.recipient_user
  assert_nil brew.recipient_name
  assert_equal "Cortado", brew.cup_style
  assert_equal weight, brew.bean_weight_grams
  assert_equal adjustment, brew.inventory_adjustment.reload.delta_grams
end

test "explicit guest selection retains an invalid typed name for redisplay" do
  sign_in_as(users(:one))
  brew = brews(:morning_espresso)
  assert_no_difference(-> { ActivityEvent.count }) do
    patch serving_brew_path(brew), params: { brew: { recipient_selection: "guest", recipient_name: "A" * 121 } }
  end
  assert_response :unprocessable_entity
  assert_select "input[name=?][value=?]", "brew[recipient_name]", "A" * 121
  assert_select "input[name=?][value=guest][checked]", "brew[recipient_selection]"
  assert_predicate brew.reload, :recipient_self?
end

test "explicit self selection clears a previous guest name without javascript" do
  sign_in_as(users(:one))
  brew = brews(:morning_espresso)
  brew.update!(recipient_kind: "guest", recipient_name: "Anna")

  patch serving_brew_path(brew), params: {
    brew: { recipient_selection: "self", recipient_name: "Anna", cup_style: "Espresso" }
  }

  assert_redirected_to brew_path(brew)
  assert_predicate brew.reload, :recipient_self?
  assert_nil brew.recipient_name
end

test "a newly typed name infers guest from the default self radio without javascript" do
  sign_in_as(users(:one))
  brew = brews(:morning_espresso)

  patch serving_brew_path(brew), params: {
    brew: { recipient_selection: "self", recipient_name: "Anna", cup_style: "Latte" }
  }

  assert_redirected_to brew_path(brew)
  assert_predicate brew.reload, :recipient_guest?
  assert_equal "Anna", brew.recipient_name
end

test "explicit former-member selection wins over a submitted name without javascript" do
  sign_in_as(users(:one))
  brew = brews(:morning_espresso)
  former_member = users(:two)
  brew.update!(recipient_kind: "household_member", recipient_user: former_member)
  memberships(:member).destroy!

  patch serving_brew_path(brew), params: {
    brew: { recipient_selection: "existing_recipient", recipient_name: "Anna" }
  }

  assert_redirected_to brew_path(brew)
  assert_predicate brew.reload, :recipient_household_member?
  assert_equal former_member, brew.recipient_user
  assert_nil brew.recipient_name
end

test "foreign member token is rejected without creating a brew or consuming inventory" do
  outsider = User.create!(email_address: "foreign-recipient@example.test", password: "password")
  bean = beans(:open_household)
  remaining = bean.remaining_grams
  sign_in_as(users(:one))
  assert_no_difference("Brew.count") do
    post brews_path, params: { brew: {
      method: "espresso", bean_id: bean.id, bean_weight_grams: "18",
      recipient_selection: "member:#{outsider.id}"
    } }
  end
  assert_response :not_found
  assert_equal remaining, bean.reload.remaining_grams
end

test "activity failure rolls back serving and both public snapshot refreshes" do
  sign_in_as(users(:one))
  brew = brews(:morning_espresso)
  brew_share = create_public_brew_share_for(brew, enabled: true)
  bean_share = create_public_bean_share_for(brew.bean)
  original = [ brew.recipient_kind, brew.recipient_user_id, brew.recipient_name, brew.cup_style ]
  original_brew_snapshot = brew_share.snapshot.deep_dup
  original_bean_snapshot = bean_share.snapshot.deep_dup
  failure = ->(**) { raise ActiveRecord::RecordInvalid.new(ActivityEvent.new) }

  assert_no_difference -> { ActivityEvent.where(action: "brew.serving_changed", subject: brew).count } do
    Activity::Emitter.stub(:record!, failure) do
      patch serving_brew_path(brew), params: {
        brew: { recipient_selection: "member:#{users(:two).id}", cup_style: "Cortado" }
      }
    end
  end

  assert_response :unprocessable_entity
  assert_equal original, [ brew.reload.recipient_kind, brew.recipient_user_id, brew.recipient_name, brew.cup_style ]
  assert_equal original_brew_snapshot, brew_share.reload.snapshot
  assert_equal original_bean_snapshot, bean_share.reload.snapshot
end

test "snapshot refresh failure rolls back serving earlier refreshes and activity" do
  sign_in_as(users(:one))
  brew = brews(:morning_espresso)
  brew_share = create_public_brew_share_for(brew, enabled: true)
  create_public_bean_share_for(brew.bean)
  original = [ brew.recipient_kind, brew.recipient_user_id, brew.recipient_name, brew.cup_style ]
  original_brew_snapshot = brew_share.snapshot.deep_dup
  failure = ->(*) { raise ActiveRecord::RecordInvalid.new(PublicBeanShare.new) }

  assert_no_difference -> { ActivityEvent.where(action: "brew.serving_changed", subject: brew).count } do
    PublicBeanShareRefresher.stub(:refresh_for, failure) do
      patch serving_brew_path(brew), params: {
        brew: { recipient_selection: "guest", recipient_name: "Anna", cup_style: "Latte" }
      }
    end
  end

  assert_response :unprocessable_entity
  assert_equal original, [ brew.reload.recipient_kind, brew.recipient_user_id, brew.recipient_name, brew.cup_style ]
  assert_equal original_brew_snapshot, brew_share.reload.snapshot
end
```

- [ ] **Step 2: Run controller tests and verify they fail**

Run: `bin/rails test test/controllers/brews_controller_test.rb`

Expected: FAIL on missing recipient form controls and unresolved tokens.

- [ ] **Step 3: Implement the resolver and use it in create, update, and serving**

Permit only `:recipient_selection`, `:recipient_name`, and `:cup_style`; invoke the resolver before constructing/updating the Brew. The focused action must refresh both share types after a successful update.

```ruby
def serving
  attributes = serving_brew_params
  resolve_recipient_attributes!(attributes, existing_brew: @brew)
  updated = with_workspace_activity(action: "brew.serving_changed", subject: @brew) do
    if @brew.update(attributes)
      refresh_public_shares_for(@brew)
      true
    else
      false
    end
  end
  if updated
    redirect_to @brew, notice: t(".updated")
  else
    render :show, status: :unprocessable_entity
  end
rescue ActiveRecord::RecordInvalid
  @brew.reload
  flash.now[:alert] = t(".failed")
  render :show, status: :unprocessable_entity
end

def resolve_recipient_attributes!(attributes, existing_brew: nil)
  selection = attributes.delete(:recipient_selection).presence || "self"
  name = attributes[:recipient_name].to_s.strip.presence
  previous_guest_name = existing_brew&.recipient_guest? ? existing_brew.recipient_name.to_s.strip.presence : nil
  selection = "guest" if selection == "self" && name.present? && name != previous_guest_name
  attributes[:recipient_selection] = selection

  case selection
  when "self"
    attributes.merge!(recipient_kind: "self", recipient_user: nil, recipient_name: nil)
  when "guest"
    attributes.merge!(recipient_kind: "guest", recipient_user: nil, recipient_name: name)
  when /\Amember:(\d+)\z/
    attributes.merge!(
      recipient_kind: "household_member",
      recipient_user: current_workspace.users.find(Regexp.last_match(1)),
      recipient_name: nil
    )
  when "existing_recipient"
    raise ActiveRecord::RecordNotFound unless existing_brew&.recipient_household_member?
    attributes.merge!(recipient_kind: "household_member", recipient_user: existing_brew.recipient_user, recipient_name: nil)
  else
    raise ActiveRecord::RecordNotFound
  end
end

def serving_brew_params
  params.expect(brew: [ :recipient_selection, :recipient_name, :cup_style ])
end
```

This replaces Activity Audit's focused-serving body; do not nest it inside a `brew.updated` wrapper and do not call `Activity::Emitter` a second time.

Add `brews.serving.failed: "Serving could not be saved. Nothing was changed."` to `config/locales/en.yml`. The rescue is deliberately generic: refresher/emitter validation details are internal, while the outer Activity transaction guarantees the Brew, both snapshots, and event all roll back.

In full `brew_params`, replace the legacy fields with `:recipient_selection, :recipient_name, :cup_style`. Call `resolve_recipient_attributes!(attributes)` in `create` after workspace-scoping references and call it with `existing_brew: @brew` in `update`. Add `:recipient_user` to `set_brew`, dashboard/history, and public-share eager loads.

Replace `set_serving_suggestions` with:

```ruby
def set_serving_suggestions
  @recipient_users = current_workspace.users.with_attached_avatar.order(:display_name, :email_address).to_a
  @recipient_name_suggestions = current_workspace.brews
    .where(recipient_kind: "guest").where.not(recipient_name: [ nil, "" ])
    .distinct.order(:recipient_name).pluck(:recipient_name)
  @cup_style_suggestions = (
    ExternalCoffee::DRINK_TYPE_SUGGESTIONS +
      current_workspace.brews.where.not(cup_style: [ nil, "" ]).distinct.order(:cup_style).pluck(:cup_style)
  ).uniq
end
```

- [ ] **Step 4: Render the same radio/name control in all three forms**

Make `_serving_form_fields.html.erb` the only recipient markup; render it from both method forms and from the focused correction form. Its essential structure is:

```erb
<% selection = brew.recipient_selection.presence || if brew.recipient_self?
  "self"
elsif brew.recipient_guest?
  "guest"
elsif Array(@recipient_users).any? { |user| user.id == brew.recipient_user_id }
  "member:#{brew.recipient_user_id}"
else
  "existing_recipient"
end %>
<% logger_id = brew.user_id || Current.user.id %>

<fieldset data-testid="brew-recipient-fields" data-controller="brew-recipient" class="grid gap-3">
  <legend class="text-sm font-extrabold text-rn-muted"><%= t("brews.form.served_to") %></legend>
  <label><%= form.radio_button :recipient_selection, "self", checked: selection == "self", data: { brew_recipient_target: "selection", action: "brew-recipient#selectionChanged" } %> <%= t("brews.recipients.myself") %></label>
  <% Array(@recipient_users).reject { |user| user.id == logger_id }.each do |user| %>
    <label>
      <%= form.radio_button :recipient_selection, "member:#{user.id}", checked: selection == "member:#{user.id}", data: { brew_recipient_target: "selection", action: "brew-recipient#selectionChanged" } %>
      <% if user.avatar.attached? %><%= image_tag media_attachment_path(user.avatar.attachment, variant: :thumbnail), alt: "", class: "h-8 w-8 rounded-full object-contain" %><% end %>
      <%= user.display_label %>
    </label>
  <% end %>
  <% if selection == "existing_recipient" %>
    <label><%= form.radio_button :recipient_selection, "existing_recipient", checked: true, data: { brew_recipient_target: "selection", action: "brew-recipient#selectionChanged" } %> <%= t("brews.recipients.former_member", name: brew.recipient_user.display_label) %></label>
  <% end %>
  <label><%= form.radio_button :recipient_selection, "guest", checked: selection == "guest", data: { brew_recipient_target: "guest selection", action: "brew-recipient#selectionChanged" } %> <%= t("brews.recipients.guest") %></label>
  <%= form.label :recipient_name, t("brews.form.person_name"), class: "text-sm font-bold text-rn-muted" %>
  <%= form.text_field :recipient_name, maxlength: 120, list: "brew_recipient_name_suggestions", data: { brew_recipient_target: "name", action: "input->brew-recipient#nameChanged" } %>
  <p class="text-sm font-semibold text-rn-muted"><%= t("brews.form.person_name_help") %></p>
  <datalist id="brew_recipient_name_suggestions"><% Array(@recipient_name_suggestions).each do |name| %><option value="<%= name %>"></option><% end %></datalist>
</fieldset>
```

Keep the existing cup-style field below this fieldset. Pass `brew: form.object` whenever rendering the partial.

Member, former-member, and explicit Guest tokens are authoritative. A nonblank name submitted with the default Self radio infers Guest even without JavaScript. The one intentional exception lets an existing named Guest switch to Self when the unchanged persisted Guest name is still posted; Self then clears it. JavaScript normally checks Guest while typing and clears the name on every non-Guest selection, while the server rules preserve the same semantics without JavaScript.

- [ ] **Step 5: Add progressive enhancement and its source test**

```javascript
// app/javascript/controllers/brew_recipient_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "selection", "guest", "name" ]

  nameChanged() {
    if (this.nameTarget.value.trim() !== "") this.guestTarget.checked = true
  }

  selectionChanged(event) {
    if (event.target.value !== "guest") this.nameTarget.value = ""
  }
}
```

```ruby
# test/assets/brew_recipient_controller_test.rb
require "test_helper"

class BrewRecipientControllerTest < ActiveSupport::TestCase
  test "name input selects guest and explicit self or member clears stale free text" do
    source = Rails.root.join("app/javascript/controllers/brew_recipient_controller.js").read
    assert_includes source, 'static targets = [ "selection", "guest", "name" ]'
    assert_includes source, "this.guestTarget.checked = true"
    assert_includes source, 'event.target.value !== "guest"'
    assert_includes source, 'this.nameTarget.value = ""'
  end
end
```

- [ ] **Step 6: Run, verify, and commit**

Run: `bin/rails test test/controllers/brews_controller_test.rb test/assets/brew_recipient_controller_test.rb`

Expected: PASS for new/edit/focused forms, no-JS inference, normalization, invalid redisplay, authorization, foreign IDs, and inventory isolation.

```bash
git add app/controllers/brews_controller.rb app/views/brews/_serving_form_fields.html.erb app/views/brews/show.html.erb app/javascript/controllers/brew_recipient_controller.js test/controllers/brews_controller_test.rb test/assets/brew_recipient_controller_test.rb
git commit -m "feat: add workspace-safe brew recipient controls"
```

### Task 3: Centralize Private Recipient Cards And Avatar Authorization

**Files:**

- Create: `app/presenters/brew_recipient_presenter.rb`
- Create: `app/views/brews/_recipient_badge.html.erb`
- Create: `app/views/brews/_recipient_byline.html.erb`
- Create: `test/presenters/brew_recipient_presenter_test.rb`
- Modify: `app/helpers/brews_helper.rb`
- Modify: `app/views/brews/_compact_card.html.erb`
- Modify: `app/views/brews/_espresso_hero_card.html.erb`
- Modify: `app/views/brews/_quick_drip_hero_card.html.erb`
- Modify: `app/views/brews/show.html.erb`
- Modify: `test/controllers/brews_controller_test.rb`

**Interfaces:**

- Produces: `BrewRecipientPresenter.new(brew:, workspace:)` with `badge_text`, `recipient_label`, `byline_text`, `icon_name`, `badge_classes`, `logger_avatar_attachment`, and `recipient_avatar_attachment`.
- Produces: `brew_recipient_presenter(brew)` helper and two shared private partials.

- [ ] **Step 1: Write presenter tests for all recipient kinds and former-member fallback**

```ruby
require "test_helper"

class BrewRecipientPresenterTest < ActiveSupport::TestCase
  include PhotoTestHelper

test "presents self member named guest and unnamed guest with fixed colors" do
  brew = brews(:morning_espresso)
  self_view = BrewRecipientPresenter.new(brew:, workspace: brew.workspace)
  assert_equal "For me", self_view.badge_text
  assert_includes self_view.badge_classes, "bg-sky-100"

  brew.update!(recipient_kind: "household_member", recipient_user: users(:two))
  member_view = BrewRecipientPresenter.new(brew:, workspace: brew.workspace)
  assert_equal "For #{users(:two).display_label}", member_view.badge_text
  assert_includes member_view.badge_classes, "bg-orange-100"

  brew.update!(recipient_kind: "guest", recipient_name: "Anna")
  assert_equal "For Anna", BrewRecipientPresenter.new(brew:, workspace: brew.workspace).badge_text
  brew.update!(recipient_kind: "guest", recipient_name: nil)
  assert_equal "For a guest", BrewRecipientPresenter.new(brew:, workspace: brew.workspace).badge_text
end

test "keeps former member label but suppresses no-longer-authorized avatar" do
  brew = brews(:morning_espresso)
  avatar = attach_named_photo(users(:two), :avatar, filename: "petra.jpg")
  brew.update!(recipient_kind: "household_member", recipient_user: users(:two))
  assert_equal avatar, BrewRecipientPresenter.new(brew:, workspace: brew.workspace).recipient_avatar_attachment
  memberships(:member).destroy!
  presenter = BrewRecipientPresenter.new(brew:, workspace: brew.workspace)
  assert_equal "For #{users(:two).display_label}", presenter.badge_text
  assert_nil presenter.recipient_avatar_attachment
end
end
```

Run: `bin/rails test test/presenters/brew_recipient_presenter_test.rb`

Expected: FAIL because the presenter is missing.

- [ ] **Step 2: Implement the presenter**

```ruby
class BrewRecipientPresenter
  def initialize(brew:, workspace:)
    @brew = brew
    @workspace = workspace
  end

  def badge_text = I18n.t("brews.recipients.badge", recipient: recipient_label)

  def recipient_label
    return I18n.t("brews.recipients.me") if brew.recipient_self?
    return brew.recipient_user.display_label if brew.recipient_household_member?
    brew.recipient_name.presence || I18n.t("brews.recipients.a_guest")
  end

  def byline_text
    recipient = brew.recipient_self? ? I18n.t("brews.recipients.themself") : recipient_label
    I18n.t("brews.recipients.byline", logger: brew.user.display_label, recipient:)
  end

  def icon_name
    { "self" => "person", "household_member" => "home", "guest" => "groups" }.fetch(brew.recipient_kind)
  end

  def badge_classes
    {
      "self" => "bg-sky-100/95 text-sky-900 ring-sky-200",
      "household_member" => "bg-orange-100/95 text-orange-900 ring-orange-200",
      "guest" => "bg-emerald-100/95 text-emerald-900 ring-emerald-200"
    }.fetch(brew.recipient_kind)
  end

  def logger_avatar_attachment = authorized_avatar(brew.user)
  def recipient_avatar_attachment = brew.recipient_household_member? ? authorized_avatar(brew.recipient_user) : nil

  private
    attr_reader :brew, :workspace

    def authorized_avatar(user)
      return unless user && workspace.memberships.exists?(user_id: user.id)
      user.avatar.attachment if user.avatar.attached?
    end
end
```

- [ ] **Step 3: Render the presenter consistently**

```ruby
# app/helpers/brews_helper.rb
def brew_recipient_presenter(brew)
  BrewRecipientPresenter.new(brew:, workspace: current_workspace)
end
```

```erb
<%# app/views/brews/_recipient_badge.html.erb %>
<span data-testid="brew-recipient-badge" class="inline-flex max-w-full items-center gap-1 rounded-full px-2.5 py-1 text-xs font-extrabold ring-1 <%= presenter.badge_classes %>">
  <span class="material-symbols-rounded text-sm" aria-hidden="true"><%= presenter.icon_name %></span>
  <span class="truncate"><%= presenter.badge_text %></span>
</span>
```

```erb
<%# app/views/brews/_recipient_byline.html.erb %>
<div data-testid="brew-recipient-byline" class="flex min-w-0 items-center gap-1.5 text-xs text-stone-200">
  <% if presenter.logger_avatar_attachment %><%= image_tag media_attachment_path(presenter.logger_avatar_attachment, variant: :thumbnail), alt: "", data: { testid: "brew-logger-avatar" }, class: "h-5 w-5 rounded-full object-contain ring-1 ring-white/30" %><% end %>
  <% if presenter.recipient_avatar_attachment %><%= image_tag media_attachment_path(presenter.recipient_avatar_attachment, variant: :thumbnail), alt: "", data: { testid: "brew-recipient-avatar" }, class: "h-5 w-5 rounded-full object-contain ring-1 ring-white/30" %><% end %>
  <span class="truncate"><%= presenter.byline_text %></span>
</div>
```

At the top of each Hero and compact partial assign `presenter = brew_recipient_presenter(brew)`. Render the badge in the header, replace logger-only bylines with `_recipient_byline`, replace the compact legacy serving chip with the badge plus a separate `cup_style` chip, and replace the detail `Guest` row with a `Served to` row using `presenter.badge_text`. Add controller assertions for Self, member, named/unnamed Guest, compact cards, and a former member with no avatar `<img>`.

- [ ] **Step 4: Run private presentation tests and commit**

Run: `bin/rails test test/presenters/brew_recipient_presenter_test.rb test/controllers/brews_controller_test.rb test/controllers/home_controller_test.rb`

Expected: PASS; private guest names appear, recipient colors match, and removed members have labels without broken avatar URLs.

```bash
git add app/presenters/brew_recipient_presenter.rb app/helpers/brews_helper.rb app/views/brews/_recipient_badge.html.erb app/views/brews/_recipient_byline.html.erb app/views/brews/_compact_card.html.erb app/views/brews/_espresso_hero_card.html.erb app/views/brews/_quick_drip_hero_card.html.erb app/views/brews/show.html.erb test/presenters/brew_recipient_presenter_test.rb test/controllers/brews_controller_test.rb test/controllers/home_controller_test.rb
git commit -m "feat: present brew recipients on private cards"
```

### Task 4: Add The Contained Hero Variant And Shared Two-Photo Backdrop

**Files:**

- Create: `app/views/shared/_brew_hero_backdrop.html.erb`
- Modify: `app/controllers/media_attachments_controller.rb`
- Modify: `app/controllers/public_brew_media_controller.rb`
- Modify: `app/views/brews/_espresso_hero_card.html.erb`
- Modify: `app/views/brews/_quick_drip_hero_card.html.erb`
- Modify: `app/helpers/brews_helper.rb`
- Modify: `test/controllers/media_attachments_controller_test.rb`
- Modify: `test/controllers/public_brew_media_controller_test.rb`
- Modify: `test/controllers/brews_controller_test.rb`
- Modify: `test/controllers/home_controller_test.rb`

**Interfaces:**

- Produces: `MediaAttachmentsController::HERO_VARIANT == "hero"` and `HERO_TRANSFORMATIONS == { resize_to_limit: [1200, 1200] }`.
- Produces: shared partial locals `bean_image_url:` and `brew_image_url:`; each may be `nil`.

- [ ] **Step 1: Write failing media and four-combination render tests**

```ruby
test "hero variant is bounded without crop semantics" do
  assert_equal({ resize_to_limit: [ 1200, 1200 ] }, MediaAttachmentsController::HERO_TRANSFORMATIONS)
  assert_not_includes MediaAttachmentsController::HERO_TRANSFORMATIONS.keys, :resize_to_fill
  sign_in_as(users(:one))
  attachment = attach_photo(beans(:open_household))
  get media_attachment_path(attachment, variant: :hero)
  assert_response :success
  assert_equal "hero", response.headers["X-Roastnode-Media-Variant"]
end
```

In `BrewsControllerTest`, iterate Espresso and Quick Drip fixtures and the arrays `[]`, `[:bean]`, `[:brew]`, `[:bean, :brew]`; attach/set each requested primary, GET its detail page, and assert two backdrop halves always exist, only requested image test IDs exist, Bean has `object-contain`, Brew has `object-cover`, center blend exists only for both, and `[data-testid=brew-bean-photo-frame]` never exists. Add one dashboard and one `coffees_path(view: "hero")` assertion for `[data-testid=brew-hero-backdrop]`.

Run: `bin/rails test test/controllers/media_attachments_controller_test.rb test/controllers/brews_controller_test.rb test/controllers/home_controller_test.rb`

Expected: FAIL because `hero` is rejected and the backdrop does not exist.

- [ ] **Step 2: Generalize safe variant dispatch**

Use these constants in `MediaAttachmentsController` and dispatch only named entries:

```ruby
THUMBNAIL_VARIANT = "thumbnail"
THUMBNAIL_TRANSFORMATIONS = { resize_to_limit: [ 480, 480 ] }.freeze
HERO_VARIANT = "hero"
HERO_TRANSFORMATIONS = { resize_to_limit: [ 1200, 1200 ] }.freeze
MEDIA_VARIANTS = {
  THUMBNAIL_VARIANT => THUMBNAIL_TRANSFORMATIONS,
  HERO_VARIANT => HERO_TRANSFORMATIONS
}.freeze

def show
  return send_blob(disposition: "inline") if params[:variant].blank?
  transformations = MEDIA_VARIANTS[params[:variant]]
  return head :not_found unless transformations
  send_variant(params[:variant], transformations)
end

def send_variant(name, transformations)
  return head :not_found unless safe_image_attachment? && @attachment.blob.image?
  response.set_header("X-Roastnode-Media-Variant", name)
  send_blob(disposition: "inline", filename: "#{name}-#{@attachment.blob.filename}", data: variant_data(transformations, name))
end

def variant_data(transformations, name)
  @attachment.blob.variant(transformations).processed.download
rescue => error
  Rails.logger.info("Falling back to original media for #{name} #{attachment_log_id}: #{error.class}")
  @attachment.blob.download
end
```

Alias the same constants in `PublicBrewMediaController`, use identical dispatch, and keep generic filenames `public-brew-thumbnail`/`public-brew-hero`/`public-brew-media` with no original filename.

- [ ] **Step 3: Create the complete decorative backdrop partial**

```erb
<div data-testid="brew-hero-backdrop" class="pointer-events-none absolute inset-0 grid grid-cols-2 bg-black" aria-hidden="true">
  <div data-testid="brew-hero-bean-half" class="relative overflow-hidden bg-black">
    <% if bean_image_url.present? %><%= image_tag bean_image_url, alt: "", data: { testid: "brew-hero-bean-image" }, class: "h-full w-full object-contain" %><% end %>
  </div>
  <div data-testid="brew-hero-brew-half" class="relative overflow-hidden bg-black">
    <% if brew_image_url.present? %><%= image_tag brew_image_url, alt: "", data: { testid: "brew-hero-brew-image" }, class: "h-full w-full object-cover" %><% end %>
  </div>
  <% if bean_image_url.present? && brew_image_url.present? %>
    <div data-testid="brew-hero-center-blend" class="absolute inset-y-0 left-1/2 w-20 -translate-x-1/2 bg-gradient-to-r from-transparent via-black/35 to-transparent"></div>
  <% end %>
  <div class="absolute inset-0 bg-[radial-gradient(ellipse_at_center,transparent_20%,rgba(0,0,0,0.72)_100%)]"></div>
  <div class="absolute inset-0 bg-gradient-to-b from-black/75 via-black/20 to-black/80"></div>
</div>
```

- [ ] **Step 4: Wrap both private Hero upper sections**

For each Hero, compute two independent URLs. Replace the current upper wrapper opening with the exact opening below, leave the existing header/title/byline/metrics nodes inside `brew-hero-overlay`, and insert two closing `</div>` tags immediately before the existing Espresso chart or Quick Drip equipment footer:

```erb
<% bean_hero_url = media_attachment_path(brew.bean.primary_photo_attachment, variant: :hero) if brew.bean.primary_photo_attachment %>
<% brew_hero_url = media_attachment_path(brew.primary_photo_attachment, variant: :hero) if brew.primary_photo_attachment %>
<div data-testid="brew-hero-upper" class="relative isolate overflow-hidden bg-black p-5">
  <%= render "shared/brew_hero_backdrop", bean_image_url: bean_hero_url, brew_image_url: brew_hero_url %>
  <div data-testid="brew-hero-overlay" class="relative z-10">
```

Delete `brew_card_photo_attachment` and the old small photo-frame markup. Do not change Espresso chart or either equipment footer.

- [ ] **Step 5: Run Hero/media tests and commit**

Run: `bin/rails test test/controllers/media_attachments_controller_test.rb test/controllers/public_brew_media_controller_test.rb test/controllers/brews_controller_test.rb test/controllers/home_controller_test.rb`

Expected: PASS for safe types, unknown variants, all eight method/image cases, contained Bean fit, cover Brew fit, blend gating, and all shared private surfaces.

```bash
git add app/controllers/media_attachments_controller.rb app/controllers/public_brew_media_controller.rb app/views/shared/_brew_hero_backdrop.html.erb app/views/brews/_espresso_hero_card.html.erb app/views/brews/_quick_drip_hero_card.html.erb app/helpers/brews_helper.rb test/controllers/media_attachments_controller_test.rb test/controllers/public_brew_media_controller_test.rb test/controllers/brews_controller_test.rb test/controllers/home_controller_test.rb
git commit -m "feat: add two-photo brew hero backdrop"
```

### Task 5: Define The Automatic Privacy-Safe Public Recipient Projection

**Files:**

- Create: `app/services/public_brew_recipient_projection.rb`
- Create: `test/services/public_brew_recipient_projection_test.rb`

**Interfaces:**

- Produces: `PublicBrewRecipientProjection.new(brew:).call -> Hash<String, String|Integer>`.
- Snapshot contract: Self `{ "kind" => "self" }`; Guest `{ "kind" => "guest" }`; a household recipient with an existing User has kind plus `display_label`, and gains `avatar_attachment_id` only while current membership authorizes the avatar.
- This approval is part of the feature design. Do not add a per-share consent column, parameter, or editor control.

- [ ] **Step 1: Write failing projection tests**

```ruby
require "test_helper"

class PublicBrewRecipientProjectionTest < ActiveSupport::TestCase
  include PhotoTestHelper

test "guest projection never contains its private name" do
  brew = brews(:morning_espresso)
  brew.update!(recipient_kind: "guest", recipient_name: "Secret Anna")
  payload = PublicBrewRecipientProjection.new(brew:).call
  assert_equal({ "kind" => "guest" }, payload)
  assert_no_match(/Secret Anna|recipient_name/, payload.to_json)
end

test "household identity is automatic while membership authorizes it" do
  brew = brews(:morning_espresso)
  avatar = attach_named_photo(users(:two), :avatar, filename: "petra.jpg")
  brew.update!(recipient_kind: "household_member", recipient_user: users(:two))
  assert_equal(
    { "kind" => "household_member", "display_label" => users(:two).display_label, "avatar_attachment_id" => avatar.id },
    PublicBrewRecipientProjection.new(brew:).call
  )
  memberships(:member).destroy!
  assert_equal(
    { "kind" => "household_member", "display_label" => users(:two).display_label },
    PublicBrewRecipientProjection.new(brew:).call
  )
end
end
```

Run: `bin/rails test test/services/public_brew_recipient_projection_test.rb`

Expected: FAIL because the service is missing.

- [ ] **Step 2: Implement the projection without adding share state**

```ruby
class PublicBrewRecipientProjection
  def initialize(brew:)
    @brew = brew
  end

  def call
    payload = { "kind" => brew.recipient_kind }
    return payload unless brew.recipient_household_member? && brew.recipient_user

    payload["display_label"] = brew.recipient_user.display_label
    if current_household_member?
      payload["avatar_attachment_id"] = brew.recipient_user.avatar.attachment&.id
    end
    payload.compact
  end

  private
    attr_reader :brew

    def current_household_member?
      brew.workspace.memberships.exists?(user_id: brew.recipient_user_id)
    end
end
```

- [ ] **Step 3: Run and commit**

Run: `bin/rails test test/services/public_brew_recipient_projection_test.rb`

Expected: PASS.

```bash
git add app/services/public_brew_recipient_projection.rb test/services/public_brew_recipient_projection_test.rb
git commit -m "feat: project public brew recipients safely"
```

### Task 6: Snapshot And Render The Curated Public Brew Hero

**Files:**

- Modify: `app/services/public_brew_share_snapshot_builder.rb`
- Modify: `app/models/public_brew_share.rb`
- Modify: `app/services/public_brew_share_refresher.rb`
- Modify: `app/helpers/public_brew_shares_helper.rb`
- Modify: `app/views/public_brew_pages/_hero_card.html.erb`
- Modify: `test/services/public_brew_share_snapshot_builder_test.rb`
- Modify: `test/services/public_brew_share_refresher_test.rb`
- Modify: `test/controllers/public_brew_shares_controller_test.rb`
- Modify: `test/controllers/public_brew_pages_controller_test.rb`
- Modify: `test/controllers/public_brew_media_controller_test.rb`

**Interfaces:**

- `PublicBrewShareSnapshotBuilder.new(brew:, title:, selected_photo_attachment_ids:)` keeps its existing signature.
- Adds snapshot keys `brew.recipient` and `hero.bean_photo_attachment_id`/`hero.brew_photo_attachment_id`.
- Public image URLs use `public_media_url_for(share, attachment_id, variant: :hero)` only.

- [ ] **Step 1: Write failing snapshot and HTML privacy tests**

Attach/set Bean and Brew primaries. Assert selecting both yields both `hero` references, selecting only Bean omits Brew, selecting neither yields `{}`, and a non-primary selected photo never becomes a Hero reference. For Self/member/Guest assert the projection above. In page tests assert opaque `/s/<token>/media/<32 hex>?variant=hero` URLs and no attachment ID, filename, `/media_attachments/`, `/rails/active_storage`, `recipient_name`, or private Guest value in HTML.

```ruby
assert_equal bean_primary.id, snapshot.dig("hero", "bean_photo_attachment_id")
assert_equal brew_primary.id, snapshot.dig("hero", "brew_photo_attachment_id")
assert_equal({ "kind" => "guest" }, snapshot.dig("brew", "recipient"))
assert_no_match(/Secret Anna|recipient_name|guest_name/, snapshot.to_json)
assert_match %r{/s/#{Regexp.escape(share.token)}/media/[0-9a-f]{32}\?variant=hero}, response.body
[ bean_primary.id, brew_primary.id ].each do |attachment_id|
  assert_no_match %r{/media_attachments/#{attachment_id}(?:[/?"']|$)}, response.body
  assert_no_match(/attachment_id=#{attachment_id}(?:[&"']|$)/, response.body)
  assert_no_match(/data-attachment-id=["']#{attachment_id}["']/, response.body)
end
assert_no_match %r{/media_attachments/|/rails/active_storage}, response.body
assert_no_match(/photo\.jpg|signed_id|X-Amz-Signature/, response.body)
```

Run: `bin/rails test test/services/public_brew_share_snapshot_builder_test.rb test/controllers/public_brew_pages_controller_test.rb`

Expected: FAIL on missing recipient/Hero payload and backdrop.

- [ ] **Step 2: Build explicit snapshot references**

Add these exact fragments without changing the builder initializer:

```ruby
payload = {
  "title" => title.presence || default_title,
  "workspace" => workspace_payload,
  "user" => user_payload,
  "brew" => brew_payload.merge("recipient" => PublicBrewRecipientProjection.new(brew:).call),
  "hero" => {
    "bean_photo_attachment_id" => selected_primary_attachment_id(brew.bean),
    "brew_photo_attachment_id" => selected_primary_attachment_id(brew)
  }.compact,
  "bean" => bean_payload,
  "equipment" => [ equipment_payload(brew.grinder, "grinder"), equipment_payload(brew.machine, "machine") ].compact,
  "tools" => tool_payloads,
  "photos" => photo_payloads([ brew ]),
  "generated_at" => time_string(Time.current)
}
```

Make `public_attachment_ids` intersect collected snapshot `public_media` IDs with `allowed_public_attachment_ids`; extend `public_identity_attachment_ids` with the recipient avatar only while `brew.workspace.memberships.exists?(user_id: brew.recipient_user_id)`. This defense removes stale avatar access immediately after membership loss.

- [ ] **Step 3: Render the public backdrop and curated byline**

At the public Hero top, replace the current upper wrapper opening with this exact opening. Keep the current public header, Bean identity, and metrics as children of `public-brew-hero-overlay`, add the byline shown, then insert two closing `</div>` tags before the chart wrapper:

```erb
<% recipient = brew.fetch("recipient", { "kind" => "unknown" }) %>
<% hero = snapshot.fetch("hero", {}) %>
<% bean_hero_url = public_media_url_for(share, hero["bean_photo_attachment_id"], variant: :hero) %>
<% brew_hero_url = public_media_url_for(share, hero["brew_photo_attachment_id"], variant: :hero) %>
<div data-testid="public-brew-hero-upper" class="relative isolate overflow-hidden bg-black p-5">
  <%= render "shared/brew_hero_backdrop", bean_image_url: bean_hero_url, brew_image_url: brew_hero_url %>
  <div data-testid="public-brew-hero-overlay" class="relative z-10">
    <p data-testid="public-brew-recipient-byline"><%= public_brew_recipient_byline(snapshot.fetch("user", {}), recipient) %></p>
```

Implement the helper without database access:

```ruby
def public_brew_recipient_byline(logger, recipient)
  target = case recipient["kind"]
  when "self" then t("brews.recipients.themself")
  when "household_member" then recipient["display_label"].presence || t("brews.recipients.a_household_member")
  when "guest" then t("brews.recipients.a_guest")
  else t("brews.recipients.someone")
  end
  t("brews.recipients.byline", logger: logger["display_label"].presence || t("public_brew_pages.show.unknown"), recipient: target)
end
```

Render the current household recipient avatar through its opaque handle/thumbnail next to the logger avatar; render no missing-image tag when absent.

Add a stale-snapshot page test with no `brew.recipient` key and assert the byline says `for someone`, never `for themself`. The one-time refresh in Task 7 upgrades normal persisted shares; this fallback remains deliberately truthful if a malformed/imported snapshot ever lacks the key.

- [ ] **Step 4: Verify refresh and opaque Hero media, then commit**

Add refresher coverage that a focused serving change replaces the snapshot recipient and that selected primary changes alter Hero refs. Add public media tests for `variant=hero`, generic filename, safe-raster gating, password gate, unknown variant 404, and numeric-ID guess 404.

Run: `bin/rails test test/services/public_brew_share_snapshot_builder_test.rb test/services/public_brew_share_refresher_test.rb test/controllers/public_brew_shares_controller_test.rb test/controllers/public_brew_pages_controller_test.rb test/controllers/public_brew_media_controller_test.rb`

Expected: PASS with no public privacy assertion failures.

```bash
git add app/services/public_brew_share_snapshot_builder.rb app/models/public_brew_share.rb app/services/public_brew_share_refresher.rb app/helpers/public_brew_shares_helper.rb app/views/public_brew_pages/_hero_card.html.erb test/services/public_brew_share_snapshot_builder_test.rb test/services/public_brew_share_refresher_test.rb test/controllers/public_brew_shares_controller_test.rb test/controllers/public_brew_pages_controller_test.rb test/controllers/public_brew_media_controller_test.rb
git commit -m "feat: add curated public brew recipient hero"
```

### Task 7: Project Recipients Into Public Bean Summaries And Refresh Identity Changes

**Files:**

- Modify: `app/models/public_bean_share.rb`
- Modify: `app/services/public_bean_share_snapshot_builder.rb`
- Modify: `app/services/public_bean_share_refresher.rb`
- Modify: `app/helpers/public_bean_shares_helper.rb`
- Modify: `app/views/public_bean_pages/_brew_card.html.erb`
- Modify: `app/views/public_bean_pages/_timeline.html.erb`
- Modify: `app/services/public_brew_share_refresher.rb`
- Modify: `app/services/workspace_membership_manager.rb`
- Modify: `test/models/public_bean_share_test.rb`
- Modify: `test/services/public_bean_share_snapshot_builder_test.rb`
- Modify: `test/services/public_bean_share_refresher_test.rb`
- Modify: `test/controllers/public_bean_pages_controller_test.rb`
- Modify: `test/controllers/public_bean_media_controller_test.rb`
- Modify: `test/services/public_brew_share_refresher_test.rb`
- Modify: `test/services/workspace_membership_manager_test.rb`
- Modify: `test/controllers/profiles_controller_test.rb`
- Create: `db/migrate/20260821113000_refresh_public_recipient_hero_snapshots.rb`
- Create: `test/migrations/refresh_public_recipient_hero_snapshots_test.rb`
- Modify: `db/schema.rb`

**Interfaces:**

- `PublicBeanShareSnapshotBuilder.new(bean:, title:, selected_photo_attachment_ids:)` keeps its existing signature.
- Every item in snapshot `brews` and `timeline.brews` gets `recipient`; the source remains `PublicBrewRecipientProjection`.
- Both `shares_for(User)` queries match logger `user_id` OR `recipient_user_id`.

- [ ] **Step 1: Write failing public Bean projection/privacy tests**

Create Self, household-member, named Guest, and unnamed Guest Brews for one Bean. Assert compact summaries/bylines for all kinds, the member's safe label and currently authorized avatar, Guest always says `for a guest`, and snapshot/HTML contain no guest value, `recipient_name`, raw avatar ID/path/filename, or private route. Destroy the member's membership and assert refresh preserves `kind`/`display_label` while removing `avatar_attachment_id`.

Run: `bin/rails test test/services/public_bean_share_snapshot_builder_test.rb test/controllers/public_bean_pages_controller_test.rb`

Expected: FAIL because Bean snapshots have no recipient projection.

- [ ] **Step 2: Add the projection to summaries and timeline**

Use one projection method in both payload locations:

```ruby
def recipient_payload(brew)
  PublicBrewRecipientProjection.new(brew:).call
end

# in common_brew_payload
"user" => user_payload(brew.user),
"recipient" => recipient_payload(brew),

# in each timeline brew
"user" => user_payload(brew.user),
"recipient" => recipient_payload(brew)
```

Build `public_media` by recursively collecting every `*_attachment_id` in the already-curated payload. In `PublicBeanShare#allowed_public_attachment_ids`, include logger avatars and current household-recipient avatars only; no new share setting participates.

- [ ] **Step 3: Render snapshot-only Bean bylines and avatars**

Add `public_bean_recipient_byline(user, recipient)` with the same Self/member/anonymous-member/Guest branches as Task 6, and use it in `_brew_card.html.erb` and timeline accessible labels. Render recipient avatar only with `public_bean_media_url_for(share, recipient["avatar_attachment_id"], variant: :thumbnail)`.

- [ ] **Step 4: Refresh logger-or-recipient profile/avatar and membership changes**

Replace each User branch with an OR query:

```ruby
when User
  PublicBrewShare.joins(:brew)
    .where("brews.user_id = :user_id OR brews.recipient_user_id = :user_id", user_id: record.id)
    .distinct
```

Use the equivalent `PublicBeanShare.joins(bean: :brews)` query. In `WorkspaceMembershipManager#remove`, after `destroy!` and active-workspace cleanup, call both refreshers for `target_user` inside the existing transaction. Tests must cover recipient-only User refresh, profile display-name/avatar refresh, selected media refresh, and membership-removal stripping.

- [ ] **Step 5: Refresh every already-published Brew and Bean snapshot once**

Create `db/migrate/20260821113000_refresh_public_recipient_hero_snapshots.rb` after the Task 6 and Task 7 builders/refresher code exists:

```ruby
class RefreshPublicRecipientHeroSnapshots < ActiveRecord::Migration[8.1]
  def up
    PublicBrewShare.find_each { |share| PublicBrewShareRefresher.refresh(share) }
    PublicBeanShare.find_each { |share| PublicBeanShareRefresher.refresh(share) }
  end

  def down
    # Curated snapshots intentionally stay on the safer current projection.
  end
end
```

Keep this migration and its test as the versioned one-time upgrade contract; do not replace it with a best-effort background job. Create `test/migrations/refresh_public_recipient_hero_snapshots_test.rb`, require the migration explicitly, and start with enabled Brew and Bean shares whose stored snapshots predate both keys:

```ruby
# test/migrations/refresh_public_recipient_hero_snapshots_test.rb
require "test_helper"
require Rails.root.join("db/migrate/20260821113000_refresh_public_recipient_hero_snapshots")

class RefreshPublicRecipientHeroSnapshotsTest < ActiveSupport::TestCase
  include PhotoTestHelper

test "upgrades existing guest shares with recipient privacy and selected primary hero media" do
  brew = brews(:morning_espresso)
  brew.update!(recipient_kind: "guest", recipient_user: nil, recipient_name: "Secret Anna")
  bean_primary = attach_photo(brew.bean)
  brew_primary = attach_photo(brew)
  brew.bean.set_primary_photo!(bean_primary)
  brew.set_primary_photo!(brew_primary)

  brew_share = PublicBrewShare.create!(
    workspace: brew.workspace, brew:, created_by: users(:one), updated_by: users(:one),
    title: "Existing Brew share", enabled: true,
    selected_photo_attachment_ids: [ bean_primary.id, brew_primary.id ],
    snapshot: { "title" => "Existing Brew share", "brew" => {} }
  )
  bean_share = PublicBeanShare.create!(
    workspace: brew.workspace, bean: brew.bean,
    created_by: users(:one), updated_by: users(:one),
    title: "Existing Bean share", enabled: true,
    selected_photo_attachment_ids: [ bean_primary.id ],
    snapshot: { "title" => "Existing Bean share", "brews" => [] }
  )

  RefreshPublicRecipientHeroSnapshots.new.up

  assert_equal({ "kind" => "guest" }, brew_share.reload.snapshot.dig("brew", "recipient"))
  assert_equal bean_primary.id, brew_share.snapshot.dig("hero", "bean_photo_attachment_id")
  assert_equal brew_primary.id, brew_share.snapshot.dig("hero", "brew_photo_attachment_id")
  bean_brew = bean_share.reload.snapshot.fetch("brews").find do |item|
    item.fetch("occurred_at") == brew.occurred_at.utc.iso8601
  end
  assert_equal({ "kind" => "guest" }, bean_brew.fetch("recipient"))
  assert_no_match(/Secret Anna|recipient_name/, brew_share.snapshot.to_json)
  assert_no_match(/Secret Anna|recipient_name/, bean_share.snapshot.to_json)
end
end
```

Extend this same test file with a household-recipient pre-feature snapshot and assert the safe display label is rebuilt, while its avatar ID appears only for a current membership and disappears after removal/refresh. Run:

```bash
bin/rails test test/migrations/refresh_public_recipient_hero_snapshots_test.rb
bin/rails db:migrate
```

Expected: the migration test passes; migration `20260821113000` is up; every existing public Brew Hero and public Bean Brew summary now contains the current privacy-safe recipient projection, and selected primary Hero halves no longer remain black merely because a share predates this feature.

- [ ] **Step 6: Run and commit**

Run: `bin/rails test test/services/public_bean_share_snapshot_builder_test.rb test/services/public_bean_share_refresher_test.rb test/controllers/public_bean_pages_controller_test.rb test/controllers/public_bean_media_controller_test.rb test/services/public_brew_share_refresher_test.rb test/services/workspace_membership_manager_test.rb test/controllers/profiles_controller_test.rb test/migrations/refresh_public_recipient_hero_snapshots_test.rb`

Expected: PASS; public Bean summaries are recipient-aware and stale identity media is inaccessible.

```bash
git add app/models/public_bean_share.rb app/services/public_bean_share_snapshot_builder.rb app/services/public_bean_share_refresher.rb app/helpers/public_bean_shares_helper.rb app/views/public_bean_pages/_brew_card.html.erb app/views/public_bean_pages/_timeline.html.erb app/services/public_brew_share_refresher.rb app/services/workspace_membership_manager.rb db/migrate/20260821113000_refresh_public_recipient_hero_snapshots.rb db/schema.rb test/models/public_bean_share_test.rb test/services/public_bean_share_snapshot_builder_test.rb test/services/public_bean_share_refresher_test.rb test/controllers/public_bean_pages_controller_test.rb test/controllers/public_bean_media_controller_test.rb test/services/public_brew_share_refresher_test.rb test/services/workspace_membership_manager_test.rb test/controllers/profiles_controller_test.rb test/migrations/refresh_public_recipient_hero_snapshots_test.rb
git commit -m "feat: add recipients to public bean brew summaries"
```

### Task 8: Make Exports And Backups Reconstruct Recipients

**Files:**

- Modify: `app/services/workspace_export_builder.rb`
- Modify: `app/services/workspace_csv_export_builder.rb`
- Modify: `app/services/instance_backup_restorer.rb`
- Modify: `test/services/workspace_export_builder_test.rb`
- Modify: `test/services/workspace_csv_export_builder_test.rb`
- Modify: `test/controllers/workspace_exports_controller_test.rb`
- Modify: `test/services/instance_backup_builders_test.rb`
- Modify: `test/services/instance_backup_restore_test.rb`
- Modify: `test/services/recipe_snapshot_builder_test.rb`
- Modify: `test/services/public_recipe_share_snapshot_builder_test.rb`

**Interfaces:**

- JSON Brew rows: `recipient_kind`, `recipient_user_id`, `recipient_user_display_name`, `recipient_user_email_address`, `recipient_name`, `cup_style`.
- CSV uses the same six columns and removes `served_for_guest`/`guest_name`.
- Restore accepts the new keys or legacy `served_for_guest`/`guest_name`, and restores `cup_style` in both cases.

- [ ] **Step 1: Write failing export and restore tests**

Add JSON/CSV assertions for Self, member, named Guest, unnamed Guest, and a former-member reference. Assert old column headers are absent. Extend archive round-trip to verify exact kind/mapped User/private name/cup. Mutate a generated archive payload so one Brew contains only `served_for_guest: true`, `guest_name: "Legacy Anna"`, and `cup_style: "Latte"`; rebuild the ZIP and assert it restores as Guest with that name/cup. Add a legacy false row assertion restoring as Self.

Run: `bin/rails test test/services/workspace_export_builder_test.rb test/services/workspace_csv_export_builder_test.rb test/services/instance_backup_builders_test.rb test/services/instance_backup_restore_test.rb`

Expected: FAIL on legacy fields/new missing fields and current restore omission.

- [ ] **Step 2: Replace export fields**

Use `includes(:user, :recipient_user)` and replace the two legacy keys with:

```ruby
recipient_kind: brew.recipient_kind,
recipient_user_id: brew.recipient_user_id,
recipient_user_display_name: brew.recipient_user&.display_label,
recipient_user_email_address: brew.recipient_user&.email_address,
recipient_name: brew.recipient_name,
cup_style: brew.cup_style,
```

Put the same names in `BREW_COLUMNS` and add these cases to `brew_value`:

```ruby
when "recipient_user_display_name" then brew.recipient_user&.display_label
when "recipient_user_email_address" then brew.recipient_user&.email_address
```

Keep export/readable/archive version constants at `1`, because restore intentionally accepts pre-change version-1 archives.

- [ ] **Step 3: Restore new and legacy rows without invalidating former recipients**

Create each Brew initially as Self, include `cup_style`, and then atomically write the trusted structural fields after creation. Replace `restore_brews` with this complete method:

```ruby
def restore_brews
  workspace_payloads.each do |workspace_payload|
    workspace = @workspace_map.fetch(old_id(workspace_payload.fetch("workspace")))
    workspace_payload.fetch("brews").each do |row|
      recipient_attributes = restored_recipient_attributes(row)
      brew = Brew.create!(
        workspace:,
        user: @user_map.fetch(row.fetch("user_id")),
        bean: @bean_map.fetch(row.fetch("bean_id")),
        grinder: optional_lookup(@equipment_map, row["grinder_id"]),
        machine: optional_lookup(@equipment_map, row["machine_id"]),
        brewer: optional_lookup(@equipment_map, row["brewer_id"]),
        data_import: optional_lookup(@data_import_map, row["data_import_id"]),
        method: row["method"],
        occurred_at: time(row["occurred_at"]),
        bean_weight_grams: row["bean_weight_grams"],
        ground_weight_grams: row["ground_weight_grams"],
        dose_grams: row["dose_grams"],
        beverage_grams: row["beverage_grams"],
        machine_cups: row["machine_cups"],
        coffee_spoons: row["coffee_spoons"],
        grams_per_coffee_spoon: row["grams_per_coffee_spoon"],
        coffee_amount_source: row["coffee_amount_source"] || "measured",
        grind_setting: row["grind_setting"],
        brew_temperature_celsius: row["brew_temperature_celsius"],
        total_time_seconds: row["total_time_seconds"],
        preinfusion_seconds: row["preinfusion_seconds"],
        low_flow_start_seconds: row["low_flow_start_seconds"],
        first_drip_seconds: row["first_drip_seconds"],
        channeling: row["channeling"],
        flow_control_used: row["flow_control_used"],
        taste_balance: row["taste_balance"],
        rating: row["rating"],
        recipient_kind: "self",
        cup_style: row["cup_style"],
        notes: row["notes"],
        retention_marker: row["retention_marker"],
        import_source: row["import_source"],
        import_source_id: row["import_source_id"],
        raw_import_data: row["raw_import_data"] || {},
        created_at: time(row["created_at"]),
        updated_at: time(row["updated_at"])
      )
      brew.inventory_adjustment&.destroy!
      brew.update_columns(coffee_amount_source: row["coffee_amount_source"]) if row["coffee_amount_source"].present?
      brew.update_columns(**recipient_attributes, updated_at: time(row["updated_at"]))
      @brew_map[old_id(row)] = brew
    end
  end
end
```

Add this exact helper; the DB constraint and User foreign key remain the final trust boundary, while `update_columns` permits a historical User whose Membership was intentionally absent from the restored workspace:

```ruby
def restored_recipient_attributes(row)
  kind = row["recipient_kind"].presence
  kind ||= ActiveModel::Type::Boolean.new.cast(row["served_for_guest"]) ? "guest" : "self"
  raise KeyError, "Unsupported recipient_kind #{kind.inspect}" unless Brew.recipient_kinds.key?(kind)

  case kind
  when "self"
    { recipient_kind: "self", recipient_user_id: nil, recipient_name: nil }
  when "household_member"
    { recipient_kind: "household_member", recipient_user_id: @user_map.fetch(row.fetch("recipient_user_id")).id, recipient_name: nil }
  when "guest"
    name = row.key?("recipient_name") ? row["recipient_name"] : row["guest_name"]
    { recipient_kind: "guest", recipient_user_id: nil, recipient_name: name.to_s.strip.presence }
  end
end
```

- [ ] **Step 4: Strengthen recipe-negative tests**

Set a recipe source Brew to a named household recipient, then assert `recipient_kind`, `recipient_user_id`, `recipient_user`, `recipient_name`, `served_for_guest`, `guest_name`, and `cup_style` are absent from `RecipeSnapshotBuilder` and the curated public recipe snapshot.

- [ ] **Step 5: Run and commit**

Run: `bin/rails test test/services/workspace_export_builder_test.rb test/services/workspace_csv_export_builder_test.rb test/controllers/workspace_exports_controller_test.rb test/services/instance_backup_builders_test.rb test/services/instance_backup_restore_test.rb test/services/recipe_snapshot_builder_test.rb test/services/public_recipe_share_snapshot_builder_test.rb`

Expected: PASS for new/legacy archives and recipient-free recipes.

```bash
git add app/services/workspace_export_builder.rb app/services/workspace_csv_export_builder.rb app/services/instance_backup_restorer.rb test/services/workspace_export_builder_test.rb test/services/workspace_csv_export_builder_test.rb test/controllers/workspace_exports_controller_test.rb test/services/instance_backup_builders_test.rb test/services/instance_backup_restore_test.rb test/services/recipe_snapshot_builder_test.rb test/services/public_recipe_share_snapshot_builder_test.rb
git commit -m "feat: export and restore brew recipients"
```

### Task 9: Update Timer Semantics, Copy, And Durable Documentation

**Files:**

- Modify: `app/services/dashboard_metrics.rb`
- Modify: `test/services/dashboard_metrics_test.rb`
- Modify: `config/locales/en.yml`
- Modify: `docs/coffee-core.md`
- Modify: `docs/brew-card.md`
- Modify: `docs/brew-corrections.md`
- Modify: `docs/public-brew-sharing.md`
- Modify: `docs/public-bean-sharing.md`
- Modify: `docs/private-media.md`
- Modify: `docs/account-privacy.md`
- Modify: `docs/workspace-export.md`
- Modify: `docs/backup-system.md`
- Modify: `docs/status.md`

**Interfaces:**

- `DashboardMetrics#latest_brew_at` excludes only `recipient_kind: "guest"`.
- Locale vocabulary is fixed to “Served to”, “Myself”, “Household member”, “Guest”, “For me”, “For %{name}”, and “Logged by %{logger} for %{recipient}”.

- [ ] **Step 1: Write the failing timer test**

```ruby
test "last coffee timer includes self and household members but excludes guests" do
  self_brew = brews(:morning_espresso)
  self_brew.update!(recipient_kind: "self", occurred_at: 3.hours.ago)
  member_brew = self_brew.dup
  member_brew.assign_attributes(recipient_kind: "household_member", recipient_user: users(:two), occurred_at: 2.hours.ago)
  member_brew.save!
  guest_brew = self_brew.dup
  guest_brew.assign_attributes(recipient_kind: "guest", recipient_name: "Anna", occurred_at: 1.hour.ago)
  guest_brew.save!
  assert_equal member_brew.occurred_at.to_i, DashboardMetrics.new(workspace: workspaces(:household)).call[:last_coffee_at].to_i
end
```

Run: `bin/rails test test/services/dashboard_metrics_test.rb`

Expected: FAIL because the query still references the removed legacy column.

- [ ] **Step 2: Replace the timer query and add exact English copy**

```ruby
def latest_brew_at
  workspace.brews.where.not(recipient_kind: "guest").maximum(:occurred_at)
end
```

Add this locale subtree:

```yaml
brews:
  recipients:
    myself: "Myself"
    guest: "Guest"
    me: "me"
    themself: "themself"
    a_guest: "a guest"
    a_household_member: "a household member"
    someone: "someone"
    former_member: "%{name} (former member)"
    badge: "For %{recipient}"
    byline: "Logged by %{logger} for %{recipient}"
  form:
    served_to: "Served to"
    person_name: "Person name"
    person_name_help: "Entering a name that is not a household member marks this Brew as Guest."
```

Remove obsolete `served_for_guest`/`guest_name` copy.

- [ ] **Step 3: Update all durable docs with exact decisions**

- `docs/coffee-core.md`: three kinds, exact fields/invariants, Workspace resolution, timer semantics.
- `docs/brew-card.md`: badge colors/copy, two avatars, former-member fallback, two black media halves and fit modes.
- `docs/brew-corrections.md`: shared Served-to control and inventory-safe focused correction.
- `docs/public-brew-sharing.md`: automatic safe member-label projection, current-membership avatar authorization, explicit primary-photo selection, opaque Hero media, and Guest-name prohibition.
- `docs/public-bean-sharing.md`: identical automatic recipient projection in all Brew summaries/timeline and former-member label/no-avatar fallback.
- `docs/private-media.md`: `hero` is `resize_to_limit [1200, 1200]`; safe raster and authorization rules remain.
- `docs/account-privacy.md`: private Guest name versus public safe household label/current-member avatar and membership-removal fallback.
- `docs/workspace-export.md`: exact JSON/CSV fields and removed legacy columns.
- `docs/backup-system.md`: new schema, legacy acceptance, mapped recipient User, cup metadata restore.
- `docs/status.md`: date-stamped delivered capability and test/visual verification summary.

- [ ] **Step 4: Run semantic tests and commit**

Run: `bin/rails test test/services/dashboard_metrics_test.rb`

Expected: PASS.

Run: `rg -n "served_for_guest|guest_name" app config db/schema.rb --glob '!app/services/instance_backup_restorer.rb'`

Expected: no matches. Legacy names remain only in the migration/backfill, backup restore compatibility, and negative/legacy tests.

```bash
git add app/services/dashboard_metrics.rb test/services/dashboard_metrics_test.rb config/locales/en.yml docs/coffee-core.md docs/brew-card.md docs/brew-corrections.md docs/public-brew-sharing.md docs/public-bean-sharing.md docs/private-media.md docs/account-privacy.md docs/workspace-export.md docs/backup-system.md docs/status.md
git commit -m "docs: document brew recipients and hero privacy"
```

### Task 10: Full Regression, Security, And Visual Verification

**Files:**

- Modify only files implicated by a failing check; keep fixes in the task owning that behavior.

**Interfaces:**

- Consumes all prior interfaces.
- Produces a green Rails suite, clean security/autoload checks, and a running LAN-reachable development server in `roastnode-dev`.

- [ ] **Step 1: Run the focused feature suite**

Run:

```bash
bin/rails test test/migrations/replace_brew_guest_fields_with_recipient_test.rb test/models/brew_test.rb test/assets/brew_recipient_controller_test.rb test/presenters/brew_recipient_presenter_test.rb test/controllers/brews_controller_test.rb test/controllers/home_controller_test.rb test/controllers/media_attachments_controller_test.rb test/services/public_brew_recipient_projection_test.rb test/services/public_brew_share_snapshot_builder_test.rb test/services/public_brew_share_refresher_test.rb test/controllers/public_brew_shares_controller_test.rb test/controllers/public_brew_pages_controller_test.rb test/controllers/public_brew_media_controller_test.rb test/services/public_bean_share_snapshot_builder_test.rb test/services/public_bean_share_refresher_test.rb test/controllers/public_bean_shares_controller_test.rb test/controllers/public_bean_pages_controller_test.rb test/controllers/public_bean_media_controller_test.rb test/services/workspace_export_builder_test.rb test/services/workspace_csv_export_builder_test.rb test/services/instance_backup_builders_test.rb test/services/instance_backup_restore_test.rb test/services/dashboard_metrics_test.rb test/services/recipe_snapshot_builder_test.rb test/services/public_recipe_share_snapshot_builder_test.rb
```

Expected: zero failures and zero errors.

- [ ] **Step 2: Run full application and security checks**

Run: `bin/rails test`

Expected: zero failures and zero errors.

Run: `bin/rails zeitwerk:check`

Expected: `All is good!`.

Run: `bin/brakeman --quiet`

Expected: exit 0 with no new warnings.

- [ ] **Step 3: Audit exact names and public leakage**

Run:

```bash
rg -n "recipient_kind|recipient_user_id|recipient_user|recipient_name" app db/schema.rb test docs
rg -n "served_for_guest|guest_name" app config db/schema.rb --glob '!app/services/instance_backup_restorer.rb'
rg -n "media_attachment_path|rails/active_storage|signed_id|filename|data-attachment-id" app/views/public_brew_pages app/views/public_bean_pages
```

Expected: new names are consistent; the runtime legacy scan and public-view leakage scan return no matches. The restore helper and intentional migration/negative tests retain legacy strings only for compatibility proof.

- [ ] **Step 4: Start or reuse the required tmux development server**

Run: `tmux has-session -t roastnode-dev`

Expected: exit 0 when already running. If absent, run `tmux new-session -d -s roastnode-dev -c /Users/d33pjs/Documents/developing/roastnode 'bin/dev'`.

Run: `curl -I http://127.0.0.1:3001`

Expected: an HTTP response from Rails. Also confirm the configured LAN DNS host responds on port 3001; do not stop a healthy `roastnode-dev` session.

- [ ] **Step 5: Perform the responsive visual matrix in the in-app Browser**

At 390×844 and 1440×1000, verify light and dark themes for:

- New Espresso, new Quick Drip, edit, and focused correction forms: Self default, avatar member rows, Guest auto-selection, long labels, no legacy checkbox, keyboard focus, and usable no-JS submission.
- Dashboard, Brew detail, compact history, and Hero history: all four Bean/Brew photo combinations for both methods; missing halves black; Bean uncropped/contained; Brew covered; blend only with both; no small thumbnail; badge/byline above images.
- Self, member, named Guest, unnamed Guest, and removed-member private cards: exact colors/copy, no overflow, no broken avatar.
- Public Brew with both selected, one selected, and neither selected: black unselected halves and only opaque media URLs.
- Public Bean Brew summaries for all kinds while the member is current and after membership removal.
- Bright and dark test photographs: readable header/title/byline/metrics, no hard center seam, gradients/vignette intact, no horizontal overflow.

Expected: every matrix item matches the design at both widths/themes; Browser network inspection shows only the opaque route shapes `/s/<share-token>/media/<32-hex-handle>` or `/b/<share-token>/media/<32-hex-handle>` for public images.

- [ ] **Step 6: Record final verification state and leave the server running**

Run: `git status --short`

Expected: no uncommitted feature files. Pre-existing user-owned paths remain untouched, and `roastnode-dev` remains running. If a check required a code fix, rerun that task's exact test command and commit only that task's explicitly listed files with its commit message before recording this state.
