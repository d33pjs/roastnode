# Public Brew Native Share Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a native mobile share shortcut for already-enabled public brew shares in the compact Brew Log and brew detail action area.

**Architecture:** Render a reusable private-app button partial only when a brew has an enabled `PublicBrewShare`. A focused Stimulus controller invokes `navigator.share` with the public share URL and copies the URL to the clipboard when native sharing is unavailable. The compact Brew Log card becomes an article with a primary body link and a separate action row so the share button is not nested inside a link.

**Tech Stack:** Rails 8.1, ERB, Hotwire Stimulus, Rails controller tests, static JavaScript asset tests.

---

## File Structure

- Modify `test/controllers/brews_controller_test.rb`: add rendering assertions for enabled, disabled, and missing share shortcuts.
- Create `test/assets/native_share_controller_test.rb`: verify the Stimulus controller contains the Web Share and clipboard fallback paths.
- Create `app/javascript/controllers/native_share_controller.js`: handle native share, clipboard fallback, and temporary labels.
- Create `app/views/shared/_native_share_button.html.erb`: reusable private-app share button.
- Modify `app/views/brews/_compact_card.html.erb`: split the card into a link body plus optional action row.
- Modify `app/views/brews/show.html.erb`: add the optional button beside the public share management link.
- Modify `config/locales/en.yml`: add button and status labels.
- Modify `docs/public-brew-sharing.md`: document the private-app shortcut.

### Task 1: Server Rendering Tests

**Files:**
- Modify: `test/controllers/brews_controller_test.rb`

- [ ] **Step 1: Write the failing compact Brew Log assertions**

In `test "index shows workspace brews newest first in compact view by default"`, after the existing shared-marker assertions, add:

```ruby
assert_select "[data-testid=?]", "brew-native-share-button-#{older.id}", I18n.t("shared.native_share.share")
assert_select "[data-testid=?]", "brew-native-share-button-#{newest.id}", count: 0
assert_select "[data-testid=?]", "brew-history-compact-card-link-#{older.id}"
```

- [ ] **Step 2: Write the failing detail action tests**

Add one test for an enabled share and one negative assertion to the disabled-share detail test:

```ruby
test "writer sees native share action when public share is enabled" do
  sign_in_as(users(:one))
  brew = brews(:morning_espresso)
  share = create_public_brew_share_for(brew, enabled: true)

  get brew_path(brew)

  assert_response :success
  assert_select "[data-testid=?][data-native-share-url-value=?]",
    "brew-native-share-button-#{brew.id}",
    public_brew_page_url(share.token),
    text: I18n.t("shared.native_share.share")
end
```

In `test "writer sees edit public share action when brew already has a share"`, add:

```ruby
assert_select "[data-testid=?]", "brew-native-share-button-#{brew.id}", count: 0
```

- [ ] **Step 3: Run tests to verify RED**

Run: `bin/rails test test/controllers/brews_controller_test.rb`

Expected: failures because the native-share button and compact-card link test IDs do not exist yet.

### Task 2: Stimulus Controller Tests

**Files:**
- Create: `test/assets/native_share_controller_test.rb`

- [ ] **Step 1: Write the failing asset test**

Create:

```ruby
require "test_helper"

class NativeShareControllerTest < ActiveSupport::TestCase
  test "native share controller opens web share and falls back to clipboard" do
    controller = Rails.root.join("app/javascript/controllers/native_share_controller.js")
    source = controller.read

    assert_includes source, "static values"
    assert_includes source, "navigator.share"
    assert_includes source, "await navigator.share(shareData)"
    assert_includes source, "navigator.clipboard.writeText(this.urlValue)"
    assert_includes source, "event.preventDefault()"
    assert_includes source, "setTimeout"
    assert_includes source, "this.labelTarget.textContent"
  end
end
```

- [ ] **Step 2: Run test to verify RED**

Run: `bin/rails test test/assets/native_share_controller_test.rb`

Expected: error or failure because `app/javascript/controllers/native_share_controller.js` does not exist.

### Task 3: Implement Button, Controller, and Views

**Files:**
- Create: `app/javascript/controllers/native_share_controller.js`
- Create: `app/views/shared/_native_share_button.html.erb`
- Modify: `app/views/brews/_compact_card.html.erb`
- Modify: `app/views/brews/show.html.erb`
- Modify: `config/locales/en.yml`

- [ ] **Step 1: Add locale labels**

Add under `en.shared`:

```yaml
    native_share:
      copied: "Copied"
      failed: "Copy failed"
      share: "Share"
```

Add under `en.brews`:

```yaml
    native_share:
      text: "Shared brew: %{title}"
```

- [ ] **Step 2: Implement the Stimulus controller**

Create `app/javascript/controllers/native_share_controller.js` with:

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "label" ]
  static values = {
    copiedLabel: String,
    failedLabel: String,
    text: String,
    title: String,
    url: String
  }

  connect() {
    this.defaultLabel = this.labelTarget.textContent
  }

  async share(event) {
    event.preventDefault()

    const shareData = {
      title: this.titleValue,
      text: this.textValue || this.titleValue,
      url: this.urlValue
    }

    if (navigator.share) {
      try {
        await navigator.share(shareData)
        return
      } catch (error) {
        if (error.name === "AbortError") return
      }
    }

    await this.copyFallback()
  }

  async copyFallback() {
    try {
      if (!navigator.clipboard?.writeText) throw new Error("Clipboard unavailable")

      await navigator.clipboard.writeText(this.urlValue)
      this.flashLabel(this.copiedLabelValue)
    } catch (_error) {
      this.flashLabel(this.failedLabelValue)
    }
  }

  flashLabel(label) {
    this.labelTarget.textContent = label
    clearTimeout(this.resetTimer)
    this.resetTimer = setTimeout(() => {
      this.labelTarget.textContent = this.defaultLabel
    }, 2000)
  }
}
```

- [ ] **Step 3: Implement the shared partial**

Create `app/views/shared/_native_share_button.html.erb` with:

```erb
<% button_class = local_assigns.fetch(:button_class, "inline-flex items-center justify-center rounded-md border border-stone-300 bg-white px-3 py-2 text-sm font-semibold text-stone-900 hover:bg-stone-100") %>
<% share_text = local_assigns.fetch(:text, title) %>

<%= button_tag type: "button",
  class: button_class,
  data: {
    controller: "native-share",
    action: "click->native-share#share",
    native_share_title_value: title,
    native_share_text_value: share_text,
    native_share_url_value: url,
    native_share_copied_label_value: t("shared.native_share.copied"),
    native_share_failed_label_value: t("shared.native_share.failed"),
    testid: local_assigns[:testid]
  } do %>
  <span data-native-share-target="label"><%= t("shared.native_share.share") %></span>
<% end %>
```

- [ ] **Step 4: Update compact card rendering**

Wrap the existing body content in an `article` and put the main content inside `link_to brew_path(brew)` with `data-testid="brew-history-compact-card-link-#{brew.id}"`. Render the shared partial in a bottom action row only when:

```erb
<% public_share = brew.public_brew_share if brew.public_brew_share&.enabled? %>
```

Use:

```erb
<%= render "shared/native_share_button",
  url: public_brew_page_url(public_share.token),
  title: public_share.title.presence || PublicBrewShare.default_title_for(brew),
  text: t("brews.native_share.text", title: public_share.title.presence || PublicBrewShare.default_title_for(brew)),
  testid: "brew-native-share-button-#{brew.id}",
  button_class: "inline-flex items-center justify-center rounded-md border border-rn-line bg-rn-surface px-3 py-2 text-sm font-extrabold text-rn-ink hover:bg-[var(--rn-surface-muted)]" %>
```

- [ ] **Step 5: Update brew detail actions**

In `app/views/brews/show.html.erb`, render the same partial beside the existing `Share publicly` management link when `@brew.public_brew_share&.enabled?`.

- [ ] **Step 6: Run tests to verify GREEN**

Run:

```bash
bin/rails test test/controllers/brews_controller_test.rb test/assets/native_share_controller_test.rb
```

Expected: both test files pass.

### Task 4: Documentation and Full Verification

**Files:**
- Modify: `docs/public-brew-sharing.md`

- [ ] **Step 1: Document the private-app shortcut**

Add an Included Now bullet:

```markdown
- Native mobile share shortcuts for enabled public shares on the private compact Brew Log and brew detail action area.
```

- [ ] **Step 2: Run focused verification**

Run:

```bash
bin/rails test test/controllers/brews_controller_test.rb test/assets/native_share_controller_test.rb
```

Expected: all tests pass.

- [ ] **Step 3: Run full Rails tests**

Run:

```bash
env PARALLEL_WORKERS=1 bin/rails test
```

Expected: all tests pass.

- [ ] **Step 4: Start local development server**

Run:

```bash
bin/dev
```

Expected: the app is available on the configured development host, preferably port `3001`.

