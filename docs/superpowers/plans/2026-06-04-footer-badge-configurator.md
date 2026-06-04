# Footer Badge Configurator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a household-configurable Buy Me a Coffee footer mode and make the GitHub/support/version footer items visually consistent.

**Architecture:** Store only trusted configuration on `Workspace`: mode, official badge slug, and text. Public controllers pass a footer support configuration to the shared footer, and the footer partial decides whether to render the simple link, official script badge, or version. The settings page stays the single admin UI for household support badge configuration.

**Tech Stack:** Rails 8, Active Record migrations, ERB views, Hotwire-compatible forms, Tailwind CSS, Minitest integration/model tests.

---

### Task 1: Workspace Data And Model Behavior

**Files:**
- Create: `db/migrate/20260604165000_add_buy_me_a_coffee_badge_config_to_workspaces.rb`
- Modify: `app/models/workspace.rb`
- Modify: `test/models/workspace_test.rb`

- [ ] **Step 1: Write failing model tests**

Add tests proving default mode, slug/text normalization, official mode requirements, and simple link behavior:

```ruby
test "buy me a coffee badge config defaults to link mode" do
  workspace = Workspace.new(name: "Test", default_currency: "EUR")

  assert_equal "link", workspace.buy_me_a_coffee_display_mode
  assert_not workspace.official_buy_me_a_coffee_badge?
  assert_nil workspace.site_footer_buy_me_a_coffee
end

test "official buy me a coffee badge requires a slug and builds footer config" do
  workspace = workspaces(:household)

  workspace.assign_attributes(
    buy_me_a_coffee_display_mode: "official_badge",
    buy_me_a_coffee_slug: " d33p.js ",
    buy_me_a_coffee_text: " Support the beans "
  )

  assert workspace.valid?
  assert_equal "d33p.js", workspace.buy_me_a_coffee_slug
  assert_equal "Support the beans", workspace.buy_me_a_coffee_text
  assert_equal(
    {
      mode: :official_badge,
      slug: "d33p.js",
      text: "Support the beans"
    },
    workspace.site_footer_buy_me_a_coffee
  )
end

test "official buy me a coffee badge rejects missing and unsafe slugs" do
  workspace = workspaces(:household)
  workspace.buy_me_a_coffee_display_mode = "official_badge"

  workspace.buy_me_a_coffee_slug = ""
  assert_not workspace.valid?

  workspace.buy_me_a_coffee_slug = "bad/slug"
  assert_not workspace.valid?

  workspace.buy_me_a_coffee_slug = "https://buymeacoffee.com/roastnode"
  assert_not workspace.valid?
end

test "buy me a coffee badge text has a length limit" do
  workspace = workspaces(:household)

  workspace.assign_attributes(
    buy_me_a_coffee_display_mode: "official_badge",
    buy_me_a_coffee_slug: "roastnode",
    buy_me_a_coffee_text: "x" * 81
  )

  assert_not workspace.valid?
end

test "simple buy me a coffee link builds footer config" do
  workspace = workspaces(:household)
  workspace.buy_me_a_coffee_url = "https://buymeacoffee.com/roastnode"

  assert_equal(
    {
      mode: :link,
      url: "https://buymeacoffee.com/roastnode"
    },
    workspace.site_footer_buy_me_a_coffee
  )
end
```

- [ ] **Step 2: Run model tests to verify failure**

Run: `bin/rails test test/models/workspace_test.rb`

Expected: failures for missing columns/methods.

- [ ] **Step 3: Add migration and model implementation**

Create migration:

```ruby
class AddBuyMeACoffeeBadgeConfigToWorkspaces < ActiveRecord::Migration[8.1]
  def change
    add_column :workspaces, :buy_me_a_coffee_display_mode, :string, null: false, default: "link"
    add_column :workspaces, :buy_me_a_coffee_slug, :string
    add_column :workspaces, :buy_me_a_coffee_text, :string
  end
end
```

Update `Workspace`:

```ruby
BUY_ME_A_COFFEE_DISPLAY_MODES = %w[link official_badge].freeze
BUY_ME_A_COFFEE_DEFAULT_TEXT = "Buy me a coffee"
BUY_ME_A_COFFEE_SLUG_FORMAT = /\A[a-zA-Z0-9._-]+\z/
```

Add normalizers and validations:

```ruby
normalizes :buy_me_a_coffee_display_mode, with: ->(mode) { mode.to_s.strip.presence || "link" }
normalizes :buy_me_a_coffee_slug, with: ->(slug) { slug.to_s.strip.presence }
normalizes :buy_me_a_coffee_text, with: ->(text) { text.to_s.strip.presence }

validates :buy_me_a_coffee_display_mode, inclusion: { in: BUY_ME_A_COFFEE_DISPLAY_MODES }
validates :buy_me_a_coffee_slug,
  presence: true,
  length: { maximum: 100 },
  format: { with: BUY_ME_A_COFFEE_SLUG_FORMAT },
  if: :official_buy_me_a_coffee_badge?
validates :buy_me_a_coffee_text, length: { maximum: 80 }, allow_blank: true
```

Add public helpers:

```ruby
def official_buy_me_a_coffee_badge?
  buy_me_a_coffee_display_mode == "official_badge"
end

def buy_me_a_coffee_badge_text
  buy_me_a_coffee_text.presence || BUY_ME_A_COFFEE_DEFAULT_TEXT
end

def site_footer_buy_me_a_coffee
  if official_buy_me_a_coffee_badge?
    return if buy_me_a_coffee_slug.blank?

    { mode: :official_badge, slug: buy_me_a_coffee_slug, text: buy_me_a_coffee_badge_text }
  elsif buy_me_a_coffee_url.present?
    { mode: :link, url: buy_me_a_coffee_url }
  end
end
```

- [ ] **Step 4: Run migration and model tests**

Run: `bin/rails db:migrate`

Expected: migration succeeds.

Run: `bin/rails test test/models/workspace_test.rb`

Expected: tests pass.

### Task 2: Household Settings Configurator

**Files:**
- Modify: `app/controllers/workspaces_controller.rb`
- Modify: `app/views/workspaces/edit.html.erb`
- Modify: `config/locales/en.yml`
- Modify: `test/controllers/workspaces_controller_test.rb`

- [ ] **Step 1: Write failing settings tests**

Update the edit test to assert the new controls exist:

```ruby
assert_select "select[name=?]", "workspace[buy_me_a_coffee_display_mode]"
assert_select "input[name=?]", "workspace[buy_me_a_coffee_slug]"
assert_select "input[name=?]", "workspace[buy_me_a_coffee_text]"
```

Add an update test:

```ruby
test "owner can update official buy me a coffee badge settings" do
  sign_in_as(users(:one))

  patch workspace_path, params: {
    workspace: {
      name: "Jens Coffee Lab",
      default_currency: "eur",
      buy_me_a_coffee_display_mode: "official_badge",
      buy_me_a_coffee_slug: "d33p.js",
      buy_me_a_coffee_text: "Buy me a coffee"
    }
  }

  workspace = workspaces(:household).reload
  assert_redirected_to dashboard_path
  assert_equal "official_badge", workspace.buy_me_a_coffee_display_mode
  assert_equal "d33p.js", workspace.buy_me_a_coffee_slug
  assert_equal "Buy me a coffee", workspace.buy_me_a_coffee_text
end
```

- [ ] **Step 2: Run settings controller tests to verify failure**

Run: `bin/rails test test/controllers/workspaces_controller_test.rb`

Expected: failures for missing permitted fields and form controls.

- [ ] **Step 3: Permit new fields**

Update `workspace_params`:

```ruby
params.require(:workspace).permit(
  :name,
  :default_currency,
  :buy_me_a_coffee_url,
  :buy_me_a_coffee_display_mode,
  :buy_me_a_coffee_slug,
  :buy_me_a_coffee_text,
  :logo,
  :banner
)
```

- [ ] **Step 4: Add configurator UI and translations**

Replace the single Buy Me a Coffee URL block with a bordered support badge fieldset containing display mode select, URL, slug, and text fields. Add translation keys for the new labels and help text.

- [ ] **Step 5: Run settings tests**

Run: `bin/rails test test/controllers/workspaces_controller_test.rb`

Expected: tests pass.

### Task 3: Footer Rendering, Public Pages, Docs, And Verification

**Files:**
- Modify: `app/controllers/public_brew_pages_controller.rb`
- Modify: `app/controllers/public_recipe_pages_controller.rb`
- Modify: `app/views/shared/_site_footer.html.erb`
- Modify: `test/controllers/home_controller_test.rb`
- Modify: `test/controllers/sessions_controller_test.rb`
- Modify: `test/controllers/public_brew_pages_controller_test.rb`
- Modify: `test/controllers/public_recipe_pages_controller_test.rb`
- Modify: `docs/workspace-settings.md`
- Modify: `docs/status.md`

- [ ] **Step 1: Write failing public footer tests**

Update simple-link assertions to expect the matched badge shell:

```ruby
assert_select "a[data-testid=site-footer-buy-me-a-coffee][href=?]", "https://buymeacoffee.com/roastnode"
assert_select "[data-testid=site-footer-github-logo]"
```

Add official badge assertions to public brew and recipe tests:

```ruby
share.workspace.update!(
  buy_me_a_coffee_display_mode: "official_badge",
  buy_me_a_coffee_slug: "d33p.js",
  buy_me_a_coffee_text: "Buy me a coffee"
)

get public_brew_page_path(share.token)

assert_select "script[data-testid=site-footer-buy-me-a-coffee][src=?]", "https://cdnjs.buymeacoffee.com/1.0.0/button.prod.min.js"
assert_select "script[data-slug=?]", "d33p.js"
assert_select "script[data-text=?]", "Buy me a coffee"
assert_select "script[data-color=?]", "#986338"
assert_select "[data-testid=site-footer-version]", count: 0
```

- [ ] **Step 2: Run public/footer tests to verify failure**

Run:

```bash
bin/rails test \
  test/controllers/home_controller_test.rb \
  test/controllers/sessions_controller_test.rb \
  test/controllers/public_brew_pages_controller_test.rb \
  test/controllers/public_recipe_pages_controller_test.rb
```

Expected: failures until the partial and controller locals are updated.

- [ ] **Step 3: Pass support config from public controllers**

Replace `@site_footer_buy_me_a_coffee_url = @share.workspace.buy_me_a_coffee_url` with:

```ruby
@site_footer_buy_me_a_coffee = @share.workspace.site_footer_buy_me_a_coffee
```

- [ ] **Step 4: Update the footer partial**

Read support config from either `buy_me_a_coffee` or legacy `buy_me_a_coffee_url`, render GitHub first, then render official script, simple link, or version on the right. Use inline SVG logos for GitHub and simple-link Buy Me a Coffee.

- [ ] **Step 5: Update layout local**

Pass `buy_me_a_coffee: @site_footer_buy_me_a_coffee` from `app/views/layouts/application.html.erb`.

- [ ] **Step 6: Update docs**

Document that household settings now support simple-link and official-script Buy Me a Coffee modes, and note that official mode loads Buy Me a Coffee CDN JavaScript on public shares.

- [ ] **Step 7: Run targeted tests**

Run:

```bash
bin/rails test \
  test/models/workspace_test.rb \
  test/controllers/workspaces_controller_test.rb \
  test/controllers/home_controller_test.rb \
  test/controllers/sessions_controller_test.rb \
  test/controllers/public_brew_pages_controller_test.rb \
  test/controllers/public_recipe_pages_controller_test.rb
```

Expected: all pass.

- [ ] **Step 8: Run full test suite**

Run: `env PARALLEL_WORKERS=1 bin/rails test`

Expected: full suite passes.

- [ ] **Step 9: Browser verification**

Start or reuse `bin/dev`, open the app on port `3001`, and verify household settings plus public brew/recipe footer desktop and mobile layouts.

- [ ] **Step 10: Commit implementation**

Run:

```bash
git add app db config test docs
git commit -m "Add footer badge configurator"
```
