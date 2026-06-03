# Public Share Refresh And Management Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make public brew shares refresh from public-safe source data, improve the shared page UI, and add private share management with full-IP view logging.

**Architecture:** Keep `PublicBrewShare.snapshot` as the public rendering boundary. Add focused services for snapshot refresh and page-view recording, then call them from existing Rails controllers after successful writes. Public pages continue to render only snapshot data and opaque public media handles.

**Tech Stack:** Rails 8.1, Minitest integration/model/service tests, ERB, Hotwire/Turbo, Stimulus, Tailwind CSS, PostgreSQL.

---

## File Map

- Create `db/migrate/*_add_view_tracking_to_public_brew_shares.rb`: adds `views_count`.
- Create `db/migrate/*_create_public_brew_share_views.rb`: stores retained full-IP view rows.
- Create `app/models/public_brew_share_view.rb`: view-row model, full-IP validation, counter cache, retention pruning.
- Modify `app/models/public_brew_share.rb`: `has_many :public_brew_share_views`, helpers for recent/latest views, selected-photo filtering helper.
- Create `app/services/public_brew_share_view_recorder.rb`: records successful public page views.
- Create `app/services/public_brew_share_refresher.rb`: regenerates snapshots for one share or all shares affected by a changed record.
- Modify `app/services/public_brew_share_snapshot_builder.rb`: add bean fields and safer tool fallback fields.
- Modify `app/controllers/public_brew_pages_controller.rb`: record page views only after access is granted.
- Modify `app/controllers/public_brew_shares_controller.rb`: support returning to household settings after quick remove.
- Modify `app/controllers/workspaces_controller.rb`: load public shares for settings and refresh shares after workspace identity changes.
- Modify `app/controllers/profiles_controller.rb`: refresh shares after display label/avatar changes.
- Modify `app/controllers/beans_controller.rb`, `app/controllers/equipment_controller.rb`, `app/controllers/preparation_tools_controller.rb`, `app/controllers/brews_controller.rb`, `app/controllers/media_attachments_controller.rb`: refresh affected public shares after successful public-safe edits and selected-media changes.
- Create `app/views/shared/_record_links_list.html.erb`: reusable private record-link display.
- Modify `app/views/beans/show.html.erb`, `app/views/equipment/show.html.erb`, `app/views/preparation_tools/show.html.erb`: render link lists.
- Create `app/views/workspaces/_public_brew_shares.html.erb`: admin-only share list with URLs, counters, recent IPs, and quick actions.
- Modify `app/views/workspaces/edit.html.erb`: render public-share management section.
- Create `app/javascript/controllers/public_lightbox_controller.js`: mobile-friendly full-screen public photo viewer.
- Modify `app/views/public_brew_pages/show.html.erb`, `app/views/public_brew_pages/_hero_card.html.erb`, `app/views/public_brew_pages/_product_section.html.erb`: public layout, contain-fit images, full-screen viewer hooks, link styling, bean facts, hero chart/metrics.
- Modify `app/helpers/public_brew_shares_helper.rb`: public formatting helpers for dates, money, rating, link icon labels, chart x positions, and bean subtitles.
- Modify `config/locales/en.yml`: labels for share management, view log, public UI, and private link lists.
- Modify docs: `docs/public-brew-sharing.md`, `docs/private-media.md`, `docs/workspace-settings.md`, `docs/coffee-core.md`, `docs/status.md`.
- Tests: `test/models/public_brew_share_view_test.rb`, `test/services/public_brew_share_refresher_test.rb`, `test/controllers/public_brew_pages_controller_test.rb`, `test/controllers/workspaces_controller_test.rb`, `test/controllers/public_brew_shares_controller_test.rb`, `test/controllers/beans_controller_test.rb`, `test/controllers/equipment_controller_test.rb`, `test/controllers/preparation_tools_controller_test.rb`, `test/controllers/media_attachments_controller_test.rb`, `test/services/public_brew_share_snapshot_builder_test.rb`.

## Important Constraints

- Stay on `main`; do not create a branch or worktree.
- Use TDD for every behavior change.
- Do not expose private notes, private links, raw media routes, signed Active Storage URLs, raw attachment IDs in public HTML, original filenames, emails, token-bearing URLs in logs, equipment/tool costs, or purchase source text.
- Page views count only successful public page renders after any password gate.
- Store full IP addresses, but show them only in the private owner/admin household settings UI.
- Retain latest 100 `PublicBrewShareView` rows per share while keeping `PublicBrewShare#views_count` as all-time successful page views.

---

### Task 1: Page View Storage And Recording

**Files:**
- Create: `db/migrate/*_add_view_tracking_to_public_brew_shares.rb`
- Create: `db/migrate/*_create_public_brew_share_views.rb`
- Create: `app/models/public_brew_share_view.rb`
- Create: `app/services/public_brew_share_view_recorder.rb`
- Modify: `app/models/public_brew_share.rb`
- Modify: `app/controllers/public_brew_pages_controller.rb`
- Test: `test/models/public_brew_share_view_test.rb`
- Test: `test/controllers/public_brew_pages_controller_test.rb`

- [ ] **Step 1: Write failing model tests for full-IP retention and all-time count**

Add `test/models/public_brew_share_view_test.rb`:

```ruby
require "test_helper"

class PublicBrewShareViewTest < ActiveSupport::TestCase
  test "records full ip addresses and keeps all time counter after pruning retained rows" do
    share = create_share

    101.times do |index|
      PublicBrewShareView.create!(
        public_brew_share: share,
        ip_address: "203.0.113.#{index % 250}",
        user_agent: "MiniTest/#{index}",
        viewed_at: Time.zone.local(2026, 6, 3, 10, 0, 0) + index.seconds
      )
    end

    share.reload
    assert_equal 101, share.views_count
    assert_equal 100, share.public_brew_share_views.count
    assert_equal "203.0.113.100", share.public_brew_share_views.recent.first.ip_address
    assert_equal share.workspace, share.public_brew_share_views.recent.first.workspace
  end

  private
    def create_share
      brew = brews(:morning_espresso)
      brew.create_public_brew_share!(
        workspace: brew.workspace,
        created_by: users(:one),
        updated_by: users(:one),
        enabled: true,
        title: "Shared shot",
        selected_photo_attachment_ids: [],
        snapshot: PublicBrewShareSnapshotBuilder.new(
          brew:,
          title: "Shared shot",
          selected_photo_attachment_ids: []
        ).call
      )
    end
end
```

- [ ] **Step 2: Run the model test and verify it fails**

Run:

```bash
bin/rails test test/models/public_brew_share_view_test.rb
```

Expected: FAIL with `NameError: uninitialized constant PublicBrewShareView` or missing table/column errors.

- [ ] **Step 3: Write failing controller tests for successful page-view counting**

Add tests to `test/controllers/public_brew_pages_controller_test.rb`:

```ruby
test "successful public page render records a full ip page view" do
  share = create_share(enabled: true)

  assert_difference -> { PublicBrewShareView.count }, 1 do
    get public_brew_page_path(share.token), headers: {
      "REMOTE_ADDR" => "198.51.100.24",
      "HTTP_USER_AGENT" => "Roastnode test browser"
    }
  end

  assert_response :success
  view = share.public_brew_share_views.last
  assert_equal "198.51.100.24", view.ip_address
  assert_equal "Roastnode test browser", view.user_agent
  assert_equal 1, share.reload.views_count
end

test "password gate does not count until the unlocked page is rendered" do
  share = create_share(enabled: true, password: "espresso")

  assert_no_difference -> { PublicBrewShareView.count } do
    get public_brew_page_path(share.token), headers: { "REMOTE_ADDR" => "198.51.100.25" }
  end

  post unlock_public_brew_page_path(share.token), params: { password: "espresso" }
  assert_redirected_to public_brew_page_path(share.token)

  assert_difference -> { PublicBrewShareView.count }, 1 do
    get public_brew_page_path(share.token), headers: { "REMOTE_ADDR" => "198.51.100.25" }
  end

  assert_equal "198.51.100.25", share.public_brew_share_views.last.ip_address
end

test "disabled and unknown shares do not record page views" do
  share = create_share(enabled: false)

  assert_no_difference -> { PublicBrewShareView.count } do
    get public_brew_page_path(share.token), headers: { "REMOTE_ADDR" => "198.51.100.26" }
  end
  assert_response :not_found

  assert_no_difference -> { PublicBrewShareView.count } do
    get public_brew_page_path("missing-token"), headers: { "REMOTE_ADDR" => "198.51.100.27" }
  end
  assert_response :not_found
end
```

- [ ] **Step 4: Run the controller tests and verify they fail**

Run:

```bash
bin/rails test test/controllers/public_brew_pages_controller_test.rb
```

Expected: FAIL because `PublicBrewShareView` and `views_count` do not exist.

- [ ] **Step 5: Add migrations**

Generate migrations:

```bash
bin/rails generate migration AddViewTrackingToPublicBrewShares views_count:integer
bin/rails generate migration CreatePublicBrewShareViews public_brew_share:references workspace:references ip_address:string user_agent:string viewed_at:datetime
```

Edit the generated migrations so they match:

```ruby
class AddViewTrackingToPublicBrewShares < ActiveRecord::Migration[8.1]
  def change
    add_column :public_brew_shares, :views_count, :integer, null: false, default: 0
  end
end
```

```ruby
class CreatePublicBrewShareViews < ActiveRecord::Migration[8.1]
  def change
    create_table :public_brew_share_views do |t|
      t.references :public_brew_share, null: false, foreign_key: true
      t.references :workspace, null: false, foreign_key: true
      t.string :ip_address, null: false
      t.string :user_agent
      t.datetime :viewed_at, null: false

      t.timestamps
    end

    add_index :public_brew_share_views,
      [ :public_brew_share_id, :viewed_at, :id ],
      name: "idx_public_brew_share_views_recent"
  end
end
```

- [ ] **Step 6: Run migrations**

Run:

```bash
bin/rails db:migrate
```

Expected: schema updates with `public_brew_share_views` and `public_brew_shares.views_count`.

- [ ] **Step 7: Implement the model and recorder**

Create `app/models/public_brew_share_view.rb`:

```ruby
class PublicBrewShareView < ApplicationRecord
  RETAINED_ROWS_PER_SHARE = 100

  belongs_to :public_brew_share, counter_cache: :views_count
  belongs_to :workspace

  before_validation :set_workspace_from_share
  before_validation :set_viewed_at
  after_create_commit :prune_old_rows

  scope :recent, -> { order(viewed_at: :desc, id: :desc) }

  validates :ip_address, presence: true, length: { maximum: 255 }
  validates :user_agent, length: { maximum: 512 }, allow_blank: true
  validate :workspace_matches_share

  private
    def set_workspace_from_share
      self.workspace ||= public_brew_share&.workspace
    end

    def set_viewed_at
      self.viewed_at ||= Time.current
    end

    def workspace_matches_share
      return if public_brew_share.blank? || workspace.blank?
      return if public_brew_share.workspace_id == workspace_id

      errors.add(:workspace, "must match the public brew share")
    end

    def prune_old_rows
      stale_ids = public_brew_share
        .public_brew_share_views
        .recent
        .offset(RETAINED_ROWS_PER_SHARE)
        .pluck(:id)
      self.class.where(id: stale_ids).delete_all if stale_ids.any?
    end
end
```

Create `app/services/public_brew_share_view_recorder.rb`:

```ruby
class PublicBrewShareViewRecorder
  USER_AGENT_LIMIT = 512

  def initialize(share:, request:)
    @share = share
    @request = request
  end

  def call
    share.public_brew_share_views.create!(
      ip_address: request.remote_ip,
      user_agent: request.user_agent.to_s.first(USER_AGENT_LIMIT),
      viewed_at: Time.current
    )
  end

  private
    attr_reader :share, :request
end
```

Modify `app/models/public_brew_share.rb`:

```ruby
has_many :public_brew_share_views, dependent: :delete_all
```

- [ ] **Step 8: Record views from successful public renders**

Modify `app/controllers/public_brew_pages_controller.rb`:

```ruby
def show
  return render :password if password_required?

  load_snapshot
  record_page_view
end
```

Add the private method:

```ruby
def record_page_view
  PublicBrewShareViewRecorder.new(share: @share, request: request).call
end
```

- [ ] **Step 9: Run focused tests and verify green**

Run:

```bash
bin/rails test test/models/public_brew_share_view_test.rb test/controllers/public_brew_pages_controller_test.rb
```

Expected: PASS.

- [ ] **Step 10: Commit**

Run:

```bash
git add db/migrate db/schema.rb app/models/public_brew_share.rb app/models/public_brew_share_view.rb app/services/public_brew_share_view_recorder.rb app/controllers/public_brew_pages_controller.rb test/models/public_brew_share_view_test.rb test/controllers/public_brew_pages_controller_test.rb
git commit -m "Add public share view tracking"
```

---

### Task 2: Snapshot Refresh Service And Write Hooks

**Files:**
- Create: `app/services/public_brew_share_refresher.rb`
- Modify: `app/models/public_brew_share.rb`
- Modify: `app/services/public_brew_share_snapshot_builder.rb`
- Modify: `app/controllers/beans_controller.rb`
- Modify: `app/controllers/equipment_controller.rb`
- Modify: `app/controllers/preparation_tools_controller.rb`
- Modify: `app/controllers/brews_controller.rb`
- Modify: `app/controllers/media_attachments_controller.rb`
- Modify: `app/controllers/workspaces_controller.rb`
- Modify: `app/controllers/profiles_controller.rb`
- Test: `test/services/public_brew_share_refresher_test.rb`
- Test: `test/services/public_brew_share_snapshot_builder_test.rb`
- Test: selected existing controller tests touched by hooks

- [ ] **Step 1: Write failing refresher service tests**

Create `test/services/public_brew_share_refresher_test.rb`:

```ruby
require "test_helper"

class PublicBrewShareRefresherTest < ActiveSupport::TestCase
  include PhotoTestHelper

  test "refresh_for bean updates all affected public shares with new public link" do
    brew = brews(:morning_espresso)
    share = create_share_for(brew)

    brew.bean.record_links.create!(
      workspace: brew.workspace,
      label: "Buy refreshed beans",
      url: "https://example.test/refreshed-beans",
      kind: "buy",
      visibility: "public"
    )

    PublicBrewShareRefresher.refresh_for(brew.bean)

    links = share.reload.snapshot.dig("bean", "links")
    assert_includes links.map { |link| link.fetch("label") }, "Buy refreshed beans"
  end

  test "refresh_for equipment updates grinder and machine shares without leaking private links" do
    brew = brews(:morning_espresso)
    share = create_share_for(brew)
    brew.grinder.record_links.create!(
      workspace: brew.workspace,
      label: "Public burr notes",
      url: "https://example.test/grinder",
      kind: "info",
      visibility: "public"
    )
    brew.grinder.record_links.create!(
      workspace: brew.workspace,
      label: "Private receipt",
      url: "https://example.test/private-grinder",
      kind: "info",
      visibility: "private"
    )

    PublicBrewShareRefresher.refresh_for(brew.grinder)

    snapshot_json = share.reload.snapshot.to_json
    assert_includes snapshot_json, "Public burr notes"
    assert_not_includes snapshot_json, "Private receipt"
  end

  test "refresh filters removed selected photos out of public media allowlist" do
    brew = brews(:morning_espresso)
    photo = attach_photo(brew.bean)
    share = create_share_for(brew, selected_photo_attachment_ids: [ photo.id ])
    assert_includes share.public_attachment_ids, photo.id

    photo.destroy!
    PublicBrewShareRefresher.refresh(share)

    share.reload
    assert_not_includes share.selected_photo_attachment_ids, photo.id
    assert_not_includes share.public_attachment_ids, photo.id
  end

  private
    def create_share_for(brew, selected_photo_attachment_ids: [])
      brew.create_public_brew_share!(
        workspace: brew.workspace,
        created_by: users(:one),
        updated_by: users(:one),
        enabled: true,
        title: "Shared shot",
        selected_photo_attachment_ids:,
        snapshot: PublicBrewShareSnapshotBuilder.new(
          brew:,
          title: "Shared shot",
          selected_photo_attachment_ids:
        ).call
      )
    end
end
```

- [ ] **Step 2: Run the service tests and verify they fail**

Run:

```bash
bin/rails test test/services/public_brew_share_refresher_test.rb
```

Expected: FAIL with `NameError: uninitialized constant PublicBrewShareRefresher`.

- [ ] **Step 3: Add selected-photo filtering helper to `PublicBrewShare`**

Modify `app/models/public_brew_share.rb`:

```ruby
def valid_selected_photo_attachment_ids
  selected_share_record_photo_attachment_ids
end
```

Keep `selected_share_record_photo_attachment_ids` private; the public helper simply exposes the filtered result for the refresher.

- [ ] **Step 4: Implement `PublicBrewShareRefresher`**

Create `app/services/public_brew_share_refresher.rb`:

```ruby
class PublicBrewShareRefresher
  def self.refresh(share)
    new(share).refresh
  end

  def self.refresh_for(record)
    shares_for(record).find_each { |share| refresh(share) }
  end

  def self.shares_for(record)
    case record
    when PublicBrewShare
      PublicBrewShare.where(id: record.id)
    when Brew
      PublicBrewShare.where(brew_id: record.id)
    when Bean
      PublicBrewShare.joins(:brew).where(brews: { bean_id: record.id })
    when Equipment
      PublicBrewShare.joins(:brew).where("brews.grinder_id = :id OR brews.machine_id = :id", id: record.id)
    when PreparationTool
      PublicBrewShare.joins(brew: :brew_preparation_tools).where(brew_preparation_tools: { preparation_tool_id: record.id }).distinct
    when Workspace
      record.public_brew_shares
    when User
      PublicBrewShare.joins(:brew).where(brews: { user_id: record.id })
    when RecordLink
      shares_for(record.linkable)
    else
      PublicBrewShare.none
    end
  end

  def initialize(share)
    @share = share
  end

  def refresh
    share.reload
    filtered_photo_ids = share.valid_selected_photo_attachment_ids
    share.update!(
      selected_photo_attachment_ids: filtered_photo_ids,
      snapshot: PublicBrewShareSnapshotBuilder.new(
        brew: share.brew,
        title: share.title,
        selected_photo_attachment_ids: filtered_photo_ids
      ).call
    )
  end

  private
    attr_reader :share
end
```

- [ ] **Step 5: Expand snapshot builder bean payload**

Modify `app/services/public_brew_share_snapshot_builder.rb` inside `bean_payload`:

```ruby
"purchased_on" => bean.purchased_on&.iso8601,
"opened_on" => bean.opened_on&.iso8601,
"purchase_price_cents" => bean.purchase_price_cents,
```

Keep `purchase_source` out. Keep equipment and tool purchase costs out.

- [ ] **Step 6: Update snapshot-builder test for new safe bean fields**

In `test/services/public_brew_share_snapshot_builder_test.rb`, add assertions to the existing test:

```ruby
assert_equal "2026-05-02", snapshot.fetch("bean").fetch("purchased_on")
assert_equal "2026-05-10", snapshot.fetch("bean").fetch("opened_on")
assert_equal 1290, snapshot.fetch("bean").fetch("purchase_price_cents")
assert_not_includes snapshot.to_json, "Local roaster"
```

- [ ] **Step 7: Add controller refresh hooks after successful updates**

Add this private helper to controllers that refresh one changed record:

```ruby
def refresh_public_brew_shares_for(record)
  PublicBrewShareRefresher.refresh_for(record)
end
```

Call it only after successful writes:

```ruby
refresh_public_brew_shares_for(@bean)
```

Add calls in:

- `BeansController#create`, after attaching photos;
- `BeansController#update`, after attaching photos;
- `BeansController#close`, `#finish`, `#reopen`;
- `EquipmentController#create`, after attaching photos;
- `EquipmentController#update`, after attaching photos;
- `EquipmentController#archive`, `#reopen`;
- `PreparationToolsController#create`, after attaching photos;
- `PreparationToolsController#update`, after attaching photos;
- `PreparationToolsController#archive`, `#reopen`;
- `BrewsController#create`, after `save_brew_with_preparation_tools`;
- `BrewsController#update`, after `update_with_inventory_correction!`;
- `BrewsController#taste`, after successful taste update.

Use this exact delete behavior:

- `BeansController#destroy`: do not refresh; deleting a bean deletes its dependent brews and public brew shares through existing history cleanup.
- `BrewsController#destroy`: do not refresh; deleting a brew destroys its public brew share.
- `EquipmentController#destroy`: before `destroy_with_history!`, collect `share_ids = PublicBrewShareRefresher.shares_for(@equipment).pluck(:id)`. After deletion, run `PublicBrewShare.where(id: share_ids).find_each { |share| PublicBrewShareRefresher.refresh(share) }` so retained brews drop deleted equipment live extras.
- `PreparationToolsController#destroy`: before `destroy_with_history!`, collect `share_ids = PublicBrewShareRefresher.shares_for(@preparation_tool).pluck(:id)`. After deletion, run `PublicBrewShare.where(id: share_ids).find_each { |share| PublicBrewShareRefresher.refresh(share) }` so retained brews drop deleted tool live extras.

- [ ] **Step 8: Add identity refresh hooks**

In `WorkspacesController#update`, after a successful update:

```ruby
PublicBrewShareRefresher.refresh_for(@workspace)
```

In `ProfilesController#update`, after a successful update:

```ruby
PublicBrewShareRefresher.refresh_for(@user)
```

- [ ] **Step 9: Add media refresh hooks**

In `MediaAttachmentsController#primary`, after `record.set_primary_photo!(@attachment)`:

```ruby
PublicBrewShareRefresher.refresh_for(record)
```

In `MediaAttachmentsController#destroy`, after `@attachment.destroy!`:

```ruby
PublicBrewShareRefresher.refresh_for(record)
```

In `MediaAttachmentsController#save_crop`, after the transaction:

```ruby
PublicBrewShareRefresher.refresh_for(record)
```

- [ ] **Step 10: Run focused refresh tests**

Run:

```bash
bin/rails test test/services/public_brew_share_refresher_test.rb test/services/public_brew_share_snapshot_builder_test.rb
```

Expected: PASS.

- [ ] **Step 11: Run controller tests touched by refresh hooks**

Run:

```bash
bin/rails test test/controllers/beans_controller_test.rb test/controllers/equipment_controller_test.rb test/controllers/preparation_tools_controller_test.rb test/controllers/brews_controller_test.rb test/controllers/workspaces_controller_test.rb
```

Expected: PASS.

- [ ] **Step 12: Commit**

Run:

```bash
git add app/models/public_brew_share.rb app/services/public_brew_share_refresher.rb app/services/public_brew_share_snapshot_builder.rb app/controllers/beans_controller.rb app/controllers/equipment_controller.rb app/controllers/preparation_tools_controller.rb app/controllers/brews_controller.rb app/controllers/media_attachments_controller.rb app/controllers/workspaces_controller.rb app/controllers/profiles_controller.rb test/services/public_brew_share_refresher_test.rb test/services/public_brew_share_snapshot_builder_test.rb
git commit -m "Refresh public brew share snapshots"
```

---

### Task 3: Household Settings Public Share Management

**Files:**
- Modify: `app/controllers/workspaces_controller.rb`
- Modify: `app/controllers/public_brew_shares_controller.rb`
- Create: `app/views/workspaces/_public_brew_shares.html.erb`
- Modify: `app/views/workspaces/edit.html.erb`
- Modify: `config/locales/en.yml`
- Test: `test/controllers/workspaces_controller_test.rb`
- Test: `test/controllers/public_brew_shares_controller_test.rb`

- [ ] **Step 1: Write failing workspace settings tests**

Add to `test/controllers/workspaces_controller_test.rb`:

```ruby
test "owner sees public share management with full ip view log" do
  share = create_public_brew_share_for(brews(:morning_espresso), enabled: true)
  share.public_brew_share_views.create!(
    ip_address: "198.51.100.31",
    user_agent: "Settings test browser",
    viewed_at: Time.zone.local(2026, 6, 3, 11, 0, 0)
  )
  sign_in_as(users(:one))

  get edit_workspace_path

  assert_response :success
  assert_select "[data-testid=workspace-public-shares]"
  assert_select "[data-testid=?]", "workspace-public-share-#{share.id}", text: /Shared shot/
  assert_select "a[href=?]", public_brew_page_path(share.token), text: public_brew_page_url(share.token)
  assert_select "a[href=?]", edit_brew_public_brew_share_path(share.brew)
  assert_select "form[action=?]", brew_public_brew_share_path(share.brew)
  assert_select "[data-testid=?]", "public-share-view-count-#{share.id}", text: "1"
  assert_select "[data-testid=?]", "public-share-recent-ip-#{share.id}", text: /198\.51\.100\.31/
end

test "workspace public share management excludes other workspaces" do
  other_share = create_public_brew_share_for(brews(:other_workspace_brew), enabled: true, user: users(:two))
  sign_in_as(users(:one))

  get edit_workspace_path

  assert_response :success
  assert_select "[data-testid=?]", "workspace-public-share-#{other_share.id}", count: 0
end

test "member cannot see public share management full ip data" do
  user = users(:two)
  user.update!(active_workspace: workspaces(:household))
  create_public_brew_share_for(brews(:morning_espresso), enabled: true)
  sign_in_as(user)

  get edit_workspace_path

  assert_redirected_to root_path
end
```

Add helper methods to the test class:

```ruby
def create_public_brew_share_for(brew, enabled:, user: users(:one), title: "Shared shot")
  brew.create_public_brew_share!(
    workspace: brew.workspace,
    created_by: user,
    updated_by: user,
    enabled:,
    title:,
    selected_photo_attachment_ids: [],
    snapshot: PublicBrewShareSnapshotBuilder.new(
      brew:,
      title:,
      selected_photo_attachment_ids: []
    ).call
  )
end
```

- [ ] **Step 2: Write failing quick-remove return test**

Add to `test/controllers/public_brew_shares_controller_test.rb`:

```ruby
test "owner can destroy public share from workspace settings and return there" do
  writer = users(:two)
  writer.update!(active_workspace: workspaces(:household))
  brew = create_brew_for(writer)
  share = create_share_for(brew, user: writer, enabled: true)
  sign_in_as(users(:one))

  assert_difference -> { PublicBrewShare.count }, -1 do
    delete brew_public_brew_share_path(brew), params: { return_to: "workspace" }
  end

  assert_redirected_to edit_workspace_path(anchor: "public-shares")
  assert_not PublicBrewShare.exists?(share.id)
end
```

- [ ] **Step 3: Run tests and verify they fail**

Run:

```bash
bin/rails test test/controllers/workspaces_controller_test.rb test/controllers/public_brew_shares_controller_test.rb
```

Expected: FAIL because the management section and redirect behavior do not exist.

- [ ] **Step 4: Load shares in `WorkspacesController#edit`**

Modify `app/controllers/workspaces_controller.rb`:

```ruby
def edit
  @workspace = current_workspace
  load_public_brew_shares
end
```

Add:

```ruby
def load_public_brew_shares
  @public_brew_shares = current_workspace
    .public_brew_shares
    .includes(:public_brew_share_views, brew: [ :bean, :user ])
    .order(updated_at: :desc, created_at: :desc)
end
```

Call `load_public_brew_shares` before rendering `:edit` on invalid update.

- [ ] **Step 5: Add the settings partial**

Create `app/views/workspaces/_public_brew_shares.html.erb`:

```erb
<% locale_scope = "workspaces.public_brew_shares" %>

<section id="public-shares" data-testid="workspace-public-shares" class="mt-6 rounded-lg border border-stone-200 bg-white p-6 shadow-sm">
  <div class="flex flex-col gap-2 sm:flex-row sm:items-start sm:justify-between">
    <div>
      <h2 class="text-xl font-semibold text-stone-950"><%= t("#{locale_scope}.title") %></h2>
      <p class="mt-1 text-sm text-stone-600"><%= t("#{locale_scope}.body") %></p>
    </div>
  </div>

  <div class="mt-5 grid gap-4">
    <% public_brew_shares.each do |share| %>
      <% latest_view = share.public_brew_share_views.recent.first %>
      <article data-testid="workspace-public-share-<%= share.id %>" class="rounded-lg border border-stone-200 bg-stone-50 p-4">
        <div class="flex flex-col gap-3 lg:flex-row lg:items-start lg:justify-between">
          <div class="min-w-0">
            <div class="flex flex-wrap items-center gap-2">
              <h3 class="text-lg font-bold text-stone-950"><%= share.title.presence || t("#{locale_scope}.untitled") %></h3>
              <span class="rounded-full bg-stone-200 px-2.5 py-1 text-xs font-bold text-stone-700"><%= share.enabled? ? t("#{locale_scope}.enabled") : t("#{locale_scope}.disabled") %></span>
              <% if share.password_protected? %>
                <span class="rounded-full bg-amber-100 px-2.5 py-1 text-xs font-bold text-amber-900"><%= t("#{locale_scope}.protected") %></span>
              <% end %>
            </div>
            <p class="mt-1 text-sm font-semibold text-stone-600"><%= t("#{locale_scope}.brew", bean: share.brew.bean.display_name) %></p>
            <p class="mt-2 break-all text-sm font-bold text-stone-950">
              <%= link_to public_brew_page_url(share.token), public_brew_page_path(share.token), target: "_blank", rel: "noopener", class: "underline decoration-stone-300 underline-offset-4 hover:decoration-stone-950" %>
            </p>
            <dl class="mt-3 grid gap-2 text-sm sm:grid-cols-3">
              <div>
                <dt class="text-xs font-bold uppercase text-stone-500"><%= t("#{locale_scope}.views") %></dt>
                <dd data-testid="public-share-view-count-<%= share.id %>" class="font-bold text-stone-950"><%= share.views_count %></dd>
              </div>
              <div>
                <dt class="text-xs font-bold uppercase text-stone-500"><%= t("#{locale_scope}.latest_ip") %></dt>
                <dd data-testid="public-share-recent-ip-<%= share.id %>" class="font-bold text-stone-950"><%= latest_view&.ip_address || t("#{locale_scope}.no_views") %></dd>
              </div>
              <div>
                <dt class="text-xs font-bold uppercase text-stone-500"><%= t("#{locale_scope}.latest_view") %></dt>
                <dd class="font-bold text-stone-950"><%= latest_view ? profile_timestamp(latest_view.viewed_at) : t("#{locale_scope}.no_views") %></dd>
              </div>
            </dl>
          </div>

          <div class="flex flex-wrap gap-2">
            <%= link_to t("#{locale_scope}.open"), public_brew_page_path(share.token), target: "_blank", rel: "noopener", class: "rounded-md border border-stone-300 bg-white px-3 py-2 text-sm font-semibold text-stone-900 hover:bg-stone-100" %>
            <%= link_to t("#{locale_scope}.edit"), edit_brew_public_brew_share_path(share.brew), class: "rounded-md border border-stone-300 bg-white px-3 py-2 text-sm font-semibold text-stone-900 hover:bg-stone-100" %>
            <%= button_to t("#{locale_scope}.remove"),
              brew_public_brew_share_path(share.brew),
              method: :delete,
              params: { return_to: "workspace" },
              form: { data: { turbo_confirm: t("#{locale_scope}.remove_confirmation") } },
              class: "rounded-md border border-red-200 bg-white px-3 py-2 text-sm font-semibold text-red-700 hover:bg-red-50" %>
          </div>
        </div>
      </article>
    <% end %>

    <% if public_brew_shares.empty? %>
      <p class="rounded-lg border border-dashed border-stone-300 p-4 text-sm font-semibold text-stone-600"><%= t("#{locale_scope}.empty") %></p>
    <% end %>
  </div>
</section>
```

- [ ] **Step 6: Render the partial in workspace settings**

Modify `app/views/workspaces/edit.html.erb` after the main settings form card:

```erb
<%= render "public_brew_shares", public_brew_shares: @public_brew_shares %>
```

- [ ] **Step 7: Add locale entries**

Add under `en.workspaces.public_brew_shares`:

```yaml
body: "Review public brew URLs, visitor counts, and recent full-IP views."
brew: "Brew: %{bean}"
disabled: "Disabled"
edit: "Edit"
empty: "No public brew shares yet."
enabled: "Enabled"
latest_ip: "Latest IP"
latest_view: "Latest view"
no_views: "No views"
open: "Open"
protected: "Protected"
remove: "Remove"
remove_confirmation: "Remove this public share? The URL will stop working."
title: "Public shares"
untitled: "Untitled share"
views: "Views"
```

- [ ] **Step 8: Support workspace return from public share destroy**

Modify `PublicBrewSharesController#destroy`:

```ruby
redirect_target = params[:return_to] == "workspace" ? edit_workspace_path(anchor: "public-shares") : @brew
@share.destroy!
redirect_to redirect_target, notice: t(".destroyed")
```

- [ ] **Step 9: Run focused tests and verify green**

Run:

```bash
bin/rails test test/controllers/workspaces_controller_test.rb test/controllers/public_brew_shares_controller_test.rb
```

Expected: PASS.

- [ ] **Step 10: Commit**

Run:

```bash
git add app/controllers/workspaces_controller.rb app/controllers/public_brew_shares_controller.rb app/views/workspaces/edit.html.erb app/views/workspaces/_public_brew_shares.html.erb config/locales/en.yml test/controllers/workspaces_controller_test.rb test/controllers/public_brew_shares_controller_test.rb
git commit -m "Add public share management to workspace settings"
```

---

### Task 4: Private Record Link Lists On Bean, Equipment, And Tool Details

**Files:**
- Create: `app/views/shared/_record_links_list.html.erb`
- Modify: `app/views/beans/show.html.erb`
- Modify: `app/views/equipment/show.html.erb`
- Modify: `app/views/preparation_tools/show.html.erb`
- Modify: `config/locales/en.yml`
- Test: `test/controllers/beans_controller_test.rb`
- Test: `test/controllers/equipment_controller_test.rb`
- Test: `test/controllers/preparation_tools_controller_test.rb`

- [ ] **Step 1: Write failing tests for detail link lists**

Add to `test/controllers/beans_controller_test.rb`:

```ruby
test "show renders bean record links with visibility labels" do
  sign_in_as(users(:one))
  bean = beans(:open_household)
  bean.record_links.create!(label: "Buy beans", url: "https://example.test/beans", kind: "buy", visibility: "public")
  bean.record_links.create!(label: "Private cupping", url: "https://example.test/private", kind: "info", visibility: "private")

  get bean_path(bean)

  assert_response :success
  assert_select "[data-testid=record-links-list]"
  assert_select "a[href='https://example.test/beans']", text: /Buy beans/
  assert_select "a[href='https://example.test/private']", text: /Private cupping/
  assert_select "[data-testid=record-link-visibility]", text: I18n.t("shared.record_links.visibilities.public")
  assert_select "[data-testid=record-link-visibility]", text: I18n.t("shared.record_links.visibilities.private")
end
```

Add matching tests to `test/controllers/equipment_controller_test.rb` and `test/controllers/preparation_tools_controller_test.rb` with one public link each.

- [ ] **Step 2: Run tests and verify they fail**

Run:

```bash
bin/rails test test/controllers/beans_controller_test.rb test/controllers/equipment_controller_test.rb test/controllers/preparation_tools_controller_test.rb
```

Expected: FAIL because `[data-testid=record-links-list]` is missing.

- [ ] **Step 3: Create shared record-link list partial**

Create `app/views/shared/_record_links_list.html.erb`:

```erb
<% links = record.record_links.ordered.to_a %>
<% if links.any? %>
  <section data-testid="record-links-list" class="<%= local_assigns.fetch(:section_class, "mt-6 rounded-lg border border-stone-200 bg-white p-5 shadow-sm") %>">
    <h2 class="<%= local_assigns.fetch(:title_class, "text-lg font-semibold text-stone-950") %>"><%= t("shared.record_links.title") %></h2>
    <div class="mt-3 flex flex-wrap gap-2">
      <% links.each do |link| %>
        <%= link_to link.url, target: "_blank", rel: "noopener", class: "inline-flex items-center gap-2 rounded-md border border-stone-300 bg-white px-3 py-2 text-sm font-bold text-stone-950 underline decoration-stone-300 underline-offset-4 hover:bg-stone-50 hover:decoration-stone-950" do %>
          <span aria-hidden="true">↗</span>
          <span><%= link.label %></span>
          <span class="rounded-full bg-stone-100 px-2 py-0.5 text-[0.65rem] font-black uppercase text-stone-600"><%= t("shared.record_links.kinds.#{link.kind}") %></span>
          <span data-testid="record-link-visibility" class="rounded-full bg-stone-100 px-2 py-0.5 text-[0.65rem] font-black uppercase text-stone-600"><%= t("shared.record_links.visibilities.#{link.visibility}") %></span>
        <% end %>
      <% end %>
    </div>
  </section>
<% end %>
```

- [ ] **Step 4: Render partial on detail pages**

In `app/views/beans/show.html.erb`, after details and before notes:

```erb
<%= render "shared/record_links_list", record: @bean %>
```

In `app/views/equipment/show.html.erb`, after notes or before photos:

```erb
<%= render "shared/record_links_list", record: @equipment, section_class: "mt-8 rounded-lg border border-stone-200 bg-white p-5 shadow-sm", title_class: "font-semibold text-stone-950" %>
```

In `app/views/preparation_tools/show.html.erb`, after notes or before photos:

```erb
<%= render "shared/record_links_list", record: @preparation_tool, section_class: "mt-8 rounded-lg border border-stone-200 bg-white p-5 shadow-sm", title_class: "font-semibold text-stone-950" %>
```

- [ ] **Step 5: Run tests and verify green**

Run:

```bash
bin/rails test test/controllers/beans_controller_test.rb test/controllers/equipment_controller_test.rb test/controllers/preparation_tools_controller_test.rb
```

Expected: PASS.

- [ ] **Step 6: Commit**

Run:

```bash
git add app/views/shared/_record_links_list.html.erb app/views/beans/show.html.erb app/views/equipment/show.html.erb app/views/preparation_tools/show.html.erb test/controllers/beans_controller_test.rb test/controllers/equipment_controller_test.rb test/controllers/preparation_tools_controller_test.rb
git commit -m "Show record links on detail pages"
```

---

### Task 5: Public Page Hero, Links, Contained Photos, And Full-Screen Viewer

**Files:**
- Create: `app/javascript/controllers/public_lightbox_controller.js`
- Modify: `app/helpers/public_brew_shares_helper.rb`
- Modify: `app/views/public_brew_pages/show.html.erb`
- Modify: `app/views/public_brew_pages/_hero_card.html.erb`
- Modify: `app/views/public_brew_pages/_product_section.html.erb`
- Modify: `config/locales/en.yml`
- Test: `test/controllers/public_brew_pages_controller_test.rb`

- [ ] **Step 1: Write failing public page UI tests**

Add to `test/controllers/public_brew_pages_controller_test.rb`:

```ruby
test "public hero mirrors private card metrics without in-card identity clutter" do
  share = create_share(enabled: true)

  get public_brew_page_path(share.token)

  assert_response :success
  assert_select "[data-testid=public-brew-hero-card]"
  assert_select "[data-testid=public-brew-dose]"
  assert_select "[data-testid=public-brew-ratio]"
  assert_select "[data-testid=public-brew-grind]"
  assert_select "[data-testid=public-brew-rating]"
  assert_select "[data-testid=public-brew-balance]"
  assert_select "[data-testid=public-brew-retention]", count: 0
  assert_select "[data-testid=public-brew-card-workspace]", count: 0
  assert_select "[data-testid=public-brew-card-byline]", count: 0
  assert_select "[data-testid=public-brew-identity-strip]"
  assert_select "[data-testid=public-brew-preinfusion-label]", text: /5s/
  assert_select "[data-testid=public-brew-first-drip-label]", text: /8s/
  assert_select "[data-testid=public-brew-total-time-label]", text: /28s/
  assert_select "[data-testid=public-brew-temperature-label]", text: /93/
end

test "public photos use contain cards and lightbox controls" do
  brew = brews(:morning_espresso)
  photo = attach_photo(brew)
  share = create_share(enabled: true, selected_photo_attachment_ids: [ photo.id ])

  get public_brew_page_path(share.token)

  assert_response :success
  assert_select "[data-controller~='public-lightbox']"
  assert_select "button[data-action*='public-lightbox#open'][data-full-src]"
  assert_select "img[data-testid=public-brew-gallery-photo].object-contain"
  assert_no_match "/media_attachments", response.body
  assert_no_match "/rails/active_storage", response.body
end

test "public links render with visible link icon treatment" do
  share = create_share(enabled: true)

  get public_brew_page_path(share.token)

  assert_response :success
  assert_select "a[data-testid=public-brew-link] [data-testid=public-link-icon]"
end

test "public bean section shows safe bean facts" do
  share = create_share(enabled: true)

  get public_brew_page_path(share.token)

  assert_response :success
  assert_select "[data-testid=public-product-section][data-kind=bean]"
  assert_select "[data-testid=public-bean-fact]", text: /Bought/
  assert_select "[data-testid=public-bean-fact]", text: /Opened/
  assert_select "[data-testid=public-bean-fact]", text: /€/
  assert_select "body", text: /Local roaster/, count: 0
end
```

- [ ] **Step 2: Run public page tests and verify they fail**

Run:

```bash
bin/rails test test/controllers/public_brew_pages_controller_test.rb
```

Expected: FAIL because the new test IDs and layout do not exist.

- [ ] **Step 3: Add helper methods**

Modify `app/helpers/public_brew_shares_helper.rb`:

```ruby
def public_snapshot_date(value)
  date = Date.iso8601(value.to_s)
  l(date, format: :long)
rescue ArgumentError, TypeError
  nil
end

def public_snapshot_money(cents)
  return if cents.blank?

  number_to_currency(cents.to_i / 100.0, unit: "€", separator: ".", delimiter: ",")
end

def public_snapshot_ratio_time(snapshot)
  seconds = snapshot.dig("brew", "total_time_seconds")
  return if seconds.blank?

  t("brews.show.ratio_time", time: public_snapshot_seconds(seconds))
end

def public_snapshot_chart_x(seconds, total_seconds)
  return if seconds.blank? || total_seconds.blank? || total_seconds.to_f <= 0

  start_x = 44
  end_x = 500
  (start_x + (seconds.to_f / total_seconds.to_f * (end_x - start_x))).clamp(start_x, end_x).round
end

def public_snapshot_rating_label(rating)
  return public_unknown_label if rating.blank?

  t("brews.show.rating_beans", rating:, maximum: 5)
end
```

- [ ] **Step 4: Add Stimulus lightbox controller**

Create `app/javascript/controllers/public_lightbox_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog", "image"]

  open(event) {
    const source = event.currentTarget.dataset.fullSrc
    if (!source) return

    this.imageTarget.src = source
    this.dialogTarget.classList.remove("hidden")
    this.dialogTarget.setAttribute("aria-hidden", "false")
    document.documentElement.classList.add("overflow-hidden")
  }

  close() {
    this.dialogTarget.classList.add("hidden")
    this.dialogTarget.setAttribute("aria-hidden", "true")
    this.imageTarget.removeAttribute("src")
    document.documentElement.classList.remove("overflow-hidden")
  }

  closeFromKeyboard(event) {
    if (event.key === "Escape") this.close()
  }
}
```

- [ ] **Step 5: Rework public page shell with identity strip and lightbox**

Modify `app/views/public_brew_pages/show.html.erb` root:

```erb
<main data-testid="public-brew-page" data-controller="public-lightbox" data-action="keydown@window->public-lightbox#closeFromKeyboard" class="min-h-screen bg-[#f6f4ef] text-stone-950">
```

Move identity below hero:

```erb
<%= render "hero_card", share: @share, snapshot: @snapshot %>

<section data-testid="public-brew-identity-strip" class="mx-auto mt-5 grid max-w-3xl gap-3 sm:grid-cols-2">
  <!-- workspace logo/name and user avatar/display label, each larger than the old header chips -->
</section>
```

Add lightbox overlay before `</main>`:

```erb
<div data-public-lightbox-target="dialog" aria-hidden="true" class="hidden fixed inset-0 z-50 bg-black/90 p-4">
  <button type="button" data-action="public-lightbox#close" class="absolute right-4 top-4 rounded-full bg-white px-4 py-2 text-sm font-black text-stone-950"><%= t("public_brew_pages.show.close_photo") %></button>
  <div class="flex h-full items-center justify-center">
    <img data-public-lightbox-target="image" alt="" class="max-h-full max-w-full object-contain" />
  </div>
</div>
```

- [ ] **Step 6: Use contain-fit gallery buttons**

In the brew gallery loop, use full-size public media for the button:

```erb
<% thumb_url = public_media_url_for(@share, photo["attachment_id"], variant: :thumbnail) %>
<% full_url = public_media_url_for(@share, photo["attachment_id"]) %>
<button type="button" data-action="public-lightbox#open" data-full-src="<%= full_url %>" class="h-72 w-full rounded-lg border border-stone-200 bg-white p-2">
  <%= image_tag thumb_url, alt: "", data: { testid: "public-brew-gallery-photo" }, class: "h-full w-full object-contain" %>
</button>
```

- [ ] **Step 7: Rework hero card metrics and chart labels**

Modify `app/views/public_brew_pages/_hero_card.html.erb`:

- Remove in-card workspace/method/logged-by spans.
- Keep timestamp and brand mark.
- Replace metric cards with `Dose`, `Ratio`, `Grind`, `Rating`, `Balance`.
- Add data test IDs:
  - `public-brew-dose`
  - `public-brew-ratio`
  - `public-brew-grind`
  - `public-brew-rating`
  - `public-brew-balance`
- Add chart labels:
  - `public-brew-preinfusion-label`
  - `public-brew-first-drip-label`
  - `public-brew-total-time-label`
  - `public-brew-temperature-label`

Use `public_snapshot_chart_x` to place preinfusion, first drip, and total time. Use `Temp <value>` for the temperature callout text.

- [ ] **Step 8: Rework product section for contain images, links, and bean facts**

Modify `app/views/public_brew_pages/_product_section.html.erb`:

- Add `data-kind="<%= kind %>"` to the section.
- Change image class from `object-cover` to `object-contain`.
- Wrap images in lightbox buttons using `public_media_url_for(share, attachment_id)` as `data-full-src`.
- Render link anchors with:

```erb
<span data-testid="public-link-icon" aria-hidden="true">↗</span>
```

- For `kind == "bean"`, render facts with `data-testid="public-bean-fact"` for purchased date, opened date, roast date, purchase price, origin/process/roast descriptor when values are present.

- [ ] **Step 9: Add locale entries**

Under `en.public_brew_pages.show`, add:

```yaml
balance: "Balance"
bought: "Bought %{date}"
close_photo: "Close"
opened: "Opened %{date}"
price: "Cost %{price}"
roasted: "Roasted %{date}"
temp_label: "Temp %{temperature}"
```

- [ ] **Step 10: Run public page tests and verify green**

Run:

```bash
bin/rails test test/controllers/public_brew_pages_controller_test.rb
```

Expected: PASS.

- [ ] **Step 11: Commit**

Run:

```bash
git add app/javascript/controllers/public_lightbox_controller.js app/helpers/public_brew_shares_helper.rb app/views/public_brew_pages/show.html.erb app/views/public_brew_pages/_hero_card.html.erb app/views/public_brew_pages/_product_section.html.erb config/locales/en.yml test/controllers/public_brew_pages_controller_test.rb
git commit -m "Improve public brew share page"
```

---

### Task 6: Documentation And Final Verification

**Files:**
- Modify: `docs/public-brew-sharing.md`
- Modify: `docs/private-media.md`
- Modify: `docs/workspace-settings.md`
- Modify: `docs/coffee-core.md`
- Modify: `docs/status.md`

- [ ] **Step 1: Update public sharing docs**

In `docs/public-brew-sharing.md`:

- Move automatic live regeneration out of Explicitly Deferred.
- Add that public-safe changes to brews, beans, equipment, tools, public links, selected media, workspace logo, and user avatar refresh affected snapshots.
- Add the private share management list and full-IP view log.
- Keep the privacy contract explicit: public rendering remains snapshot-only.

- [ ] **Step 2: Update media/settings/core/status docs**

Update:

- `docs/private-media.md`: selected public photos now render contain-fit cards and full-screen viewer through opaque handles.
- `docs/workspace-settings.md`: settings page lists public shares with URLs, counters, and full-IP recent views for owners/admins.
- `docs/coffee-core.md`: public links now auto-refresh affected public brew shares.
- `docs/status.md`: update Built Now and Changed/Deferred sections for automatic public-safe share refresh and share management.

- [ ] **Step 3: Run the focused regression suite**

Run:

```bash
bin/rails test test/models/public_brew_share_view_test.rb test/services/public_brew_share_refresher_test.rb test/services/public_brew_share_snapshot_builder_test.rb test/controllers/public_brew_pages_controller_test.rb test/controllers/public_brew_shares_controller_test.rb test/controllers/workspaces_controller_test.rb test/controllers/beans_controller_test.rb test/controllers/equipment_controller_test.rb test/controllers/preparation_tools_controller_test.rb test/controllers/brews_controller_test.rb test/controllers/media_attachments_controller_test.rb
```

Expected: PASS.

- [ ] **Step 4: Run the full Rails test suite**

Run:

```bash
bin/rails test
```

Expected: PASS.

- [ ] **Step 5: Start the local development server**

Run:

```bash
bin/dev
```

Expected: server starts on the configured development host/port, preferably port `3001`.

- [ ] **Step 6: Browser smoke test**

Use the Browser plugin to open the local app and inspect:

- an enabled public share page on desktop and mobile widths;
- full-screen public photo viewer open/close;
- workspace settings Public Shares list;
- bean and equipment detail link lists;
- brew edit shared marker.

Expected: no overlapping text, no cropped public images, no private media URLs in public HTML, and temperature/total-time labels fit in the public hero chart.

- [ ] **Step 7: Commit documentation and any smoke-test fixes**

Run:

```bash
git add docs/public-brew-sharing.md docs/private-media.md docs/workspace-settings.md docs/coffee-core.md docs/status.md
git commit -m "Document refreshed public share behavior"
```

If smoke-test fixes changed code, include the relevant files and use a message that describes the actual fix.

---

## Plan Self-Review

- Spec coverage: Tasks cover snapshot refresh, public UI, contained/full-screen media, visible links, all-share management, full-IP view logging, retained view rows, detail-page link lists, docs, and verification.
- Privacy coverage: Public rendering remains snapshot-only; public media remains opaque; private notes/links, raw media routes, original filenames, user emails, equipment/tool prices, and purchase source text stay excluded.
- Type consistency: The plan uses `PublicBrewShareRefresher`, `PublicBrewShareView`, `PublicBrewShareViewRecorder`, `views_count`, `public_brew_share_views`, and existing route/helper names consistently.
- Scope: One implementation slice with six independently testable tasks. No branch or worktree is required because repository guidance says current solo development stays on `main`.
