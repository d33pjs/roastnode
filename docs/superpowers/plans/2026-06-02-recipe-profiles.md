# Recipe Profiles Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build v1 recipe profiles from logged brews, including private recipe management, guided logging, Hero Card ghost comparison, public recipe sharing, and JSON import/export.

**Architecture:** Recipes are workspace-scoped records with JSON profile snapshots initialized from source brews. Brews logged with recipes keep a brew-time recipe snapshot for historical comparison. Public recipe pages and recipe JSON export render from curated snapshots and never read private workspace data publicly.

**Tech Stack:** Rails 8.1, Active Record, Hotwire/Turbo-compatible server-rendered views, Tailwind CSS classes, PostgreSQL jsonb, Minitest.

---

## File Structure

- Create `db/migrate/*_create_recipes_and_public_recipe_shares.rb`: recipe and public recipe share tables, plus `brews.recipe_id` and `brews.recipe_snapshot`.
- Create `app/models/recipe.rb`: workspace-scoped recipe model, source brew provenance, JSON profile validation, export filename, public-share association.
- Create `app/models/public_recipe_share.rb`: public token/password/snapshot model mirroring `PublicBrewShare` without v1 media.
- Modify `app/models/brew.rb`: optional recipe association and snapshot capture on recipe-guided create.
- Modify `app/models/record_link.rb`: allow `Recipe` as a linkable type.
- Create `app/services/recipe_snapshot_builder.rb`: build editable/private recipe profile snapshots from brews and imported data.
- Create `app/services/recipe_exporter.rb`: produce the v1 portable JSON document.
- Create `app/services/recipe_importer.rb`: validate and import a v1 portable JSON document as an unlinked recipe.
- Create `app/services/public_recipe_share_snapshot_builder.rb`: build public-safe recipe share snapshots.
- Create `app/controllers/recipes_controller.rb`: private index/show/new/create/edit/update/import/export/log-with-recipe/destroy flow.
- Create `app/controllers/public_recipe_shares_controller.rb`: private public-share management for one recipe.
- Create `app/controllers/public_recipe_pages_controller.rb`: unauthenticated public recipe page and password gate.
- Modify `app/controllers/brews_controller.rb`: load optional recipe guide, associate recipe snapshot on create, and keep normal brew defaults unchanged.
- Create recipe views under `app/views/recipes/`, `app/views/public_recipe_shares/`, and `app/views/public_recipe_pages/`.
- Modify `app/views/brews/new.html.erb`, `app/views/brews/_form.html.erb`, and `app/views/brews/_hero_card.html.erb`: guide slot and ghost chart.
- Modify `app/views/shared/_app_navigation.html.erb`: add Recipes navigation.
- Modify `config/routes.rb`: recipe CRUD, import/export/log route, public recipe share routes.
- Modify `config/locales/en.yml`: labels and notices.
- Create fixtures `test/fixtures/recipes.yml` and `test/fixtures/public_recipe_shares.yml`.
- Create tests for models, services, controllers, public pages, and brew integration.
- Add `docs/recipe-profiles.md` and update public project docs after implementation.

---

### Task 1: Recipe Data Model And Snapshot Builder

**Files:**
- Create: `db/migrate/*_create_recipes_and_public_recipe_shares.rb`
- Create: `app/models/recipe.rb`
- Create: `app/services/recipe_snapshot_builder.rb`
- Modify: `app/models/brew.rb`
- Modify: `app/models/record_link.rb`
- Test: `test/models/recipe_test.rb`
- Test: `test/services/recipe_snapshot_builder_test.rb`
- Fixture: `test/fixtures/recipes.yml`

- [ ] **Step 1: Write failing model and snapshot tests**

Create tests proving that recipes are workspace scoped, can be built from a brew, preserve source brew values in a profile snapshot, and reject cross-workspace source brews.

Run: `bin/rails test test/models/recipe_test.rb test/services/recipe_snapshot_builder_test.rb`

Expected: failure because `Recipe` and `RecipeSnapshotBuilder` do not exist.

- [ ] **Step 2: Add migration and model code**

Create recipes with `workspace_id`, `created_by_id`, optional `source_brew_id`, `title`, `method`, `profile`, `source_snapshot`, and timestamps. Add `brews.recipe_id` and `brews.recipe_snapshot`. Allow `Recipe` in `RecordLink::LINKABLE_TYPES`.

Run: `bin/rails db:migrate`

Expected: migration succeeds.

- [ ] **Step 3: Implement `RecipeSnapshotBuilder`**

Build a hash containing target values from a source brew, bean/grinder/machine/tool snapshots, source brew provenance, public links, and optional target guide note. Do not include private notes.

- [ ] **Step 4: Run tests green and commit**

Run: `bin/rails test test/models/recipe_test.rb test/services/recipe_snapshot_builder_test.rb`

Expected: all tests pass.

Commit: `git commit -m "feat: add recipe profile model"`

---

### Task 2: Private Recipes Area

**Files:**
- Create: `app/controllers/recipes_controller.rb`
- Create: `app/views/recipes/index.html.erb`
- Create: `app/views/recipes/show.html.erb`
- Create: `app/views/recipes/new.html.erb`
- Create: `app/views/recipes/edit.html.erb`
- Create: `app/views/recipes/_form.html.erb`
- Create: `app/views/recipes/_target_guide.html.erb`
- Modify: `config/routes.rb`
- Modify: `app/views/shared/_app_navigation.html.erb`
- Modify: `config/locales/en.yml`
- Test: `test/controllers/recipes_controller_test.rb`

- [ ] **Step 1: Write failing private controller tests**

Test recipe index/detail, create from brew, edit exact targets, viewer read-only behavior, cross-workspace isolation, and navigation presence.

Run: `bin/rails test test/controllers/recipes_controller_test.rb`

Expected: failure because recipe routes/controllers/views do not exist.

- [ ] **Step 2: Implement routes, controller, and views**

Add `resources :recipes` with member `log`, collection `import` and `export` routes. Use `current_workspace.recipes` for all lookups. Require write access for new/create/edit/update/destroy/import/export/log; allow viewers to index/show.

- [ ] **Step 3: Render private Recipes UI**

Index shows recipe cards with key targets. Detail shows target guide, full profile, source brew link when local, public share state, export, edit, and log actions. Form edits exact target values and public-safe notes/links.

- [ ] **Step 4: Run tests green and commit**

Run: `bin/rails test test/controllers/recipes_controller_test.rb`

Expected: all tests pass.

Commit: `git commit -m "feat: add private recipe library"`

---

### Task 3: Recipe-Guided Logging And Hero Ghost

**Files:**
- Modify: `app/controllers/brews_controller.rb`
- Modify: `app/models/brew.rb`
- Modify: `app/views/brews/new.html.erb`
- Modify: `app/views/brews/_form.html.erb`
- Modify: `app/views/brews/_hero_card.html.erb`
- Modify: `app/helpers/brews_helper.rb`
- Test: `test/controllers/brews_controller_test.rb`
- Test: `test/models/brew_test.rb`

- [ ] **Step 1: Write failing guided logging tests**

Test that `new_brew_path(recipe_id: recipes(:household_recipe))` keeps normal default field values, renders the recipe target guide, saves `recipe_id` and `recipe_snapshot`, and rejects cross-workspace recipes.

Run: `bin/rails test test/controllers/brews_controller_test.rb test/models/brew_test.rb`

Expected: failures for missing recipe integration.

- [ ] **Step 2: Implement guided logging load and snapshot capture**

Load optional recipe from `current_workspace.recipes` in `BrewsController#new` and `#create`. Add hidden `recipe_id` only when present. On successful create, store `brew.recipe_snapshot = recipe.profile` for same-workspace recipes.

- [ ] **Step 3: Add guide slot and Hero Card ghost**

Render `recipes/_target_guide` beside the normal brew form on desktop and above it on mobile. Add faint SVG ghost path/timing guides in the Hero Card when `brew.recipe_snapshot` is present.

- [ ] **Step 4: Run tests green and commit**

Run: `bin/rails test test/controllers/brews_controller_test.rb test/models/brew_test.rb`

Expected: all tests pass.

Commit: `git commit -m "feat: guide espresso logs with recipes"`

---

### Task 4: Recipe JSON Export And Import

**Files:**
- Create: `app/services/recipe_exporter.rb`
- Create: `app/services/recipe_importer.rb`
- Modify: `app/controllers/recipes_controller.rb`
- Modify: `app/views/recipes/index.html.erb`
- Modify: `app/views/recipes/show.html.erb`
- Test: `test/services/recipe_exporter_test.rb`
- Test: `test/services/recipe_importer_test.rb`
- Test: `test/controllers/recipes_controller_test.rb`

- [ ] **Step 1: Write failing portability tests**

Test JSON export schema/version, exclusion of private notes/media internals, malformed JSON rejection, unsafe link scheme rejection, and import creating an unlinked recipe without beans/equipment/tools/brews/media.

Run: `bin/rails test test/services/recipe_exporter_test.rb test/services/recipe_importer_test.rb test/controllers/recipes_controller_test.rb`

Expected: failure because services and actions do not exist.

- [ ] **Step 2: Implement exporter and importer**

Exporter emits a single JSON document with `schema: "roastnode.recipe"`, `version: 1`, recipe target profile, public links, source provenance, and generated timestamp. Importer validates schema/version and HTTP/HTTPS links before creating a recipe in `current_workspace`.

- [ ] **Step 3: Add controller endpoints and UI actions**

Export downloads a `.json` file. Import accepts one uploaded JSON file and redirects to the imported recipe or back with an alert on invalid input.

- [ ] **Step 4: Run tests green and commit**

Run: `bin/rails test test/services/recipe_exporter_test.rb test/services/recipe_importer_test.rb test/controllers/recipes_controller_test.rb`

Expected: all tests pass.

Commit: `git commit -m "feat: import and export recipes"`

---

### Task 5: Public Recipe Sharing

**Files:**
- Create: `app/models/public_recipe_share.rb`
- Create: `app/services/public_recipe_share_snapshot_builder.rb`
- Create: `app/controllers/public_recipe_shares_controller.rb`
- Create: `app/controllers/public_recipe_pages_controller.rb`
- Create: `app/views/public_recipe_shares/new.html.erb`
- Create: `app/views/public_recipe_shares/edit.html.erb`
- Create: `app/views/public_recipe_shares/_form.html.erb`
- Create: `app/views/public_recipe_pages/show.html.erb`
- Create: `app/views/public_recipe_pages/password.html.erb`
- Modify: `config/routes.rb`
- Modify: `config/locales/en.yml`
- Test: `test/models/public_recipe_share_test.rb`
- Test: `test/controllers/public_recipe_shares_controller_test.rb`
- Test: `test/controllers/public_recipe_pages_controller_test.rb`
- Fixture: `test/fixtures/public_recipe_shares.yml`

- [ ] **Step 1: Write failing public sharing tests**

Test share management authorization, enabled/disabled public pages, optional password gate, snapshot rendering, no live private reads, and no leakage of private notes, emails, raw media URLs, attachment ids, invite tokens, or equipment/tool costs.

Run: `bin/rails test test/models/public_recipe_share_test.rb test/controllers/public_recipe_shares_controller_test.rb test/controllers/public_recipe_pages_controller_test.rb`

Expected: failure because public recipe sharing does not exist.

- [ ] **Step 2: Implement public recipe share model and snapshot builder**

Mirror public brew share token/password behavior but omit v1 media. Snapshot includes title, targets, public-safe bean/gear/tool data, public links, workspace name, user display label, and source provenance.

- [ ] **Step 3: Implement share management and public pages**

Private share editor controls enabled, title, password, and snapshot refresh. Public pages render target instructions first and source brew provenance below. Unknown/disabled shares return not found.

- [ ] **Step 4: Run tests green and commit**

Run: `bin/rails test test/models/public_recipe_share_test.rb test/controllers/public_recipe_shares_controller_test.rb test/controllers/public_recipe_pages_controller_test.rb`

Expected: all tests pass.

Commit: `git commit -m "feat: share recipe profiles publicly"`

---

### Task 6: Documentation, Full Verification, And Server

**Files:**
- Create: `docs/recipe-profiles.md`
- Modify: `docs/README.md`
- Modify: `docs/status.md`
- Modify: `docs/coffee-core.md`
- Modify: `docs/brew-card.md`
- Modify: `AGENTS.md` if the new privacy rules need agent-level visibility.

- [ ] **Step 1: Write recipe documentation**

Document private recipes, guided logging, snapshot rules, public sharing, JSON portability, v1 limits, and agent notes.

- [ ] **Step 2: Update existing docs**

Remove recipes from the deferred lists and add recipe profile status. Keep public media warnings aligned with v1 no-media recipe shares.

- [ ] **Step 3: Run focused tests**

Run: `bin/rails test test/models/recipe_test.rb test/services/recipe_snapshot_builder_test.rb test/controllers/recipes_controller_test.rb test/models/brew_test.rb test/controllers/brews_controller_test.rb test/services/recipe_exporter_test.rb test/services/recipe_importer_test.rb test/models/public_recipe_share_test.rb test/controllers/public_recipe_shares_controller_test.rb test/controllers/public_recipe_pages_controller_test.rb`

Expected: all tests pass.

- [ ] **Step 4: Run full serial Rails test suite**

Run: `env PARALLEL_WORKERS=1 bin/rails test`

Expected: all tests pass.

- [ ] **Step 5: Start development server**

Run: `bin/dev`

Expected: Rails starts on the project dev port so the user can review the recipe UI.

- [ ] **Step 6: Commit docs and final state**

Commit: `git commit -m "docs: document recipe profiles"`
