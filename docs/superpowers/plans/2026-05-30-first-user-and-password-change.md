# First User And Password Change Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add first-user bootstrap for empty private installs and signed-in password changes for existing users.

**Architecture:** Use two focused controllers: `FirstUserSetupsController` for empty-instance account creation and `PasswordChangesController` for authenticated credential changes. Keep workspace creation in the existing `WorkspaceOnboardingsController`, and keep invite signup private after bootstrap.

**Tech Stack:** Rails 8.1, Rails-native authentication concern, `has_secure_password`, Minitest integration tests, Hotwire-ready ERB views, Tailwind CSS utility classes.

---

## File Structure

- Create `app/controllers/first_user_setups_controller.rb`: empty-instance guard, first account creation, automatic sign-in.
- Create `app/views/first_user_setups/new.html.erb`: first-user email/password form.
- Create `test/controllers/first_user_setups_controller_test.rb`: controller and empty-instance link coverage.
- Create `app/controllers/password_changes_controller.rb`: signed-in password change with current-password verification and session rotation.
- Create `app/views/password_changes/edit.html.erb`: current password plus new password form.
- Create `test/controllers/password_changes_controller_test.rb`: password change behavior and session invalidation.
- Modify `config/routes.rb`: add singleton setup and password-change routes.
- Modify `app/controllers/application_controller.rb`: expose `first_user_setup_available?` helper for public pages.
- Modify `app/views/home/index.html.erb`: show setup link only for an empty instance.
- Modify `app/views/sessions/new.html.erb`: show setup link only for an empty instance.
- Modify `app/views/profiles/edit.html.erb`: add password-change link.
- Modify `config/locales/en.yml`: add user-facing copy for the new flows.
- Modify `docs/setup.md`, `docs/instance-admin.md`, and `docs/status.md`: document first-run account creation and password-change support.

## Task 1: First-User Setup Tests

**Files:**
- Create: `test/controllers/first_user_setups_controller_test.rb`
- Modify during Task 2: `config/routes.rb`, `app/controllers/first_user_setups_controller.rb`, `app/views/first_user_setups/new.html.erb`, `app/controllers/application_controller.rb`, `app/views/home/index.html.erb`, `app/views/sessions/new.html.erb`, `config/locales/en.yml`

- [ ] **Step 1: Write the failing tests**

```ruby
require "test_helper"

class FirstUserSetupsControllerTest < ActionDispatch::IntegrationTest
  setup { clear_instance_records }

  test "empty instance shows setup links on public home and sign in" do
    get root_path
    assert_response :success
    assert_select "a[href=?]", new_first_user_setup_path, text: I18n.t("home.index.setup_first_user")

    get new_session_path
    assert_response :success
    assert_select "a[href=?]", new_first_user_setup_path, text: I18n.t("sessions.new.setup_first_user")
  end

  test "new renders setup form only when no users exist" do
    get new_first_user_setup_path

    assert_response :success
    assert_select "h1", I18n.t("first_user_setups.new.title")
    assert_select "form[action=?]", first_user_setup_path
    assert_select "input[name=?]", "user[email_address]"
    assert_select "input[name=?]", "user[password]"
    assert_select "input[name=?]", "user[password_confirmation]"
  end

  test "create makes the first user an instance admin and signs them in" do
    assert_difference -> { User.count }, 1 do
      post first_user_setup_path, params: {
        user: {
          email_address: "owner@example.com",
          password: "password",
          password_confirmation: "password"
        }
      }
    end

    user = User.find_by!(email_address: "owner@example.com")
    assert_redirected_to root_path
    assert_predicate user, :instance_admin?
    assert user.sessions.exists?
    assert cookies[:session_id].present?

    follow_redirect!
    assert_select "h1", I18n.t("workspace_onboardings.new.title")
  end

  test "create rejects invalid user input without creating an account" do
    assert_no_difference -> { User.count } do
      post first_user_setup_path, params: {
        user: {
          email_address: "",
          password: "password",
          password_confirmation: "mismatch"
        }
      }
    end

    assert_response :unprocessable_entity
    assert_select "h1", I18n.t("first_user_setups.new.title")
  end

  test "setup redirects once any user exists" do
    User.create!(email_address: "existing@example.com", password: "password")

    get new_first_user_setup_path
    assert_redirected_to new_session_path

    assert_no_difference -> { User.count } do
      post first_user_setup_path, params: {
        user: {
          email_address: "second@example.com",
          password: "password",
          password_confirmation: "password"
        }
      }
    end
    assert_redirected_to new_session_path
  end

  private
    def clear_instance_records
      ActiveRecord::Base.connection.disable_referential_integrity do
        [
          ActiveStorage::Attachment,
          ActiveStorage::VariantRecord,
          ActiveStorage::Blob,
          BrewPreparationTool,
          InventoryAdjustment,
          Brew,
          EquipmentEventItem,
          EquipmentEvent,
          Bean,
          Equipment,
          PreparationTool,
          DataImport,
          WorkspaceInvite,
          Membership,
          Session,
          Workspace,
          User
        ].each(&:delete_all)
      end
    end
end
```

- [ ] **Step 2: Run the first-user tests to verify they fail**

Run: `env PARALLEL_WORKERS=1 bin/rails test test/controllers/first_user_setups_controller_test.rb`

Expected: FAIL because `new_first_user_setup_path` and `first_user_setup_path` are undefined.

## Task 2: First-User Setup Implementation

**Files:**
- Modify: `config/routes.rb`
- Modify: `app/controllers/application_controller.rb`
- Create: `app/controllers/first_user_setups_controller.rb`
- Create: `app/views/first_user_setups/new.html.erb`
- Modify: `app/views/home/index.html.erb`
- Modify: `app/views/sessions/new.html.erb`
- Modify: `config/locales/en.yml`

- [ ] **Step 1: Add routes**

```ruby
resource :first_user_setup, path: "setup/first_user", only: %i[new create]
```

- [ ] **Step 2: Add public-page helper**

```ruby
helper_method :current_workspace, :current_membership, :current_workspace_policy, :first_user_setup_available?

def first_user_setup_available?
  !User.exists?
end
```

- [ ] **Step 3: Add controller**

```ruby
class FirstUserSetupsController < ApplicationController
  allow_unauthenticated_access
  before_action :redirect_if_already_configured

  def new
    @user = User.new
  end

  def create
    @user = User.new(first_user_params.merge(instance_admin: true))

    if @user.save
      start_new_session_for(@user)
      redirect_to root_path, notice: t(".created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  private
    def redirect_if_already_configured
      return if first_user_setup_available?

      redirect_to new_session_path, alert: t("first_user_setups.already_configured")
    end

    def first_user_params
      params.expect(user: [ :email_address, :password, :password_confirmation ])
    end
end
```

- [ ] **Step 4: Add setup view**

```erb
<main class="min-h-screen bg-stone-50">
  <section class="mx-auto flex min-h-screen max-w-3xl flex-col justify-center px-6 py-16">
    <div>
      <%= render "shared/brand_wordmark",
        container_class: "mb-6 block h-14 w-64",
        image_class: "h-full w-full object-contain object-left" %>
      <p class="text-sm font-semibold uppercase text-stone-600"><%= t(".eyebrow") %></p>
      <h1 class="mt-4 text-4xl font-bold text-stone-950"><%= t(".title") %></h1>
      <p class="mt-5 text-lg leading-8 text-stone-700"><%= t(".intro") %></p>

      <%= form_with model: @user, url: first_user_setup_path, class: "mt-8 max-w-xl space-y-5" do |form| %>
        <% if @user.errors.any? %>
          <div class="rounded-md border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
            <%= @user.errors.full_messages.to_sentence %>
          </div>
        <% end %>

        <div>
          <%= form.label :email_address, t(".email_address"), class: "block text-sm font-medium text-stone-800" %>
          <%= form.email_field :email_address, required: true, autofocus: true, autocomplete: "username", class: "mt-2 block w-full rounded-md border border-stone-300 bg-white px-3 py-3 text-base text-stone-950 shadow-sm focus:border-stone-900 focus:outline-none" %>
        </div>

        <div>
          <%= form.label :password, t(".password"), class: "block text-sm font-medium text-stone-800" %>
          <%= form.password_field :password, required: true, autocomplete: "new-password", maxlength: 72, class: "mt-2 block w-full rounded-md border border-stone-300 bg-white px-3 py-3 text-base text-stone-950 shadow-sm focus:border-stone-900 focus:outline-none" %>
        </div>

        <div>
          <%= form.label :password_confirmation, t(".password_confirmation"), class: "block text-sm font-medium text-stone-800" %>
          <%= form.password_field :password_confirmation, required: true, autocomplete: "new-password", maxlength: 72, class: "mt-2 block w-full rounded-md border border-stone-300 bg-white px-3 py-3 text-base text-stone-950 shadow-sm focus:border-stone-900 focus:outline-none" %>
        </div>

        <%= form.submit t(".submit"), class: "rounded-md bg-stone-950 px-5 py-3 text-sm font-semibold text-white shadow-sm hover:bg-stone-800" %>
      <% end %>
    </div>
  </section>
</main>
```

- [ ] **Step 5: Add public links**

In `app/views/home/index.html.erb`, add this setup link beside sign-in inside the existing button row:

```erb
<% if first_user_setup_available? %>
  <%= link_to t(".setup_first_user"), new_first_user_setup_path, class: "rounded-md border border-stone-300 px-5 py-3 text-sm font-semibold text-stone-900 hover:bg-stone-100" %>
<% end %>
```

In `app/views/sessions/new.html.erb`, add this setup link near the forgot-password link:

```erb
<% if first_user_setup_available? %>
  <div class="mt-3 text-sm text-gray-500">
    <%= link_to t(".setup_first_user"), new_first_user_setup_path, class: "text-gray-700 underline hover:no-underline" %>
  </div>
<% end %>
```

- [ ] **Step 6: Add translations**

```yaml
  home:
    index:
      setup_first_user: "Set up first account"
  first_user_setups:
    already_configured: "First-user setup is already complete."
    create:
      created: "First account created."
    new:
      email_address: "Email"
      eyebrow: "First run"
      intro: "Create the first account for this private Roastnode instance. Household setup comes next."
      password: "Password"
      password_confirmation: "Confirm password"
      submit: "Create first account"
      title: "Create the first account"
  sessions:
    new:
      setup_first_user: "Set up first account"
```

- [ ] **Step 7: Run the first-user tests to verify they pass**

Run: `env PARALLEL_WORKERS=1 bin/rails test test/controllers/first_user_setups_controller_test.rb`

Expected: PASS.

- [ ] **Step 8: Commit first-user setup**

Run:

```bash
git add config/routes.rb app/controllers/application_controller.rb app/controllers/first_user_setups_controller.rb app/views/first_user_setups/new.html.erb app/views/home/index.html.erb app/views/sessions/new.html.erb config/locales/en.yml test/controllers/first_user_setups_controller_test.rb
git commit -m "feat: add first user setup"
```

## Task 3: Password Change Tests

**Files:**
- Create: `test/controllers/password_changes_controller_test.rb`
- Modify: `test/controllers/profiles_controller_test.rb`
- Modify during Task 4: `config/routes.rb`, `app/controllers/password_changes_controller.rb`, `app/views/password_changes/edit.html.erb`, `app/views/profiles/edit.html.erb`, `config/locales/en.yml`

- [ ] **Step 1: Write failing password-change tests**

```ruby
require "test_helper"

class PasswordChangesControllerTest < ActionDispatch::IntegrationTest
  test "signed-in user can open password change form" do
    sign_in_as(users(:one))

    get edit_password_change_path

    assert_response :success
    assert_select "h1", I18n.t("password_changes.edit.title")
    assert_select "form[action=?]", password_change_path
    assert_select "input[name=?]", "user[current_password]"
    assert_select "input[name=?]", "user[password]"
    assert_select "input[name=?]", "user[password_confirmation]"
  end

  test "password change requires current password" do
    user = users(:one)
    sign_in_as(user)

    assert_no_changes -> { user.reload.password_digest } do
      patch password_change_path, params: {
        user: {
          current_password: "wrong",
          password: "new-password",
          password_confirmation: "new-password"
        }
      }
    end

    assert_response :unprocessable_entity
    assert_select "div", /#{I18n.t("password_changes.update.current_password_invalid")}/
  end

  test "password change rejects mismatched confirmation" do
    user = users(:one)
    sign_in_as(user)

    assert_no_changes -> { user.reload.password_digest } do
      patch password_change_path, params: {
        user: {
          current_password: "password",
          password: "new-password",
          password_confirmation: "different"
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "password change updates digest rotates sessions and keeps current browser signed in" do
    user = users(:one)
    other_session = user.sessions.create!
    sign_in_as(user)
    old_current_session_id = Current.session.id

    assert_changes -> { user.reload.password_digest } do
      patch password_change_path, params: {
        user: {
          current_password: "password",
          password: "new-password",
          password_confirmation: "new-password"
        }
      }
    end

    assert_redirected_to edit_profile_path
    assert_not Session.exists?(other_session.id)
    assert_not Session.exists?(old_current_session_id)
    assert_equal 1, user.sessions.count
    assert cookies[:session_id].present?

    get dashboard_path
    assert_response :success

    delete session_path
    post session_path, params: { email_address: user.email_address, password: "new-password" }
    assert_redirected_to root_path
  end
end
```

- [ ] **Step 2: Add failing profile-link expectation**

Add to `test/controllers/profiles_controller_test.rb`:

```ruby
assert_select "a[href=?]", edit_password_change_path, text: I18n.t("profiles.edit.change_password")
```

- [ ] **Step 3: Run password tests to verify they fail**

Run: `env PARALLEL_WORKERS=1 bin/rails test test/controllers/password_changes_controller_test.rb test/controllers/profiles_controller_test.rb`

Expected: FAIL because password-change routes are undefined.

## Task 4: Password Change Implementation

**Files:**
- Modify: `config/routes.rb`
- Create: `app/controllers/password_changes_controller.rb`
- Create: `app/views/password_changes/edit.html.erb`
- Modify: `app/views/profiles/edit.html.erb`
- Modify: `config/locales/en.yml`

- [ ] **Step 1: Add route**

```ruby
resource :password_change, only: %i[edit update]
```

- [ ] **Step 2: Add controller**

```ruby
class PasswordChangesController < ApplicationController
  before_action :set_user

  def edit
  end

  def update
    unless @user.authenticate(password_change_params[:current_password].to_s)
      @user.errors.add(:current_password, t(".current_password_invalid"))
      return render :edit, status: :unprocessable_entity
    end

    if password_change_params[:password].blank?
      @user.errors.add(:password, :blank)
      return render :edit, status: :unprocessable_entity
    end

    if @user.update(password_change_params.except(:current_password))
      @user.sessions.destroy_all
      start_new_session_for(@user)
      redirect_to edit_profile_path, notice: t(".updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private
    def set_user
      @user = Current.user
    end

    def password_change_params
      params.expect(user: [ :current_password, :password, :password_confirmation ])
    end
end
```

- [ ] **Step 3: Add password-change view**

```erb
<main class="min-h-screen bg-stone-50">
  <section class="mx-auto max-w-xl px-6 py-10">
    <%= render "shared/back_link", label: t(".back"), path: edit_profile_path %>

    <div class="mt-6 rounded-lg border border-stone-200 bg-white p-6 shadow-sm">
      <h1 class="text-3xl font-bold text-stone-950"><%= t(".title") %></h1>

      <%= form_with url: password_change_path, method: :patch, scope: :user, class: "mt-6 space-y-5" do |form| %>
        <% if @user.errors.any? %>
          <div class="rounded-md border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
            <%= @user.errors.full_messages.to_sentence %>
          </div>
        <% end %>

        <div>
          <%= form.label :current_password, t(".current_password"), class: "block text-sm font-medium text-stone-700" %>
          <%= form.password_field :current_password, required: true, autocomplete: "current-password", maxlength: 72, class: "mt-1 w-full rounded-md border border-stone-300 px-3 py-2 text-stone-950 shadow-sm focus:border-stone-900 focus:outline-none" %>
        </div>

        <div>
          <%= form.label :password, t(".password"), class: "block text-sm font-medium text-stone-700" %>
          <%= form.password_field :password, required: true, autocomplete: "new-password", maxlength: 72, class: "mt-1 w-full rounded-md border border-stone-300 px-3 py-2 text-stone-950 shadow-sm focus:border-stone-900 focus:outline-none" %>
        </div>

        <div>
          <%= form.label :password_confirmation, t(".password_confirmation"), class: "block text-sm font-medium text-stone-700" %>
          <%= form.password_field :password_confirmation, required: true, autocomplete: "new-password", maxlength: 72, class: "mt-1 w-full rounded-md border border-stone-300 px-3 py-2 text-stone-950 shadow-sm focus:border-stone-900 focus:outline-none" %>
        </div>

        <%= form.submit t(".save"), class: "rounded-md bg-stone-950 px-5 py-3 text-sm font-semibold text-white shadow-sm hover:bg-stone-800" %>
      <% end %>
    </div>
  </section>
</main>
```

- [ ] **Step 4: Link from profile**

Add a link near the read-only email block in `app/views/profiles/edit.html.erb`:

```erb
<%= link_to t(".change_password"), edit_password_change_path, class: "mt-3 inline-flex rounded-md border border-stone-300 px-4 py-2 text-sm font-semibold text-stone-800 hover:bg-stone-100" %>
```

- [ ] **Step 5: Add translations**

```yaml
  password_changes:
    edit:
      back: "Back to profile"
      current_password: "Current password"
      password: "New password"
      password_confirmation: "Confirm new password"
      save: "Change password"
      title: "Change password"
    update:
      current_password_invalid: "is not correct"
      updated: "Password changed."
```

- [ ] **Step 6: Run password tests to verify they pass**

Run: `env PARALLEL_WORKERS=1 bin/rails test test/controllers/password_changes_controller_test.rb test/controllers/profiles_controller_test.rb`

Expected: PASS.

- [ ] **Step 7: Commit password change**

Run:

```bash
git add config/routes.rb app/controllers/password_changes_controller.rb app/views/password_changes/edit.html.erb app/views/profiles/edit.html.erb config/locales/en.yml test/controllers/password_changes_controller_test.rb test/controllers/profiles_controller_test.rb
git commit -m "feat: add authenticated password change"
```

## Task 5: Documentation And Full Verification

**Files:**
- Modify: `docs/setup.md`
- Modify: `docs/instance-admin.md`
- Modify: `docs/status.md`

- [ ] **Step 1: Update documentation**

In `docs/setup.md`, replace the paragraph beginning `After signing in` with:

```markdown
On a fresh instance with no users, open `http://localhost:3001` and choose first account setup. That creates the initial user account, signs it in, and marks it as the instance admin. The existing household onboarding screen then creates the first private workspace. After that, additional users can join only from valid workspace invite links.
```

In `docs/instance-admin.md`, add this paragraph under Authorization:

```markdown
The first account created through first-run setup is automatically marked `instance_admin` so a fresh private instance has an initial operator. Later account role changes remain out of scope until a dedicated user-management design exists.
```

In `docs/status.md`, update the authentication bullet to:

```markdown
- Rails-native authentication, first-user setup for empty installs, password reset and signed-in password change flows, private-by-default app shell, and an instance admin dashboard with safe read-only checks plus backup controls.
```

- [ ] **Step 2: Run targeted auth tests**

Run: `env PARALLEL_WORKERS=1 bin/rails test test/controllers/first_user_setups_controller_test.rb test/controllers/password_changes_controller_test.rb test/controllers/profiles_controller_test.rb test/controllers/sessions_controller_test.rb test/controllers/passwords_controller_test.rb test/controllers/workspace_invites_controller_test.rb test/controllers/home_controller_test.rb test/controllers/workspace_onboardings_controller_test.rb`

Expected: PASS.

- [ ] **Step 3: Run full test suite**

Run: `env PARALLEL_WORKERS=1 bin/rails test`

Expected: PASS.

- [ ] **Step 4: Commit docs and any final fixes**

Run:

```bash
git add docs/setup.md docs/instance-admin.md docs/status.md
git commit -m "docs: document first-run account setup"
```

If verification required additional code or test fixes, include those exact files in this final commit instead of leaving them unstaged.
