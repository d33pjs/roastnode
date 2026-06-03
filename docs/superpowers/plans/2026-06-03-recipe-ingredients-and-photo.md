# Recipe Ingredients And Finished Photo Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add structured finish ingredients, a finish note, and one optional finished-drink recipe photo with explicit public-share selection.

**Architecture:** Keep drink-building data inside `recipe.profile` so existing recipe snapshots, exports, imports, and guided logging can carry it without a new domain table. Use the existing Active Storage photo pattern for private recipe media, then add a recipe-specific public media route that mirrors public brew media with opaque per-share handles and password gating.

**Tech Stack:** Rails 8.1, Active Record, Active Storage, Hotwire/Turbo server-rendered ERB, PostgreSQL JSONB and integer arrays, Minitest integration/model/service tests.

---

## File Structure

- `db/migrate/20260603120000_add_media_to_recipes_and_public_recipe_shares.rb`: add recipe primary photo support and selected public recipe photo IDs.
- `app/models/recipe.rb`: include `HasPrimaryPhoto`, add `has_many_attached :photos`.
- `app/models/public_recipe_share.rb`: track selected recipe media, generate opaque media handles, refresh snapshots with selected media.
- `app/controllers/recipes_controller.rb`: normalize ingredient rows, finish note, recipe photo upload, and source brew photo reuse.
- `app/controllers/media_attachments_controller.rb`: route private recipe photo redirects back to recipe pages.
- `app/controllers/public_recipe_media_controller.rb`: serve selected public recipe media through opaque handles.
- `app/controllers/public_recipe_shares_controller.rb`: load selectable recipe photos and persist explicit public selection.
- `app/helpers/public_recipe_pages_helper.rb`: add public recipe media URL helper.
- `app/services/public_recipe_share_snapshot_builder.rb`: include ingredients, finish note, and selected recipe photo metadata.
- `app/services/recipe_snapshot_builder.rb`: initialize new recipes with empty ingredient/finish data.
- `app/services/recipe_exporter.rb`: rely on sanitized profile export and preserve ingredients/finish note.
- `app/services/recipe_importer.rb`: validate and sanitize imported ingredients/finish note while still excluding media.
- `app/views/recipes/_form.html.erb`: add ingredients/finish/photo controls.
- `app/views/recipes/_finish_card.html.erb`: shared private/guided finish display.
- `app/views/recipes/show.html.erb`: render finish card and recipe photo.
- `app/views/brews/new.html.erb`: render finish card in the recipe guide column.
- `app/views/public_recipe_shares/_form.html.erb`: add explicit recipe photo checkbox.
- `app/views/public_recipe_pages/show.html.erb`: render public finish section and selected recipe photo.
- `config/routes.rb`: add public recipe media route.
- `config/locales/en.yml`: add labels for ingredients, finish note, recipe photo, source photo reuse, and public photo selection.
- `docs/recipe-profiles.md`, `docs/coffee-core.md`, `docs/private-media.md`, `docs/status.md`: update shipped behavior and privacy rules.
- Tests listed per task below.

---

### Task 1: Structured Ingredients And Finish Note

**Files:**
- Modify: `app/controllers/recipes_controller.rb`
- Modify: `app/services/recipe_snapshot_builder.rb`
- Modify: `app/views/recipes/_form.html.erb`
- Create: `app/views/recipes/_finish_card.html.erb`
- Modify: `app/views/recipes/show.html.erb`
- Modify: `app/views/brews/new.html.erb`
- Modify: `config/locales/en.yml`
- Test: `test/controllers/recipes_controller_test.rb`
- Test: `test/controllers/brews_controller_test.rb`

- [ ] **Step 1: Write failing controller tests for storing and showing ingredients**

Add tests to `test/controllers/recipes_controller_test.rb`:

```ruby
test "writer creates recipe with structured ingredients and finish note" do
  sign_in_as(users(:one))

  assert_difference -> { workspaces(:household).recipes.count }, 1 do
    post recipes_path, params: {
      recipe: {
        source_brew_id: brews(:morning_espresso).id,
        title: "Matcha honey espresso",
        finish_note: "Add matcha after pulling the espresso, then stir in honey.",
        ingredients: {
          "0" => { amount: "200", unit: "ml", name: "matcha" },
          "1" => { amount: "1", unit: "shot", name: "honey" },
          "2" => { amount: "", unit: "", name: "" }
        }
      }
    }
  end

  recipe = workspaces(:household).recipes.order(:created_at).last
  assert_redirected_to recipe_path(recipe)
  assert_equal "Add matcha after pulling the espresso, then stir in honey.", recipe.profile["finish_note"]
  assert_equal [
    { "amount" => "200", "unit" => "ml", "name" => "matcha" },
    { "amount" => "1", "unit" => "shot", "name" => "honey" }
  ], recipe.profile["ingredients"]
end

test "writer edits and removes structured ingredients" do
  sign_in_as(users(:one))
  recipe = recipes(:household_recipe)
  profile = recipe.profile.deep_dup
  profile["ingredients"] = [
    { "amount" => "200", "unit" => "ml", "name" => "matcha" },
    { "amount" => "1", "unit" => "shot", "name" => "honey" }
  ]
  profile["finish_note"] = "Old finish."
  recipe.update!(profile:)

  patch recipe_path(recipe), params: {
    recipe: {
      title: recipe.title,
      finish_note: "Stir gently.",
      ingredients: {
        "0" => { amount: "180", unit: "ml", name: "iced matcha" },
        "1" => { amount: "", unit: "", name: "" }
      }
    }
  }

  assert_redirected_to recipe_path(recipe)
  recipe.reload
  assert_equal "Stir gently.", recipe.profile["finish_note"]
  assert_equal [
    { "amount" => "180", "unit" => "ml", "name" => "iced matcha" }
  ], recipe.profile["ingredients"]
end

test "show renders finish ingredients and finish note" do
  sign_in_as(users(:one))
  recipe = recipes(:household_recipe)
  profile = recipe.profile.deep_dup
  profile["ingredients"] = [
    { "amount" => "200", "unit" => "ml", "name" => "matcha" },
    { "amount" => "1", "unit" => "shot", "name" => "honey" }
  ]
  profile["finish_note"] = "Add matcha after pulling the espresso."
  recipe.update!(profile:)

  get recipe_path(recipe)

  assert_response :success
  assert_select "[data-testid=recipe-finish-card]", text: /200 ml matcha/
  assert_select "[data-testid=recipe-finish-card]", text: /1 shot honey/
  assert_select "[data-testid=recipe-finish-card]", text: /Add matcha/
end
```

- [ ] **Step 2: Write failing guided logging test for finish card**

Add to `test/controllers/brews_controller_test.rb` near existing recipe-guided logging tests:

```ruby
test "new brew with recipe renders recipe finish card without pre-filling brew fields" do
  sign_in_as(users(:one))
  recipe = recipes(:household_recipe)
  profile = recipe.profile.deep_dup
  profile["ingredients"] = [
    { "amount" => "200", "unit" => "ml", "name" => "matcha" }
  ]
  profile["finish_note"] = "Pour espresso over matcha."
  recipe.update!(profile:)

  get new_brew_path(recipe_id: recipe.id)

  assert_response :success
  assert_select "[data-testid=recipe-finish-card]", text: /200 ml matcha/
  assert_select "[data-testid=recipe-finish-card]", text: /Pour espresso over matcha/
  assert_select "input[name='brew[dose_grams]'][value='18.0']", count: 0
end
```

- [ ] **Step 3: Run tests to verify they fail**

Run:

```bash
env PARALLEL_WORKERS=1 bin/rails test test/controllers/recipes_controller_test.rb test/controllers/brews_controller_test.rb
```

Expected: failures showing missing `recipe.profile["ingredients"]` persistence and missing `recipe-finish-card`.

- [ ] **Step 4: Implement ingredient normalization in `RecipesController`**

Add constants and helpers:

```ruby
INGREDIENT_FIELDS = %i[amount unit name].freeze
INGREDIENT_MAX_LENGTHS = {
  "amount" => 32,
  "unit" => 32,
  "name" => 120
}.freeze
FINISH_NOTE_MAX_LENGTH = 1_000

def profile_from_params(profile)
  attributes = recipe_params
  title = attributes[:title].presence || profile["title"]
  profile["title"] = title
  profile["guide"] = guide_from_params(profile["guide"] || {})
  profile["targets"] = targets_from_params(profile["targets"] || {})
  profile["ingredients"] = ingredients_from_params
  profile["finish_note"] = finish_note_from_params
  profile.compact
end

def ingredients_from_params
  rows = recipe_params[:ingredients] || ActionController::Parameters.new
  rows.to_unsafe_h.values.filter_map do |row|
    payload = INGREDIENT_FIELDS.each_with_object({}) do |field, result|
      key = field.to_s
      value = row[key].to_s.strip.first(INGREDIENT_MAX_LENGTHS.fetch(key))
      result[key] = value if value.present?
    end
    payload if payload["name"].present?
  end
end

def finish_note_from_params
  recipe_params[:finish_note].to_s.strip.first(FINISH_NOTE_MAX_LENGTH).presence
end
```

Update `recipe_params`:

```ruby
params.fetch(:recipe, {}).permit(
  :source_brew_id,
  :title,
  :guide_note,
  :pressure_note,
  :finish_note,
  targets: TARGET_FIELDS,
  ingredients: [ INGREDIENT_FIELDS ],
  record_links_attributes: [ [ :id, :label, :url, :kind, :visibility, :position, :_destroy ] ]
)
```

- [ ] **Step 5: Initialize defaults in `RecipeSnapshotBuilder`**

Add to the returned hash in `RecipeSnapshotBuilder#call`:

```ruby
"ingredients" => [],
"finish_note" => nil,
```

Keep `.compact` off the full hash so the form can always work with arrays. If the existing hash does not compact the root, leave it as explicit empty values.

- [ ] **Step 6: Add finish form fields**

In `app/views/recipes/_form.html.erb`, define:

```erb
<% ingredients = Array(profile["ingredients"]) %>
<% ingredient_rows = ingredients.presence || [ {}, {} ] %>
```

Add a section after guide fields:

```erb
<section class="<%= section_class %>">
  <h2 class="text-sm font-extrabold uppercase tracking-[0.08em] text-rn-muted"><%= t("recipes.form.finish") %></h2>
  <div class="grid gap-3">
    <% ingredient_rows.each_with_index do |ingredient, index| %>
      <div class="grid gap-2 sm:grid-cols-[7rem_7rem_minmax(0,1fr)]">
        <div>
          <%= label_tag "recipe_ingredients_#{index}_amount", t("recipes.form.ingredient_amount"), class: label_class %>
          <%= text_field_tag "recipe[ingredients][#{index}][amount]", ingredient["amount"], id: "recipe_ingredients_#{index}_amount", class: input_class %>
        </div>
        <div>
          <%= label_tag "recipe_ingredients_#{index}_unit", t("recipes.form.ingredient_unit"), class: label_class %>
          <%= text_field_tag "recipe[ingredients][#{index}][unit]", ingredient["unit"], id: "recipe_ingredients_#{index}_unit", class: input_class %>
        </div>
        <div>
          <%= label_tag "recipe_ingredients_#{index}_name", t("recipes.form.ingredient_name"), class: label_class %>
          <%= text_field_tag "recipe[ingredients][#{index}][name]", ingredient["name"], id: "recipe_ingredients_#{index}_name", class: input_class %>
        </div>
      </div>
    <% end %>

    <div class="grid gap-2 sm:grid-cols-[7rem_7rem_minmax(0,1fr)]">
      <% index = ingredient_rows.length %>
      <div>
        <%= label_tag "recipe_ingredients_#{index}_amount", t("recipes.form.ingredient_amount"), class: label_class %>
        <%= text_field_tag "recipe[ingredients][#{index}][amount]", nil, id: "recipe_ingredients_#{index}_amount", class: input_class %>
      </div>
      <div>
        <%= label_tag "recipe_ingredients_#{index}_unit", t("recipes.form.ingredient_unit"), class: label_class %>
        <%= text_field_tag "recipe[ingredients][#{index}][unit]", nil, id: "recipe_ingredients_#{index}_unit", class: input_class %>
      </div>
      <div>
        <%= label_tag "recipe_ingredients_#{index}_name", t("recipes.form.ingredient_name"), class: label_class %>
        <%= text_field_tag "recipe[ingredients][#{index}][name]", nil, id: "recipe_ingredients_#{index}_name", class: input_class %>
      </div>
    </div>

    <div>
      <%= label_tag "recipe_finish_note", t("recipes.form.finish_note"), class: label_class %>
      <%= text_area_tag "recipe[finish_note]", profile["finish_note"], id: "recipe_finish_note", rows: 3, class: input_class %>
    </div>
  </div>
</section>
```

This uses one extra blank row per render instead of adding JavaScript in this slice.

- [ ] **Step 7: Add reusable finish display partial**

Create `app/views/recipes/_finish_card.html.erb`:

```erb
<% profile = recipe.profile || {} %>
<% ingredients = Array(profile["ingredients"]).select { |item| item["name"].present? } %>
<% finish_note = profile["finish_note"].presence %>

<% if ingredients.any? || finish_note.present? %>
  <section data-testid="recipe-finish-card" class="rounded-3xl border border-rn-line bg-rn-surface p-4 shadow-sm sm:p-5">
    <h2 class="text-sm font-extrabold uppercase tracking-[0.08em] text-rn-muted"><%= t("recipes.finish.title") %></h2>

    <% if ingredients.any? %>
      <ul class="mt-3 grid gap-2">
        <% ingredients.each do |ingredient| %>
          <% amount = [ ingredient["amount"], ingredient["unit"] ].compact_blank.join(" ") %>
          <li class="rounded-2xl bg-[var(--rn-surface-muted)] px-4 py-3 text-sm font-extrabold text-rn-ink">
            <%= [ amount.presence, ingredient["name"] ].compact.join(" ") %>
          </li>
        <% end %>
      </ul>
    <% end %>

    <% if finish_note.present? %>
      <p class="mt-3 whitespace-pre-line text-sm font-semibold leading-6 text-rn-muted"><%= finish_note %></p>
    <% end %>
  </section>
<% end %>
```

- [ ] **Step 8: Render finish card on recipe detail and guided logging**

In `app/views/recipes/show.html.erb`, wrap the existing recipe details section in a left-column container and render the finish card directly below it:

```erb
<div class="grid gap-5">
  <section class="rounded-3xl border border-rn-line bg-rn-surface p-4 shadow-sm sm:p-5">
    ...
  </section>

  <%= render "recipes/finish_card", recipe: @recipe %>
</div>
```

In `app/views/brews/new.html.erb`, render the finish card in the sticky recipe guide column:

```erb
<div class="grid gap-5 lg:order-2 lg:sticky lg:top-6">
  <%= render "recipes/target_guide", recipe: @recipe %>
  <%= render "recipes/finish_card", recipe: @recipe %>
</div>
```

- [ ] **Step 9: Add locale keys**

Add to `config/locales/en.yml`:

```yaml
recipes:
  finish:
    title: "Finish with"
  form:
    finish: "Ingredients / finish"
    finish_note: "Finish note"
    ingredient_amount: "Amount"
    ingredient_name: "Ingredient"
    ingredient_unit: "Unit"
```

- [ ] **Step 10: Run tests and commit**

Run:

```bash
env PARALLEL_WORKERS=1 bin/rails test test/controllers/recipes_controller_test.rb test/controllers/brews_controller_test.rb
```

Expected: all tests pass.

Commit:

```bash
git add app/controllers/recipes_controller.rb app/services/recipe_snapshot_builder.rb app/views/recipes/_form.html.erb app/views/recipes/_finish_card.html.erb app/views/recipes/show.html.erb app/views/brews/new.html.erb config/locales/en.yml test/controllers/recipes_controller_test.rb test/controllers/brews_controller_test.rb
git commit -m "feat: add recipe finish ingredients"
```

---

### Task 2: Private Finished-Drink Recipe Photo And Source Photo Reuse

**Files:**
- Create: `db/migrate/20260603120000_add_media_to_recipes_and_public_recipe_shares.rb`
- Modify: `app/models/recipe.rb`
- Modify: `app/controllers/recipes_controller.rb`
- Modify: `app/controllers/media_attachments_controller.rb`
- Modify: `app/views/recipes/_form.html.erb`
- Modify: `app/views/recipes/show.html.erb`
- Modify: `config/locales/en.yml`
- Test: `test/controllers/recipes_controller_test.rb`
- Test: `test/models/recipe_test.rb`

- [ ] **Step 1: Write failing model and controller tests**

Add to `test/models/recipe_test.rb`:

```ruby
test "recipe supports one primary finished drink photo" do
  recipe = recipes(:household_recipe)
  recipe.photos.attach(
    io: file_fixture("photo.jpg").open,
    filename: "photo.jpg",
    content_type: "image/jpeg"
  )

  assert recipe.photos.attached?
  assert_equal recipe.photos.attachments.first, recipe.primary_photo_attachment
end
```

Add to `test/controllers/recipes_controller_test.rb`:

```ruby
test "new recipe form suggests source brew primary photo without selecting it" do
  sign_in_as(users(:one))
  brew = brews(:morning_espresso)
  brew.photos.attach(
    io: file_fixture("photo.jpg").open,
    filename: "photo.jpg",
    content_type: "image/jpeg"
  )
  brew.set_primary_photo!(brew.photos.attachments.first)

  get new_recipe_path(source_brew_id: brew.id)

  assert_response :success
  assert_select "[data-testid=source-brew-photo-suggestion]"
  assert_select "input[type=checkbox][name=?][checked]", "recipe[use_source_brew_photo]", count: 0
end

test "writer can reuse source brew primary photo for recipe" do
  sign_in_as(users(:one))
  brew = brews(:morning_espresso)
  brew.photos.attach(
    io: file_fixture("photo.jpg").open,
    filename: "photo.jpg",
    content_type: "image/jpeg"
  )
  brew.set_primary_photo!(brew.photos.attachments.first)

  post recipes_path, params: {
    recipe: {
      source_brew_id: brew.id,
      title: "Photo recipe",
      use_source_brew_photo: "1"
    }
  }

  recipe = workspaces(:household).recipes.order(:created_at).last
  assert_redirected_to recipe_path(recipe)
  assert recipe.photos.attached?
  assert_equal brew.primary_photo_attachment.blob_id, recipe.primary_photo_attachment.blob_id
end

test "writer cannot reuse cross workspace source photo" do
  sign_in_as(users(:one))
  other_brew = brews(:other_workspace_brew)
  other_brew.photos.attach(
    io: file_fixture("photo.jpg").open,
    filename: "photo.jpg",
    content_type: "image/jpeg"
  )
  other_brew.set_primary_photo!(other_brew.photos.attachments.first)

  assert_no_difference -> { workspaces(:household).recipes.count } do
    post recipes_path, params: {
      recipe: {
        source_brew_id: brews(:morning_espresso).id,
        source_brew_photo_attachment_id: other_brew.primary_photo_attachment.id,
        use_source_brew_photo: "1"
      }
    }
  end

  assert_response :not_found
end

test "writer uploads recipe finished drink photo" do
  sign_in_as(users(:one))

  post recipes_path, params: {
    recipe: {
      source_brew_id: brews(:morning_espresso).id,
      title: "Uploaded photo recipe",
      photos: [
        fixture_file_upload("photo.jpg", "image/jpeg")
      ]
    }
  }

  recipe = workspaces(:household).recipes.order(:created_at).last
  assert_redirected_to recipe_path(recipe)
  assert recipe.primary_photo_attachment.present?
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
env PARALLEL_WORKERS=1 bin/rails test test/models/recipe_test.rb test/controllers/recipes_controller_test.rb
```

Expected: failures for missing `photos`, missing primary photo column, and missing form controls.

- [ ] **Step 3: Add migration**

Create migration:

```ruby
class AddMediaToRecipesAndPublicRecipeShares < ActiveRecord::Migration[8.1]
  def change
    add_column :recipes, :primary_photo_attachment_id, :bigint
    add_index :recipes, :primary_photo_attachment_id

    add_column :public_recipe_shares, :selected_photo_attachment_ids, :integer, array: true, null: false, default: []
  end
end
```

Run:

```bash
bin/rails db:migrate
```

Expected: migration succeeds and `db/schema.rb` shows both new columns.

- [ ] **Step 4: Update `Recipe` model**

Modify `app/models/recipe.rb`:

```ruby
class Recipe < ApplicationRecord
  include HasPrimaryPhoto
  include HasRecordLinks

  has_many_attached :photos
end
```

Keep the existing associations and validations intact.

- [ ] **Step 5: Add photo handling in `RecipesController`**

In `new`, include source brew photo attachments:

```ruby
source_brew = source_brew_from_params!
@source_brew_primary_photo = source_brew.primary_photo_attachment
```

Update `source_brew_from_params!` includes:

```ruby
.includes(:bean, :grinder, :machine, :record_links, :primary_photo_record, photos_attachments: :blob, brew_preparation_tools: :preparation_tool)
```

After building record links in `create`, attach photos before saving:

```ruby
assign_recipe_photos(@recipe, source_brew)
```

After updating attributes in `update`, attach uploaded photos:

```ruby
assign_uploaded_recipe_photos(@recipe)
```

Add helpers:

```ruby
def assign_recipe_photos(recipe, source_brew)
  assign_uploaded_recipe_photos(recipe)
  attach_source_brew_photo(recipe, source_brew) if recipe_params[:use_source_brew_photo] == "1"
end

def assign_uploaded_recipe_photos(recipe)
  photos = Array(recipe_params[:photos]).reject(&:blank?)
  recipe.photos.attach(photos) if photos.any?
end

def attach_source_brew_photo(recipe, source_brew)
  attachment = source_brew.primary_photo_attachment
  requested_id = recipe_params[:source_brew_photo_attachment_id].presence&.to_i
  return if attachment.blank?
  raise ActiveRecord::RecordNotFound if requested_id && requested_id != attachment.id

  recipe.photos.attach(attachment.blob)
end
```

Update `recipe_params`:

```ruby
:use_source_brew_photo,
:source_brew_photo_attachment_id,
photos: [],
```

- [ ] **Step 6: Update private media controller redirect**

Add to `MediaAttachmentsController#record_path`:

```ruby
when Recipe
  recipe_path(record)
```

- [ ] **Step 7: Add form and show photo UI**

In `app/views/recipes/_form.html.erb`, add to the finish section:

```erb
<div>
  <%= form.label :photos, t("recipes.form.photo"), class: label_class %>
  <%= form.file_field :photos, multiple: false, accept: "image/*", class: "mt-1 block w-full text-sm font-bold text-rn-muted file:mr-4 file:rounded-full file:border-0 file:bg-[var(--rn-accent-strong)] file:px-4 file:py-2 file:text-sm file:font-extrabold file:text-[#f8faf6] hover:file:opacity-90" %>
</div>

<% if defined?(@source_brew_primary_photo) && @source_brew_primary_photo.present? %>
  <label data-testid="source-brew-photo-suggestion" class="flex items-center gap-3 rounded-2xl border border-rn-line bg-[var(--rn-canvas)] p-3 text-sm font-extrabold text-rn-ink">
    <%= check_box_tag "recipe[use_source_brew_photo]", "1", false, class: "h-4 w-4 rounded border-rn-line text-rn-ink" %>
    <%= hidden_field_tag "recipe[source_brew_photo_attachment_id]", @source_brew_primary_photo.id %>
    <%= image_tag media_attachment_path(@source_brew_primary_photo, variant: :thumbnail), alt: "", class: "h-16 w-16 rounded-lg object-cover" %>
    <%= t("recipes.form.use_source_brew_photo") %>
  </label>
<% end %>
```

In `app/views/recipes/show.html.erb`, render recipe photo in the finish area:

```erb
<% if @recipe.primary_photo_attachment.present? %>
  <%= image_tag media_attachment_path(@recipe.primary_photo_attachment, variant: :thumbnail), alt: "", data: { testid: "recipe-finished-photo" }, class: "mt-4 h-64 w-full rounded-lg object-cover" %>
<% end %>
```

- [ ] **Step 8: Add locale keys**

Add:

```yaml
recipes:
  form:
    photo: "Finished drink photo"
    use_source_brew_photo: "Use source brew photo"
```

- [ ] **Step 9: Run tests and commit**

Run:

```bash
env PARALLEL_WORKERS=1 bin/rails test test/models/recipe_test.rb test/controllers/recipes_controller_test.rb
```

Expected: all tests pass.

Commit:

```bash
git add db/migrate db/schema.rb app/models/recipe.rb app/controllers/recipes_controller.rb app/controllers/media_attachments_controller.rb app/views/recipes app/views/recipes/show.html.erb config/locales/en.yml test/models/recipe_test.rb test/controllers/recipes_controller_test.rb
git commit -m "feat: add recipe finished photo"
```

---

### Task 3: Export, Import, Snapshot, And Public Page Finish Content

**Files:**
- Modify: `app/services/recipe_importer.rb`
- Modify: `app/services/recipe_exporter.rb`
- Modify: `app/services/public_recipe_share_snapshot_builder.rb`
- Modify: `app/views/public_recipe_pages/show.html.erb`
- Modify: `config/locales/en.yml`
- Modify: `test/fixtures/files/recipe_export.json`
- Test: `test/services/recipe_exporter_test.rb`
- Test: `test/services/recipe_importer_test.rb`
- Test: `test/models/public_recipe_share_test.rb`
- Test: `test/controllers/public_recipe_pages_controller_test.rb`

- [ ] **Step 1: Write failing export/import tests**

Update `RecipeExporterTest`:

```ruby
test "exports ingredients and finish note but no media internals" do
  recipe = recipes(:household_recipe)
  profile = recipe.profile.deep_dup
  profile["ingredients"] = [
    { "amount" => "200", "unit" => "ml", "name" => "matcha" }
  ]
  profile["finish_note"] = "Pour espresso over matcha."
  recipe.update!(profile:)
  recipe.photos.attach(
    io: file_fixture("photo.jpg").open,
    filename: "photo.jpg",
    content_type: "image/jpeg"
  )

  payload = RecipeExporter.new(recipe).call

  exported_profile = payload.fetch("recipe").fetch("profile")
  assert_equal [ { "amount" => "200", "unit" => "ml", "name" => "matcha" } ], exported_profile.fetch("ingredients")
  assert_equal "Pour espresso over matcha.", exported_profile.fetch("finish_note")
  json = JSON.generate(payload)
  assert_not_includes json, "attachment_id"
  assert_not_includes json, "/rails/active_storage"
  assert_not_includes json, "photo.jpg"
end
```

Update `RecipeImporterTest`:

```ruby
test "imports ingredients and finish note without media" do
  payload = export_payload(
    "profile" => export_payload.fetch("recipe").fetch("profile").merge(
      "ingredients" => [
        { "amount" => "200", "unit" => "ml", "name" => "matcha" },
        { "amount" => "", "unit" => "", "name" => "" }
      ],
      "finish_note" => "Stir in honey."
    )
  )

  recipe = RecipeImporter.new(workspace: workspaces(:household), user: users(:one), json: JSON.generate(payload)).call

  assert_equal [ { "amount" => "200", "unit" => "ml", "name" => "matcha" } ], recipe.profile["ingredients"]
  assert_equal "Stir in honey.", recipe.profile["finish_note"]
  assert_not recipe.photos.attached?
end
```

- [ ] **Step 2: Write failing public snapshot/page tests**

Add to `PublicRecipeShareTest`:

```ruby
test "snapshot includes public ingredients and finish note" do
  recipe = recipes(:household_recipe)
  profile = recipe.profile.deep_dup
  profile["ingredients"] = [
    { "amount" => "200", "unit" => "ml", "name" => "matcha" }
  ]
  profile["finish_note"] = "Pour espresso over matcha."
  recipe.update!(profile:)

  share = PublicRecipeShare.create!(
    workspace: recipe.workspace,
    recipe:,
    created_by: users(:one),
    updated_by: users(:one)
  )
  share.refresh_snapshot!(title: "Public recipe", selected_photo_attachment_ids: [], updated_by: users(:one))

  assert_equal [ { "amount" => "200", "unit" => "ml", "name" => "matcha" } ], share.snapshot.dig("recipe", "ingredients")
  assert_equal "Pour espresso over matcha.", share.snapshot.dig("recipe", "finish_note")
end
```

Add to `PublicRecipePagesControllerTest`:

```ruby
test "enabled share renders public ingredients and finish note" do
  recipe = recipes(:household_recipe)
  profile = recipe.profile.deep_dup
  profile["ingredients"] = [
    { "amount" => "200", "unit" => "ml", "name" => "matcha" }
  ]
  profile["finish_note"] = "Pour espresso over matcha."
  recipe.update!(profile:)
  share = recipe.create_public_recipe_share!(
    workspace: recipe.workspace,
    created_by: users(:one),
    updated_by: users(:one),
    title: "Shared recipe",
    enabled: true,
    snapshot: PublicRecipeShareSnapshotBuilder.new(recipe:, title: "Shared recipe", selected_photo_attachment_ids: []).call
  )

  get public_recipe_page_path(share.token)

  assert_response :success
  assert_select "[data-testid=public-recipe-finish]", text: /200 ml matcha/
  assert_select "[data-testid=public-recipe-finish]", text: /Pour espresso over matcha/
end
```

- [ ] **Step 3: Run tests to verify they fail**

Run:

```bash
env PARALLEL_WORKERS=1 bin/rails test test/services/recipe_exporter_test.rb test/services/recipe_importer_test.rb test/models/public_recipe_share_test.rb test/controllers/public_recipe_pages_controller_test.rb
```

Expected: failures for missing snapshot keys and `refresh_snapshot!` signature changes.

- [ ] **Step 4: Sanitize imported profile finish data**

In `RecipeImporter`, add:

```ruby
INGREDIENT_FIELDS = %w[amount unit name].freeze
INGREDIENT_MAX_LENGTHS = {
  "amount" => 32,
  "unit" => 32,
  "name" => 120
}.freeze
FINISH_NOTE_MAX_LENGTH = 1_000
```

Before creating the recipe:

```ruby
profile = sanitize_profile(recipe_payload.fetch("profile"))
```

Use `profile:` in create. Add:

```ruby
def sanitize_profile(profile)
  sanitized = profile.deep_dup
  sanitized["ingredients"] = sanitize_ingredients(sanitized["ingredients"])
  sanitized["finish_note"] = sanitized["finish_note"].to_s.strip.first(FINISH_NOTE_MAX_LENGTH).presence
  sanitized.compact
end

def sanitize_ingredients(ingredients)
  Array(ingredients).filter_map do |ingredient|
    next unless ingredient.is_a?(Hash)

    payload = INGREDIENT_FIELDS.each_with_object({}) do |field, result|
      value = ingredient[field].to_s.strip.first(INGREDIENT_MAX_LENGTHS.fetch(field))
      result[field] = value if value.present?
    end
    payload if payload["name"].present?
  end
end
```

The exporter already exports `profile.deep_dup`; keep it that way and rely on the no-media test to protect against adding media data.

- [ ] **Step 5: Update public snapshot builder**

Change initializer:

```ruby
def initialize(recipe:, title:, selected_photo_attachment_ids: [])
  @recipe = recipe
  @title = title
  @profile = recipe.profile || {}
  @selected_photo_attachment_ids = Array(selected_photo_attachment_ids).map(&:to_i).uniq
end
```

Add reader and keys:

```ruby
INGREDIENT_KEYS = %w[amount unit name].freeze
attr_reader :recipe, :title, :profile, :selected_photo_attachment_ids
```

Add to `recipe_payload`:

```ruby
"ingredients" => ingredient_payloads,
"finish_note" => profile["finish_note"].presence,
```

Add method:

```ruby
def ingredient_payloads
  Array(profile["ingredients"]).filter_map do |ingredient|
    payload = slice_hash(ingredient, INGREDIENT_KEYS)
    payload if payload["name"].present?
  end
end
```

- [ ] **Step 6: Update `PublicRecipeShare#refresh_snapshot!` signature**

Change method:

```ruby
def refresh_snapshot!(title:, selected_photo_attachment_ids: [], updated_by:)
  update!(
    title:,
    selected_photo_attachment_ids: Array(selected_photo_attachment_ids).map(&:to_i).uniq,
    updated_by:,
    snapshot: PublicRecipeShareSnapshotBuilder.new(
      recipe:,
      title:,
      selected_photo_attachment_ids:
    ).call
  )
end
```

Existing callers pass no selected photos, so the default keeps them working.

- [ ] **Step 7: Render public finish section**

In `app/views/public_recipe_pages/show.html.erb`, near the target guide:

```erb
<% ingredients = Array(recipe["ingredients"]).select { |item| item["name"].present? } %>
<% finish_note = recipe["finish_note"].presence %>

<% if ingredients.any? || finish_note.present? %>
  <section data-testid="public-recipe-finish" class="mt-6 rounded-lg border border-stone-300 bg-white p-4">
    <h2 class="text-xs font-black uppercase tracking-[0.08em] text-stone-600"><%= t(".finish") %></h2>
    <% if ingredients.any? %>
      <ul class="mt-3 grid gap-2">
        <% ingredients.each do |ingredient| %>
          <% amount = [ ingredient["amount"], ingredient["unit"] ].compact_blank.join(" ") %>
          <li class="rounded-lg bg-[#f6f4ef] px-4 py-3 text-sm font-black text-stone-950">
            <%= [ amount.presence, ingredient["name"] ].compact.join(" ") %>
          </li>
        <% end %>
      </ul>
    <% end %>
    <% if finish_note.present? %>
      <p class="mt-3 whitespace-pre-line text-sm font-semibold leading-6 text-stone-700"><%= finish_note %></p>
    <% end %>
  </section>
<% end %>
```

Locale:

```yaml
public_recipe_pages:
  show:
    finish: "Finish with"
```

- [ ] **Step 8: Update fixture export JSON**

Edit `test/fixtures/files/recipe_export.json` to include:

```json
"ingredients": [
  { "amount": "200", "unit": "ml", "name": "matcha" }
],
"finish_note": "Pour espresso over matcha."
```

inside `recipe.profile`.

- [ ] **Step 9: Run tests and commit**

Run:

```bash
env PARALLEL_WORKERS=1 bin/rails test test/services/recipe_exporter_test.rb test/services/recipe_importer_test.rb test/models/public_recipe_share_test.rb test/controllers/public_recipe_pages_controller_test.rb
```

Expected: all tests pass.

Commit:

```bash
git add app/services/recipe_importer.rb app/services/public_recipe_share_snapshot_builder.rb app/models/public_recipe_share.rb app/views/public_recipe_pages/show.html.erb config/locales/en.yml test/fixtures/files/recipe_export.json test/services/recipe_exporter_test.rb test/services/recipe_importer_test.rb test/models/public_recipe_share_test.rb test/controllers/public_recipe_pages_controller_test.rb
git commit -m "feat: include recipe finish details in sharing"
```

---

### Task 4: Public Recipe Photo Selection And Opaque Media Route

**Files:**
- Modify: `config/routes.rb`
- Create: `app/controllers/public_recipe_media_controller.rb`
- Modify: `app/models/public_recipe_share.rb`
- Modify: `app/controllers/public_recipe_shares_controller.rb`
- Modify: `app/helpers/public_recipe_pages_helper.rb`
- Modify: `app/services/public_recipe_share_snapshot_builder.rb`
- Modify: `app/views/public_recipe_shares/_form.html.erb`
- Modify: `app/views/public_recipe_pages/show.html.erb`
- Modify: `config/locales/en.yml`
- Test: `test/models/public_recipe_share_test.rb`
- Test: `test/controllers/public_recipe_shares_controller_test.rb`
- Create: `test/controllers/public_recipe_media_controller_test.rb`
- Test: `test/controllers/public_recipe_pages_controller_test.rb`

- [ ] **Step 1: Write failing public share form and snapshot tests**

Add to `PublicRecipeSharesControllerTest`:

```ruby
test "share form can select recipe photo but does not include it by default" do
  recipe = recipes(:household_recipe)
  recipe.photos.attach(
    io: file_fixture("photo.jpg").open,
    filename: "photo.jpg",
    content_type: "image/jpeg"
  )
  photo = recipe.photos.attachments.first
  sign_in_as(users(:one))

  get new_recipe_public_recipe_share_path(recipe)

  assert_response :success
  assert_select "input[type=checkbox][name=?][value=?]", "public_recipe_share[selected_photo_attachment_ids][]", photo.id.to_s
  assert_select "input[type=checkbox][name=?][value=?][checked]", "public_recipe_share[selected_photo_attachment_ids][]", photo.id.to_s, count: 0
end

test "update stores only selected recipe-owned public photo" do
  recipe = recipes(:household_recipe)
  recipe.photos.attach(
    io: file_fixture("photo.jpg").open,
    filename: "photo.jpg",
    content_type: "image/jpeg"
  )
  selected = recipe.photos.attachments.first
  unrelated_record = beans(:house_blend)
  unrelated_record.photos.attach(
    io: file_fixture("photo.jpg").open,
    filename: "photo.jpg",
    content_type: "image/jpeg"
  )
  unrelated = unrelated_record.photos.attachments.first
  create_share_for(recipe, enabled: false)
  sign_in_as(users(:one))

  patch recipe_public_recipe_share_path(recipe), params: {
    public_recipe_share: {
      enabled: "1",
      title: "Photo recipe",
      selected_photo_attachment_ids: [ selected.id, unrelated.id ]
    }
  }

  share = recipe.reload.public_recipe_share
  assert_redirected_to edit_recipe_public_recipe_share_path(recipe)
  assert_equal [ selected.id ], share.selected_photo_attachment_ids
  assert_equal selected.id, share.snapshot.dig("recipe", "photo", "attachment_id")
end
```

Add to `PublicRecipeShareTest`:

```ruby
test "public media handles resolve only selected recipe photos" do
  recipe = recipes(:household_recipe)
  recipe.photos.attach(
    io: file_fixture("photo.jpg").open,
    filename: "photo.jpg",
    content_type: "image/jpeg"
  )
  selected = recipe.photos.attachments.first
  share = PublicRecipeShare.create!(
    workspace: recipe.workspace,
    recipe:,
    created_by: users(:one),
    updated_by: users(:one),
    selected_photo_attachment_ids: [ selected.id ]
  )

  handle = share.public_media_handle_for(selected.id)

  assert handle.present?
  assert_equal selected.id, share.public_attachment_id_for_media_handle(handle)
  assert_nil share.public_media_handle_for(999_999)
end
```

- [ ] **Step 2: Write failing public media controller tests**

Create `test/controllers/public_recipe_media_controller_test.rb`:

```ruby
require "test_helper"

class PublicRecipeMediaControllerTest < ActionDispatch::IntegrationTest
  test "serves selected recipe photo through opaque handle" do
    share, photo = create_share_with_photo(enabled: true)

    get public_recipe_media_path(share.token, share.public_media_handle_for(photo.id), variant: "thumbnail")

    assert_response :success
    assert_equal "thumbnail", response.headers["X-Roastnode-Media-Variant"]
  end

  test "does not serve unselected recipe photo" do
    share, photo = create_share_with_photo(enabled: true, selected: false)

    get public_recipe_media_path(share.token, share.public_media_handle_for(photo.id) || "missing")

    assert_response :not_found
  end

  test "password protected share gates selected recipe media" do
    share, photo = create_share_with_photo(enabled: true, password: "espresso")

    get public_recipe_media_path(share.token, share.public_media_handle_for(photo.id))
    assert_response :not_found

    post unlock_public_recipe_page_path(share.token), params: { password: "espresso" }
    get public_recipe_media_path(share.token, share.public_media_handle_for(photo.id))
    assert_response :success
  end

  private
    def create_share_with_photo(enabled:, selected: true, password: nil)
      recipe = recipes(:household_recipe)
      recipe.photos.attach(
        io: file_fixture("photo.jpg").open,
        filename: "photo.jpg",
        content_type: "image/jpeg"
      )
      photo = recipe.photos.attachments.first
      selected_ids = selected ? [ photo.id ] : []
      share = recipe.create_public_recipe_share!(
        workspace: recipe.workspace,
        created_by: users(:one),
        updated_by: users(:one),
        title: "Shared recipe",
        enabled:,
        password:,
        selected_photo_attachment_ids: selected_ids,
        snapshot: PublicRecipeShareSnapshotBuilder.new(
          recipe:,
          title: "Shared recipe",
          selected_photo_attachment_ids: selected_ids
        ).call
      )
      [ share, photo ]
    end
end
```

- [ ] **Step 3: Write failing public page selected photo test**

Add to `PublicRecipePagesControllerTest`:

```ruby
test "enabled share renders selected recipe photo with opaque public media url" do
  recipe = recipes(:household_recipe)
  recipe.photos.attach(
    io: file_fixture("photo.jpg").open,
    filename: "photo.jpg",
    content_type: "image/jpeg"
  )
  photo = recipe.photos.attachments.first
  share = recipe.create_public_recipe_share!(
    workspace: recipe.workspace,
    created_by: users(:one),
    updated_by: users(:one),
    title: "Shared recipe",
    enabled: true,
    selected_photo_attachment_ids: [ photo.id ],
    snapshot: PublicRecipeShareSnapshotBuilder.new(recipe:, title: "Shared recipe", selected_photo_attachment_ids: [ photo.id ]).call
  )

  get public_recipe_page_path(share.token)

  assert_response :success
  assert_select "img[data-testid=public-recipe-photo][src^=?]", "/r/#{share.token}/media/"
  assert_no_match "attachment_id", response.body
  assert_no_match "/rails/active_storage", response.body
  assert_no_match "/media_attachments", response.body
end
```

- [ ] **Step 4: Run tests to verify they fail**

Run:

```bash
env PARALLEL_WORKERS=1 bin/rails test test/models/public_recipe_share_test.rb test/controllers/public_recipe_shares_controller_test.rb test/controllers/public_recipe_pages_controller_test.rb test/controllers/public_recipe_media_controller_test.rb
```

Expected: route/controller/method failures for public recipe media and selected photo IDs.

- [ ] **Step 5: Add route and controller**

In `config/routes.rb`:

```ruby
get "r/:token/media/:media_id" => "public_recipe_media#show", as: :public_recipe_media
```

Create `app/controllers/public_recipe_media_controller.rb`:

```ruby
class PublicRecipeMediaController < ApplicationController
  THUMBNAIL_VARIANT = MediaAttachmentsController::THUMBNAIL_VARIANT
  THUMBNAIL_TRANSFORMATIONS = MediaAttachmentsController::THUMBNAIL_TRANSFORMATIONS

  allow_unauthenticated_access

  before_action :set_share
  before_action :ensure_share_unlocked!
  before_action :set_attachment

  def show
    return send_thumbnail if params[:variant] == THUMBNAIL_VARIANT
    return head :not_found if params[:variant].present?

    send_blob(disposition: "inline")
  end

  private
    def set_share
      @share = PublicRecipeShare.find_enabled_by_token!(params[:token])
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

    def send_blob(disposition:, data: @attachment.blob.download)
      send_data data,
        type: @attachment.blob.content_type,
        disposition:,
        filename: public_filename
    end

    def send_thumbnail
      return head :not_found unless @attachment.blob.image?

      response.set_header("X-Roastnode-Media-Variant", THUMBNAIL_VARIANT)
      send_blob(disposition: "inline", data: thumbnail_data)
    end

    def thumbnail_data
      @attachment.blob.variant(THUMBNAIL_TRANSFORMATIONS).processed.download
    rescue LoadError, StandardError => error
      Rails.logger.info("Falling back to public recipe thumbnail original #{public_attachment_log_id}: #{error.class}")
      @attachment.blob.download
    end

    def public_attachment_log_id
      share_digest = Digest::SHA256.hexdigest(@share.id.to_s).first(12)
      attachment_digest = Digest::SHA256.hexdigest(@attachment.id.to_s).first(12)
      "PublicRecipeShare##{share_digest}/attachment/#{attachment_digest}"
    end

    def public_filename
      params[:variant] == THUMBNAIL_VARIANT ? "public-recipe-thumbnail" : "public-recipe-media"
    end

    def unlock_session_key
      "public_recipe_share:#{@share.token}:unlocked"
    end
end
```

- [ ] **Step 6: Add selected media methods to `PublicRecipeShare`**

Require OpenSSL:

```ruby
require "openssl"
```

Add methods:

```ruby
def public_attachment_ids
  collect_attachment_ids(snapshot.fetch("public_media", [])).map(&:to_i).uniq & selected_recipe_photo_attachment_ids
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

private
  def selected_recipe_photo_attachment_ids
    selected_ids = Array(selected_photo_attachment_ids).map(&:to_i)
    recipe.photos.attachments.map(&:id) & selected_ids
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
    Rails.application.key_generator.generate_key("public-recipe-share-media-handle")
  end
```

- [ ] **Step 7: Include selected photo metadata in public snapshot**

In `PublicRecipeShareSnapshotBuilder#call`, after payload build:

```ruby
payload["public_media"] = public_media_payloads(payload)
payload
```

Add to `recipe_payload`:

```ruby
"photo" => recipe_photo_payload,
```

Add methods:

```ruby
def recipe_photo_payload
  attachment = recipe.primary_photo_attachment
  return unless attachment && selected_photo_attachment_ids.include?(attachment.id)

  { "attachment_id" => attachment.id }
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
```

- [ ] **Step 8: Update public recipe share controller and form**

In `PublicRecipeSharesController`, add:

```ruby
def new
  load_form_state(default_selected_photo_attachment_ids)
end

def edit
  load_form_state(@share.selected_photo_attachment_ids)
end
```

On create/update rescue, call:

```ruby
load_form_state(permitted_selected_photo_attachment_ids)
```

In `save_share!`, pass:

```ruby
selected_photo_attachment_ids: permitted_selected_photo_attachment_ids,
```

Add helpers:

```ruby
def load_form_state(selected_photo_attachment_ids)
  @available_photos = @recipe.photos.attachments
  @selected_photo_attachment_ids = Array(selected_photo_attachment_ids).map(&:to_i)
end

def default_selected_photo_attachment_ids
  []
end

def selected_photo_attachment_ids_from_params
  Array(share_params[:selected_photo_attachment_ids]).map(&:to_i)
end

def permitted_selected_photo_attachment_ids
  selected_photo_attachment_ids_from_params & @recipe.photos.attachments.map(&:id)
end
```

Permit:

```ruby
selected_photo_attachment_ids: []
```

In `app/views/public_recipe_shares/_form.html.erb` add a media section when `available_photos.any?`:

```erb
<% if local_assigns.fetch(:available_photos, []).any? %>
  <section class="grid gap-4 rounded-2xl border border-rn-line bg-rn-surface p-4 shadow-sm sm:p-5">
    <h2 class="text-lg font-black text-rn-ink"><%= t(".photos") %></h2>
    <div class="grid gap-3 sm:grid-cols-3">
      <% available_photos.each do |photo| %>
        <label class="overflow-hidden rounded-2xl border border-rn-line bg-[var(--rn-canvas)]">
          <%= image_tag media_attachment_path(photo, variant: :thumbnail), alt: "", class: "h-36 w-full object-cover" %>
          <span class="flex items-center gap-2 p-3 text-sm font-extrabold text-rn-ink">
            <%= check_box_tag "public_recipe_share[selected_photo_attachment_ids][]", photo.id, selected_photo_attachment_ids.include?(photo.id), class: "h-4 w-4 rounded border-rn-line text-rn-ink" %>
            <%= t(".include_photo") %>
          </span>
        </label>
      <% end %>
    </div>
  </section>
<% end %>
```

Pass locals from `new.html.erb` and `edit.html.erb`:

```erb
available_photos: @available_photos,
selected_photo_attachment_ids: @selected_photo_attachment_ids,
```

- [ ] **Step 9: Render public selected photo**

In `PublicRecipePagesHelper`:

```ruby
def public_recipe_media_url_for(share, attachment_id, variant: nil)
  return if attachment_id.blank?

  media_handle = share.public_media_handle_for(attachment_id)
  return if media_handle.blank?

  public_recipe_media_path(share.token, media_handle, variant:)
end
```

In public recipe page:

```erb
<% if (photo_url = public_recipe_media_url_for(@share, recipe.dig("photo", "attachment_id"), variant: :thumbnail)).present? %>
  <%= image_tag photo_url, alt: "", data: { testid: "public-recipe-photo" }, class: "mt-6 h-80 w-full rounded-lg object-cover" %>
<% end %>
```

Locale:

```yaml
public_recipe_shares:
  form:
    photos: "Public recipe photo"
    include_photo: "Include"
```

- [ ] **Step 10: Run tests and commit**

Run:

```bash
env PARALLEL_WORKERS=1 bin/rails test test/models/public_recipe_share_test.rb test/controllers/public_recipe_shares_controller_test.rb test/controllers/public_recipe_pages_controller_test.rb test/controllers/public_recipe_media_controller_test.rb
```

Expected: all tests pass.

Commit:

```bash
git add config/routes.rb app/controllers/public_recipe_media_controller.rb app/models/public_recipe_share.rb app/controllers/public_recipe_shares_controller.rb app/helpers/public_recipe_pages_helper.rb app/services/public_recipe_share_snapshot_builder.rb app/views/public_recipe_shares app/views/public_recipe_pages/show.html.erb config/locales/en.yml test/models/public_recipe_share_test.rb test/controllers/public_recipe_shares_controller_test.rb test/controllers/public_recipe_pages_controller_test.rb test/controllers/public_recipe_media_controller_test.rb
git commit -m "feat: share selected recipe photo publicly"
```

---

### Task 5: Docs, Full Verification, And Browser Smoke

**Files:**
- Modify: `docs/recipe-profiles.md`
- Modify: `docs/coffee-core.md`
- Modify: `docs/private-media.md`
- Modify: `docs/status.md`
- Modify: `AGENTS.md` if the public recipe media privacy rule needs compact agent guidance.

- [ ] **Step 1: Update docs**

Update `docs/recipe-profiles.md`:

```markdown
- Recipe profiles support structured finish ingredients, a finish note, and one private finished-drink photo.
- Public recipe shares include ingredients and finish note by default.
- Public recipe media is private by default and appears publicly only when the share explicitly selects the recipe photo.
```

Update privacy notes:

```markdown
- Public recipe media must use opaque `PublicRecipeShare` media handles and the share's selected recipe-photo allowlist.
- Recipe JSON export/import includes ingredients and finish note, but never photo files, attachment IDs, signed URLs, or media handles.
```

Update `docs/private-media.md`:

```markdown
Public recipe share pages may render explicitly selected recipe photos through `PublicRecipeMediaController`. They must not use `MediaAttachmentsController` or raw Active Storage URLs.
```

Update `docs/status.md` and `docs/coffee-core.md` with one compact built-now bullet.

- [ ] **Step 2: Run focused recipe and media tests**

Run:

```bash
env PARALLEL_WORKERS=1 bin/rails test test/models/recipe_test.rb test/models/public_recipe_share_test.rb test/controllers/recipes_controller_test.rb test/controllers/brews_controller_test.rb test/controllers/public_recipe_shares_controller_test.rb test/controllers/public_recipe_pages_controller_test.rb test/controllers/public_recipe_media_controller_test.rb test/services/recipe_exporter_test.rb test/services/recipe_importer_test.rb
```

Expected: all tests pass.

- [ ] **Step 3: Run full test suite**

Run:

```bash
env PARALLEL_WORKERS=1 bin/rails test
```

Expected: all tests pass with `0 failures, 0 errors`.

- [ ] **Step 4: Browser smoke private recipe flow**

With the local server running on `http://localhost:3001`:

1. Open a recipe create form from a brew with a photo.
2. Verify the source photo suggestion is visible and unchecked.
3. Create a recipe with:
   - ingredient row `200 / ml / matcha`
   - ingredient row `1 / shot / honey`
   - finish note
   - source photo selected
4. Verify recipe detail shows target guide, finish card, and recipe photo.
5. Open "Log with this recipe" and verify the finish card appears beside the normal brew form.

- [ ] **Step 5: Browser smoke public recipe flow**

1. Open the recipe public share form.
2. Enable the share.
3. Verify the recipe photo checkbox is present and unchecked by default.
4. Save with the recipe photo checked.
5. Open the public `/r/:token` page.
6. Verify ingredients, finish note, target guide, and selected photo render.
7. Verify page HTML does not include:
   - `/rails/active_storage`
   - `/media_attachments`
   - `attachment_id`
   - original filename

- [ ] **Step 6: Commit final docs**

Run:

```bash
git status --short
git add docs/recipe-profiles.md docs/coffee-core.md docs/private-media.md docs/status.md AGENTS.md
git commit -m "docs: document recipe ingredients and photo"
```

Expected: commit succeeds and `git status --short` is clean.
