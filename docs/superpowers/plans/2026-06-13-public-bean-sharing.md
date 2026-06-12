# Public Bean Sharing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build curated, optionally password-protected public bean bag share pages with selected bean photos, public-safe statistics, a compact timeline, and all espresso plus Quick Drip brew summaries for the bag.

**Architecture:** Add a snapshot-based `PublicBeanShare` surface that mirrors existing public brew and recipe sharing without reading live private records for public content. Private controllers manage a single share per publishable bean through the active workspace; unauthenticated public controllers render `/b/:token`, password gates, and selected bean media strictly through token digests, snapshots, and opaque media handles.

**Tech Stack:** Rails 8.1, Active Record, PostgreSQL JSONB/arrays, Active Storage, BCrypt `has_secure_password`, ERB, Tailwind CSS, Minitest.

---

## File Structure

- Create `db/migrate/20260613120000_create_public_bean_shares.rb`: public bean share records.
- Create `db/migrate/20260613120100_create_public_bean_share_views.rb`: capped recent view history.
- Create `app/models/public_bean_share.rb`: token/password state, lifecycle validation, authorization helper, media handle mapping.
- Create `app/models/public_bean_share_view.rb`: recent view scope and retention cap.
- Modify `app/models/bean.rb`: `has_one :public_bean_share`.
- Modify `app/models/workspace.rb`: `has_many :public_bean_shares`.
- Create `app/services/public_bean_share_snapshot_builder.rb`: public-safe bean stats, timeline, and all-brew summaries.
- Create `app/services/public_bean_share_refresher.rb`: snapshot refresh for bean, brew, workspace, user, media, and record-link changes.
- Create `app/services/public_bean_share_view_recorder.rb`: page view persistence and counter increment.
- Modify `config/routes.rb`: nested private bean share management and public `/b/:token` routes.
- Create `app/controllers/public_bean_shares_controller.rb`: private share editor.
- Create `app/controllers/public_bean_pages_controller.rb`: unauthenticated page and password unlock.
- Create `app/controllers/public_bean_media_controller.rb`: opaque public bean media streaming.
- Modify `app/controllers/beans_controller.rb`: share action links and bean-share refresh.
- Modify `app/controllers/brews_controller.rb`: bean-share refresh on brew create/update/taste/delete.
- Modify `app/controllers/media_attachments_controller.rb`: bean-share refresh on selected media changes.
- Modify `app/controllers/workspaces_controller.rb`: load bean shares in settings and refresh workspace public-safe identity changes.
- Modify `app/controllers/profiles_controller.rb`: refresh bean shares when user labels or avatars change.
- Create `app/views/public_bean_shares/new.html.erb`, `app/views/public_bean_shares/edit.html.erb`, and `app/views/public_bean_shares/_form.html.erb`: private share editor.
- Create `app/views/public_bean_pages/show.html.erb`, `app/views/public_bean_pages/password.html.erb`, `_timeline.html.erb`, `_stat_bar_list.html.erb`, and `_brew_card.html.erb`: public page.
- Create `app/helpers/public_bean_shares_helper.rb`: formatting, media URLs, timeline positions, rating icons, public link labels.
- Modify `app/views/beans/show.html.erb`: add `Share bean` / `Edit public share` action for writers.
- Create `app/views/workspaces/_public_bean_shares.html.erb`: settings management list.
- Modify `app/views/workspaces/edit.html.erb`: render public bean shares under public brew shares.
- Modify `config/locales/en.yml`: labels, notices, public page copy.
- Create `test/models/public_bean_share_test.rb` and `test/models/public_bean_share_view_test.rb`.
- Create `test/services/public_bean_share_snapshot_builder_test.rb`, `test/services/public_bean_share_refresher_test.rb`, and `test/services/public_bean_share_view_recorder_test.rb`.
- Create `test/controllers/public_bean_shares_controller_test.rb`, `test/controllers/public_bean_pages_controller_test.rb`, and `test/controllers/public_bean_media_controller_test.rb`.
- Modify `test/controllers/beans_controller_test.rb`, `test/controllers/brews_controller_test.rb`, `test/controllers/workspaces_controller_test.rb`, `test/controllers/media_attachments_controller_test.rb`, and `test/controllers/profiles_controller_test.rb`.
- Create `docs/public-bean-sharing.md`.
- Modify `docs/README.md`, `docs/status.md`, `docs/coffee-core.md`, `docs/private-media.md`, and `AGENTS.md`.

---

### Task 1: Schema And Public Bean Share Model

**Files:**
- Create: `db/migrate/20260613120000_create_public_bean_shares.rb`
- Create: `db/migrate/20260613120100_create_public_bean_share_views.rb`
- Create: `app/models/public_bean_share.rb`
- Create: `app/models/public_bean_share_view.rb`
- Modify: `app/models/bean.rb`
- Modify: `app/models/workspace.rb`
- Test: `test/models/public_bean_share_test.rb`
- Test: `test/models/public_bean_share_view_test.rb`

- [ ] **Step 1: Write failing model tests**

Create `test/models/public_bean_share_test.rb`:

```ruby
require "test_helper"

class PublicBeanShareTest < ActiveSupport::TestCase
  include PhotoTestHelper

  test "generates token and starts disabled" do
    share = PublicBeanShare.create!(
      workspace: workspaces(:household),
      bean: beans(:open_household),
      created_by: users(:one),
      updated_by: users(:one),
      title: "House Blend"
    )

    assert share.token.present?
    assert_equal Digest::SHA256.hexdigest(share.token), share.token_digest
    assert_not share.enabled?
    assert_equal({}, share.snapshot)
  end

  test "finds enabled shares by token digest" do
    share = PublicBeanShare.create!(
      workspace: workspaces(:household),
      bean: beans(:open_household),
      created_by: users(:one),
      updated_by: users(:one),
      enabled: true
    )

    assert_equal share, PublicBeanShare.find_enabled_by_token!(share.token)
    assert_raises(ActiveRecord::RecordNotFound) { PublicBeanShare.find_enabled_by_token!("wrong") }
  end

  test "does not find disabled shares by token" do
    share = PublicBeanShare.create!(
      workspace: workspaces(:household),
      bean: beans(:open_household),
      created_by: users(:one),
      updated_by: users(:one),
      enabled: false
    )

    assert_raises(ActiveRecord::RecordNotFound) { PublicBeanShare.find_enabled_by_token!(share.token) }
  end

  test "requires publishable bean lifecycle" do
    stock = workspaces(:household).beans.create!(
      name: "Stock Bag",
      roaster_name: "Shelf Roaster",
      bag_size_grams: 250,
      remaining_grams: 250
    )
    share = PublicBeanShare.new(
      workspace: stock.workspace,
      bean: stock,
      created_by: users(:one),
      updated_by: users(:one),
      enabled: true
    )

    assert_not share.valid?
    assert_includes share.errors[:bean], "must be open, finished, or used up"
  end

  test "allows finished and used up bags" do
    finished = beans(:open_household)
    finished.finish!
    used_up = beans(:second_open_household)
    used_up.update!(remaining_grams: 0)

    [ finished, used_up ].each do |bean|
      share = PublicBeanShare.new(
        workspace: bean.workspace,
        bean:,
        created_by: users(:one),
        updated_by: users(:one)
      )
      assert share.valid?, share.errors.full_messages.to_sentence
    end
  end

  test "only one public share can exist for a bean" do
    bean = beans(:open_household)
    PublicBeanShare.create!(
      workspace: bean.workspace,
      bean:,
      created_by: users(:one),
      updated_by: users(:one)
    )
    duplicate = PublicBeanShare.new(
      workspace: bean.workspace,
      bean:,
      created_by: users(:one),
      updated_by: users(:one)
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:bean_id], "has already been taken"
  end

  test "member can manage own bean share but not another member share" do
    users(:two).update!(active_workspace: workspaces(:household))
    share = PublicBeanShare.create!(
      workspace: workspaces(:household),
      bean: beans(:open_household),
      created_by: users(:one),
      updated_by: users(:one)
    )

    assert share.manageable_by?(users(:one))
    assert_not share.manageable_by?(users(:two))
  end

  test "workspace admin can manage any bean share" do
    memberships(:member).update!(role: "admin")
    users(:two).update!(active_workspace: workspaces(:household))
    share = PublicBeanShare.create!(
      workspace: workspaces(:household),
      bean: beans(:open_household),
      created_by: users(:one),
      updated_by: users(:one)
    )

    assert share.manageable_by?(users(:two))
  end

  test "viewer cannot manage bean shares" do
    memberships(:member).update!(role: "viewer")
    users(:two).update!(active_workspace: workspaces(:household))
    share = PublicBeanShare.create!(
      workspace: workspaces(:household),
      bean: beans(:open_household),
      created_by: users(:one),
      updated_by: users(:one)
    )

    assert_not share.manageable_by?(users(:two))
  end

  test "public attachment ids come only from curated media manifest" do
    bean = beans(:open_household)
    selected_photo = attach_photo(bean)
    rogue_photo = attach_photo(beans(:other_workspace_open))
    share = PublicBeanShare.create!(
      workspace: bean.workspace,
      bean:,
      created_by: users(:one),
      updated_by: users(:one),
      selected_photo_attachment_ids: [ selected_photo.id ],
      snapshot: {
        "public_media" => [ { "attachment_id" => selected_photo.id } ],
        "photos" => [
          { "attachment_id" => selected_photo.id },
          { "attachment_id" => rogue_photo.id }
        ]
      }
    )

    assert_equal [ selected_photo.id ], share.public_attachment_ids
  end

  test "public media handles are opaque and resolve only for public attachments" do
    bean = beans(:open_household)
    photo = attach_photo(bean)
    share = PublicBeanShare.create!(
      workspace: bean.workspace,
      bean:,
      created_by: users(:one),
      updated_by: users(:one),
      snapshot: {
        "public_media" => [ { "attachment_id" => photo.id } ]
      }
    )

    handle = share.public_media_handle_for(photo.id)

    assert handle.present?
    assert_not_equal photo.id.to_s, handle
    assert_equal photo.id, share.public_attachment_id_for_media_handle(handle)
    assert_nil share.public_media_handle_for(999_999)
    assert_nil share.public_attachment_id_for_media_handle(photo.id.to_s)
  end
end
```

Create `test/models/public_bean_share_view_test.rb`:

```ruby
require "test_helper"

class PublicBeanShareViewTest < ActiveSupport::TestCase
  test "recent scope returns newest views first" do
    share = PublicBeanShare.create!(
      workspace: workspaces(:household),
      bean: beans(:open_household),
      created_by: users(:one),
      updated_by: users(:one),
      enabled: true
    )
    older = share.public_bean_share_views.create!(
      workspace: share.workspace,
      ip_address: "198.51.100.10",
      viewed_at: 2.days.ago
    )
    newer = share.public_bean_share_views.create!(
      workspace: share.workspace,
      ip_address: "198.51.100.11",
      viewed_at: 1.hour.ago
    )

    assert_equal [ newer, older ], share.public_bean_share_views.recent.to_a
  end

  test "retains only latest 100 views for a share" do
    share = PublicBeanShare.create!(
      workspace: workspaces(:household),
      bean: beans(:open_household),
      created_by: users(:one),
      updated_by: users(:one),
      enabled: true
    )

    101.times do |index|
      share.public_bean_share_views.create!(
        workspace: share.workspace,
        ip_address: "198.51.100.#{index}",
        viewed_at: index.minutes.ago
      )
    end

    assert_equal 100, share.public_bean_share_views.count
  end
end
```

- [ ] **Step 2: Run model tests to verify failure**

Run:

```bash
bin/rails test test/models/public_bean_share_test.rb test/models/public_bean_share_view_test.rb
```

Expected: fail with missing constants and missing tables.

- [ ] **Step 3: Add migrations**

Create `db/migrate/20260613120000_create_public_bean_shares.rb`:

```ruby
class CreatePublicBeanShares < ActiveRecord::Migration[8.1]
  def change
    create_table :public_bean_shares do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :bean, null: false, foreign_key: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.references :updated_by, null: false, foreign_key: { to_table: :users }
      t.string :token, null: false
      t.string :token_digest, null: false
      t.boolean :enabled, null: false, default: false
      t.string :title
      t.string :password_digest
      t.integer :selected_photo_attachment_ids, null: false, default: [], array: true
      t.jsonb :snapshot, null: false, default: {}
      t.integer :views_count, null: false, default: 0

      t.timestamps
    end

    add_index :public_bean_shares, :bean_id, unique: true
    add_index :public_bean_shares, :token, unique: true
    add_index :public_bean_shares, :token_digest, unique: true
    add_index :public_bean_shares, [ :workspace_id, :enabled ]
  end
end
```

Create `db/migrate/20260613120100_create_public_bean_share_views.rb`:

```ruby
class CreatePublicBeanShareViews < ActiveRecord::Migration[8.1]
  def change
    create_table :public_bean_share_views do |t|
      t.references :public_bean_share, null: false, foreign_key: true
      t.references :workspace, null: false, foreign_key: true
      t.string :ip_address, null: false
      t.string :user_agent
      t.datetime :viewed_at, null: false

      t.timestamps
    end

    add_index :public_bean_share_views, [ :public_bean_share_id, :viewed_at, :id ], name: "idx_public_bean_share_views_recent"
  end
end
```

Run:

```bash
bin/rails db:migrate
```

Expected: migrations complete and schema includes `public_bean_shares` plus `public_bean_share_views`.

- [ ] **Step 4: Add model code and associations**

Create `app/models/public_bean_share.rb`:

```ruby
require "digest"
require "openssl"

class PublicBeanShare < ApplicationRecord
  PUBLISHABLE_STATUSES = %w[open finished used_up].freeze

  has_secure_password :password, validations: false

  belongs_to :workspace
  belongs_to :bean
  belongs_to :created_by, class_name: "User"
  belongs_to :updated_by, class_name: "User"

  has_many :public_bean_share_views, dependent: :delete_all

  before_validation :set_token, on: :create
  before_validation :set_token_digest
  before_validation :set_workspace_from_bean

  validates :token, presence: true, uniqueness: true
  validates :token_digest, presence: true, uniqueness: true
  validates :bean_id, uniqueness: true
  validates :password, length: { maximum: ActiveModel::SecurePassword::MAX_PASSWORD_LENGTH_ALLOWED }, allow_blank: true
  validate :bean_belongs_to_workspace
  validate :bean_must_be_publishable

  def self.default_title_for(bean)
    bean.display_name
  end

  def self.find_enabled_by_token!(token)
    joins(:bean)
      .where(token_digest: token_digest_for(token), enabled: true, beans: { archived_at: nil })
      .where.not(beans: { opened_on: nil })
      .first!
  end

  def self.token_digest_for(token)
    Digest::SHA256.hexdigest(token.to_s)
  end

  def password_protected?
    password_digest.present?
  end

  def password_unlock_fingerprint
    return unless password_protected?

    Digest::SHA256.hexdigest(password_digest)
  end

  def manageable_by?(user)
    membership = user&.membership_for(workspace)
    return false unless membership

    policy = WorkspacePolicy.new(membership)
    policy.manage? || (policy.write? && created_by_id == user.id)
  end

  def public_status
    bean.open? ? "open" : "finished"
  end

  def publishable?
    PUBLISHABLE_STATUSES.include?(bean&.bag_status)
  end

  def public_attachment_ids
    snapshot_payload = snapshot.is_a?(Hash) ? snapshot : {}
    collect_attachment_ids(snapshot_payload.fetch("public_media", [])).map(&:to_i).uniq
  end

  def public_media_handle_for(attachment_id)
    attachment_id = attachment_id.to_i
    return unless public_attachment_ids.include?(attachment_id)

    media_handle_for_attachment_id(attachment_id)
  end

  def public_attachment_id_for_media_handle(handle)
    handle = handle.to_s
    return if handle.blank?

    public_attachment_ids.find do |attachment_id|
      expected = media_handle_for_attachment_id(attachment_id)
      handle.bytesize == expected.bytesize && ActiveSupport::SecurityUtils.secure_compare(handle, expected)
    end
  end

  def refresh_snapshot!(title:, selected_photo_attachment_ids:, updated_by:)
    update!(
      title: title.presence || self.class.default_title_for(bean),
      selected_photo_attachment_ids: Array(selected_photo_attachment_ids).map(&:to_i).uniq,
      updated_by:,
      snapshot: PublicBeanShareSnapshotBuilder.new(
        bean:,
        title: title.presence || self.class.default_title_for(bean),
        selected_photo_attachment_ids:
      ).call
    )
  end

  def valid_selected_photo_attachment_ids
    selected_ids = Array(selected_photo_attachment_ids).map(&:to_i)
    bean.photos.attachments.map(&:id) & selected_ids
  end

  private
    def set_token
      self.token ||= SecureRandom.urlsafe_base64(24)
    end

    def set_token_digest
      self.token_digest = self.class.token_digest_for(token) if token.present?
    end

    def set_workspace_from_bean
      self.workspace ||= bean.workspace if bean
    end

    def bean_belongs_to_workspace
      return if bean.blank? || workspace.blank? || bean.workspace_id == workspace_id

      errors.add(:bean, "must belong to the workspace")
    end

    def bean_must_be_publishable
      return if bean.blank? || publishable?

      errors.add(:bean, "must be open, finished, or used up")
    end

    def collect_attachment_ids(value)
      case value
      when Hash
        value.flat_map do |key, nested|
          key.to_s.end_with?("attachment_id") && nested.present? ? [ nested.to_i ] : collect_attachment_ids(nested)
        end
      when Array
        value.flat_map { |nested| collect_attachment_ids(nested) }
      else
        []
      end
    end

    def media_handle_for_attachment_id(attachment_id)
      OpenSSL::HMAC.hexdigest("SHA256", public_media_handle_secret, "#{token}:#{attachment_id}").first(32)
    end

    def public_media_handle_secret
      Rails.application.key_generator.generate_key("public-bean-share-media-handle")
    end
end
```

Create `app/models/public_bean_share_view.rb`:

```ruby
class PublicBeanShareView < ApplicationRecord
  RETAINED_VIEW_LIMIT = 100

  belongs_to :public_bean_share, counter_cache: :views_count
  belongs_to :workspace

  scope :recent, -> { order(viewed_at: :desc, id: :desc) }

  validates :ip_address, presence: true, length: { maximum: 255 }
  validates :viewed_at, presence: true

  after_create_commit :trim_old_views

  private
    def trim_old_views
      stale_ids = public_bean_share
        .public_bean_share_views
        .recent
        .offset(RETAINED_VIEW_LIMIT)
        .pluck(:id)

      PublicBeanShareView.where(id: stale_ids).delete_all if stale_ids.any?
    end
end
```

Modify `app/models/bean.rb`:

```ruby
has_one :public_bean_share, dependent: :destroy
```

Place it near the other bean associations.

Modify `app/models/workspace.rb`:

```ruby
has_many :public_bean_shares, dependent: :destroy
```

Place it near `has_many :public_brew_shares`.

- [ ] **Step 5: Run migrations and model tests**

Run:

```bash
bin/rails db:migrate
bin/rails test test/models/public_bean_share_test.rb test/models/public_bean_share_view_test.rb
```

Expected: pass.

- [ ] **Step 6: Commit**

Run:

```bash
git add db/migrate/20260613120000_create_public_bean_shares.rb db/migrate/20260613120100_create_public_bean_share_views.rb db/schema.rb app/models/public_bean_share.rb app/models/public_bean_share_view.rb app/models/bean.rb app/models/workspace.rb test/models/public_bean_share_test.rb test/models/public_bean_share_view_test.rb
git commit -m "Add public bean share model"
```

---

### Task 2: Snapshot Builder, Stats, Timeline, And Refresher

**Files:**
- Create: `app/services/public_bean_share_snapshot_builder.rb`
- Create: `app/services/public_bean_share_refresher.rb`
- Test: `test/services/public_bean_share_snapshot_builder_test.rb`
- Test: `test/services/public_bean_share_refresher_test.rb`

- [ ] **Step 1: Write failing snapshot builder tests**

Create `test/services/public_bean_share_snapshot_builder_test.rb`:

```ruby
require "test_helper"

class PublicBeanShareSnapshotBuilderTest < ActiveSupport::TestCase
  include PhotoTestHelper

  test "builds a public-safe bean snapshot with all brew methods" do
    bean = beans(:open_household)
    bean.update!(
      public_note: "Public bean note.",
      notes: "Private bean note.",
      purchase_source: "Private cellar source.",
      purchase_price_cents: 1290,
      origin: "Colombia",
      process: "Washed",
      tasting_notes: "Berry and caramel"
    )
    bean.record_links.create!(
      workspace: bean.workspace,
      label: "Buy beans",
      url: "https://example.com/beans",
      kind: "affiliate",
      visibility: "public",
      position: 10
    )
    bean.record_links.create!(
      workspace: bean.workspace,
      label: "Private receipt",
      url: "https://example.com/private",
      kind: "info",
      visibility: "private",
      position: 20
    )
    espresso = brews(:morning_espresso)
    espresso.update!(
      bean:,
      notes: "Private espresso note",
      public_note: "Public espresso note",
      bean_weight_grams: 18,
      ground_weight_grams: 17.2,
      dose_grams: 17.2,
      beverage_grams: 42,
      total_time_seconds: 28,
      rating: 5,
      channeling: true,
      taste_balance: "neutral",
      grind_setting: "2.3"
    )
    quick_drip = bean.workspace.brews.create!(
      user: users(:two),
      method: "quick_drip",
      bean:,
      brewer: equipment(:household_brewer),
      machine_cups: 6,
      coffee_spoons: 6,
      grams_per_coffee_spoon: 5,
      bean_weight_grams: 30,
      beverage_grams: 720,
      total_time_seconds: 300,
      rating: 4,
      taste_balance: "neutral",
      notes: "Private batch note",
      public_note: "Public batch note"
    )
    bean_photo = attach_photo_with_filename(bean, "private-bag-name.jpg")
    brew_photo = attach_photo(espresso)
    avatar = attach_named_photo(users(:two), :avatar, filename: "avatar.jpg")
    logo = attach_named_photo(bean.workspace, :logo, filename: "house.jpg")

    snapshot = PublicBeanShareSnapshotBuilder.new(
      bean:,
      title: "Shared bean",
      selected_photo_attachment_ids: [ bean_photo.id, brew_photo.id ]
    ).call

    assert_equal "Shared bean", snapshot.fetch("title")
    assert_equal "Public bean note.", snapshot.dig("bean", "public_note")
    assert_equal "Colombia", snapshot.dig("bean", "origin")
    assert_equal "Washed", snapshot.dig("bean", "process")
    assert_equal "Berry and caramel", snapshot.dig("bean", "tasting_notes")
    assert_equal 2, snapshot.dig("stats", "brew_count")
    assert_equal "48.0", snapshot.dig("stats", "consumed_grams")
    assert_equal "0.8", snapshot.dig("stats", "dead_grams")
    assert_equal 50, snapshot.dig("stats", "channeling_percent")
    assert_equal({ "4" => 1, "5" => 1 }, snapshot.dig("distributions", "rating"))
    assert_equal({ "neutral" => 2 }, snapshot.dig("distributions", "taste_balance"))
    assert_equal({ "2.3" => 1 }, snapshot.dig("distributions", "grind_setting"))
    assert_equal 2, snapshot.fetch("brews").size
    assert_equal %w[quick_drip espresso], snapshot.fetch("brews").map { |brew| brew.fetch("method") }
    assert_includes snapshot.to_json, "Public espresso note"
    assert_includes snapshot.to_json, "Public batch note"
    assert_includes snapshot.to_json, "Buy beans"
    assert_includes snapshot.to_json, avatar.id.to_s
    assert_includes snapshot.to_json, logo.id.to_s
    assert_not_includes snapshot.to_json, "Private bean note"
    assert_not_includes snapshot.to_json, "Private cellar source"
    assert_not_includes snapshot.to_json, "Private receipt"
    assert_not_includes snapshot.to_json, "Private espresso note"
    assert_not_includes snapshot.to_json, "Private batch note"
    assert_not_includes snapshot.to_json, "one@example.com"
    assert_not_includes snapshot.to_json, "private-bag-name.jpg"
    assert_includes collect_attachment_ids(snapshot), bean_photo.id
    assert_not_includes collect_attachment_ids(snapshot), brew_photo.id
  end

  test "public status collapses used up to finished" do
    bean = beans(:open_household)
    bean.update!(remaining_grams: 0)

    snapshot = PublicBeanShareSnapshotBuilder.new(
      bean:,
      title: "",
      selected_photo_attachment_ids: []
    ).call

    assert_equal "finished", snapshot.dig("bean", "public_status")
  end

  private
    def attach_photo_with_filename(record, filename)
      File.open(Rails.root.join("test/fixtures/files/photo.jpg")) do |file|
        record.photos.attach(io: file, filename:, content_type: "image/jpeg")
      end
      record.photos.attachments.last
    end

    def collect_attachment_ids(value)
      case value
      when Hash
        value.flat_map do |key, nested|
          key.to_s.end_with?("attachment_id") && nested.present? ? [ nested.to_i ] : collect_attachment_ids(nested)
        end
      when Array
        value.flat_map { |nested| collect_attachment_ids(nested) }
      else
        []
      end
    end
end
```

Create `test/services/public_bean_share_refresher_test.rb`:

```ruby
require "test_helper"

class PublicBeanShareRefresherTest < ActiveSupport::TestCase
  include PhotoTestHelper

  test "refreshes shares for bean changes" do
    bean = beans(:open_household)
    share = create_share(bean)

    bean.update!(public_note: "Updated public note")
    PublicBeanShareRefresher.refresh_for(bean)

    assert_equal "Updated public note", share.reload.snapshot.dig("bean", "public_note")
  end

  test "refreshes shares for brew changes" do
    bean = beans(:open_household)
    brew = brews(:morning_espresso)
    brew.update!(bean:, public_note: "Old note")
    share = create_share(bean)

    brew.update!(public_note: "New brew note")
    PublicBeanShareRefresher.refresh_for(brew)

    assert_includes share.reload.snapshot.fetch("brews").map { |row| row["public_note"] }, "New brew note"
  end

  test "refresh removes selected photos that no longer belong to bean" do
    bean = beans(:open_household)
    photo = attach_photo(bean)
    share = create_share(bean, selected_photo_attachment_ids: [ photo.id ])

    photo.destroy
    PublicBeanShareRefresher.refresh(share)

    assert_equal [], share.reload.selected_photo_attachment_ids
    assert_equal [], share.snapshot.fetch("photos")
  end

  private
    def create_share(bean, selected_photo_attachment_ids: [])
      PublicBeanShare.create!(
        workspace: bean.workspace,
        bean:,
        created_by: users(:one),
        updated_by: users(:one),
        enabled: true,
        selected_photo_attachment_ids:,
        snapshot: PublicBeanShareSnapshotBuilder.new(
          bean:,
          title: "Shared bean",
          selected_photo_attachment_ids:
        ).call
      )
    end
end
```

- [ ] **Step 2: Run service tests to verify failure**

Run:

```bash
bin/rails test test/services/public_bean_share_snapshot_builder_test.rb test/services/public_bean_share_refresher_test.rb
```

Expected: fail with missing `PublicBeanShareSnapshotBuilder` and `PublicBeanShareRefresher`.

- [ ] **Step 3: Implement snapshot builder**

Create `app/services/public_bean_share_snapshot_builder.rb`:

```ruby
class PublicBeanShareSnapshotBuilder
  def initialize(bean:, title:, selected_photo_attachment_ids:)
    @bean = bean
    @title = title
    @selected_photo_attachment_ids = Array(selected_photo_attachment_ids).map(&:to_i).uniq
    @brews = bean.brews.includes(:user, :grinder, :machine, :brewer).order(occurred_at: :desc, created_at: :desc).to_a
  end

  def call
    payload = {
      "title" => title.presence || PublicBeanShare.default_title_for(bean),
      "workspace" => workspace_payload,
      "bean" => bean_payload,
      "stats" => stats_payload,
      "distributions" => distributions_payload,
      "timeline" => timeline_payload,
      "photos" => photo_payloads,
      "brews" => brew_payloads,
      "generated_at" => Time.current.iso8601
    }
    payload["public_media"] = public_media_payloads(payload)
    payload
  end

  private
    attr_reader :bean, :title, :selected_photo_attachment_ids, :brews

    def workspace_payload
      {
        "name" => bean.workspace.name,
        "logo_attachment_id" => attachment_id(bean.workspace.logo.attachment)
      }
    end

    def bean_payload
      {
        "name" => bean.name,
        "display_name" => bean.display_name,
        "roaster_name" => bean.roaster_name,
        "origin" => bean.origin,
        "process" => bean.process,
        "roast_date" => bean.roast_date&.iso8601,
        "opened_on" => bean.opened_on&.iso8601,
        "roast_type" => bean.roast_type,
        "roast_level" => bean.roast_level,
        "roast_degree" => decimal_string(bean.roast_degree),
        "tasting_notes" => bean.tasting_notes,
        "public_note" => bean.public_note,
        "public_status" => bean.open? ? "open" : "finished",
        "bag_size_grams" => decimal_string(bean.bag_size_grams),
        "remaining_grams" => decimal_string(bean.remaining_grams),
        "remaining_percent" => bean.remaining_percent,
        "decaffeinated" => bean.decaffeinated,
        "country" => bean.country,
        "region" => bean.region,
        "farm" => bean.farm,
        "farmer" => bean.farmer,
        "elevation" => bean.elevation,
        "variety" => bean.variety,
        "harvested" => bean.harvested,
        "blend_type" => bean.blend_type,
        "blend_percentage" => bean.blend_percentage,
        "links" => link_payloads(bean)
      }
    end

    def stats_payload
      {
        "brew_count" => brews.size,
        "consumed_grams" => decimal_string(consumed_grams),
        "dead_grams" => decimal_string(dead_grams),
        "average_rating" => decimal_string(average_rating),
        "channeling_count" => channeling_count,
        "channeling_brew_count" => espresso_brews.size,
        "channeling_percent" => percentage(channeling_count, espresso_brews.size),
        "open_duration_days" => open_duration_days
      }
    end

    def distributions_payload
      {
        "rating" => count_by_present_value(brews.filter_map(&:rating).map(&:to_s)),
        "taste_balance" => count_by_present_value(brews.filter_map(&:taste_balance)),
        "grind_setting" => count_by_present_value(brews.filter_map(&:grind_setting))
      }
    end

    def timeline_payload
      end_time = bean.finished_at || brews.first&.occurred_at || Time.current
      {
        "opened_on" => bean.opened_on&.iso8601,
        "finished_at" => bean.finished_at&.iso8601,
        "last_brew_at" => brews.first&.occurred_at&.iso8601,
        "end_at" => end_time&.iso8601,
        "brews" => brews.sort_by(&:occurred_at).map do |brew|
          {
            "occurred_at" => brew.occurred_at&.iso8601,
            "method" => brew.method,
            "rating" => brew.rating
          }
        end
      }
    end

    def brew_payloads
      brews.map do |brew|
        {
          "occurred_at" => brew.occurred_at&.iso8601,
          "method" => brew.method,
          "public_note" => brew.public_note,
          "bean_weight_grams" => decimal_string(brew.bean_weight_grams),
          "ground_weight_grams" => decimal_string(brew.ground_weight_grams),
          "dose_grams" => decimal_string(brew.dose_grams),
          "beverage_grams" => decimal_string(brew.beverage_grams),
          "grind_setting" => brew.grind_setting,
          "brew_temperature_celsius" => decimal_string(brew.brew_temperature_celsius),
          "total_time_seconds" => brew.total_time_seconds,
          "preinfusion_seconds" => brew.preinfusion_seconds,
          "first_drip_seconds" => brew.first_drip_seconds,
          "channeling" => brew.channeling,
          "taste_balance" => brew.taste_balance,
          "rating" => brew.rating,
          "machine_cups" => decimal_string(brew.machine_cups),
          "coffee_spoons" => decimal_string(brew.coffee_spoons),
          "grams_per_coffee_spoon" => decimal_string(brew.grams_per_coffee_spoon),
          "user" => user_payload(brew.user)
        }
      end
    end

    def user_payload(user)
      {
        "display_label" => user.display_label,
        "avatar_attachment_id" => attachment_id(user.avatar.attachment)
      }
    end

    def link_payloads(record)
      record.record_links.publicly_visible.map do |link|
        {
          "label" => link.label,
          "url" => link.url,
          "kind" => link.kind,
          "position" => link.position
        }
      end
    end

    def photo_payloads
      bean.photos.attachments.select { |attachment| selected_photo_attachment_ids.include?(attachment.id) }.map do |attachment|
        { "attachment_id" => attachment.id }
      end
    end

    def public_media_payloads(payload)
      collect_attachment_ids(payload).map { |id| { "attachment_id" => id } }.uniq
    end

    def collect_attachment_ids(value)
      case value
      when Hash
        value.flat_map do |key, nested|
          key.to_s.end_with?("attachment_id") && nested.present? ? [ nested.to_i ] : collect_attachment_ids(nested)
        end
      when Array
        value.flat_map { |nested| collect_attachment_ids(nested) }
      else
        []
      end
    end

    def espresso_brews
      @espresso_brews ||= brews.select(&:espresso?)
    end

    def consumed_grams
      brews.sum { |brew| brew.bean_weight_grams.to_d }.round(1)
    end

    def dead_grams
      espresso_brews.sum do |brew|
        next 0.to_d if brew.bean_weight_grams.blank? || brew.ground_weight_grams.blank?

        [ brew.bean_weight_grams.to_d - brew.ground_weight_grams.to_d, 0.to_d ].max
      end.round(1)
    end

    def average_rating
      ratings = brews.filter_map(&:rating)
      return if ratings.empty?

      (ratings.sum.to_d / ratings.size).round(1)
    end

    def channeling_count
      espresso_brews.count(&:channeling?)
    end

    def percentage(part, whole)
      return 0 if whole.blank? || whole.to_d.zero?

      ((part.to_d / whole.to_d) * 100).round
    end

    def open_duration_days
      return if bean.opened_on.blank?

      end_date = bean.finished_at&.to_date || brews.first&.occurred_at&.to_date || Date.current
      [ (end_date - bean.opened_on).to_i, 0 ].max
    end

    def count_by_present_value(values)
      values.compact_blank.tally.sort_by { |label, count| [ -count, label ] }.to_h
    end

    def attachment_id(attachment)
      attachment&.id
    end

    def decimal_string(value)
      value&.to_s
    end
end
```

- [ ] **Step 4: Implement refresher**

Create `app/services/public_bean_share_refresher.rb`:

```ruby
class PublicBeanShareRefresher
  class << self
    def refresh(share)
      new(share).refresh
    end

    def refresh_for(record)
      shares_for(record).find_each { |share| refresh(share) }
    end

    def shares_for(record)
      case record
      when PublicBeanShare
        PublicBeanShare.where(id: record.id)
      when Bean
        PublicBeanShare.where(bean_id: record.id)
      when Brew
        PublicBeanShare.where(bean_id: record.bean_id)
      when Workspace
        PublicBeanShare.where(workspace_id: record.id)
      when User
        PublicBeanShare.joins(bean: :brews).where(brews: { user_id: record.id }).distinct
      when RecordLink
        record.linkable ? shares_for(record.linkable) : PublicBeanShare.none
      else
        PublicBeanShare.none
      end
    end
  end

  def initialize(share)
    @share = share
  end

  def refresh
    share.reload
    selected_photo_attachment_ids = share.valid_selected_photo_attachment_ids
    title = share.title.presence || PublicBeanShare.default_title_for(share.bean)
    snapshot = PublicBeanShareSnapshotBuilder.new(
      bean: share.bean,
      title:,
      selected_photo_attachment_ids:
    ).call

    share.update!(
      title:,
      selected_photo_attachment_ids:,
      snapshot:
    )
  end

  private
    attr_reader :share
end
```

- [ ] **Step 5: Run snapshot/refresher tests**

Run:

```bash
bin/rails test test/services/public_bean_share_snapshot_builder_test.rb test/services/public_bean_share_refresher_test.rb
```

Expected: pass.

- [ ] **Step 6: Commit**

Run:

```bash
git add app/services/public_bean_share_snapshot_builder.rb app/services/public_bean_share_refresher.rb test/services/public_bean_share_snapshot_builder_test.rb test/services/public_bean_share_refresher_test.rb
git commit -m "Build public bean share snapshots"
```

---

### Task 3: Private Share Management

**Files:**
- Modify: `config/routes.rb`
- Create: `app/controllers/public_bean_shares_controller.rb`
- Create: `app/views/public_bean_shares/new.html.erb`
- Create: `app/views/public_bean_shares/edit.html.erb`
- Create: `app/views/public_bean_shares/_form.html.erb`
- Modify: `app/views/beans/show.html.erb`
- Modify: `config/locales/en.yml`
- Test: `test/controllers/public_bean_shares_controller_test.rb`
- Test: `test/controllers/beans_controller_test.rb`

- [ ] **Step 1: Write failing private controller tests**

Create `test/controllers/public_bean_shares_controller_test.rb`:

```ruby
require "test_helper"

class PublicBeanSharesControllerTest < ActionDispatch::IntegrationTest
  test "writer can open new share form for own publishable bean" do
    user = users(:two)
    user.update!(active_workspace: workspaces(:household))
    bean = beans(:open_household)
    photo = attach_photo(bean)
    sign_in_as(user)

    get new_bean_public_bean_share_path(bean)

    assert_response :success
    assert_select "h1", I18n.t("public_bean_shares.new.title")
    assert_select "input[type=checkbox][name=?]", "public_bean_share[enabled]"
    assert_select "input[name=?]", "public_bean_share[title]"
    assert_select "input[type=password][name=?]", "public_bean_share[password]"
    assert_select "input[type=checkbox][name=?][value=?]", "public_bean_share[selected_photo_attachment_ids][]", photo.id.to_s
  end

  test "writer creates disabled password protected share snapshot" do
    user = users(:two)
    user.update!(active_workspace: workspaces(:household))
    bean = beans(:open_household)
    bean.update!(public_note: "Public bean note.")
    photo = attach_photo(bean)
    sign_in_as(user)

    assert_difference -> { PublicBeanShare.count }, 1 do
      post bean_public_bean_share_path(bean), params: {
        public_bean_share: {
          enabled: "0",
          title: "Shared bag",
          password: "coffee",
          selected_photo_attachment_ids: [ photo.id ]
        }
      }
    end

    share = bean.reload.public_bean_share
    assert_redirected_to edit_bean_public_bean_share_path(bean)
    assert_equal "Shared bag", share.title
    assert_not share.enabled?
    assert share.password_protected?
    assert_equal [ photo.id ], share.selected_photo_attachment_ids
    assert_equal user, share.created_by
    assert_equal user, share.updated_by
    assert_equal "Public bean note.", share.snapshot.dig("bean", "public_note")
  end

  test "create filters selected photos to bean photos" do
    user = users(:two)
    user.update!(active_workspace: workspaces(:household))
    bean = beans(:open_household)
    selected_photo = attach_photo(bean)
    unrelated_photo = attach_photo(beans(:other_workspace_open))
    sign_in_as(user)

    post bean_public_bean_share_path(bean), params: {
      public_bean_share: {
        enabled: "0",
        title: "Filtered bag",
        selected_photo_attachment_ids: [ selected_photo.id, unrelated_photo.id ]
      }
    }

    share = bean.reload.public_bean_share
    assert_equal [ selected_photo.id ], share.selected_photo_attachment_ids
    assert_includes share.public_attachment_ids, selected_photo.id
    assert_not_includes share.public_attachment_ids, unrelated_photo.id
  end

  test "stock bean cannot be shared" do
    stock = workspaces(:household).beans.create!(
      name: "Unopened",
      roaster_name: "Shelf",
      bag_size_grams: 250,
      remaining_grams: 250
    )
    sign_in_as(users(:one))

    assert_no_difference -> { PublicBeanShare.count } do
      get new_bean_public_bean_share_path(stock)
    end

    assert_redirected_to bean_path(stock)
    assert_equal I18n.t("public_bean_shares.unsupported_status"), flash[:alert]
  end

  test "viewer cannot manage public bean shares" do
    memberships(:member).update!(role: "viewer")
    user = users(:two)
    user.update!(active_workspace: workspaces(:household))
    sign_in_as(user)

    get new_bean_public_bean_share_path(beans(:open_household))

    assert_redirected_to root_path
  end

  test "owner can manage another users bean share" do
    writer = users(:two)
    writer.update!(active_workspace: workspaces(:household))
    bean = beans(:open_household)
    share = create_share_for(bean, user: writer)
    sign_in_as(users(:one))

    get edit_bean_public_bean_share_path(bean)

    assert_response :success
    assert_select "h1", I18n.t("public_bean_shares.edit.title")
    assert_select "input[name=?][value=?]", "public_bean_share[title]", share.title
  end

  test "writer cannot manage another writers bean share" do
    user = users(:two)
    user.update!(active_workspace: workspaces(:household))
    create_share_for(beans(:open_household), user: users(:one))
    sign_in_as(user)

    get edit_bean_public_bean_share_path(beans(:open_household))

    assert_redirected_to root_path
  end

  test "update can enable share and clear password" do
    user = users(:two)
    user.update!(active_workspace: workspaces(:household))
    bean = beans(:open_household)
    share = create_share_for(bean, user:, enabled: false, password: "coffee")
    sign_in_as(user)

    patch bean_public_bean_share_path(bean), params: {
      public_bean_share: {
        enabled: "1",
        title: "Enabled bag",
        password: "",
        clear_password: "1",
        selected_photo_attachment_ids: []
      }
    }

    assert_redirected_to edit_bean_public_bean_share_path(bean)
    share.reload
    assert share.enabled?
    assert_equal "Enabled bag", share.title
    assert_not share.password_protected?
    assert_equal user, share.updated_by
  end

  test "writer can destroy own public bean share" do
    user = users(:two)
    user.update!(active_workspace: workspaces(:household))
    bean = beans(:open_household)
    create_share_for(bean, user:)
    sign_in_as(user)

    assert_difference -> { PublicBeanShare.count }, -1 do
      delete bean_public_bean_share_path(bean)
    end

    assert_redirected_to bean_path(bean)
  end

  private
    def create_share_for(bean, user:, enabled: true, password: nil, title: "Shared bean")
      bean.create_public_bean_share!(
        workspace: bean.workspace,
        created_by: user,
        updated_by: user,
        enabled:,
        title:,
        password:,
        selected_photo_attachment_ids: [],
        snapshot: PublicBeanShareSnapshotBuilder.new(
          bean:,
          title:,
          selected_photo_attachment_ids: []
        ).call
      )
    end
end
```

- [ ] **Step 2: Run private controller tests to verify failure**

Run:

```bash
bin/rails test test/controllers/public_bean_shares_controller_test.rb
```

Expected: fail with missing route/controller.

- [ ] **Step 3: Add routes and controller**

Modify `config/routes.rb` inside `resources :beans`:

```ruby
resource :public_bean_share, only: %i[new create edit update destroy]
```

Create `app/controllers/public_bean_shares_controller.rb`:

```ruby
class PublicBeanSharesController < ApplicationController
  before_action :set_bean
  before_action :ensure_publishable_bean!, only: %i[new create edit update]
  before_action :set_or_build_share
  before_action :authorize_share_management!

  def new
    load_form_state(default_selected_photo_attachment_ids)
  end

  def create
    save_share!

    redirect_to edit_bean_public_bean_share_path(@bean), notice: t(".created")
  rescue ActiveRecord::RecordInvalid
    load_form_state(permitted_selected_photo_attachment_ids)
    render :new, status: :unprocessable_entity
  end

  def edit
    load_form_state(@share.selected_photo_attachment_ids)
  end

  def update
    save_share!

    redirect_to edit_bean_public_bean_share_path(@bean), notice: t(".updated")
  rescue ActiveRecord::RecordInvalid
    load_form_state(permitted_selected_photo_attachment_ids)
    render :edit, status: :unprocessable_entity
  end

  def destroy
    redirect_target = params[:return_to] == "workspace" ? edit_workspace_path(anchor: "public-shares") : @bean
    @share.destroy!

    redirect_to redirect_target, notice: t(".destroyed")
  end

  private
    def set_bean
      @bean = current_workspace.beans.includes(:primary_photo_record, photos_attachments: :blob).find(params[:bean_id])
    end

    def ensure_publishable_bean!
      return if PublicBeanShare::PUBLISHABLE_STATUSES.include?(@bean.bag_status)

      redirect_to @bean, alert: t("public_bean_shares.unsupported_status")
    end

    def set_or_build_share
      @share = @bean.public_bean_share || @bean.build_public_bean_share(
        workspace: current_workspace,
        created_by: Current.user,
        updated_by: Current.user,
        title: PublicBeanShare.default_title_for(@bean)
      )
    end

    def authorize_share_management!
      return if @share.manageable_by?(Current.user)

      redirect_to root_path, alert: t("authorization.denied")
    end

    def save_share!
      PublicBeanShare.transaction do
        @share.assign_attributes(
          title: share_params[:title],
          enabled: share_params[:enabled] == "1"
        )
        @share.created_by ||= Current.user
        @share.updated_by = Current.user
        apply_password_changes
        @share.refresh_snapshot!(
          title: share_params[:title],
          selected_photo_attachment_ids: permitted_selected_photo_attachment_ids,
          updated_by: Current.user
        )
      end
    end

    def apply_password_changes
      if share_params[:clear_password] == "1"
        @share.password_digest = nil
      elsif share_params[:password].present?
        @share.password = share_params[:password]
      end
    end

    def load_form_state(selected_photo_attachment_ids)
      @available_photos = @bean.photos.attachments
      @selected_photo_attachment_ids = Array(selected_photo_attachment_ids).map(&:to_i)
    end

    def default_selected_photo_attachment_ids
      [ @bean.primary_photo_attachment&.id ].compact
    end

    def selected_photo_attachment_ids_from_params
      Array(share_params[:selected_photo_attachment_ids]).map(&:to_i)
    end

    def permitted_selected_photo_attachment_ids
      selected_photo_attachment_ids_from_params & @bean.photos.attachments.map(&:id)
    end

    def share_params
      params.fetch(:public_bean_share, {}).permit(
        :title,
        :enabled,
        :password,
        :clear_password,
        selected_photo_attachment_ids: []
      )
    end
end
```

- [ ] **Step 4: Add private share views and locales**

Create `app/views/public_bean_shares/new.html.erb`:

```erb
<main class="min-h-screen bg-stone-50">
  <section class="mx-auto max-w-3xl px-6 py-10">
    <%= render "shared/back_link", label: t(".back"), path: @bean %>
    <div class="mt-6 rounded-lg border border-stone-200 bg-white p-6 shadow-sm">
      <h1 class="text-3xl font-bold text-stone-950"><%= t(".title") %></h1>
      <%= render "form", bean: @bean, share: @share %>
    </div>
  </section>
</main>
```

Create `app/views/public_bean_shares/edit.html.erb`:

```erb
<main class="min-h-screen bg-stone-50">
  <section class="mx-auto max-w-3xl px-6 py-10">
    <%= render "shared/back_link", label: t(".back"), path: @bean %>
    <div class="mt-6 rounded-lg border border-stone-200 bg-white p-6 shadow-sm">
      <h1 class="text-3xl font-bold text-stone-950"><%= t(".title") %></h1>

      <% if @share.persisted? %>
        <div data-testid="public-bean-share-url" class="mt-4 rounded-md border border-stone-200 bg-stone-50 p-3">
          <p class="text-xs font-bold uppercase text-stone-500"><%= t(".public_url") %></p>
          <%= link_to public_bean_page_url(@share.token), public_bean_page_path(@share.token), target: "_blank", rel: "noopener", class: "mt-1 block overflow-hidden text-ellipsis whitespace-nowrap text-sm font-bold text-stone-950 underline decoration-stone-300 underline-offset-4 hover:decoration-stone-950" %>
        </div>
      <% end %>

      <%= render "form", bean: @bean, share: @share %>

      <% if @share.persisted? %>
        <%= button_to t(".remove"),
          bean_public_bean_share_path(@bean),
          method: :delete,
          data: { testid: "public-bean-share-destroy-form" },
          form: { data: { turbo_confirm: t(".remove_confirmation") } },
          class: "mt-6 rounded-md border border-red-200 px-4 py-2 text-sm font-semibold text-red-700 hover:bg-red-50" %>
      <% end %>
    </div>
  </section>
</main>
```

Create `app/views/public_bean_shares/_form.html.erb`:

```erb
<%= form_with model: share, url: bean_public_bean_share_path(bean), method: share.persisted? ? :patch : :post, class: "mt-6 space-y-5" do |form| %>
  <% if share.errors.any? %>
    <div class="rounded-md border border-red-200 bg-red-50 p-4 text-sm text-red-800">
      <%= share.errors.full_messages.to_sentence %>
    </div>
  <% end %>

  <fieldset class="space-y-4 border-t border-stone-200 pt-5">
    <legend class="text-base font-bold text-stone-950"><%= t(".settings") %></legend>

    <label class="flex items-center gap-2 text-sm font-semibold text-stone-800">
      <%= form.check_box :enabled, class: "h-4 w-4 rounded border-stone-300" %>
      <%= t(".enabled") %>
    </label>

    <div>
      <%= form.label :title, t(".title"), class: "block text-sm font-medium text-stone-700" %>
      <%= form.text_field :title, class: "mt-1 w-full rounded-md border border-stone-300 px-3 py-2 text-stone-950 shadow-sm focus:border-stone-900 focus:outline-none" %>
    </div>

    <div>
      <%= form.label :password, t(".password"), class: "block text-sm font-medium text-stone-700" %>
      <%= form.password_field :password, value: "", autocomplete: "new-password", class: "mt-1 w-full rounded-md border border-stone-300 px-3 py-2 text-stone-950 shadow-sm focus:border-stone-900 focus:outline-none" %>
      <p class="mt-1 text-xs font-semibold text-stone-500"><%= t(".password_help") %></p>
    </div>

    <% if share.password_protected? %>
      <label class="flex items-center gap-2 text-sm font-semibold text-stone-800">
        <%= form.check_box :clear_password, class: "h-4 w-4 rounded border-stone-300" %>
        <%= t(".clear_password") %>
      </label>
    <% end %>
  </fieldset>

  <fieldset class="space-y-4 border-t border-stone-200 pt-5">
    <legend class="text-base font-bold text-stone-950"><%= t(".photos") %></legend>

    <% if @available_photos.any? %>
      <div class="grid gap-3 sm:grid-cols-2">
        <% @available_photos.each do |photo| %>
          <label class="flex gap-3 rounded-md border border-stone-200 p-3">
            <%= check_box_tag "public_bean_share[selected_photo_attachment_ids][]", photo.id, @selected_photo_attachment_ids.include?(photo.id), class: "mt-2 h-4 w-4 rounded border-stone-300" %>
            <%= image_tag media_attachment_path(photo, variant: :thumbnail), alt: "", class: "h-24 w-24 rounded-md object-contain ring-1 ring-stone-200" %>
            <span class="text-sm font-semibold text-stone-800"><%= t(".include_photo") %></span>
          </label>
        <% end %>
      </div>
    <% else %>
      <p class="text-sm font-semibold text-stone-600"><%= t(".no_photos") %></p>
    <% end %>
  </fieldset>

  <%= form.submit share.persisted? ? t("public_bean_shares.edit.update") : t("public_bean_shares.new.create"), class: "rounded-md bg-stone-950 px-5 py-3 text-sm font-semibold text-white shadow-sm hover:bg-stone-800" %>
<% end %>
```

Add locale keys under `en:`:

```yaml
  public_bean_shares:
    unsupported_status: "Public sharing is only available for opened, finished, or used up bags."
    create:
      created: "Public bean share saved."
    destroy:
      destroyed: "Public bean share removed."
    edit:
      back: "Back to bean"
      public_url: "Public URL"
      remove: "Remove public bean share"
      remove_confirmation: "Remove this public bean share? The URL will stop working."
      title: "Edit public bean share"
      update: "Save public bean share"
    form:
      clear_password: "Remove password"
      enabled: "Enable public bean page"
      include_photo: "Include"
      no_photos: "No bean photos yet."
      password: "Password"
      password_help: "Leave blank to keep the current password. Public visitors need this password before seeing the bean page."
      photos: "Public bean photos"
      settings: "Share settings"
      title: "Share title"
    new:
      back: "Back to bean"
      create: "Create public bean share"
      title: "Create public bean share"
    update:
      updated: "Public bean share saved."
```

- [ ] **Step 5: Add bean detail action**

Modify `app/views/beans/show.html.erb` inside the writer action button group:

```erb
<% if PublicBeanShare::PUBLISHABLE_STATUSES.include?(@bean.bag_status) %>
  <% if @bean.public_bean_share.present? %>
    <%= link_to t(".edit_public_share"), edit_bean_public_bean_share_path(@bean), class: "rounded-md border border-stone-300 px-4 py-2 text-sm font-semibold text-stone-900 hover:bg-stone-100" %>
  <% else %>
    <%= link_to t(".share_publicly"), new_bean_public_bean_share_path(@bean), class: "rounded-md border border-stone-300 px-4 py-2 text-sm font-semibold text-stone-900 hover:bg-stone-100" %>
  <% end %>
<% end %>
```

Add under `beans.show` in `config/locales/en.yml`:

```yaml
      edit_public_share: "Edit public share"
      share_publicly: "Share bean"
```

- [ ] **Step 6: Run private management tests**

Run:

```bash
bin/rails test test/controllers/public_bean_shares_controller_test.rb test/controllers/beans_controller_test.rb
```

Expected: pass.

- [ ] **Step 7: Commit**

Run:

```bash
git add config/routes.rb app/controllers/public_bean_shares_controller.rb app/views/public_bean_shares app/views/beans/show.html.erb config/locales/en.yml test/controllers/public_bean_shares_controller_test.rb test/controllers/beans_controller_test.rb
git commit -m "Add public bean share management"
```

---

### Task 4: Public Page, Password Gate, Media, And View Tracking

**Files:**
- Modify: `config/routes.rb`
- Create: `app/services/public_bean_share_view_recorder.rb`
- Create: `app/controllers/public_bean_pages_controller.rb`
- Create: `app/controllers/public_bean_media_controller.rb`
- Create: `app/helpers/public_bean_shares_helper.rb`
- Create: `app/views/public_bean_pages/show.html.erb`
- Create: `app/views/public_bean_pages/password.html.erb`
- Create: `app/views/public_bean_pages/_timeline.html.erb`
- Create: `app/views/public_bean_pages/_stat_bar_list.html.erb`
- Create: `app/views/public_bean_pages/_brew_card.html.erb`
- Modify: `config/locales/en.yml`
- Test: `test/services/public_bean_share_view_recorder_test.rb`
- Test: `test/controllers/public_bean_pages_controller_test.rb`
- Test: `test/controllers/public_bean_media_controller_test.rb`

- [ ] **Step 1: Write failing public page and media tests**

Create `test/controllers/public_bean_pages_controller_test.rb`:

```ruby
require "test_helper"

class PublicBeanPagesControllerTest < ActionDispatch::IntegrationTest
  include PhotoTestHelper

  test "disabled share returns not found" do
    share = create_share(enabled: false)

    get public_bean_page_path(share.token)

    assert_response :not_found
  end

  test "enabled share renders public snapshot without private content" do
    share = create_share(enabled: true)
    share.workspace.update!(buy_me_a_coffee_url: "https://buymeacoffee.com/roastnode")

    get public_bean_page_path(share.token)

    assert_response :success
    assert_select "[data-testid=public-bean-page]"
    assert_select "[data-testid=public-bean-timeline]"
    assert_select "[data-testid=public-bean-brew-card]", minimum: 1
    assert_select "body", text: /Public bean note/
    assert_select "body", text: /Private bean note/, count: 0
    assert_select "body", text: /Private brew note/, count: 0
    assert_select "body", text: /one@example.com/, count: 0
    assert_select "a[data-testid=site-footer-buy-me-a-coffee][href=?]", "https://buymeacoffee.com/roastnode"
    assert_no_match "/rails/active_storage", response.body
    assert_no_match "/media_attachments", response.body
  end

  test "renders espresso and quick drip brews" do
    bean = beans(:open_household)
    bean.workspace.brews.create!(
      user: users(:two),
      method: "quick_drip",
      bean:,
      brewer: equipment(:household_brewer),
      machine_cups: 6,
      bean_weight_grams: 30,
      taste_balance: "neutral",
      public_note: "Public batch"
    )
    share = create_share(bean:, enabled: true)

    get public_bean_page_path(share.token)

    assert_response :success
    assert_select "[data-testid=public-bean-brew-card][data-method=espresso]"
    assert_select "[data-testid=public-bean-brew-card][data-method=quick_drip]"
    assert_select "body", text: /Quick Drip/
  end

  test "successful public page render records view" do
    share = create_share(enabled: true)

    assert_difference -> { PublicBeanShareView.count }, 1 do
      get public_bean_page_path(share.token), headers: {
        "REMOTE_ADDR" => "198.51.100.40",
        "HTTP_USER_AGENT" => "Roastnode test browser"
      }
    end

    assert_response :success
    view = share.public_bean_share_views.last
    assert_equal "198.51.100.40", view.ip_address
    assert_equal "Roastnode test browser", view.user_agent
    assert_equal 1, share.reload.views_count
  end

  test "password gate does not count until unlocked page is rendered" do
    share = create_share(enabled: true, password: "coffee")

    assert_no_difference -> { PublicBeanShareView.count } do
      get public_bean_page_path(share.token), headers: { "REMOTE_ADDR" => "198.51.100.41" }
    end

    post unlock_public_bean_page_path(share.token), params: { password: "coffee" }
    assert_redirected_to public_bean_page_path(share.token)

    assert_difference -> { PublicBeanShareView.count }, 1 do
      get public_bean_page_path(share.token), headers: { "REMOTE_ADDR" => "198.51.100.41" }
    end
  end

  private
    def create_share(bean: beans(:open_household), enabled:, password: nil)
      bean.update!(public_note: "Public bean note.", notes: "Private bean note.")
      brews(:morning_espresso).update!(bean:, public_note: "Public brew note", notes: "Private brew note")
      PublicBeanShare.create!(
        workspace: bean.workspace,
        bean:,
        created_by: users(:one),
        updated_by: users(:one),
        enabled:,
        password:,
        title: "Shared bean",
        selected_photo_attachment_ids: [],
        snapshot: PublicBeanShareSnapshotBuilder.new(
          bean:,
          title: "Shared bean",
          selected_photo_attachment_ids: []
        ).call
      )
    end
end
```

Create `test/controllers/public_bean_media_controller_test.rb`:

```ruby
require "test_helper"

class PublicBeanMediaControllerTest < ActionDispatch::IntegrationTest
  include PhotoTestHelper

  test "streams selected public bean media through opaque handle" do
    bean = beans(:open_household)
    photo = attach_photo(bean)
    share = create_share(bean:, selected_photo_attachment_ids: [ photo.id ])
    handle = share.public_media_handle_for(photo.id)

    get public_bean_media_path(share.token, handle)

    assert_response :success
    assert_equal "image/jpeg", response.media_type
  end

  test "rejects unselected and private media" do
    bean = beans(:open_household)
    selected = attach_photo(bean)
    unselected = attach_photo(bean)
    share = create_share(bean:, selected_photo_attachment_ids: [ selected.id ])

    assert_nil share.public_media_handle_for(unselected.id)
    get public_bean_media_path(share.token, unselected.id)

    assert_response :not_found
  end

  test "password protected media returns not found until unlocked" do
    bean = beans(:open_household)
    photo = attach_photo(bean)
    share = create_share(bean:, selected_photo_attachment_ids: [ photo.id ], password: "coffee")
    handle = share.public_media_handle_for(photo.id)

    get public_bean_media_path(share.token, handle)
    assert_response :not_found

    post unlock_public_bean_page_path(share.token), params: { password: "coffee" }
    get public_bean_media_path(share.token, handle)
    assert_response :success
  end

  private
    def create_share(bean:, selected_photo_attachment_ids:, password: nil)
      PublicBeanShare.create!(
        workspace: bean.workspace,
        bean:,
        created_by: users(:one),
        updated_by: users(:one),
        enabled: true,
        password:,
        selected_photo_attachment_ids:,
        snapshot: PublicBeanShareSnapshotBuilder.new(
          bean:,
          title: "Shared bean",
          selected_photo_attachment_ids:
        ).call
      )
    end
end
```

- [ ] **Step 2: Add public routes**

Modify `config/routes.rb` near existing public share routes:

```ruby
get "b/:token" => "public_bean_pages#show", as: :public_bean_page
post "b/:token/password" => "public_bean_pages#unlock", as: :unlock_public_bean_page
get "b/:token/media/:media_id" => "public_bean_media#show", as: :public_bean_media
```

- [ ] **Step 3: Implement public page controller and view recorder**

Create `app/services/public_bean_share_view_recorder.rb`:

```ruby
class PublicBeanShareViewRecorder
  def initialize(share:, request:)
    @share = share
    @request = request
  end

  def call
    PublicBeanShareView.create!(
      public_bean_share: share,
      workspace: share.workspace,
      ip_address: request.remote_ip.to_s.first(255),
      user_agent: request.user_agent.to_s.first(255).presence,
      viewed_at: Time.current
    )
  rescue => error
    Rails.logger.info(
      "PublicBeanShareViewRecorder failed " \
      "share=#{Digest::SHA256.hexdigest(share.id.to_s).first(12)} " \
      "error=#{error.class}"
    )
  end

  private
    attr_reader :share, :request
end
```

Create `app/controllers/public_bean_pages_controller.rb`:

```ruby
class PublicBeanPagesController < ApplicationController
  allow_unauthenticated_access

  before_action :set_share
  rate_limit to: 10,
    within: 3.minutes,
    only: :unlock,
    by: -> { "#{request.remote_ip}:#{PublicBeanShare.token_digest_for(params[:token])}" },
    with: -> {
      flash.now[:alert] = t(".rate_limited")
      render :password, status: :too_many_requests
    }

  def show
    return render :password if password_required?

    load_snapshot
    record_page_view
  end

  def unlock
    if @share.authenticate_password(params[:password])
      session[unlock_session_key] = @share.password_unlock_fingerprint
      redirect_to public_bean_page_path(@share.token)
    else
      flash.now[:alert] = t(".failed")
      render :password, status: :unprocessable_entity
    end
  end

  private
    def set_share
      @share = PublicBeanShare.find_enabled_by_token!(params[:token])
      @site_footer_buy_me_a_coffee = @share.workspace.site_footer_buy_me_a_coffee
      @site_footer_show_version = false
    rescue ActiveRecord::RecordNotFound
      head :not_found
    end

    def load_snapshot
      @snapshot = @share.snapshot
    end

    def record_page_view
      PublicBeanShareViewRecorder.new(share: @share, request:).call
    end

    def password_required?
      @share.password_protected? && !share_unlocked?
    end

    def share_unlocked?
      session[unlock_session_key] == @share.password_unlock_fingerprint
    end

    def unlock_session_key
      "public_bean_share:#{@share.token}:unlocked"
    end
end
```

- [ ] **Step 4: Implement media controller**

Create `app/controllers/public_bean_media_controller.rb`:

```ruby
class PublicBeanMediaController < ApplicationController
  THUMBNAIL_VARIANT = MediaAttachmentsController::THUMBNAIL_VARIANT
  THUMBNAIL_TRANSFORMATIONS = MediaAttachmentsController::THUMBNAIL_TRANSFORMATIONS

  allow_unauthenticated_access

  before_action :set_share
  before_action :ensure_share_unlocked!
  before_action :set_attachment
  before_action :ensure_attachment_public!

  def show
    return send_thumbnail if params[:variant] == THUMBNAIL_VARIANT
    return head :not_found if params[:variant].present?

    send_blob(disposition: "inline")
  end

  private
    def set_share
      @share = PublicBeanShare.find_enabled_by_token!(params[:token])
    rescue ActiveRecord::RecordNotFound
      head :not_found
    end

    def ensure_share_unlocked!
      return unless @share&.password_protected?
      return if session[unlock_session_key] == @share.password_unlock_fingerprint

      head :not_found
    end

    def set_attachment
      attachment_id = @share.public_attachment_id_for_media_handle(params[:media_id])
      return head :not_found if attachment_id.blank?

      @attachment = ActiveStorage::Attachment.find(attachment_id)
    rescue ActiveRecord::RecordNotFound
      head :not_found
    end

    def ensure_attachment_public!
      head :not_found unless @attachment
    end

    def send_blob(disposition:, data: @attachment.blob.download)
      send_data data,
        type: @attachment.blob.content_type,
        disposition:,
        filename: public_filename
    end

    def send_thumbnail
      return head :not_found unless @attachment.blob.image?

      response.set_header("X-Roastnode-Media-Variant", THUMBNAIL_VARIANT)
      send_blob(
        disposition: "inline",
        data: thumbnail_data
      )
    end

    def thumbnail_data
      @attachment.blob.variant(THUMBNAIL_TRANSFORMATIONS).processed.download
    rescue LoadError => error
      log_thumbnail_fallback(error)
      @attachment.blob.download
    rescue => error
      log_thumbnail_fallback(error)
      @attachment.blob.download
    end

    def log_thumbnail_fallback(error)
      Rails.logger.info("Falling back to public bean thumbnail original #{public_attachment_log_id}: #{error.class}")
    end

    def public_attachment_log_id
      share_digest = Digest::SHA256.hexdigest(@share.id.to_s).first(12)
      attachment_digest = Digest::SHA256.hexdigest(@attachment.id.to_s).first(12)
      "PublicBeanShare##{share_digest}/attachment/#{attachment_digest}"
    end

    def public_filename
      params[:variant] == THUMBNAIL_VARIANT ? "public-bean-thumbnail" : "public-bean-media"
    end

    def unlock_session_key
      "public_bean_share:#{@share.token}:unlocked"
    end
end
```

- [ ] **Step 5: Add public helper and views**

Create `app/helpers/public_bean_shares_helper.rb`:

```ruby
module PublicBeanSharesHelper
  def public_bean_media_url_for(share, attachment_id, variant: nil)
    handle = share.public_media_handle_for(attachment_id)
    return if handle.blank?

    public_bean_media_path(share.token, handle, variant:)
  end

  def public_bean_grams(value)
    value.present? ? "#{value.to_d.to_fs(:delimited)}g" : t("public_bean_pages.show.unknown")
  end

  def public_bean_seconds(value)
    value.present? ? "#{value}s" : t("public_bean_pages.show.unknown")
  end

  def public_bean_percent(value)
    value.present? ? "#{value}%" : t("public_bean_pages.show.unknown")
  end

  def public_bean_rating(value)
    value.present? ? "#{value}/5" : t("public_bean_pages.show.unknown")
  end

  def public_bean_timeline_position(opened_on, end_at, occurred_at)
    return 0 if opened_on.blank? || end_at.blank? || occurred_at.blank?

    start_time = Time.zone.parse(opened_on.to_s)
    end_time = Time.zone.parse(end_at.to_s)
    event_time = Time.zone.parse(occurred_at.to_s)
    duration = end_time - start_time
    return 0 if duration <= 0

    percent = ((event_time - start_time) / duration * 100).round
    [ [ percent, 0 ].max, 100 ].min
  end

  def public_bean_link_label(link)
    link["label"].presence || t("public_bean_pages.show.#{link["kind"].presence || "info"}")
  end
end
```

Create public page views using the selected Balanced Bean Story layout. Keep the page in `max-w-6xl`, use full-width sections, and use cards only for metric blocks and brew entries. Use these test IDs: `public-bean-page`, `public-bean-timeline`, `public-bean-brew-card`, `public-bean-stat-consumed`, `public-bean-stat-dead`, `public-bean-grind-distribution`, `public-bean-rating-distribution`, `public-bean-taste-distribution`.

The public page view must use `public_bean_media_url_for` for all images and must not call `media_attachment_path`, `rails_blob_path`, or `rails_storage_proxy_path`.

- [ ] **Step 6: Add public page locale keys**

Add under `en:`:

```yaml
  public_bean_pages:
    password:
      intro: "Enter the password to view this shared bean."
      password: "Password"
      submit: "View bean"
      title: "Protected bean"
    show:
      average_rating: "Average rating"
      bean: "Bean"
      brews: "Brews"
      channeling: "Channeling"
      close_photo: "Close"
      consumed: "Consumed"
      dead_grams: "Dead grams"
      details: "Details"
      finished: "Finished"
      grind: "Grind"
      grinder_settings: "Grinder settings"
      info: "Info"
      next_photo: "Next photo"
      open: "Open"
      opened: "Opened"
      open_photo: "Open photo"
      previous_photo: "Previous photo"
      quick_drip: "Quick Drip"
      rating: "Rating"
      ratings: "Ratings"
      remaining: "Remaining"
      status: "Status"
      taste_balance: "Taste balance"
      timeline: "Timeline"
      unknown: "Unknown"
    unlock:
      failed: "Password is not correct."
      rate_limited: "Try again later."
```

- [ ] **Step 7: Run public page and media tests**

Run:

```bash
bin/rails test test/controllers/public_bean_pages_controller_test.rb test/controllers/public_bean_media_controller_test.rb
```

Expected: pass.

- [ ] **Step 8: Commit**

Run:

```bash
git add config/routes.rb app/services/public_bean_share_view_recorder.rb app/controllers/public_bean_pages_controller.rb app/controllers/public_bean_media_controller.rb app/helpers/public_bean_shares_helper.rb app/views/public_bean_pages config/locales/en.yml test/controllers/public_bean_pages_controller_test.rb test/controllers/public_bean_media_controller_test.rb test/services/public_bean_share_view_recorder_test.rb
git commit -m "Render public bean share pages"
```

---

### Task 5: Refresh Hooks And Workspace Settings

**Files:**
- Modify: `app/controllers/beans_controller.rb`
- Modify: `app/controllers/brews_controller.rb`
- Modify: `app/controllers/media_attachments_controller.rb`
- Modify: `app/controllers/workspaces_controller.rb`
- Modify: `app/controllers/profiles_controller.rb`
- Modify: `app/views/workspaces/edit.html.erb`
- Create: `app/views/workspaces/_public_bean_shares.html.erb`
- Modify: `config/locales/en.yml`
- Test: `test/services/public_bean_share_refresher_test.rb`
- Test: `test/controllers/brews_controller_test.rb`
- Test: `test/controllers/workspaces_controller_test.rb`
- Test: `test/controllers/media_attachments_controller_test.rb`
- Test: `test/controllers/profiles_controller_test.rb`

- [ ] **Step 1: Add failing refresh and settings tests**

Extend `test/services/public_bean_share_refresher_test.rb`:

```ruby
test "shares_for user finds bean shares containing that users brews" do
  bean = beans(:open_household)
  brew = brews(:morning_espresso)
  brew.update!(bean:, user: users(:two))
  share = create_share(bean)

  assert_includes PublicBeanShareRefresher.shares_for(users(:two)), share
end
```

Extend controller tests with assertions that:

- creating a brew for a shared bean adds that brew to the share snapshot
- updating a brew public note refreshes the share snapshot
- deleting a brew removes it from the share snapshot
- workspace settings renders a `workspace-public-bean-shares` section with open/edit/remove actions
- workspace logo/name updates refresh public bean snapshots
- profile display label/avatar updates refresh public bean snapshots
- removing a selected bean photo removes it from the share media allowlist

- [ ] **Step 2: Update refresh helper calls**

Modify `app/controllers/beans_controller.rb`:

```ruby
def refresh_public_shares_for(record)
  PublicBrewShareRefresher.refresh_for(record)
  PublicBeanShareRefresher.refresh_for(record)
end
```

Replace calls to `refresh_public_brew_shares_for(@bean)` with `refresh_public_shares_for(@bean)`.

Modify `app/controllers/brews_controller.rb`:

```ruby
def refresh_public_shares_for(record)
  PublicBrewShareRefresher.refresh_for(record)
  PublicBeanShareRefresher.refresh_for(record)
end
```

Use `refresh_public_shares_for(@brew)` after create, update, and taste. In `destroy`, capture the bean first:

```ruby
bean = @brew.bean
@brew.destroy_with_inventory_reversal!
PublicBeanShareRefresher.refresh_for(bean)
redirect_to root_path, notice: t(".destroyed")
```

When update can move a brew to another bean, capture `previous_bean = @brew.bean` before update and call `PublicBeanShareRefresher.refresh_for(previous_bean)` if the bean changed.

Modify `app/controllers/media_attachments_controller.rb`, `app/controllers/workspaces_controller.rb`, and `app/controllers/profiles_controller.rb` to call both public brew and public bean refreshers for records they already refresh.

- [ ] **Step 3: Add workspace settings partial**

Create `app/views/workspaces/_public_bean_shares.html.erb` with the same structure as `_public_brew_shares.html.erb`, but use:

- collection local `public_bean_shares`
- URL helper `public_bean_page_path(share.token)`
- edit helper `edit_bean_public_bean_share_path(share.bean)`
- destroy helper `bean_public_bean_share_path(share.bean)`
- record link `bean_path(share.bean)`
- test id prefix `workspace-public-bean-share`

Modify `app/controllers/workspaces_controller.rb`:

```ruby
def edit
  @workspace = current_workspace
  load_public_brew_shares
  load_public_bean_shares
end

def update
  @workspace = current_workspace

  if @workspace.update(workspace_params)
    PublicBrewShareRefresher.refresh_for(@workspace)
    PublicBeanShareRefresher.refresh_for(@workspace)
    redirect_to dashboard_path, notice: t(".updated")
  else
    load_public_brew_shares
    load_public_bean_shares
    render :edit, status: :unprocessable_entity
  end
end

def load_public_bean_shares
  @public_bean_shares = current_workspace
    .public_bean_shares
    .includes(:public_bean_share_views, bean: [ :primary_photo_record ])
    .order(updated_at: :desc, created_at: :desc)
end
```

Modify `app/views/workspaces/edit.html.erb` after public brew shares:

```erb
<%= render "public_bean_shares", public_bean_shares: @public_bean_shares %>
```

- [ ] **Step 4: Run refresh and settings tests**

Run:

```bash
bin/rails test test/services/public_bean_share_refresher_test.rb test/controllers/brews_controller_test.rb test/controllers/workspaces_controller_test.rb test/controllers/media_attachments_controller_test.rb test/controllers/profiles_controller_test.rb
```

Expected: pass.

- [ ] **Step 5: Commit**

Run:

```bash
git add app/controllers/beans_controller.rb app/controllers/brews_controller.rb app/controllers/media_attachments_controller.rb app/controllers/workspaces_controller.rb app/controllers/profiles_controller.rb app/views/workspaces/edit.html.erb app/views/workspaces/_public_bean_shares.html.erb config/locales/en.yml test/services/public_bean_share_refresher_test.rb test/controllers/brews_controller_test.rb test/controllers/workspaces_controller_test.rb test/controllers/media_attachments_controller_test.rb test/controllers/profiles_controller_test.rb
git commit -m "Refresh and manage public bean shares"
```

---

### Task 6: Documentation And Full Verification

**Files:**
- Create: `docs/public-bean-sharing.md`
- Modify: `docs/README.md`
- Modify: `docs/status.md`
- Modify: `docs/coffee-core.md`
- Modify: `docs/private-media.md`
- Modify: `AGENTS.md`

- [ ] **Step 1: Add documentation**

Create `docs/public-bean-sharing.md` with this structure:

```markdown
# Public Bean Sharing

Public Bean Sharing lets workspace writers publish one curated bean bag page without opening the private workspace.

## Included Now

- One public share per opened, finished, or used-up bean bag.
- Unlisted public URL at `/b/:token`.
- Optional per-share password gate.
- Selected bean package photos only.
- Snapshot-driven public bean page with remaining inventory, brew count, public status, consumed grams, dead grams, average rating, channeling rate, taste balance, rating distribution, grinder-setting distribution, open duration, and a compact timeline.
- All espresso and Quick Drip brews for the bag, rendered as public-safe compact cards.
- Workspace settings management with URL, enabled/protected state, view count, and recent IP history.

## Privacy Contract

Public bean shares render from `PublicBeanShare` snapshots. They must not render private notes, purchase source, purchase cost, private links, brew photos, raw attachment IDs, original filenames, signed Active Storage URLs, private media routes, user email addresses, invite tokens, session data, admin data, export data, backup data, environment variables, or infrastructure secrets.

## Public Media

Public bean pages use `PublicBeanMediaController` and opaque media handles. The only user-selected photos in v1 are bean package photos. Workspace logos and brewer avatars may appear through the snapshot media allowlist.

## Agent Notes

- Use `PublicBeanShareSnapshotBuilder` for public bean data.
- Use `PublicBeanShareRefresher` when public-safe source records change.
- Treat `/b/:token` as bearer access and do not log raw share tokens.
- Public pages must not use `MediaAttachmentsController`, raw Active Storage routes, or private record links.
```

Update docs index/status/core/private-media/AGENTS with short links and the new public media rule.

- [ ] **Step 2: Run focused tests**

Run:

```bash
bin/rails test \
  test/models/public_bean_share_test.rb \
  test/models/public_bean_share_view_test.rb \
  test/services/public_bean_share_snapshot_builder_test.rb \
  test/services/public_bean_share_refresher_test.rb \
  test/services/public_bean_share_view_recorder_test.rb \
  test/controllers/public_bean_shares_controller_test.rb \
  test/controllers/public_bean_pages_controller_test.rb \
  test/controllers/public_bean_media_controller_test.rb
```

Expected: pass.

- [ ] **Step 3: Run affected existing tests**

Run:

```bash
bin/rails test \
  test/controllers/beans_controller_test.rb \
  test/controllers/brews_controller_test.rb \
  test/controllers/workspaces_controller_test.rb \
  test/controllers/media_attachments_controller_test.rb \
  test/controllers/profiles_controller_test.rb \
  test/services/public_brew_share_refresher_test.rb \
  test/services/public_brew_share_snapshot_builder_test.rb
```

Expected: pass.

- [ ] **Step 4: Run security scan**

Run:

```bash
bin/brakeman
```

Expected: no new warnings related to public bean sharing, token lookup, media streaming, or public page rendering.

- [ ] **Step 5: Start local server for visual review**

Run:

```bash
bin/dev
```

Expected: Rails starts on port `3001`. Open a private bean detail, create a public bean share, and verify:

- `/b/:token` renders without sign-in when enabled
- the password gate blocks protected shares
- selected bean photos render through `/b/:token/media/:media_id`
- page HTML has no `/rails/active_storage` or `/media_attachments`
- all espresso and Quick Drip brews for the bag appear
- private bean notes, private brew notes, purchase source, purchase cost, private links, and brew photos do not appear
- the timeline fits without horizontal scrolling on mobile and desktop widths

- [ ] **Step 6: Commit**

Run:

```bash
git add docs/public-bean-sharing.md docs/README.md docs/status.md docs/coffee-core.md docs/private-media.md AGENTS.md
git commit -m "Document public bean sharing"
```

---

## Self-Review Checklist

- The plan implements snapshot-based `PublicBeanShare`, token digest lookup, optional password gate, selected bean media, public view tracking, workspace settings management, refresh hooks, public UI, docs, and verification.
- The plan includes all-brew summaries for espresso and Quick Drip.
- The plan excludes private notes, purchase source, purchase cost, private links, brew photos, raw media routes, raw attachment IDs in HTML, filenames, and email addresses.
- The plan covers publishable lifecycle states and rejects stock/archived beans.
- The plan uses existing Roastnode patterns: `current_workspace`, `current_workspace_policy`, public share snapshots, opaque media handles, and Minitest.
