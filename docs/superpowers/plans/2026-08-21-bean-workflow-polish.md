# Bean Workflow Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use exodos-dev:subagent-driven-development (recommended) or exodos-dev:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make new and duplicated Bean bags start as private stock, improve Bean entry and focused rating correction, add a workspace-safe Bean filter to Coffees, store and present separate purchase/origin websites, and explain the Espresso-only waste-aware Cost per shot calculation.

**Architecture:** Keep Bean lifecycle, URL normalization, validation, duplication, and cost math in Bean; keep workspace authorization and focused mutations in BeansController; and extend the existing Coffees index with one optional Bean relation loaded strictly through current_workspace. Direct purchase/origin URLs remain private Bean columns and are rendered as synthesized link chips rather than RecordLink rows, while export/restore explicitly carries both values and every public snapshot remains allowlist based.

**Tech Stack:** Ruby 3.3.12, Rails 8.1.3.1, Active Record, PostgreSQL 17.11, Hotwire/Turbo, ERB, Tailwind CSS, Active Storage, Minitest

## Global Constraints

- Work directly on main; do not create a branch or worktree.
- Preserve unrelated user changes and inspect git status --short before every commit.
- Use red-green TDD: run every stated red test before its implementation, then rerun it green.
- Run Rails tests with POSTGRES_PORT=55433 and PARALLEL_WORKERS=1 so the existing Roastnode database and serial test assumptions are preserved.
- Execute this plan after both Activity Audit and Brew Recipient/Two-Photo Hero. Task 4 reuses Activity's `ActivityEvent`, `with_workspace_activity(...)`, and exact-action-multiset `assert_activity_event(...)` interfaces without a generic duplicate; Task 7 extends the already-updated public Brew snapshot/privacy boundary.
- Treat Workspace as the authorization boundary. Bean and Brew lookups must use current_workspace; a supplied missing or foreign Bean filter returns 404.
- New Beans and duplicates derive stock status from blank opened_on, finished_at, and archived_at; neither enters Bean.open, normal Brew selection, or Repeat Good Brew until an explicit open transition.
- Bean rating is nil or an integer from 1 through 5. Migration 20260821130000 converts every legacy Bean rating 0 to NULL before the model rejects 0.
- purchase_url remains the private Purchase Website and Rebuy source. coffee_origin_url is a separate private Coffee Origin Website. Both normalize surrounding whitespace and accept only HTTP or HTTPS with a host.
- Purchase Website and Coffee Origin Website are Bean columns, not RecordLink rows. The private Links section synthesizes their chips before ordinary RecordLink rows.
- Never copy either direct URL into PublicBeanShare, PublicBrewShare, PublicRecipeShare, or recipe public-profile snapshots. Remove the existing `purchase_price_cents` field from new PublicBrewShare snapshots and stop rendering it; existing snapshots may retain the ignored key until refreshed. Do not expose costs, private notes, raw IDs, signed media URLs, or private media routes.
- Cost per shot is purchase price per gram multiplied by average Espresso bean_weight_grams (Bean In) for the Bean, with an 18g fallback before the first Espresso. Quick Drip, ground_weight_grams, dose_grams, and manual InventoryAdjustment rows do not enter the denominator.
- Preserve current currency rounding and user number formatting.
- Do not add a discard reason, infer waste from generic manual adjustments, synchronize direct URL columns into RecordLink, or change Beanconqueror URL semantics.
- Keep the local development server running in tmux session roastnode-dev on port 3001 after visual verification so the user can inspect the result.

---

## File Structure And Responsibility Map

### Create

- db/migrate/20260821130000_add_coffee_origin_url_and_normalize_bean_ratings.rb — add the nullable origin URL and backfill legacy rating zeroes.
- test/migrations/add_coffee_origin_url_and_normalize_bean_ratings_test.rb — execute the migration backfill helper against a legacy zero row.
- app/views/beans/_rating_correction.html.erb — focused, writer-only Bean rating form used by the detail page.

### Modify: Bean domain and private UI

- app/models/bean.rb — shared safe HTTP URL contract, 1..5 rating validation, stock duplicate attributes, and Espresso-only cost calculation.
- app/controllers/beans_controller.rb — stock create default, focused rating action, parameter allowlist, public refresh, and ActivityEvent emission.
- app/helpers/beans_helper.rb — safe synthesized Purchase URL and Origin Coffee URL presentation entries.
- app/views/beans/_form.html.erb — full-width rating row, exact examples, Purchase Website label/guidance, and Coffee Origin Website input.
- app/views/beans/show.html.erb — rating correction, View all link, private synthesized links, and accessible Cost per shot explanation.
- app/views/shared/_record_links_list.html.erb — render optional read-only system entries before editable RecordLink rows.
- config/routes.rb — PATCH /beans/:id/rating.
- config/locales/en.yml — exact field labels, examples, filter chip copy, correction copy, link labels, and cost explanation.
- db/schema.rb — schema dump containing beans.coffee_origin_url.

### Modify: Bean-filtered Coffees

- app/controllers/brews_controller.rb — load the optional active-workspace Bean and constrain Brew history.
- app/views/brews/index.html.erb — active Bean chip and query preservation across view, compatible type filters, clear action, and pagination.

### Modify: private portability and compatibility

- app/services/workspace_export_builder.rb — include coffee_origin_url in workspace JSON and instance-readable payloads.
- app/services/workspace_csv_export_builder.rb — include coffee_origin_url in Beans CSV.
- app/services/instance_backup_restorer.rb — validate and restore both direct Bean URLs with backward compatibility.

### Modify: automated coverage

- test/models/bean_test.rb — rating range, URL normalization/validation, duplicate stock/copy behavior, and cost formula.
- test/controllers/beans_controller_test.rb — form markup, new/duplicate defaults, focused rating authorization/allowlist/activity/refresh, private chips, View all, and tooltip markup.
- test/controllers/brews_controller_test.rb — duplicate eligibility plus Bean-filtered history/isolation/query persistence/External behavior.
- test/helpers/beans_helper_test.rb — synthesized system-link presentation and unsafe URL rejection.
- test/services/workspace_export_builder_test.rb — JSON URL export.
- test/services/workspace_csv_export_builder_test.rb — CSV URL export.
- test/services/instance_backup_builders_test.rb — readable backup URL coverage.
- test/services/instance_backup_restore_test.rb — valid URL restoration and unsafe URL dropping.
- test/services/beanconqueror_import_test.rb — source URL remains Purchase Website only.
- test/services/public_bean_share_snapshot_builder_test.rb — negative assertions for both direct URLs.
- test/services/public_brew_share_snapshot_builder_test.rb — negative assertions for both direct URLs.
- test/services/public_recipe_share_snapshot_builder_test.rb — public recipe allowlist rejects both direct URLs.

### Modify: durable documentation

- docs/coffee-core.md
- docs/bean-analytics.md
- docs/bean-danger-zone.md
- docs/formatting.md
- docs/navigation.md
- docs/workspace-export.md
- docs/backup-system.md
- docs/beanconqueror-import.md
- docs/status.md

---

### Task 1: Add the Bean URL/rating data contract

**Files:**

- Create: db/migrate/20260821130000_add_coffee_origin_url_and_normalize_bean_ratings.rb
- Create: test/migrations/add_coffee_origin_url_and_normalize_bean_ratings_test.rb
- Modify: db/schema.rb
- Modify: app/models/bean.rb:1-55, 286-297
- Modify: test/models/bean_test.rb:95-157, 373-444

**Interfaces:**

- Consumes: existing Bean.purchase_url, Bean.safe_purchase_url(url), and PostgreSQL beans table.
- Produces: Bean.coffee_origin_url -> String|nil; Bean.safe_http_url(url) -> String|nil; Bean.valid_http_url?(url) -> boolean; Bean ratings valid only for nil or Integer 1..5.

- [ ] **Step 1: Write the migration backfill test**

Create the test directory, which does not yet exist:

~~~bash
mkdir -p test/migrations
~~~

Expected: test/migrations exists and contains no generated files.

Create test/migrations/add_coffee_origin_url_and_normalize_bean_ratings_test.rb:

~~~ruby
require "test_helper"
require Rails.root.join(
  "db/migrate/20260821130000_add_coffee_origin_url_and_normalize_bean_ratings"
).to_s

class AddCoffeeOriginUrlAndNormalizeBeanRatingsTest < ActiveSupport::TestCase
  test "normalizes legacy zero ratings to null" do
    bean = beans(:open_household)
    bean.update_column(:rating, 0)

    migration = AddCoffeeOriginUrlAndNormalizeBeanRatings.new
    migration.send(:normalize_legacy_bean_ratings)

    assert_nil bean.reload.rating
  end
end
~~~

- [ ] **Step 2: Run the migration test red**

Run:

~~~bash
env POSTGRES_PORT=55433 PARALLEL_WORKERS=1 bin/rails test test/migrations/add_coffee_origin_url_and_normalize_bean_ratings_test.rb
~~~

Expected: ERROR with LoadError for db/migrate/20260821130000_add_coffee_origin_url_and_normalize_bean_ratings.

- [ ] **Step 3: Add the migration**

Create db/migrate/20260821130000_add_coffee_origin_url_and_normalize_bean_ratings.rb:

~~~ruby
class AddCoffeeOriginUrlAndNormalizeBeanRatings < ActiveRecord::Migration[8.1]
  def up
    add_column :beans, :coffee_origin_url, :string
    normalize_legacy_bean_ratings
  end

  def down
    remove_column :beans, :coffee_origin_url
  end

  private
    def normalize_legacy_bean_ratings
      execute("UPDATE beans SET rating = NULL WHERE rating = 0")
    end
end
~~~

The down migration intentionally does not recreate zero ratings: NULL is a valid value and the former distinction between zero and blank was not meaningful.

- [ ] **Step 4: Run the migration and its test green**

Run:

~~~bash
env POSTGRES_PORT=55433 bin/rails db:migrate
env POSTGRES_PORT=55433 PARALLEL_WORKERS=1 bin/rails test test/migrations/add_coffee_origin_url_and_normalize_bean_ratings_test.rb
~~~

Expected: migration reports AddCoffeeOriginUrlAndNormalizeBeanRatings migrated; the test passes with 0 failures and 0 errors; db/schema.rb contains t.string "coffee_origin_url" and no schema change unrelated to this migration.

- [ ] **Step 5: Write model tests for rating and both URLs**

In test/models/bean_test.rb, add:

~~~ruby
test "rating is blank or an integer from one through five" do
  bean = workspaces(:household).beans.build(
    name: "Rated Bag",
    bag_size_grams: 250
  )

  [ nil, 1, 2, 3, 4, 5 ].each do |rating|
    bean.rating = rating
    assert_predicate bean, :valid?, "expected #{rating.inspect} to be valid"
  end

  [ 0, 6 ].each do |rating|
    bean.rating = rating
    assert_not_predicate bean, :valid?, "expected #{rating.inspect} to be invalid"
    assert_includes bean.errors[:rating], "must be in 1..5"
  end
end

test "private bean urls normalize valid http and https values" do
  bean = workspaces(:household).beans.build(
    name: "Two Website Bag",
    bag_size_grams: 250,
    purchase_url: " https://shop.example/beans ",
    coffee_origin_url: " http://origin.example/coffee "
  )

  assert_predicate bean, :valid?
  assert_equal "https://shop.example/beans", bean.purchase_url
  assert_equal "http://origin.example/coffee", bean.coffee_origin_url

  bean.purchase_url = " "
  bean.coffee_origin_url = ""
  assert_predicate bean, :valid?
  assert_nil bean.purchase_url
  assert_nil bean.coffee_origin_url
end

test "private bean urls reject unsafe schemeless and hostless values" do
  bean = workspaces(:household).beans.build(
    name: "Unsafe Website Bag",
    bag_size_grams: 250
  )

  %i[purchase_url coffee_origin_url].each do |attribute|
    [ "javascript:alert(1)", "data:text/html,x", "example.com/path", "https:///path" ].each do |url|
      bean.public_send("#{attribute}=", url)

      assert_not_predicate bean, :valid?, "#{attribute}=#{url.inspect} should be invalid"
      assert_includes bean.errors[attribute], "must be an HTTP or HTTPS URL"
    end
  end
end

test "safe http url strips valid values and drops unsafe values" do
  assert_equal "https://example.com/beans", Bean.safe_http_url(" https://example.com/beans ")
  assert_equal "http://example.com/beans", Bean.safe_http_url("http://example.com/beans")
  assert_nil Bean.safe_http_url("javascript:alert(1)")
  assert_nil Bean.safe_http_url("example.com/path")
  assert_nil Bean.safe_http_url("https:///path")
end
~~~

Keep the existing safe_purchase_url test because Beanconqueror and older callers retain that compatibility wrapper.

- [ ] **Step 6: Run the model tests red**

Run:

~~~bash
env POSTGRES_PORT=55433 PARALLEL_WORKERS=1 bin/rails test test/models/bean_test.rb
~~~

Expected: failures because rating 0 is still accepted and safe_http_url/coffee_origin_url normalization and validation are not implemented.

- [ ] **Step 7: Implement the shared URL contract and stricter rating**

In app/models/bean.rb, add the constant beside the other Bean constants:

~~~ruby
PRIVATE_URL_FIELDS = %i[purchase_url coffee_origin_url].freeze
~~~

Replace the purchase-only normalizer and class URL methods with:

~~~ruby
normalizes(*PRIVATE_URL_FIELDS, with: ->(url) { url.to_s.strip.presence })

def self.safe_http_url(url)
  url = url.to_s.strip
  return if url.blank?

  url if valid_http_url?(url)
end

def self.valid_http_url?(url)
  uri = URI.parse(url.to_s.strip)
  uri.is_a?(URI::HTTP) && uri.host.present?
rescue URI::InvalidURIError
  false
end

def self.safe_purchase_url(url)
  safe_http_url(url)
end

def self.valid_purchase_url?(url)
  valid_http_url?(url)
end
~~~

Replace the rating validation and purchase-only custom validation with:

~~~ruby
validates :rating, numericality: { only_integer: true, in: 1..5 }, allow_nil: true
validate :private_urls_are_http_or_https
~~~

Replace purchase_url_is_http_or_https with:

~~~ruby
def private_urls_are_http_or_https
  PRIVATE_URL_FIELDS.each do |attribute|
    next unless will_save_change_to_attribute?(attribute)

    value = public_send(attribute)
    next if value.blank? || self.class.valid_http_url?(value)

    errors.add(attribute, "must be an HTTP or HTTPS URL")
  end
end
~~~

The change-sensitive validation preserves the existing behavior that unrelated edits can save a legacy invalid URL; duplication and restore sanitize those values through safe_http_url.

- [ ] **Step 8: Run the model and migration tests green**

Run:

~~~bash
env POSTGRES_PORT=55433 PARALLEL_WORKERS=1 bin/rails test test/migrations/add_coffee_origin_url_and_normalize_bean_ratings_test.rb test/models/bean_test.rb
~~~

Expected: all tests pass with 0 failures and 0 errors.

- [ ] **Step 9: Commit the data contract**

Run:

~~~bash
git status --short
git add db/migrate/20260821130000_add_coffee_origin_url_and_normalize_bean_ratings.rb db/schema.rb app/models/bean.rb test/migrations/add_coffee_origin_url_and_normalize_bean_ratings_test.rb test/models/bean_test.rb
git commit -m "Add private bean origin URL contract"
~~~

Expected: one commit containing only the listed data-contract files.

---

### Task 2: Make new and duplicated bags stock until explicitly opened

**Files:**

- Modify: app/controllers/beans_controller.rb:28-54
- Modify: app/models/bean.rb:193-215, 298-333
- Modify: test/controllers/beans_controller_test.rb:220-271, 684-707
- Modify: test/models/bean_test.rb:257-316
- Modify: test/controllers/brews_controller_test.rb:404-439

**Interfaces:**

- Consumes: Bean#apply_bag_status("stock"), Bean#open_bag!, Bean.open, BeansController#extract_bag_status.
- Produces: BeansController create default status "stock"; Bean#duplicate_for_new_bag! -> persisted stock Bean with copied descriptive/private metadata, shared photo blobs, preserved primary-photo blob identity, and duplicated_from_bean.

- [ ] **Step 1: Write stock-default and duplicate regressions**

Rename and extend the existing BeansController member-create test so its post omits bag_status but includes a misleading opened_on, then assert:

~~~ruby
test "new bean defaults to full unopened stock" do
  user = users(:two)
  user.update!(active_workspace: workspaces(:household))
  sign_in_as(user)

  assert_difference -> { workspaces(:household).beans.count }, 1 do
    post beans_path, params: {
      bean: {
        name: "Sweet Valley",
        roaster_name: "Calendar Coffee",
        bag_size_grams: "250",
        remaining_grams: "",
        opened_on: "2026-05-26",
        photos: [ photo_upload ]
      }
    }
  end

  bean = workspaces(:household).beans.order(:created_at).last
  assert_redirected_to bean_path(bean)
  assert_equal "stock", bean.bag_status
  assert_equal 250.to_d, bean.remaining_grams
  assert_nil bean.opened_on
  assert_nil bean.finished_at
  assert_nil bean.archived_at
  assert_equal 1, bean.photos.count
end
~~~

Replace the existing duplicate model test with a full copy/reset contract:

~~~ruby
test "duplicates a bean as full unopened stock with metadata urls notes and photos" do
  source = beans(:open_household)
  source.update!(
    grind_state: "pre_ground",
    remaining_grams: 12,
    purchase_price_cents: 1490,
    purchase_url: "https://shop.example/house-blend",
    coffee_origin_url: "https://origin.example/house-blend",
    notes: "Private resting note.",
    public_note: "Public tasting note."
  )
  source.update_columns(
    opened_on: Date.new(2026, 5, 10),
    finished_at: Time.zone.local(2026, 6, 1, 9),
    archived_at: Time.zone.local(2026, 6, 2, 9)
  )
  File.open(Rails.root.join("test/fixtures/files/photo.jpg")) do |file|
    source.photos.attach(io: file, filename: "photo.jpg", content_type: "image/jpeg")
  end
  File.open(Rails.root.join("test/fixtures/files/photo.jpg")) do |file|
    source.photos.attach(io: file, filename: "label.jpg", content_type: "image/jpeg")
  end
  source.set_primary_photo!(source.photos.last)

  duplicate = source.duplicate_for_new_bag!

  assert_not_equal source.id, duplicate.id
  assert_equal "stock", duplicate.bag_status
  assert_equal duplicate.bag_size_grams, duplicate.remaining_grams
  assert_nil duplicate.opened_on
  assert_nil duplicate.finished_at
  assert_nil duplicate.archived_at
  assert_equal source.name, duplicate.name
  assert_equal source.roaster_name, duplicate.roaster_name
  assert_equal source.purchase_price_cents, duplicate.purchase_price_cents
  assert_equal source.purchase_url, duplicate.purchase_url
  assert_equal source.coffee_origin_url, duplicate.coffee_origin_url
  assert_equal source.notes, duplicate.notes
  assert_equal source.public_note, duplicate.public_note
  assert_equal "pre_ground", duplicate.grind_state
  assert_equal source, duplicate.duplicated_from_bean
  assert_equal source.photos.first.blob, duplicate.photos.first.blob
  assert_equal source.primary_photo_attachment.blob, duplicate.primary_photo_attachment.blob
  assert_not_includes source.workspace.beans.open, duplicate
end
~~~

Update the controller duplicate test assertions to:

~~~ruby
assert_equal "stock", duplicate.bag_status
assert_equal duplicate.bag_size_grams, duplicate.remaining_grams
assert_nil duplicate.opened_on
assert_nil duplicate.finished_at
assert_nil duplicate.archived_at
assert_equal source, duplicate.duplicated_from_bean
assert_equal 1, duplicate.photos.count
~~~

- [ ] **Step 2: Write explicit-open Brew and Repeat Good Brew eligibility**

In test/controllers/brews_controller_test.rb, add:

~~~ruby
test "duplicated stock bag is unavailable to repeat until explicitly opened" do
  source_brew = brews(:morning_espresso)
  source_bean = source_brew.bean
  duplicate = source_bean.duplicate_for_new_bag!
  source_bean.update!(
    remaining_grams: 0,
    finished_at: Time.zone.local(2026, 6, 1, 9)
  )
  sign_in_as(users(:one))

  get new_brew_path(method: "espresso")

  assert_response :success
  assert_select "input[type=radio][name=?][value=?]",
    "brew[bean_id]",
    duplicate.id.to_s,
    count: 0

  get new_brew_path(repeat_brew_id: source_brew.id)

  assert_redirected_to new_brew_path
  assert_equal I18n.t("brews.new.repeat_source_unavailable"), flash[:alert]

  duplicate.open_bag!

  get new_brew_path(method: "espresso")

  assert_response :success
  assert_select "input[type=radio][name=?][value=?]",
    "brew[bean_id]",
    duplicate.id.to_s

  get new_brew_path(repeat_brew_id: source_brew.id)

  assert_response :success
  assert_select "input[type=radio][name=?][value=?][checked]",
    "brew[bean_id]",
    duplicate.id.to_s
end
~~~

- [ ] **Step 3: Run the lifecycle tests red**

Run:

~~~bash
env POSTGRES_PORT=55433 PARALLEL_WORKERS=1 bin/rails test test/models/bean_test.rb test/controllers/beans_controller_test.rb test/controllers/brews_controller_test.rb
~~~

Expected: duplicate assertions receive open status/current opened date; the create-without-status test remains open; the first Repeat Good Brew request succeeds instead of redirecting.

- [ ] **Step 4: Default new/create to stock**

In app/controllers/beans_controller.rb, replace new with:

~~~ruby
def new
  @bean = current_workspace.beans.new
  prepare_record_links(@bean)
end
~~~

In create, default only the create path to stock:

~~~ruby
attributes = bean_params
photos = Array(attributes.delete(:photos)).reject(&:blank?)
bag_status = extract_bag_status(attributes) || "stock"
@bean = current_workspace.beans.new(attributes)
@bean.apply_bag_status(bag_status)
~~~

Do not add the fallback inside update: an update request that omits bag_status must not silently reset a bag to stock.

- [ ] **Step 5: Reset duplicate lifecycle and copy the two URLs/public note**

In Bean#duplicate_attributes, use this complete hash:

~~~ruby
def duplicate_attributes
  {
    name:,
    roaster_name:,
    origin:,
    process:,
    roast_date:,
    roast_level:,
    tasting_notes:,
    bag_size_grams:,
    remaining_grams: bag_size_grams,
    opened_on: nil,
    finished_at: nil,
    archived_at: nil,
    purchase_source:,
    purchase_url: self.class.safe_http_url(purchase_url),
    coffee_origin_url: self.class.safe_http_url(coffee_origin_url),
    purchased_on:,
    purchase_price_cents:,
    rating:,
    notes:,
    public_note:,
    roast_type:,
    roast_degree:,
    blend_type:,
    decaffeinated:,
    grind_state:,
    country:,
    continent:,
    region:,
    farm:,
    farmer:,
    elevation:,
    variety:,
    harvested:,
    blend_percentage:,
    country_of_manufacturer:,
    manufacturer:,
    duplicated_from_bean: self
  }
end
~~~

Keep duplicate_for_new_bag! and its photo transaction unchanged; it already reattaches the source blobs and maps the primary blob to the duplicate attachment ID.

- [ ] **Step 6: Run the lifecycle tests green**

Run the Step 3 command.

Expected: all Bean model/controller and Brews controller tests pass with 0 failures and 0 errors.

- [ ] **Step 7: Commit the stock workflow**

Run:

~~~bash
git status --short
git add app/models/bean.rb app/controllers/beans_controller.rb test/models/bean_test.rb test/controllers/beans_controller_test.rb test/controllers/brews_controller_test.rb
git commit -m "Default new and duplicated beans to stock"
~~~

Expected: one commit containing only the stock and explicit-open behavior.

---

### Task 3: Polish Bean form examples, URLs, and rating layout

**Files:**

- Modify: app/controllers/beans_controller.rb:148-182
- Modify: app/views/beans/_form.html.erb:70-178
- Modify: config/locales/en.yml:209-260
- Modify: test/controllers/beans_controller_test.rb:273-358, 415-450

**Interfaces:**

- Consumes: Bean.coffee_origin_url, Bean::BAG_STATUSES, existing beans/rating_choices partial.
- Produces: bean[coffee_origin_url] permitted parameter; exact form examples; data-testid bean-form-rating-row containing blank plus 1..5 rating choices.

- [ ] **Step 1: Write form markup and persistence tests**

Extend the new-form test with:

~~~ruby
assert_select "select[name=?] option[value=stock][selected]", "bean[bag_status]"
assert_select "input[name=?][value='']", "bean[opened_on]"
assert_select "input[name=?][placeholder=?]", "bean[elevation]", "1100-1200m"
assert_select "input[name=?][placeholder=?]", "bean[variety]", "Arabica and/or Robusta"
assert_select "input[name=?][placeholder=?]", "bean[blend_percentage]", "50%/60%"
assert_select "input[name=?][placeholder=?]", "bean[process]", "washed or natural"
assert_select "input[type=url][name=?][placeholder=?]",
  "bean[coffee_origin_url]",
  "URL to original Coffee"
assert_select "label[for=bean_purchase_url]", "Purchase Website"
assert_select "input[type=url][name=?][placeholder=?]",
  "bean[purchase_url]",
  "URL to buy this bag again"
assert_select "label[for=bean_coffee_origin_url]", "Coffee Origin Website"
~~~

Extend the rating-control test with:

~~~ruby
assert_select "[data-testid=bean-form-rating-row] [data-testid=bean-rating-options]"
assert_select "[data-testid=bean-form-rating-row] input[type=radio][name=?]", "bean[rating]", count: 6
assert_select "[data-testid=bean-form-rating-row] .rn-rating-scale input[type=radio]", count: 5
assert_select "[data-testid=bean-form-rating-row]", text: I18n.t("beans.form.no_rating")
~~~

Add a persistence test:

~~~ruby
test "writer can save purchase and coffee origin websites separately" do
  sign_in_as(users(:one))

  post beans_path, params: {
    bean: {
      name: "Two Link Bag",
      bag_size_grams: "250",
      purchase_url: " https://shop.example/two-link ",
      coffee_origin_url: " https://origin.example/two-link "
    }
  }

  bean = workspaces(:household).beans.find_by!(name: "Two Link Bag")
  assert_redirected_to bean_path(bean)
  assert_equal "https://shop.example/two-link", bean.purchase_url
  assert_equal "https://origin.example/two-link", bean.coffee_origin_url
end
~~~

- [ ] **Step 2: Run the form tests red**

Run:

~~~bash
env POSTGRES_PORT=55433 PARALLEL_WORKERS=1 bin/rails test test/controllers/beans_controller_test.rb
~~~

Expected: failures for the opened date, exact examples, labels, missing coffee_origin_url input/permit, and missing full-width rating row.

- [ ] **Step 3: Permit the new field**

Add :coffee_origin_url immediately after :purchase_url in BeansController#bean_params:

~~~ruby
:purchase_source,
:purchase_url,
:coffee_origin_url,
:purchased_on,
~~~

- [ ] **Step 4: Replace the Roast section with a four-field row plus full-width rating**

In app/views/beans/_form.html.erb, replace the complete Roast section with:

~~~erb
<section data-testid="bean-form-section" data-section="roast" class="<%= section_class %>">
  <div>
    <h2 class="<%= section_title_class %>"><%= t("beans.form.sections.roast") %></h2>
  </div>

  <div class="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
    <div>
      <%= form.label :roast_date, t("beans.form.roast_date"), class: label_class %>
      <%= form.date_field :roast_date, class: input_class %>
    </div>

    <div>
      <%= form.label :roast_type, t("beans.form.roast_type"), class: label_class %>
      <%= form.select :roast_type, Bean::ROAST_TYPES.map { |type| [ type.humanize, type ] }, {}, class: input_class %>
    </div>

    <div>
      <%= form.label :roast_degree, t("beans.form.roast_degree"), class: label_class %>
      <%= form.text_field :roast_degree, inputmode: "decimal", class: input_class %>
    </div>

    <label class="flex items-center gap-3 rounded-2xl border border-rn-line bg-[var(--rn-surface-muted)] px-3 py-3 text-sm font-extrabold text-rn-ink lg:self-end">
      <%= form.check_box :decaffeinated, class: "h-4 w-4 rounded border-rn-line text-rn-ink" %>
      <%= t("beans.form.decaffeinated") %>
    </label>
  </div>

  <div data-testid="bean-form-rating-row">
    <%= form.label :rating, t("beans.form.rating"), class: label_class %>
    <%= render "beans/rating_choices", form: form %>
  </div>
</section>
~~~

- [ ] **Step 5: Render exact examples and the origin URL in Origin & process**

Replace the field loop in the Origin section with:

~~~erb
<div class="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
  <% %i[
    continent country region elevation variety blend_percentage process coffee_origin_url blend_type
    country_of_manufacturer manufacturer farm farmer harvested
  ].each do |field| %>
    <% placeholder = {
      elevation: t("beans.form.examples.elevation"),
      variety: t("beans.form.examples.variety"),
      blend_percentage: t("beans.form.examples.blend_percentage"),
      process: t("beans.form.examples.process")
    }[field] %>
    <div>
      <%= form.label field, t("beans.form.#{field}"), class: label_class %>
      <% if field == :blend_type %>
        <%= form.select :blend_type, Bean::BLEND_TYPES.map { |type| [ type.humanize, type ] }, {}, class: input_class %>
      <% elsif field == :coffee_origin_url %>
        <%= form.url_field :coffee_origin_url,
          placeholder: t("beans.form.examples.coffee_origin_url"),
          class: input_class %>
      <% else %>
        <%= form.text_field field, placeholder:, class: input_class %>
      <% end %>
    </div>
  <% end %>
</div>
~~~

Change the Purchase URL input to:

~~~erb
<div>
  <%= form.label :purchase_url, t("beans.form.purchase_url"), class: label_class %>
  <%= form.url_field :purchase_url,
    placeholder: t("beans.form.examples.purchase_url"),
    class: input_class %>
</div>
~~~

- [ ] **Step 6: Add the exact English copy**

In config/locales/en.yml under beans.form, change/add:

~~~yaml
coffee_origin_url: "Coffee Origin Website"
purchase_url: "Purchase Website"
examples:
  blend_percentage: "50%/60%"
  coffee_origin_url: "URL to original Coffee"
  elevation: "1100-1200m"
  process: "washed or natural"
  purchase_url: "URL to buy this bag again"
  variety: "Arabica and/or Robusta"
~~~

- [ ] **Step 7: Run the form tests green**

Run the Step 2 command.

Expected: BeansControllerTest passes with 0 failures and 0 errors; the rating control is outside the four-column Roast row and all six choices remain visible.

- [ ] **Step 8: Commit the form polish**

Run:

~~~bash
git status --short
git add app/controllers/beans_controller.rb app/views/beans/_form.html.erb config/locales/en.yml test/controllers/beans_controller_test.rb
git commit -m "Polish bean form fields and rating layout"
~~~

Expected: one commit containing the private form and exact copy.

---

### Task 4: Add focused, activity-audited Bean rating correction

**Files:**

- Modify: config/routes.rb:52-61
- Modify: app/controllers/beans_controller.rb:8-13, 20-27, 74-82, 129-139, 186-194
- Create: app/views/beans/_rating_correction.html.erb
- Modify: app/views/beans/show.html.erb:155-170
- Modify: config/locales/en.yml:193-405
- Modify: test/controllers/beans_controller_test.rb

**Interfaces:**

- Consumes: current_workspace_policy.write?; current_workspace.beans.find(id); with_workspace_activity; assert_activity_event; PublicBrewShareRefresher.refresh_for(bean); PublicBeanShareRefresher.refresh_for(bean).
- Produces: PATCH rating_bean_path(bean), accepting only bean[rating]; ActivityEvent action "bean.updated", category "beans_inventory", visibility "workspace"; successful response redirects to bean_path.

- [ ] **Step 1: Write route/form/allowlist/activity/public-refresh tests**

Add these tests to test/controllers/beans_controller_test.rb:

~~~ruby
test "writer sees focused bean rating correction" do
  sign_in_as(users(:one))
  bean = beans(:open_household)

  get bean_path(bean)

  assert_response :success
  assert_select "[data-testid=bean-rating-correction]"
  assert_select "form[action=?][method=post]", rating_bean_path(bean)
  assert_select "input[name=_method][value=patch]"
  assert_select "[data-testid=bean-rating-correction] input[type=radio][name=?]",
    "bean[rating]",
    count: 6
  assert_select "[data-testid=bean-rating-correction] input[type=radio][value=?][checked]",
    bean.rating.to_s
  assert_select "input[type=submit][value=?]", I18n.t("beans.show.save_rating")
end

test "focused rating updates only rating emits activity and refreshes direct public snapshots" do
  user = users(:one)
  sign_in_as(user)
  bean = beans(:open_household)
  brew = brews(:morning_espresso)
  public_brew_share = create_public_brew_share_for(brew)
  public_bean_share = bean.create_public_bean_share!(
    workspace: bean.workspace,
    created_by: user,
    updated_by: user,
    enabled: true,
    title: "Rating refresh",
    selected_photo_attachment_ids: [],
    snapshot: PublicBeanShareSnapshotBuilder.new(
      bean:,
      title: "Rating refresh",
      selected_photo_attachment_ids: []
    ).call
  )
  original = {
    remaining_grams: bean.remaining_grams,
    opened_on: bean.opened_on,
    purchase_price_cents: bean.purchase_price_cents,
    notes: bean.notes,
    workspace_id: bean.workspace_id
  }
  original_comparisons = public_bean_share.snapshot.fetch("comparisons").deep_dup
  bean_generated_at = public_bean_share.snapshot.fetch("generated_at")
  brew_generated_at = public_brew_share.snapshot.fetch("generated_at")

  event = nil
  travel_to(Time.current + 1.minute) do
    event = assert_activity_event(
      action: "bean.updated", workspace: bean.workspace, actor: user, subject: bean
    ) do
      patch rating_bean_path(bean), params: {
        bean: {
          rating: "5",
          bag_status: "archived",
          remaining_grams: "1",
          opened_on: "2020-01-01",
          purchase_price: "999",
          notes: "Ignored private note",
          workspace_id: workspaces(:other_household).id
        }
      }
    end
  end

  assert_redirected_to bean_path(bean)
  bean.reload
  assert_equal 5, bean.rating
  original.each { |attribute, value| assert_equal value, bean.public_send(attribute) }

  assert_equal bean.workspace, event.workspace
  assert_equal "beans_inventory", event.category
  assert_equal "workspace", event.visibility
  assert_operator public_bean_share.reload.snapshot.fetch("generated_at"), :>, bean_generated_at
  assert_operator public_brew_share.reload.snapshot.fetch("generated_at"), :>, brew_generated_at
  assert_equal original_comparisons, public_bean_share.snapshot.fetch("comparisons")
end

test "writer can clear focused bean rating" do
  sign_in_as(users(:one))
  bean = beans(:open_household)

  assert_activity_event(
    action: "bean.updated", workspace: bean.workspace, actor: users(:one), subject: bean
  ) do
    patch rating_bean_path(bean), params: { bean: { rating: "" } }
  end

  assert_redirected_to bean_path(bean)
  assert_nil bean.reload.rating
end

test "invalid focused rating rolls back without activity" do
  sign_in_as(users(:one))
  bean = beans(:open_household)
  original_rating = bean.rating

  assert_no_difference -> { ActivityEvent.count } do
    patch rating_bean_path(bean), params: { bean: { rating: "6" } }
  end

  assert_response :unprocessable_entity
  assert_select "[data-testid=bean-rating-correction]"
  assert_select "[data-testid=bean-rating-correction]", text: /must be in 1\.\.5/
  assert_equal original_rating, bean.reload.rating
end

test "activity failure rolls back the focused rating" do
  sign_in_as(users(:one))
  bean = beans(:open_household)
  brew_share = create_public_brew_share_for(brews(:morning_espresso))
  bean_share = bean.create_public_bean_share!(
    workspace: bean.workspace,
    created_by: users(:one),
    updated_by: users(:one),
    enabled: true,
    title: "Emitter rollback",
    selected_photo_attachment_ids: [],
    snapshot: PublicBeanShareSnapshotBuilder.new(
      bean:, title: "Emitter rollback", selected_photo_attachment_ids: []
    ).call
  )
  original_rating = bean.rating
  original_brew_snapshot = brew_share.snapshot.deep_dup
  original_bean_snapshot = bean_share.snapshot.deep_dup
  emitter_failure = lambda do |**|
    raise ActiveRecord::RecordInvalid.new(ActivityEvent.new)
  end

  travel_to(Time.current + 1.minute) do
    assert_no_difference -> { ActivityEvent.count } do
      Activity::Emitter.stub(:record!, emitter_failure) do
        patch rating_bean_path(bean), params: { bean: { rating: "5" } }
      end
    end
  end

  assert_response :unprocessable_entity
  assert_equal original_rating, bean.reload.rating
  assert_equal original_brew_snapshot, brew_share.reload.snapshot
  assert_equal original_bean_snapshot, bean_share.reload.snapshot
end

test "public snapshot refresh failure rolls back rating snapshots and activity" do
  sign_in_as(users(:one))
  bean = beans(:open_household)
  share = create_public_brew_share_for(brews(:morning_espresso))
  original_rating = bean.rating
  original_snapshot = share.snapshot.deep_dup
  refresh_failure = lambda do |*|
    raise ActiveRecord::RecordInvalid.new(PublicBeanShare.new)
  end

  assert_no_difference -> { ActivityEvent.count } do
    PublicBeanShareRefresher.stub(:refresh_for, refresh_failure) do
      patch rating_bean_path(bean), params: { bean: { rating: "5" } }
    end
  end

  assert_response :unprocessable_entity
  assert_equal original_rating, bean.reload.rating
  assert_equal original_snapshot, share.reload.snapshot
end

test "viewer cannot see or submit focused bean rating" do
  memberships(:member).update!(role: "viewer")
  viewer = users(:two)
  viewer.update!(active_workspace: workspaces(:household))
  sign_in_as(viewer)
  bean = beans(:open_household)

  get bean_path(bean)
  assert_response :success
  assert_select "[data-testid=bean-rating-correction]", count: 0

  assert_no_difference -> { ActivityEvent.count } do
    assert_no_changes -> { bean.reload.rating } do
      patch rating_bean_path(bean), params: { bean: { rating: "5" } }
    end
  end
  assert_redirected_to root_path
end

test "focused rating is scoped to active workspace" do
  sign_in_as(users(:one))
  foreign = beans(:other_workspace_open)

  assert_no_difference -> { ActivityEvent.count } do
    assert_no_changes -> { foreign.reload.rating } do
      patch rating_bean_path(foreign), params: { bean: { rating: "5" } }
    end
  end

  assert_response :not_found
end
~~~

- [ ] **Step 2: Run the focused-rating tests red**

Run:

~~~bash
env POSTGRES_PORT=55433 PARALLEL_WORKERS=1 bin/rails test test/controllers/beans_controller_test.rb
~~~

Expected: route helper/action/form failures; no bean rating ActivityEvent is emitted.

- [ ] **Step 3: Add the route and controller action**

Inside resources :beans in config/routes.rb add:

~~~ruby
patch :rating, on: :member
~~~

Add rating to both BeansController before-action lists:

~~~ruby
before_action :authorize_workspace_write!,
  only: %i[new create edit update rating finish close open_bag reopen duplicate destroy roaster_suggestions]
before_action :set_bean,
  only: %i[show edit update rating finish close open_bag reopen duplicate destroy]
~~~

Extract the show setup and add the focused action:

~~~ruby
def show
  prepare_show
end

def rating
  normalized_rating = rating_bean_params[:rating].presence

  with_workspace_activity(action: "bean.updated", subject: @bean) do
    @bean.update!(rating: normalized_rating)
    refresh_public_shares_for(@bean)
    true
  end

  redirect_to @bean, notice: t(".updated")
rescue ActiveRecord::RecordInvalid => error
  @bean.reload unless error.record.equal?(@bean)
  prepare_show
  render :show, status: :unprocessable_entity
end
~~~

Add these private methods:

~~~ruby
def rating_bean_params
  params.expect(bean: [ :rating ])
end

def prepare_show
  @bean_statistics = BeanStatistics.new(bean: @bean).call
  @grinder_tendency_first_brew = @bean.brews.espresso
    .includes(:grinder)
    .order(:occurred_at, :created_at)
    .first
  @grinder_setting_suggestions = load_grinder_setting_suggestions
end
~~~

The shared Activity wrapper is the mandatory outer transaction: the rating, both targeted public snapshot refreshers, and exactly one `bean.updated` ActivityEvent commit or roll back together. A Bean validation, refresher, or emitter failure writes none of them, and the exact-multiset helper rejects an accidental generic duplicate. Bean.rating cannot perturb peer comparison ranks, which are derived only from Brew ratings/channeling.

- [ ] **Step 4: Add the focused form partial**

Create app/views/beans/_rating_correction.html.erb:

~~~erb
<section data-testid="bean-rating-correction" class="mt-6 rounded-3xl border border-rn-line bg-rn-surface p-4 shadow-sm sm:p-5">
  <h2 class="text-sm font-extrabold uppercase tracking-[0.08em] text-rn-muted"><%= t("beans.show.adjust_rating") %></h2>
  <%= form_with model: bean,
    url: rating_bean_path(bean),
    method: :patch,
    class: "mt-4 grid gap-3 sm:grid-cols-[minmax(0,1fr)_auto] sm:items-end" do |form| %>
    <% if bean.errors.any? %>
      <div class="rounded-2xl border border-red-200 bg-red-50 p-3 text-sm font-semibold text-red-800 sm:col-span-2">
        <%= bean.errors.full_messages.to_sentence %>
      </div>
    <% end %>

    <div>
      <%= form.label :rating, t("beans.form.rating"), class: "block text-sm font-extrabold text-rn-muted" %>
      <%= render "beans/rating_choices", form: form %>
    </div>

    <%= form.submit t("beans.show.save_rating"),
      class: "rounded-2xl bg-[var(--rn-coffee)] px-5 py-3 text-sm font-extrabold text-[#fff8e8] shadow-lg hover:opacity-90" %>
  <% end %>
</section>
~~~

Render it in app/views/beans/show.html.erb immediately after the cost cards and before grinder tendency:

~~~erb
<%= render "beans/rating_correction", bean: @bean if current_workspace_policy.write? %>
~~~

- [ ] **Step 5: Add correction copy**

Under beans add:

~~~yaml
rating:
  updated: "Bean rating updated."
~~~

Under beans.show add:

~~~yaml
adjust_rating: "Adjust rating"
save_rating: "Save rating"
~~~

- [ ] **Step 6: Run focused-rating and activity integration green**

Run:

~~~bash
env POSTGRES_PORT=55433 PARALLEL_WORKERS=1 bin/rails test test/controllers/beans_controller_test.rb test/models/activity_event_test.rb test/services/activity/emitter_test.rb
~~~

Expected: all tests pass with 0 failures and 0 errors, including one bean.updated event per successful focused save and none for invalid/unauthorized saves.

- [ ] **Step 7: Commit focused correction**

Run:

~~~bash
git status --short
git add config/routes.rb app/controllers/beans_controller.rb app/views/beans/_rating_correction.html.erb app/views/beans/show.html.erb config/locales/en.yml test/controllers/beans_controller_test.rb
git commit -m "Add focused bean rating correction"
~~~

Expected: one commit containing the focused route, form, authorization, activity, and snapshot refresh.

---

### Task 5: Add workspace-safe Bean-filtered Coffees history

**Files:**

- Modify: app/controllers/brews_controller.rb:8-12, 211-231
- Modify: app/views/brews/index.html.erb:1-75
- Modify: app/views/beans/show.html.erb:288-312
- Modify: config/locales/en.yml:297-405, 432-449
- Modify: test/controllers/brews_controller_test.rb:2120-2290
- Modify: test/controllers/beans_controller_test.rb:940-1025

**Interfaces:**

- Consumes: GET coffees_path(filter:, view:, page:, bean_id:); current_workspace.beans.find(bean_id); HistoryPaginator.
- Produces: @history_bean -> Bean|nil; brew_history_scope constrained by bean_id; active chip data-testid coffee-bean-filter; remove link data-testid coffee-bean-filter-remove.

- [ ] **Step 1: Write Bean detail View all test**

Extend the Bean analytics controller test with:

~~~ruby
assert_select "[data-testid=bean-recent-brews-heading] a[href=?]",
  coffees_path(filter: "brews", bean_id: bean.id),
  text: I18n.t("beans.show.view_all_brews")
~~~

- [ ] **Step 2: Write filtered-history behavior and isolation tests**

Add to test/controllers/brews_controller_test.rb:

~~~ruby
test "bean filter shows that bean espresso and quick drip but no other coffees" do
  bean = beans(:open_household)
  espresso = brews(:morning_espresso)
  quick_drip = bean.workspace.brews.create!(
    user: users(:one),
    method: "quick_drip",
    bean:,
    brewer: equipment(:household_brewer),
    grinder: equipment(:household_grinder),
    machine_cups: 6,
    bean_weight_grams: 30
  )
  other_brew = bean.workspace.brews.create!(
    user: users(:one),
    method: "espresso",
    bean: beans(:second_open_household),
    grinder: equipment(:household_grinder),
    machine: equipment(:household_machine),
    bean_weight_grams: 18
  )
  external = bean.workspace.external_coffees.create!(
    user: users(:one),
    drink_type: "Cortado"
  )
  sign_in_as(users(:one))

  get coffees_path, params: { filter: "brews", bean_id: bean.id }

  assert_response :success
  assert_select "[data-testid=coffee-filter-brews][aria-current=page]"
  assert_select "[data-testid=coffee-bean-filter]", text: /#{Regexp.escape(bean.display_name)}/
  assert_select "a[href=?]", brew_path(espresso)
  assert_select "a[href=?]", brew_path(quick_drip)
  assert_select "a[href=?]", brew_path(other_brew), count: 0
  assert_select "a[href=?]", external_coffee_path(external), count: 0
end

test "bean filter persists through view compatible filters and pagination" do
  bean = beans(:open_household)
  21.times do |index|
    bean.workspace.brews.create!(
      user: users(:one),
      method: index.even? ? "espresso" : "quick_drip",
      bean:,
      grinder: equipment(:household_grinder),
      machine: index.even? ? equipment(:household_machine) : nil,
      brewer: index.odd? ? equipment(:household_brewer) : nil,
      machine_cups: index.odd? ? 6 : nil,
      bean_weight_grams: 18,
      occurred_at: Time.zone.local(2026, 6, 1, 12) - index.minutes
    )
  end
  sign_in_as(users(:one))

  get coffees_path, params: { filter: "brews", bean_id: bean.id, view: "hero" }

  assert_response :success
  assert_select "a[href=?]", coffees_path(filter: "brews", bean_id: bean.id), text: I18n.t("brews.index.compact_view")
  assert_select "a[href=?]", coffees_path(filter: "brews", bean_id: bean.id, view: "hero"), text: I18n.t("brews.index.hero_view")
  assert_select "[data-testid=coffee-filter-all][href=?]",
    coffees_path(bean_id: bean.id, view: "hero")
  assert_select "[data-testid=coffee-filter-brews][href=?]",
    coffees_path(filter: "brews", bean_id: bean.id, view: "hero")
  assert_select "[data-testid=history-next-page][href=?]",
    coffees_path(filter: "brews", bean_id: bean.id, view: "hero", page: 2)

  get coffees_path, params: { filter: "brews", bean_id: bean.id, view: "hero", page: 2 }

  assert_response :success
  assert_select "[data-testid=coffee-bean-filter]"
  assert_select "[data-testid=history-previous-page][href=?]",
    coffees_path(filter: "brews", bean_id: bean.id, view: "hero", page: 1)
end

test "external filter link clears incompatible bean filter" do
  bean = beans(:open_household)
  sign_in_as(users(:one))

  get coffees_path, params: { filter: "brews", bean_id: bean.id, view: "hero" }

  external_link = css_select("[data-testid=coffee-filter-external]").first
  query = Rack::Utils.parse_nested_query(URI.parse(external_link.fetch("href")).query)
  assert_equal "external", query.fetch("filter")
  assert_equal "hero", query.fetch("view")
  assert_not query.key?("bean_id")

  get external_link.fetch("href")

  assert_response :success
  assert_select "[data-testid=coffee-filter-external][aria-current=page]"
  assert_select "[data-testid=coffee-bean-filter]", count: 0
end

test "active bean chip can be removed while preserving view and coffee type" do
  bean = beans(:open_household)
  sign_in_as(users(:one))

  get coffees_path, params: { filter: "brews", bean_id: bean.id, view: "hero" }

  assert_select "[data-testid=coffee-bean-filter-remove][href=?]",
    coffees_path(filter: "brews", view: "hero")
end

test "missing and foreign bean filters return not found" do
  sign_in_as(users(:one))

  get coffees_path, params: { filter: "brews", bean_id: Bean.maximum(:id) + 100_000 }
  assert_response :not_found

  get coffees_path, params: { filter: "brews", bean_id: beans(:other_workspace_open).id }
  assert_response :not_found
end
~~~

- [ ] **Step 3: Run filtered history tests red**

Run:

~~~bash
env POSTGRES_PORT=55433 PARALLEL_WORKERS=1 bin/rails test test/controllers/beans_controller_test.rb test/controllers/brews_controller_test.rb
~~~

Expected: View all/chip are absent, other Beans and External Coffees leak into the result, query links lose bean_id, and foreign/missing IDs do not return 404.

- [ ] **Step 4: Load and apply the Bean filter in BrewsController**

Replace index with:

~~~ruby
def index
  @brew_history_view = params[:view] == "hero" ? "hero" : "compact"
  @coffee_filter = params[:filter].presence_in(%w[all brews external]) || "all"
  @history_bean = history_bean_from_params
  @history_bean = nil if @coffee_filter == "external"
  @brew_history = HistoryPaginator.new(coffee_history_scope, page: params[:page])
end
~~~

Add:

~~~ruby
def history_bean_from_params
  return if params[:bean_id].blank?

  current_workspace.beans.find(params[:bean_id])
end
~~~

Replace coffee_history_scope and brew_history_scope with:

~~~ruby
def coffee_history_scope
  return brew_history_scope if @history_bean

  case @coffee_filter
  when "brews"
    brew_history_scope
  when "external"
    external_coffee_history_scope
  else
    (brew_history_scope.to_a + external_coffee_history_scope.to_a)
      .sort_by { |record| [ record.occurred_at || Time.at(0), record.created_at || Time.at(0) ] }
      .reverse
  end
end

def brew_history_scope
  scope = current_workspace
    .brews
    .includes(
      :bean,
      :user,
      :grinder,
      :machine,
      :brewer,
      :public_brew_share,
      brew_preparation_tools: :preparation_tool
    )
  scope = scope.where(bean: @history_bean) if @history_bean
  scope.order(occurred_at: :desc, created_at: :desc)
end
~~~

Loading happens before External clears the instance variable. Therefore a manually supplied invalid/foreign bean_id still fails closed, while the generated External link omits bean_id and opens valid unfiltered External history.

- [ ] **Step 5: Preserve the Bean query and render its removable chip**

In app/views/brews/index.html.erb, replace the Compact/Hero parameter setup with:

~~~erb
<% view_filter_params = {} %>
<% view_filter_params[:filter] = @coffee_filter unless @coffee_filter == "all" %>
<% view_filter_params[:bean_id] = @history_bean.id if @history_bean %>
<%= link_to t(".compact_view"),
  coffees_path(view_filter_params),
  class: "rounded-lg px-3 py-2 text-sm font-extrabold #{@brew_history_view == "compact" ? "bg-[var(--rn-coffee)] text-[#fff8e8]" : "text-rn-muted hover:text-rn-ink"}" %>
<%= link_to t(".hero_view"),
  coffees_path(view_filter_params.merge(view: "hero")),
  class: "rounded-lg px-3 py-2 text-sm font-extrabold #{@brew_history_view == "hero" ? "bg-[var(--rn-coffee)] text-[#fff8e8]" : "text-rn-muted hover:text-rn-ink"}" %>
~~~

Replace the Coffee type filter parameter block with:

~~~erb
<% filter_view_params = @brew_history_view == "hero" ? { view: "hero" } : {} %>
<% { "all" => t(".filter_all"), "brews" => t(".filter_brews"), "external" => t(".filter_external") }.each do |filter, label| %>
  <% filter_params = filter_view_params.dup %>
  <% filter_params[:filter] = filter unless filter == "all" %>
  <% filter_params[:bean_id] = @history_bean.id if @history_bean && filter != "external" %>
  <%= link_to label,
    coffees_path(filter_params),
    data: { testid: "coffee-filter-#{filter}" },
    aria: (@coffee_filter == filter ? { current: "page" } : {}),
    class: "rounded-lg px-3 py-2 text-sm font-extrabold #{@coffee_filter == filter ? "bg-[var(--rn-accent-strong)] text-[#f8faf6]" : "text-rn-muted hover:text-rn-ink"}" %>
<% end %>
~~~

Immediately below the page header controls, add:

~~~erb
<% if @history_bean %>
  <% clear_bean_params = {} %>
  <% clear_bean_params[:filter] = @coffee_filter unless @coffee_filter == "all" %>
  <% clear_bean_params[:view] = "hero" if @brew_history_view == "hero" %>
  <div data-testid="coffee-bean-filter" class="mt-5 inline-flex max-w-full items-center gap-2 rounded-full border border-rn-line bg-rn-surface px-3 py-2 text-sm font-extrabold text-rn-ink shadow-sm">
    <span class="truncate"><%= t(".bean_filter", bean: @history_bean.display_name) %></span>
    <%= link_to t(".remove_bean_filter"),
      coffees_path(clear_bean_params),
      data: { testid: "coffee-bean-filter-remove" },
      aria: { label: t(".remove_bean_filter_for", bean: @history_bean.display_name) },
      class: "shrink-0 rounded-full px-1 text-rn-muted hover:text-rn-ink" %>
  </div>
<% end %>
~~~

Add the Bean to pagination preservation:

~~~erb
<% history_params[:bean_id] = @history_bean.id if @history_bean %>
~~~

- [ ] **Step 6: Add View all to Recent brews**

Replace the recent heading in app/views/beans/show.html.erb with:

~~~erb
<div data-testid="bean-recent-brews-heading" class="flex items-center justify-between gap-3">
  <h3 class="text-sm font-semibold uppercase text-stone-600"><%= t(".recent_brews") %></h3>
  <%= link_to t(".view_all_brews"),
    coffees_path(filter: "brews", bean_id: @bean.id),
    class: "text-sm font-bold text-stone-700 hover:underline" %>
</div>
~~~

Keep bean-recent-brews directly below it.

- [ ] **Step 7: Add history copy**

Under brews.index:

~~~yaml
bean_filter: "Bean: %{bean}"
remove_bean_filter: "×"
remove_bean_filter_for: "Remove Bean filter for %{bean}"
~~~

Under beans.show:

~~~yaml
view_all_brews: "View all"
~~~

- [ ] **Step 8: Run filtered history tests green**

Run the Step 3 command.

Expected: all BeansControllerTest and BrewsControllerTest cases pass; target Espresso and Quick Drip rows appear; other Beans/External do not; Bean persists through Compact/Hero, All/Brews, and pagination; External removes it; invalid/foreign IDs return 404.

- [ ] **Step 9: Commit Bean-filtered history**

Run:

~~~bash
git status --short
git add app/controllers/brews_controller.rb app/views/brews/index.html.erb app/views/beans/show.html.erb config/locales/en.yml test/controllers/brews_controller_test.rb test/controllers/beans_controller_test.rb
git commit -m "Add bean-filtered coffees history"
~~~

Expected: one commit containing only navigation and history filtering.

---

### Task 6: Synthesize two private Bean URL chips above RecordLinks

**Files:**

- Modify: app/helpers/beans_helper.rb:1-21
- Modify: app/views/shared/_record_links_list.html.erb:1-18
- Modify: app/views/beans/show.html.erb:3, 338-376
- Modify: config/locales/en.yml:297-405
- Modify: test/helpers/beans_helper_test.rb
- Modify: test/controllers/beans_controller_test.rb:730-794, 920-940

**Interfaces:**

- Consumes: Bean.safe_http_url; Bean#record_links.ordered.
- Produces: bean_private_system_links(bean) -> Array<Hash> with keys label, url, kind, visibility, testid; shared record-links partial optional local system_links.

- [ ] **Step 1: Write helper and private presentation tests**

Add to test/helpers/beans_helper_test.rb:

~~~ruby
test "private system links expose separate safe purchase and origin entries" do
  bean = Bean.new(
    purchase_url: "https://shop.example/bean",
    coffee_origin_url: "https://origin.example/coffee"
  )

  assert_equal(
    [
      {
        label: "Purchase URL",
        url: "https://shop.example/bean",
        kind: "buy",
        visibility: "private",
        testid: "bean-system-purchase-url"
      },
      {
        label: "Origin Coffee URL",
        url: "https://origin.example/coffee",
        kind: "info",
        visibility: "private",
        testid: "bean-system-origin-url"
      }
    ],
    bean_private_system_links(bean)
  )
end

test "private system links omit blank and unsafe legacy urls" do
  bean = Bean.new(purchase_url: "", coffee_origin_url: nil)
  bean.purchase_url = "javascript:alert(1)"

  assert_empty bean_private_system_links(bean)
end
~~~

Add a controller rendering test:

~~~ruby
test "show synthesizes private url chips before normal record links without creating rows" do
  sign_in_as(users(:one))
  bean = beans(:open_household)
  bean.update!(
    purchase_url: "https://shop.example/bean",
    coffee_origin_url: "https://origin.example/coffee"
  )
  record_link = bean.record_links.create!(
    label: "Private cupping",
    url: "https://notes.example/cupping",
    kind: "info",
    visibility: "private",
    position: 10
  )

  assert_no_difference -> { bean.record_links.count } do
    get bean_path(bean)
  end

  assert_response :success
  assert_select "[data-testid=record-links-list]"
  assert_select "a[data-testid=bean-system-purchase-url][href=?]", bean.purchase_url, text: /Purchase URL/
  assert_select "a[data-testid=bean-system-origin-url][href=?]", bean.coffee_origin_url, text: /Origin Coffee URL/
  assert_select "a[data-testid=bean-system-purchase-url]", text: /Buy/
  assert_select "a[data-testid=bean-system-origin-url]", text: /Info/
  assert_select "a[data-testid=bean-system-purchase-url]", text: /Private/
  assert_select "a[data-testid=bean-system-origin-url]", text: /Private/
  assert_select "a[href=?]", record_link.url, text: /Private cupping/
  assert_appears_before "bean-system-purchase-url", "bean-system-origin-url"
  assert_appears_before "bean-system-origin-url", "Private cupping"
  assert_select "[data-testid=bean-detail-purchase-url]", count: 0
end
~~~

Replace the assertions in the existing Rebuy rendering test with:

~~~ruby
assert_select "a[data-testid=bean-rebuy-link][href=?][target=_blank][rel=noopener]", bean.purchase_url
assert_select "a[data-testid=bean-system-purchase-url][href=?]", bean.purchase_url
assert_select "[data-testid=bean-detail-purchase-url]", count: 0
assert_select "body", text: /https:\/\/example.com\/beans\/house-blend\?ref=private/, count: 0
~~~

Replace the Details-row assertions in the legacy-invalid-URL test with:

~~~ruby
assert_select "a[data-testid=bean-rebuy-link]", count: 0
assert_select "a[data-testid=bean-system-purchase-url]", count: 0
assert_select "[data-testid=bean-detail-purchase-url]", count: 0
assert_select "body", text: /javascript:alert\('bean'\)/, count: 0
~~~

In the existing quick-open/legacy-invalid-URL test, replace its Details-row assertion with:

~~~ruby
assert_select "a[data-testid=bean-system-purchase-url]", count: 0
assert_select "[data-testid=bean-detail-purchase-url]", count: 0
~~~

- [ ] **Step 2: Run link tests red**

Run:

~~~bash
env POSTGRES_PORT=55433 PARALLEL_WORKERS=1 bin/rails test test/helpers/beans_helper_test.rb test/controllers/beans_controller_test.rb
~~~

Expected: helper missing; system chips missing; Purchase Website still appears in Details.

- [ ] **Step 3: Build safe presentation entries**

Add to app/helpers/beans_helper.rb:

~~~ruby
def bean_private_system_links(bean)
  [
    bean_private_system_link(
      bean.purchase_url,
      label: t("beans.show.system_links.purchase"),
      kind: "buy",
      testid: "bean-system-purchase-url"
    ),
    bean_private_system_link(
      bean.coffee_origin_url,
      label: t("beans.show.system_links.origin"),
      kind: "info",
      testid: "bean-system-origin-url"
    )
  ].compact
end

private
  def bean_private_system_link(url, label:, kind:, testid:)
    safe_url = Bean.safe_http_url(url)
    return if safe_url.blank?

    {
      label:,
      url: safe_url,
      kind:,
      visibility: "private",
      testid:
    }
  end
~~~

Keep bean_purchase_url_href as the Rebuy compatibility helper.

- [ ] **Step 4: Extend the shared list without creating model rows**

Replace app/views/shared/_record_links_list.html.erb with:

~~~erb
<% system_links = Array(local_assigns[:system_links]) %>
<% links = record.record_links.ordered.to_a %>
<% if system_links.any? || links.any? %>
  <section data-testid="record-links-list" class="<%= local_assigns.fetch(:section_class, "mt-6 rounded-lg border border-stone-200 bg-white p-5 shadow-sm") %>">
    <h2 class="<%= local_assigns.fetch(:title_class, "text-lg font-semibold text-stone-950") %>"><%= t("shared.record_links.title") %></h2>
    <div class="mt-3 flex flex-wrap gap-2">
      <% system_links.each do |link| %>
        <%= link_to link.fetch(:url),
          target: "_blank",
          rel: "noopener",
          data: { testid: link.fetch(:testid) },
          class: "inline-flex items-center gap-2 rounded-md border border-stone-300 bg-white px-3 py-2 text-sm font-bold text-stone-950 underline decoration-stone-300 underline-offset-4 hover:bg-stone-50 hover:decoration-stone-950" do %>
          <span aria-hidden="true">-&gt;</span>
          <span><%= link.fetch(:label) %></span>
          <span class="rounded-full bg-stone-100 px-2 py-0.5 text-[0.65rem] font-black uppercase text-stone-600"><%= t("shared.record_links.kinds.#{link.fetch(:kind)}") %></span>
          <span data-testid="record-link-visibility" class="rounded-full bg-stone-100 px-2 py-0.5 text-[0.65rem] font-black uppercase text-stone-600"><%= t("shared.record_links.visibilities.#{link.fetch(:visibility)}") %></span>
        <% end %>
      <% end %>

      <% links.each do |link| %>
        <%= link_to link.url, target: "_blank", rel: "noopener", class: "inline-flex items-center gap-2 rounded-md border border-stone-300 bg-white px-3 py-2 text-sm font-bold text-stone-950 underline decoration-stone-300 underline-offset-4 hover:bg-stone-50 hover:decoration-stone-950" do %>
          <span aria-hidden="true">-&gt;</span>
          <span><%= link.label %></span>
          <span class="rounded-full bg-stone-100 px-2 py-0.5 text-[0.65rem] font-black uppercase text-stone-600"><%= t("shared.record_links.kinds.#{link.kind}") %></span>
          <span data-testid="record-link-visibility" class="rounded-full bg-stone-100 px-2 py-0.5 text-[0.65rem] font-black uppercase text-stone-600"><%= t("shared.record_links.visibilities.#{link.visibility}") %></span>
        <% end %>
      <% end %>
    </div>
  </section>
<% end %>
~~~

- [ ] **Step 5: Use the system entries on Bean detail and remove the duplicate Details URL**

Replace the Bean render call with:

~~~erb
<%= render "shared/record_links_list",
  record: @bean,
  system_links: bean_private_system_links(@bean) %>
~~~

Delete the entire bean-detail-purchase-url dt/dd block from Details. Keep the purchase_url_href local and header Rebuy action; Coffee Origin Website never powers Rebuy.

Add:

~~~yaml
system_links:
  origin: "Origin Coffee URL"
  purchase: "Purchase URL"
~~~

- [ ] **Step 6: Run link tests green**

Run the Step 2 command.

Expected: both system chips render first with BUY/INFO and PRIVATE visual badges, normal RecordLinks follow, GET creates no rows, unsafe legacy values render nowhere, and Rebuy still uses only purchase_url.

- [ ] **Step 7: Commit private link presentation**

Run:

~~~bash
git status --short
git add app/helpers/beans_helper.rb app/views/shared/_record_links_list.html.erb app/views/beans/show.html.erb config/locales/en.yml test/helpers/beans_helper_test.rb test/controllers/beans_controller_test.rb
git commit -m "Show private bean website chips"
~~~

Expected: one commit containing synthesized presentation only; no RecordLink data migration or synchronization.

---

### Task 7: Carry origin URLs through private export/restore and lock public privacy

**Files:**

- Modify: app/services/workspace_export_builder.rb:58-108
- Modify: app/services/workspace_csv_export_builder.rb:4-10
- Modify: app/services/instance_backup_restorer.rb:171-221
- Modify: app/services/public_brew_share_snapshot_builder.rb:72-91
- Modify: app/views/public_brew_pages/_product_section.html.erb:28-51
- Modify: test/services/workspace_export_builder_test.rb
- Modify: test/services/workspace_csv_export_builder_test.rb
- Modify: test/services/instance_backup_builders_test.rb
- Modify: test/services/instance_backup_restore_test.rb
- Modify: test/services/beanconqueror_import_test.rb
- Modify: test/services/public_bean_share_snapshot_builder_test.rb
- Modify: test/services/public_brew_share_snapshot_builder_test.rb
- Modify: test/services/public_recipe_share_snapshot_builder_test.rb
- Modify: test/controllers/public_brew_pages_controller_test.rb

**Interfaces:**

- Consumes: WorkspaceExportBuilder beans payload; WorkspaceCsvExportBuilder::BEAN_COLUMNS; InstanceBackupRestorer#restore_beans; Bean.safe_http_url.
- Produces: private JSON/CSV/readable backup key coffee_origin_url; backward-compatible restore when key absent; invalid restored URL -> nil.
- Removes: `purchase_price_cents` from newly built public Brew Bean snapshots and from public rendering, including stale snapshots that still carry the key.

- [ ] **Step 1: Write private export and restore tests**

In WorkspaceExportBuilderTest, extend the existing Bean setup and payload assertions with:

~~~ruby
bean.update!(
  purchase_url: "https://shop.example/house-blend",
  coffee_origin_url: "https://origin.example/house-blend"
)

assert_equal "https://shop.example/house-blend", bean_payload.fetch(:purchase_url)
assert_equal "https://origin.example/house-blend", bean_payload.fetch(:coffee_origin_url)
~~~

In WorkspaceCsvExportBuilderTest, add this setup before building the CSV and add the assertions after locating exported:

~~~ruby
beans(:open_household).update!(
  purchase_url: "https://shop.example/house-blend",
  coffee_origin_url: "https://origin.example/house-blend"
)

assert_includes rows.headers, "purchase_url"
assert_includes rows.headers, "coffee_origin_url"
assert_equal "https://shop.example/house-blend", exported.fetch("purchase_url")
assert_equal "https://origin.example/house-blend", exported.fetch("coffee_origin_url")
~~~

In InstanceBackupBuildersTest, add this setup before building the readable payload, then assert the Bean payload contains it:

~~~ruby
beans(:open_household).update!(
  purchase_url: "https://shop.example/house-blend",
  coffee_origin_url: "https://origin.example/house-blend"
)

assert_equal "https://shop.example/house-blend",
  bean_payload.fetch(:purchase_url)
assert_equal "https://origin.example/house-blend",
  bean_payload.fetch(:coffee_origin_url)
~~~

In the full restore test, add both keys to source_bean.update!:

~~~ruby
purchase_url: "https://shop.example/house-blend",
coffee_origin_url: "https://origin.example/house-blend",
~~~

Add both values to original:

~~~ruby
purchase_url: source_bean.purchase_url,
coffee_origin_url: source_bean.coffee_origin_url,
~~~

After loading restored_bean, assert:

~~~ruby
assert_equal original.fetch(:purchase_url), restored_bean.purchase_url
assert_equal original.fetch(:coffee_origin_url), restored_bean.coffee_origin_url
~~~

Rename the unsafe restore test to "restorer drops invalid bean website urls instead of failing restore", assign its Bean row once, and mutate both keys:

~~~ruby
row = household.fetch("beans").find { |bean| bean.fetch("name") == source_bean_name }
row["purchase_url"] = "javascript:alert('purchase')"
row["coffee_origin_url"] = "data:text/html,origin"
~~~

Then assert:

~~~ruby
assert_nil restored_bean.purchase_url
assert_nil restored_bean.coffee_origin_url
~~~

Add this complete legacy-archive regression:

~~~ruby
test "restores legacy bean rating zero and an archive without coffee origin url" do
  source_bean_name = beans(:open_household).name
  source_workspace_name = workspaces(:household).name
  archive_bytes = mutate_backup_payload(
    InstanceBackupArchiveBuilder.new(generated_at: Time.zone.parse("2026-05-28 12:00:00")).call
  ) do |payload|
    household = payload.fetch("workspaces").find do |workspace_payload|
      workspace_payload.dig("workspace", "name") == source_workspace_name
    end
    row = household.fetch("beans").find { |bean| bean.fetch("name") == source_bean_name }
    row["rating"] = 0
    row.delete("coffee_origin_url")
  end

  empty_instance!
  InstanceBackupRestorer.new(archive_bytes).call

  restored_bean = Bean.find_by!(name: source_bean_name)
  assert_nil restored_bean.rating
  assert_nil restored_bean.coffee_origin_url
end
~~~

This covers archives created before `coffee_origin_url` existed and before rating zero became invalid.

- [ ] **Step 2: Run portability tests red**

Run:

~~~bash
env POSTGRES_PORT=55433 PARALLEL_WORKERS=1 bin/rails test test/services/workspace_export_builder_test.rb test/services/workspace_csv_export_builder_test.rb test/services/instance_backup_builders_test.rb test/services/instance_backup_restore_test.rb
~~~

Expected: coffee_origin_url is missing from JSON/CSV/readable backup and restore returns nil even for the valid origin URL.

- [ ] **Step 3: Add the field to private JSON, CSV, and restore**

In WorkspaceExportBuilder#beans_payload add next to purchase_url:

~~~ruby
purchase_url: bean.purchase_url,
coffee_origin_url: bean.coffee_origin_url,
~~~

In WorkspaceCsvExportBuilder::BEAN_COLUMNS add coffee_origin_url immediately after purchase_url:

~~~ruby
purchase_source purchase_url coffee_origin_url purchased_on purchase_price notes created_at updated_at
~~~

No bean_value branch is needed because string fields use public_send.

In InstanceBackupRestorer#restore_beans use safe validation for both:

~~~ruby
purchase_url: Bean.safe_http_url(row["purchase_url"]),
coffee_origin_url: Bean.safe_http_url(row["coffee_origin_url"]),
rating: [ 0, "0" ].include?(row["rating"]) ? nil : row["rating"],
~~~

Replace the existing `rating: row["rating"]` assignment rather than adding a duplicate key. Using `row["coffee_origin_url"]` rather than `fetch` keeps older v1 archives restorable; normalize only numeric/string zero so malformed nonzero values still fail validation and roll back the restore.

- [ ] **Step 4: Run portability tests green**

Run the Step 2 command.

Expected: all four service test files pass; valid URLs round-trip; invalid URLs become nil; missing legacy key remains valid.

- [ ] **Step 5: Lock Beanconqueror compatibility**

In the supported Beanconqueror import test add:

~~~ruby
assert_equal "https://example.test/beans/bc-espresso", bean.purchase_url
assert_nil bean.coffee_origin_url
~~~

Run:

~~~bash
env POSTGRES_PORT=55433 PARALLEL_WORKERS=1 bin/rails test test/services/beanconqueror_import_test.rb
~~~

Expected: PASS immediately; BEANS.url still maps only to Purchase Website.

- [ ] **Step 6: Add negative assertions to every public Bean-bearing snapshot**

In the main PublicBeanShareSnapshotBuilder test, update the Bean before building the snapshot:

~~~ruby
bean.update!(
  purchase_url: "https://private-purchase.example/bean-secret",
  coffee_origin_url: "https://private-origin.example/coffee-secret"
)
~~~

and assert:

~~~ruby
assert_not_includes snapshot.to_json, "private-purchase.example"
assert_not_includes snapshot.to_json, "private-origin.example"
assert_not snapshot.fetch("bean").key?("purchase_url")
assert_not snapshot.fetch("bean").key?("coffee_origin_url")
~~~

In the main PublicBrewShareSnapshotBuilder test, update the Brew's Bean before building the snapshot:

~~~ruby
brew.bean.update!(
  purchase_url: "https://private-purchase.example/brew-secret",
  coffee_origin_url: "https://private-origin.example/brew-secret"
)
~~~

Then add these distinct negative assertions:

~~~ruby
assert_not_includes snapshot.to_json, "private-purchase.example"
assert_not_includes snapshot.to_json, "private-origin.example"
assert_not snapshot.fetch("bean").key?("purchase_url")
assert_not snapshot.fetch("bean").key?("coffee_origin_url")
assert_not snapshot.fetch("bean").key?("purchase_price_cents")
~~~

Replace the existing positive `purchase_price_cents` assertion with the negative assertion above. Remove `"purchase_price_cents" => bean.purchase_price_cents` from `PublicBrewShareSnapshotBuilder#bean_payload`.

In `PublicBrewPagesControllerTest`, extend the stale-cost privacy regression so the Bean snapshot also carries a recognizable price:

~~~ruby
snapshot["bean"] = {
  "name" => "Secret-price bean",
  "purchase_price_cents" => 987_654
}
share.update!(snapshot:)

get public_brew_page_path(share.token)

assert_response :success
assert_select "body", text: /Secret-price bean/
assert_no_match "€9,876.54", response.body
~~~

Delete the `purchase_price_cents` branch from `app/views/public_brew_pages/_product_section.html.erb`. This makes already-stored snapshots safe immediately, without requiring a refresh or mutating historical data.

In PublicRecipeShareSnapshotBuilderTest add:

~~~ruby
test "does not copy direct bean websites from recipe profiles" do
  recipe = recipes(:household_recipe)
  recipe.update!(
    profile: recipe.profile.deep_merge(
      "bean" => {
        "name" => "Safe bean name",
        "purchase_url" => "https://private-purchase.example/recipe-secret",
        "coffee_origin_url" => "https://private-origin.example/recipe-secret"
      }
    )
  )

  snapshot = PublicRecipeShareSnapshotBuilder.new(
    recipe:,
    title: "Shared recipe",
    selected_photo_attachment_ids: []
  ).call

  assert_equal "Safe bean name", snapshot.dig("bean", "name")
  assert_not_includes snapshot.to_json, "private-purchase.example"
  assert_not_includes snapshot.to_json, "private-origin.example"
  assert_not snapshot.fetch("bean").key?("purchase_url")
  assert_not snapshot.fetch("bean").key?("coffee_origin_url")
end
~~~

Run:

~~~bash
env POSTGRES_PORT=55433 PARALLEL_WORKERS=1 bin/rails test test/services/public_bean_share_snapshot_builder_test.rb test/services/public_brew_share_snapshot_builder_test.rb test/services/public_recipe_share_snapshot_builder_test.rb test/controllers/public_brew_pages_controller_test.rb
~~~

Expected: direct-URL assertions PASS because the existing explicit public allowlists exclude them; the new cost assertion fails until the builder and public product partial stop copying/rendering Bean purchase cost. After those two removals, all four files PASS.

- [ ] **Step 7: Commit portability and privacy**

Run:

~~~bash
git status --short
git add app/services/workspace_export_builder.rb app/services/workspace_csv_export_builder.rb app/services/instance_backup_restorer.rb app/services/public_brew_share_snapshot_builder.rb app/views/public_brew_pages/_product_section.html.erb test/services/workspace_export_builder_test.rb test/services/workspace_csv_export_builder_test.rb test/services/instance_backup_builders_test.rb test/services/instance_backup_restore_test.rb test/services/beanconqueror_import_test.rb test/services/public_bean_share_snapshot_builder_test.rb test/services/public_brew_share_snapshot_builder_test.rb test/services/public_recipe_share_snapshot_builder_test.rb test/controllers/public_brew_pages_controller_test.rb
git commit -m "Export and restore private bean origin URLs"
~~~

Expected: one commit with private portability plus public negative tests; no public snapshot payload gains a URL or Bean purchase cost, and stale public snapshots cannot render the old cost key.

---

### Task 8: Make Cost per shot Espresso-only and explain it accessibly

**Files:**

- Modify: app/models/bean.rb:255-270
- Modify: app/views/beans/show.html.erb:156-174
- Modify: config/locales/en.yml:319-330
- Modify: test/models/bean_test.rb:446-494
- Modify: test/controllers/beans_controller_test.rb:730-779

**Interfaces:**

- Consumes: Bean#brews.espresso, Brew#bean_weight_grams, Bean#purchase_price, Bean#bag_size_grams.
- Produces: Bean#average_espresso_bean_weight_grams -> BigDecimal|nil; Bean#shot_weight_for_cost -> BigDecimal; Bean#cost_per_shot -> BigDecimal|nil; tooltip IDs bean-cost-per-shot-info and bean-cost-per-shot-explanation.

- [ ] **Step 1: Replace cost tests with the approved formula**

Replace the current average-dose cost test and extend the fallback coverage with:

~~~ruby
test "cost per shot averages bean in across espresso brews only" do
  bean = workspaces(:household).beans.create!(
    name: "Espresso Cost Bag",
    bag_size_grams: 250,
    remaining_grams: 250,
    opened_on: Date.current,
    purchase_price_cents: 1000
  )
  [ 18, 20 ].each do |bean_in|
    bean.brews.create!(
      workspace: bean.workspace,
      user: users(:one),
      method: "espresso",
      grinder: equipment(:household_grinder),
      machine: equipment(:household_machine),
      bean_weight_grams: bean_in,
      ground_weight_grams: bean_in - 1,
      dose_grams: bean_in - 2,
      beverage_grams: 45
    )
  end
  bean.brews.create!(
    workspace: bean.workspace,
    user: users(:one),
    method: "quick_drip",
    grinder: equipment(:household_grinder),
    brewer: equipment(:household_brewer),
    machine_cups: 6,
    bean_weight_grams: 60
  )

  assert_equal 19.to_d, bean.average_espresso_bean_weight_grams
  assert_equal 0.76.to_d, bean.cost_per_shot
end

test "cost per shot charges full bean in without double counting ground out or dose" do
  bean = workspaces(:household).beans.create!(
    name: "Waste Cost Bag",
    bag_size_grams: 250,
    remaining_grams: 250,
    opened_on: Date.current,
    purchase_price_cents: 1000
  )
  bean.brews.create!(
    workspace: bean.workspace,
    user: users(:one),
    method: "espresso",
    grinder: equipment(:household_grinder),
    machine: equipment(:household_machine),
    bean_weight_grams: 20,
    ground_weight_grams: 19,
    dose_grams: 17,
    beverage_grams: 42
  )

  assert_equal 20.to_d, bean.shot_weight_for_cost
  assert_equal 0.8.to_d, bean.cost_per_shot
end

test "cost per shot uses eighteen grams before espresso and ignores manual corrections" do
  bean = workspaces(:household).beans.create!(
    name: "Fresh Cost Bag",
    bag_size_grams: 250,
    remaining_grams: 250,
    opened_on: Date.current,
    purchase_price_cents: 1000
  )

  assert_equal 18.to_d, bean.shot_weight_for_cost
  assert_equal 0.72.to_d, bean.cost_per_shot

  adjustment = bean.inventory_adjustments.new(
    workspace: bean.workspace,
    user: users(:one),
    reason: "manual",
    delta_grams: -25,
    note: "Count correction"
  )
  assert adjustment.save_with_inventory_update

  assert_equal 18.to_d, bean.reload.shot_weight_for_cost
  assert_equal 0.72.to_d, bean.cost_per_shot
end
~~~

- [ ] **Step 2: Run cost model tests red**

Run:

~~~bash
env POSTGRES_PORT=55433 PARALLEL_WORKERS=1 bin/rails test test/models/bean_test.rb
~~~

Expected: the Quick Drip weight distorts the average and average_espresso_bean_weight_grams is undefined.

- [ ] **Step 3: Implement the Espresso-only Bean In average**

Replace average_logged_bean_weight_grams and shot_weight_for_cost in app/models/bean.rb with:

~~~ruby
def average_espresso_bean_weight_grams
  weights = brews.espresso
    .where.not(bean_weight_grams: nil)
    .pluck(:bean_weight_grams)
    .map(&:to_d)
  return if weights.empty?

  (weights.sum / weights.size).round(2)
end

def shot_weight_for_cost
  average_espresso_bean_weight_grams || DEFAULT_SHOT_COST_GRAMS
end
~~~

Leave cost_per_shot rounding unchanged:

~~~ruby
def cost_per_shot
  return if purchase_price.blank? || bag_size_grams.blank? || bag_size_grams.to_d <= 0

  ((purchase_price.to_d / bag_size_grams.to_d) * shot_weight_for_cost).round(2)
end
~~~

- [ ] **Step 4: Run cost model tests green**

Run the Step 2 command.

Expected: BeanTest passes; 60g Quick Drip has no effect; the 20g/19g/17g example costs exactly the price of 20g; manual -25g has no effect; fallback remains 18g.

- [ ] **Step 5: Write accessible explanation markup test**

Extend the Bean show cost test with:

~~~ruby
assert_select "button[data-testid=bean-cost-per-shot-info][type=button][aria-describedby=bean-cost-per-shot-explanation][aria-label=?]",
  I18n.t("beans.show.cost_per_shot_info_label")
assert_select "#bean-cost-per-shot-explanation[role=tooltip]",
  text: I18n.t("beans.show.cost_per_shot_explanation")

button = css_select("[data-testid=bean-cost-per-shot-info]").first
tooltip = css_select("#bean-cost-per-shot-explanation").first
assert_includes button.parent["class"], "group"
assert_includes tooltip["class"], "group-hover:opacity-100"
assert_includes tooltip["class"], "group-focus-within:opacity-100"
~~~

- [ ] **Step 6: Run the markup test red**

Run:

~~~bash
env POSTGRES_PORT=55433 PARALLEL_WORKERS=1 bin/rails test test/controllers/beans_controller_test.rb
~~~

Expected: bean-cost-per-shot-info and bean-cost-per-shot-explanation are absent.

- [ ] **Step 7: Add a hover-and-focus information control**

Inside the cost_metrics heading in app/views/beans/show.html.erb, replace the h2 with:

~~~erb
<div class="flex items-center gap-1.5">
  <h2 class="text-sm font-semibold uppercase text-stone-600"><%= t(".#{field}") %></h2>
  <% if field == :cost_per_shot %>
    <span class="group relative inline-flex">
      <button
        type="button"
        data-testid="bean-cost-per-shot-info"
        aria-label="<%= t(".cost_per_shot_info_label") %>"
        aria-describedby="bean-cost-per-shot-explanation"
        class="inline-flex h-6 w-6 items-center justify-center rounded-full border border-stone-300 text-xs font-black normal-case text-stone-600 focus:outline-2 focus:outline-offset-2 focus:outline-[var(--rn-accent-strong)]">
        <span aria-hidden="true">i</span>
      </button>
      <span
        id="bean-cost-per-shot-explanation"
        role="tooltip"
        class="pointer-events-none absolute right-0 top-8 z-20 w-72 max-w-[calc(100vw-3rem)] rounded-lg bg-stone-950 p-3 text-left text-xs font-semibold normal-case leading-relaxed text-white opacity-0 shadow-lg transition-opacity group-hover:opacity-100 group-focus-within:opacity-100">
        <%= t(".cost_per_shot_explanation") %>
      </span>
    </span>
  <% end %>
</div>
~~~

Add exact copy:

~~~yaml
cost_per_shot_info_label: "How Cost per shot is calculated"
cost_per_shot_explanation: "Purchase price per gram × average Bean In across this Bean's Espresso brews. Bean In is the full amount removed from the bag; Ground Out and Dose are not added again. Before the first Espresso brew, Roastnode uses 18g. Generic manual inventory corrections are excluded."
~~~

The tooltip remains in the accessibility tree through aria-describedby, appears visually when the group is hovered, and appears when the button receives keyboard focus through group-focus-within.

- [ ] **Step 8: Run cost and markup tests green**

Run:

~~~bash
env POSTGRES_PORT=55433 PARALLEL_WORKERS=1 bin/rails test test/models/bean_test.rb test/controllers/beans_controller_test.rb
~~~

Expected: both files pass with 0 failures and 0 errors.

- [ ] **Step 9: Commit cost semantics and explanation**

Run:

~~~bash
git status --short
git add app/models/bean.rb app/views/beans/show.html.erb config/locales/en.yml test/models/bean_test.rb test/controllers/beans_controller_test.rb
git commit -m "Clarify espresso bean cost per shot"
~~~

Expected: one commit containing the formula and accessible explanation.

---

### Task 9: Update durable product documentation

**Files:**

- Modify: docs/coffee-core.md
- Modify: docs/bean-analytics.md
- Modify: docs/bean-danger-zone.md
- Modify: docs/formatting.md
- Modify: docs/navigation.md
- Modify: docs/workspace-export.md
- Modify: docs/backup-system.md
- Modify: docs/beanconqueror-import.md
- Modify: docs/public-brew-sharing.md
- Modify: docs/status.md

**Interfaces:**

- Consumes: behavior completed in Tasks 1-8.
- Produces: durable contract for future agents; no runtime interface.

- [ ] **Step 1: Update Coffee Core**

Replace the duplicate/new inventory wording and add these exact rules under Inventory Rules:

~~~markdown
- New Beans default to full unopened stock: remaining grams initialize once from bag size, while opened_on, finished_at, and archived_at stay blank.
- Duplicating a bag copies descriptive metadata, package photos and primary-photo identity, price, Purchase Website, Coffee Origin Website, private/public notes, and its duplicate-family link. The new bag resets to full unopened stock and becomes brewable only after an explicit open action.
- Bean rating is optional; a saved value is a whole number from 1 through 5.
- Purchase Website is the private place-to-buy-again URL and continues to power Rebuy. Coffee Origin Website is a separate private source-information URL. Both require HTTP or HTTPS plus a host and appear as synthesized private Links rather than RecordLink rows.
- Cost per shot is purchase price per gram multiplied by average Bean In across the Bean's Espresso brews, with an 18g fallback before the first Espresso. Quick Drip and generic manual inventory corrections do not enter this calculation.
~~~

- [ ] **Step 2: Update Bean Analytics and Navigation**

Add to docs/bean-analytics.md:

~~~markdown
- Recent brews includes a View all link to Coffees with Brews active and the current Bean filter selected.
- Workspace writers can set or clear only the Bean's own 1–5 rating from a focused detail-page correction. This refreshes directly affected public snapshots and records a Bean update activity, but it does not change Brew-derived average-rating or channeling ranks.
- Cost per shot uses purchase price per gram × average Espresso Bean In. Bean In is the full bag deduction, so Ground Out and Dose are not added again. The fallback is 18g before the first Espresso; Quick Drip and generic manual inventory corrections are excluded.
~~~

Add to its Data Rules:

~~~markdown
- A Bean-filtered Coffees request includes Espresso and Quick Drip for that active-workspace Bean only. Missing/foreign Bean IDs return not found. Compact/Hero, All/Brews, and pagination preserve the Bean; External clears it.
~~~

Add to docs/navigation.md:

~~~markdown
- Bean Analytics Recent brews links to /coffees with Brews active and a removable active-Bean chip. The Bean selection survives Compact/Hero, compatible Coffee-type filters, and pagination. External is incompatible and clears it; invalid or foreign-workspace Bean IDs return not found.
~~~

- [ ] **Step 3: Update privacy, formatting, export, backup, and import docs**

Add to docs/formatting.md:

~~~markdown
## Bean Text And URL Examples

Bean entry uses compact examples without changing the stored free-text contract: Elevation 1100-1200m, Variety Arabica and/or Robusta, Percentage 50%/60%, and Processing washed or natural. Purchase Website and Coffee Origin Website trim surrounding whitespace and accept only HTTP or HTTPS URLs with a host.
~~~

Add to docs/bean-danger-zone.md:

~~~markdown
Bean deletion also removes its two direct private website values and ordinary dependent RecordLink rows. Purchase URL and Origin Coffee URL chips are synthesized from Bean columns, so there are no separate system-link records to orphan or synchronize.
~~~

Update docs/workspace-export.md Bean coverage with:

~~~markdown
- Rich private Bean metadata includes both Purchase Website (purchase_url) and Coffee Origin Website (coffee_origin_url) in JSON and Beans CSV exports.
~~~

Update docs/backup-system.md Full Reconstructable Export with:

~~~markdown
- Bean Purchase Website and Coffee Origin Website are included in readable/full backup data and restored after HTTP/HTTPS-with-host validation. Older archives without coffee_origin_url remain valid.
~~~

Change the Beanconqueror mapping in docs/beanconqueror-import.md to:

~~~markdown
- BEANS.url -> Purchase Website (purchase_url). Beanconqueror does not populate Coffee Origin Website.
~~~

In `docs/public-brew-sharing.md`, delete `bean purchase price` from the “snapshot may include” list, replace the existing Agent Note that says it may render publicly, and add this rule:

~~~markdown
- Purchase Website, Coffee Origin Website, and Bean purchase cost are private. New public Brew snapshots omit them, and the public renderer ignores the legacy purchase_price_cents key if an older stored snapshot still contains it.
~~~

- [ ] **Step 4: Update status**

Change docs/status.md Last reviewed to 2026-08-21. Append these exact sentences to the existing Beans/Analytics/Export/Backup summaries where they fit:

~~~markdown
New and duplicated bags now begin as full unopened stock, Bean entry has readable rating/examples and separate private Purchase/Coffee Origin websites, and Bean detail supports focused rating correction plus a waste-aware Espresso-only Cost per shot explanation.

Bean Recent brews links into a workspace-safe Bean-filtered Coffees history that preserves its scope across views, compatible filters, and pagination.

Private workspace export and instance backup/restore preserve both direct Bean websites, while public Bean, Brew, and Recipe snapshots exclude them and public Brew pages no longer expose Bean purchase cost.
~~~

- [ ] **Step 5: Review documentation language against the implemented contract**

Run:

~~~bash
rg -n "duplicate as a new open|set opened_on to the current|website$|average logged dose|Quick Drip.*Cost per shot" docs AGENTS.md -g '!docs/superpowers/**'
~~~

Expected: no stale statement says duplicates open automatically, no stale generic Website label remains for the Bean field, and no documentation says Quick Drip/dose/manual adjustments enter Cost per shot. Historical specs/plans may retain old decisions and need not be rewritten.

- [ ] **Step 6: Commit documentation**

Run:

~~~bash
git status --short
git add docs/coffee-core.md docs/bean-analytics.md docs/bean-danger-zone.md docs/formatting.md docs/navigation.md docs/workspace-export.md docs/backup-system.md docs/beanconqueror-import.md docs/public-brew-sharing.md docs/status.md
git commit -m "Document polished bean workflows"
~~~

Expected: one documentation-only commit.

---

### Task 10: Run full verification and visual QA

**Files:**

- Verify all files listed above.
- Do not create screenshot fixtures or generated artifacts.

**Interfaces:**

- Consumes: completed implementation and local development environment.
- Produces: passing automated suite, clean static checks, and verified desktop/mobile/keyboard behavior with bin/dev left running in roastnode-dev.

- [ ] **Step 1: Run the focused regression suite**

Run:

~~~bash
env POSTGRES_PORT=55433 PARALLEL_WORKERS=1 bin/rails test \
  test/migrations/add_coffee_origin_url_and_normalize_bean_ratings_test.rb \
  test/models/bean_test.rb \
  test/controllers/beans_controller_test.rb \
  test/controllers/brews_controller_test.rb \
  test/helpers/beans_helper_test.rb \
  test/services/workspace_export_builder_test.rb \
  test/services/workspace_csv_export_builder_test.rb \
  test/services/instance_backup_builders_test.rb \
  test/services/instance_backup_restore_test.rb \
  test/services/beanconqueror_import_test.rb \
  test/services/public_bean_share_snapshot_builder_test.rb \
  test/services/public_brew_share_snapshot_builder_test.rb \
  test/services/public_recipe_share_snapshot_builder_test.rb \
  test/models/activity_event_test.rb \
  test/services/activity/emitter_test.rb
~~~

Expected: 0 failures and 0 errors.

- [ ] **Step 2: Run the complete Rails suite**

Run:

~~~bash
env POSTGRES_PORT=55433 PARALLEL_WORKERS=1 bin/rails test
~~~

Expected: every test passes with 0 failures and 0 errors.

- [ ] **Step 3: Run formatting, lint, and security gates**

Run:

~~~bash
git diff --check
bin/rubocop
bin/brakeman --no-pager
~~~

Expected: git diff --check prints nothing; RuboCop reports no offenses; Brakeman reports 0 security warnings.

- [ ] **Step 4: Start the user-checkable development server in tmux**

Run:

~~~bash
tmux has-session -t roastnode-dev 2>/dev/null || tmux new-session -d -s roastnode-dev -c "$PWD"
tmux send-keys -t roastnode-dev C-c
tmux send-keys -t roastnode-dev "bin/dev" C-m
tmux capture-pane -pt roastnode-dev -S -80
~~~

Expected: the pane shows Rails listening on 0.0.0.0:3001 and the Tailwind watcher running. Leave this tmux session running for the user.

- [ ] **Step 5: Verify Bean entry at desktop and mobile widths**

Use the in-app Browser at http://localhost:3001, sign in, open /beans/new, and check at approximately 1280px and 390px:

1. Status starts In stock, Opened on is blank, and Remaining initializes one way from Bag size.
2. Rating occupies its own full-width row; No rating plus 1, 2, 3, 4, and 5 are all readable without horizontal scrolling.
3. Exact examples are visible: 1100-1200m; Arabica and/or Robusta; 50%/60%; washed or natural; URL to original Coffee.
4. Purchase Website appears under Purchase with URL to buy this bag again.
5. Coffee Origin Website appears inside Origin & process.

Expected: no clipped labels, squeezed rating choices, horizontal page overflow, or Translation missing text.

- [ ] **Step 6: Verify duplicate/open and focused rating workflows**

Using an existing Bean with photos, both websites, notes, price, and at least one Brew:

1. Duplicate bag and confirm the edit/detail state is In stock, full remaining, and has no opened/finished/archive date.
2. Confirm copied photos, primary photo, price, both websites, and private/public notes.
3. Open Log Espresso and Repeat Good Brew from the source; the stock duplicate must not be selected.
4. Explicitly Open bag, repeat again, and confirm it can now be selected.
5. On Bean detail, clear Rating, save, then choose 1 and 5 in separate saves; confirm only Rating changes.
6. Sign in as a Viewer and confirm Adjust rating is absent.

Expected: lifecycle/eligibility changes only after Open bag; focused saves never change inventory, lifecycle, notes, price, or ownership.

- [ ] **Step 7: Verify Bean-filtered Coffees navigation**

From a Bean with Espresso and Quick Drip history:

1. Select View all beside Recent brews.
2. Confirm /coffees has Brews active, an active Bean chip, both methods for that Bean, no other Bean, and no External Coffee.
3. Switch Compact to Hero and back; use All and Brews; navigate to a second page when available.
4. Confirm bean_id remains in the URL through those compatible transitions.
5. Select External and confirm bean_id/chip disappear.
6. Remove the chip and confirm the current Hero/Compact and compatible Coffee-type selection remain.

Expected: the result scope is obvious and stable; External intentionally returns to unfiltered External history.

- [ ] **Step 8: Verify private links and accessible cost explanation**

On Bean detail:

1. Confirm Links shows Purchase URL with BUY and PRIVATE, then Origin Coffee URL with INFO and PRIVATE, then normal RecordLinks.
2. Confirm Purchase URL still powers Rebuy; Origin Coffee URL does not.
3. Hover the Cost per shot information button and read the full explanation.
4. Move focus with Tab to the same button without using a pointer; confirm the explanation appears and the focus ring is visible.
5. Inspect the displayed value for a Bean with Espresso 20g Bean In, 19g Ground Out, and 17g Dose; it must use the price of 20g, not 56g.

Expected: both direct URLs stay on authenticated pages, the tooltip works on hover and keyboard focus, and the card retains existing currency rounding.

- [ ] **Step 9: Inspect privacy-sensitive HTML and payload tests once more**

Run:

~~~bash
rg -n "purchase_url|coffee_origin_url" app/services/public_* app/views/public_* app/controllers/public_*
~~~

Expected: no public view/controller directly reads either URL; any matches are negative allowlist tests or unrelated private code. Re-run the three public snapshot tests if the search reveals any new builder reference.

- [ ] **Step 10: Final repository audit and commit only if verification caused a correction**

Run:

~~~bash
git status --short
git log -10 --oneline
~~~

Expected: no generated build, log, backup, screenshot, or temporary file is staged. If visual verification exposed a defect, return to the task that owns that file, add the exact paths listed in that task's commit step, rerun its focused test plus the full suite, and use that task's commit command. If no correction was needed, do not create an empty verification commit.

---

## Completion Criteria

- New and duplicated Beans are full stock with blank lifecycle dates and remain outside Brew/Repeat selection until explicit open.
- Duplicate metadata includes photos/primary identity, price, both URLs, private/public notes, and duplicate-family linkage.
- Bean form examples and full-width blank-or-1..5 rating layout match the approved copy.
- Legacy Bean rating 0 is NULL, and model/focused route accept only blank or 1..5.
- Focused rating is writer-only, workspace-scoped, parameter-allowlisted, transactionally emits bean.updated activity, and refreshes directly affected public snapshots without changing Brew-derived ranks.
- Coffees Bean filtering includes Espresso and Quick Drip only, fails closed for bad IDs, persists across compatible navigation and pagination, shows a removable chip, and clears for External.
- Purchase/Coffee Origin Websites validate, normalize, duplicate, render as private system chips without RecordLink synchronization, export, and restore.
- Public Bean, Brew, and Recipe snapshots contain neither direct URL.
- Cost per shot uses average Espresso Bean In only, retains the 18g fallback/rounding, ignores Quick Drip/manual corrections, handles the 20g waste example correctly, and has hover/focus-accessible explanatory text.
- Required docs, focused tests, full suite, lint, security scan, and desktop/mobile/keyboard visual checks all pass; bin/dev remains available in roastnode-dev on port 3001.
