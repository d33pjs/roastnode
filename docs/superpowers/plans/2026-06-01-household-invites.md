# Household Invites Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add instance-admin email invites that let recipients create their own separate household on a private Roastnode instance.

**Architecture:** Add a new instance-scoped `HouseholdInvite` lifecycle parallel to, but separate from, workspace member invites. Instance admins manage these invites under `/instance_admin`; recipients use public token routes to create an account or, when already signed in with the invited email, create a brand-new household where they become owner. The inviter never becomes a member of that new household.

**Tech Stack:** Rails 8.1, Active Record, Action Mailer, Hotwire-compatible server-rendered ERB, Minitest, PostgreSQL.

---

## File Structure

- Create `db/migrate/20260601120000_create_household_invites.rb`: table for email-required instance-level invite tokens.
- Create `app/models/household_invite.rb`: lifecycle, email binding, token defaults, and transactional acceptance that creates a new household.
- Modify `app/models/user.rb`: associations for created and accepted household invites.
- Modify `app/models/workspace.rb`: association for the household invite that created a workspace, using nullification on workspace deletion.
- Create `test/fixtures/household_invites.yml`: active and expired invite fixtures.
- Create `test/models/household_invite_test.rb`: model and acceptance behavior.
- Modify `config/routes.rb`: add instance-admin management routes and public recipient routes.
- Create `app/mailers/household_invites_mailer.rb`: email delivery for household invites.
- Create `app/views/household_invites_mailer/invite.html.erb` and `app/views/household_invites_mailer/invite.text.erb`: email bodies.
- Create `test/mailers/household_invites_mailer_test.rb`: mail subject, recipient, and link tests.
- Create `app/controllers/instance_admin/household_invites_controller.rb`: create, revoke, resend, and re-invite actions.
- Modify `app/controllers/instance_admin_controller.rb`: preload household invites/form for the dashboard.
- Modify `app/views/instance_admin/index.html.erb`: instance-admin household-invite form and table.
- Create `test/controllers/instance_admin_household_invites_controller_test.rb`: authorization and lifecycle controller tests.
- Modify `test/controllers/instance_admin_controller_test.rb`: render assertions for admin-only invite management.
- Create `app/controllers/household_invites_controller.rb`: public show, signup, and signed-in accept actions.
- Create `app/views/household_invites/show.html.erb`: recipient signup/accept page.
- Create `test/controllers/household_invites_controller_test.rb`: recipient flow tests.
- Modify `config/locales/en.yml`: strings for controllers, views, and mailer.
- Modify `docs/instance-admin.md`, `docs/workspace-core.md`, and `docs/status.md`: shipped behavior and boundary docs.

---

### Task 1: HouseholdInvite Model And Schema

**Files:**
- Create: `db/migrate/20260601120000_create_household_invites.rb`
- Create: `app/models/household_invite.rb`
- Modify: `app/models/user.rb`
- Modify: `app/models/workspace.rb`
- Create: `test/fixtures/household_invites.yml`
- Create: `test/models/household_invite_test.rb`

- [ ] **Step 1: Write the failing model tests**

Add `test/fixtures/household_invites.yml`:

```yaml
active_household_invite:
  created_by: one
  token: household-token
  email_address: new-owner@example.com
  expires_at: <%= 3.days.from_now %>
  revoked_at:
  accepted_at:
  accepted_by:
  workspace:

expired_household_invite:
  created_by: one
  token: expired-household-token
  email_address: expired-owner@example.com
  expires_at: <%= 1.day.ago %>
  revoked_at:
  accepted_at:
  accepted_by:
  workspace:
```

Create `test/models/household_invite_test.rb`:

```ruby
require "test_helper"

class HouseholdInviteTest < ActiveSupport::TestCase
  test "requires email address" do
    invite = HouseholdInvite.new(created_by: users(:one), email_address: "")

    assert_not invite.valid?
    assert_includes invite.errors[:email_address], "can't be blank"
  end

  test "normalizes email address" do
    invite = HouseholdInvite.create!(created_by: users(:one), email_address: "New.Owner@Example.COM")

    assert_equal "new.owner@example.com", invite.email_address
  end

  test "new invite sets token and expiration" do
    invite = HouseholdInvite.create!(created_by: users(:one), email_address: "fresh-owner@example.com")

    assert invite.token.present?
    assert invite.expires_at.future?
  end

  test "active invite is acceptable only before it is closed" do
    assert household_invites(:active_household_invite).acceptable?
    assert_not household_invites(:expired_household_invite).acceptable?
  end

  test "invite is acceptable only for matching normalized email" do
    invite = household_invites(:active_household_invite)
    matching = User.create!(email_address: "NEW-OWNER@example.com", password: "password")
    other = User.create!(email_address: "other-owner@example.com", password: "password")

    assert invite.acceptable_for?(matching)
    assert_not invite.acceptable_for?(other)
  end

  test "accepting invite creates a separate household owned by recipient" do
    invite = household_invites(:active_household_invite)
    user = User.create!(email_address: invite.email_address, password: "password")
    workspace = Workspace.new(name: "Morning Flat")

    assert_difference -> { Workspace.count }, 1 do
      assert_difference -> { Membership.owner.count }, 1 do
        invite.accept!(user, workspace:)
      end
    end

    created_workspace = invite.reload.workspace
    assert_equal "Morning Flat", created_workspace.name
    assert_equal "household", created_workspace.kind
    assert_equal "EUR", created_workspace.default_currency
    assert_equal user, invite.accepted_by
    assert invite.accepted_at.present?
    assert_equal created_workspace, user.reload.active_workspace
    assert_equal "owner", user.membership_for(created_workspace).role
    assert_nil users(:one).membership_for(created_workspace)
  end

  test "accepting invite rejects mismatched email without creating household" do
    invite = household_invites(:active_household_invite)
    user = User.create!(email_address: "other-owner@example.com", password: "password")

    assert_no_difference -> { Workspace.count } do
      assert_raises ActiveRecord::RecordInvalid do
        invite.accept!(user, workspace: Workspace.new(name: "Other Flat"))
      end
    end

    assert_nil invite.reload.accepted_at
  end
end
```

- [ ] **Step 2: Run the model tests to verify they fail**

Run:

```bash
bin/rails test test/models/household_invite_test.rb
```

Expected: `NameError: uninitialized constant HouseholdInvite` or fixture table errors, because the model/table do not exist yet.

- [ ] **Step 3: Add the migration and model implementation**

Create `db/migrate/20260601120000_create_household_invites.rb`:

```ruby
class CreateHouseholdInvites < ActiveRecord::Migration[8.1]
  def change
    create_table :household_invites do |t|
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.references :accepted_by, foreign_key: { to_table: :users }
      t.references :workspace, foreign_key: true
      t.string :token, null: false
      t.string :email_address, null: false
      t.datetime :expires_at, null: false
      t.datetime :revoked_at
      t.datetime :accepted_at

      t.timestamps
    end

    add_index :household_invites, :token, unique: true
    add_index :household_invites, :email_address
  end
end
```

Run:

```bash
bin/rails db:migrate
```

Create `app/models/household_invite.rb`:

```ruby
class HouseholdInvite < ApplicationRecord
  belongs_to :created_by, class_name: "User"
  belongs_to :accepted_by, class_name: "User", optional: true
  belongs_to :workspace, optional: true

  before_validation :set_token, on: :create
  before_validation :set_expiration, on: :create

  validates :email_address, presence: true
  validates :token, presence: true, uniqueness: true
  validates :expires_at, presence: true

  normalizes :email_address, with: ->(email) { email.presence&.strip&.downcase }

  def acceptable?
    accepted_at.blank? && revoked_at.blank? && expires_at.future?
  end

  def acceptable_for?(user)
    acceptable? && normalized_email(user&.email_address) == email_address
  end

  def accept!(user, workspace:)
    unless acceptable_for?(user)
      errors.add(:base, "is not available for this email")
      raise ActiveRecord::RecordInvalid, self
    end

    transaction do
      workspace.kind = :household
      workspace.default_currency = "EUR"
      workspace.save!

      user.memberships.create!(workspace:, role: :owner)
      update!(accepted_by: user, accepted_at: Time.current, workspace:)
      user.update!(active_workspace: workspace)

      workspace
    end
  end

  def revoke!
    update!(revoked_at: Time.current)
  end

  private
    def set_token
      self.token ||= SecureRandom.urlsafe_base64(24)
    end

    def set_expiration
      self.expires_at ||= 7.days.from_now
    end

    def normalized_email(value)
      value.to_s.strip.downcase
    end
end
```

Modify `app/models/user.rb` near the workspace invite associations:

```ruby
  has_many :created_household_invites, class_name: "HouseholdInvite", foreign_key: :created_by_id, dependent: :destroy,
    inverse_of: :created_by
  has_many :accepted_household_invites, class_name: "HouseholdInvite", foreign_key: :accepted_by_id, dependent: :nullify,
    inverse_of: :accepted_by
```

Modify `app/models/workspace.rb` near `has_many :workspace_invites`:

```ruby
  has_many :household_invites, dependent: :nullify
```

- [ ] **Step 4: Run the model tests to verify they pass**

Run:

```bash
bin/rails test test/models/household_invite_test.rb
```

Expected: all tests in `household_invite_test.rb` pass.

- [ ] **Step 5: Commit the model slice**

Run:

```bash
git add db/migrate/20260601120000_create_household_invites.rb db/schema.rb app/models/household_invite.rb app/models/user.rb app/models/workspace.rb test/fixtures/household_invites.yml test/models/household_invite_test.rb
git commit -m "feat: add household invite model"
```

---

### Task 2: Routes And Household Invite Mailer

**Files:**
- Modify: `config/routes.rb`
- Create: `app/mailers/household_invites_mailer.rb`
- Create: `app/views/household_invites_mailer/invite.html.erb`
- Create: `app/views/household_invites_mailer/invite.text.erb`
- Modify: `config/locales/en.yml`
- Create: `test/mailers/household_invites_mailer_test.rb`

- [ ] **Step 1: Write the failing mailer test**

Create `test/mailers/household_invites_mailer_test.rb`:

```ruby
require "test_helper"

class HouseholdInvitesMailerTest < ActionMailer::TestCase
  test "invite email includes recipient and household invite link" do
    invite = household_invites(:active_household_invite)

    mail = HouseholdInvitesMailer.invite(invite)
    invite_url = Rails.application.routes.url_helpers.household_invite_url(invite.token, host: "example.com")

    assert_equal "Create your Roastnode household", mail.subject
    assert_equal [ invite.email_address ], mail.to
    assert_includes mail.text_part.body.to_s, invite.email_address
    assert_includes mail.text_part.body.to_s, invite_url
    assert_includes mail.html_part.body.to_s, invite_url
  end

  test "invite email uses configured from address" do
    invite = household_invites(:active_household_invite)

    with_mail_from_address("Roastnode <invites@coffee.example.test>") do
      mail = HouseholdInvitesMailer.invite(invite)

      assert_equal [ "invites@coffee.example.test" ], mail.from
    end
  end
end
```

- [ ] **Step 2: Run the mailer test to verify it fails**

Run:

```bash
bin/rails test test/mailers/household_invites_mailer_test.rb
```

Expected: failure because `HouseholdInvitesMailer` and route helpers do not exist.

- [ ] **Step 3: Add routes, mailer, views, and locale**

Modify `config/routes.rb`:

```ruby
  namespace :instance_admin, path: "instance_admin" do
    resources :backup_profiles, only: %i[create update] do
      post :run, on: :member
    end
    resources :household_invites, only: :create, param: :token do
      post :resend, on: :member
      post :reinvite, on: :member
      patch :revoke, on: :member
    end
  end
```

Also add the public recipient routes near `workspace_invites`:

```ruby
  resources :household_invites, only: :show, param: :token do
    post :accept, on: :member
    post :signup, on: :member
  end
```

Create `app/mailers/household_invites_mailer.rb`:

```ruby
class HouseholdInvitesMailer < ApplicationMailer
  def invite(household_invite)
    @household_invite = household_invite

    mail(
      subject: t(".subject"),
      to: @household_invite.email_address
    )
  end
end
```

Create `app/views/household_invites_mailer/invite.html.erb`:

```erb
<p>
  You have been invited to create a new household on Roastnode for
  <strong><%= @household_invite.email_address %></strong>.
</p>

<p>
  <%= link_to "Create your household", household_invite_url(@household_invite.token) %>
</p>

<p>This invite expires on <%= l(@household_invite.expires_at, format: :european_seconds) %>.</p>
```

Create `app/views/household_invites_mailer/invite.text.erb`:

```erb
You have been invited to create a new household on Roastnode for <%= @household_invite.email_address %>.

Create your household:
<%= household_invite_url(@household_invite.token) %>

This invite expires on <%= l(@household_invite.expires_at, format: :european_seconds) %>.
```

Add under `household_invites_mailer` in `config/locales/en.yml`:

```yaml
  household_invites_mailer:
    invite:
      subject: "Create your Roastnode household"
```

- [ ] **Step 4: Run the mailer test to verify it passes**

Run:

```bash
bin/rails test test/mailers/household_invites_mailer_test.rb
```

Expected: all mailer tests pass.

- [ ] **Step 5: Commit the route and mailer slice**

Run:

```bash
git add config/routes.rb app/mailers/household_invites_mailer.rb app/views/household_invites_mailer/invite.html.erb app/views/household_invites_mailer/invite.text.erb config/locales/en.yml test/mailers/household_invites_mailer_test.rb
git commit -m "feat: add household invite mailer"
```

---

### Task 3: Instance Admin Household Invite Management

**Files:**
- Create: `app/controllers/instance_admin/household_invites_controller.rb`
- Modify: `app/controllers/instance_admin_controller.rb`
- Modify: `app/views/instance_admin/index.html.erb`
- Modify: `config/locales/en.yml`
- Create: `test/controllers/instance_admin_household_invites_controller_test.rb`
- Modify: `test/controllers/instance_admin_controller_test.rb`

- [ ] **Step 1: Write failing controller tests for management actions**

Create `test/controllers/instance_admin_household_invites_controller_test.rb`:

```ruby
require "test_helper"

class InstanceAdminHouseholdInvitesControllerTest < ActionDispatch::IntegrationTest
  test "instance admin can create household invite and queue email" do
    admin = users(:one)
    admin.update!(instance_admin: true)
    sign_in_as(admin)

    assert_enqueued_emails 1 do
      assert_difference -> { HouseholdInvite.count }, 1 do
        post instance_admin_household_invites_path, params: {
          household_invite: { email_address: "New.Owner@Example.com" }
        }
      end
    end

    invite = HouseholdInvite.order(:created_at).last
    assert_redirected_to instance_admin_path
    assert_equal "new.owner@example.com", invite.email_address
    assert_equal admin, invite.created_by
  end

  test "instance admin cannot create household invite without email" do
    admin = users(:one)
    admin.update!(instance_admin: true)
    sign_in_as(admin)

    assert_no_enqueued_emails do
      assert_no_difference -> { HouseholdInvite.count } do
        post instance_admin_household_invites_path, params: {
          household_invite: { email_address: "" }
        }
      end
    end

    assert_redirected_to instance_admin_path
    assert_match(/Email address/, flash[:alert])
  end

  test "regular user cannot create household invite" do
    sign_in_as(users(:one))

    assert_no_difference -> { HouseholdInvite.count } do
      post instance_admin_household_invites_path, params: {
        household_invite: { email_address: "new-owner@example.com" }
      }
    end

    assert_redirected_to root_path
  end

  test "instance admin can revoke active household invite" do
    admin = users(:one)
    admin.update!(instance_admin: true)
    sign_in_as(admin)
    invite = household_invites(:active_household_invite)

    patch revoke_instance_admin_household_invite_path(invite.token)

    assert_redirected_to instance_admin_path
    assert invite.reload.revoked_at.present?
  end

  test "instance admin can resend active household invite" do
    admin = users(:one)
    admin.update!(instance_admin: true)
    sign_in_as(admin)
    invite = household_invites(:active_household_invite)

    assert_no_difference -> { HouseholdInvite.count } do
      assert_enqueued_email_with HouseholdInvitesMailer, :invite, args: [ invite ] do
        post resend_instance_admin_household_invite_path(invite.token)
      end
    end

    assert_redirected_to instance_admin_path
  end

  test "instance admin can re-invite closed household invite with fresh token" do
    admin = users(:one)
    admin.update!(instance_admin: true)
    sign_in_as(admin)
    invite = household_invites(:active_household_invite)
    invite.update!(revoked_at: 1.minute.ago)

    assert_enqueued_emails 1 do
      assert_difference -> { HouseholdInvite.count }, 1 do
        post reinvite_instance_admin_household_invite_path(invite.token)
      end
    end

    fresh_invite = HouseholdInvite.order(:created_at).last
    assert_redirected_to instance_admin_path
    assert_equal invite.email_address, fresh_invite.email_address
    assert_not_equal invite.token, fresh_invite.token
    assert fresh_invite.acceptable?
  end
end
```

- [ ] **Step 2: Run the management tests to verify they fail**

Run:

```bash
bin/rails test test/controllers/instance_admin_household_invites_controller_test.rb
```

Expected: routing/controller failures because the controller does not exist.

- [ ] **Step 3: Implement the instance-admin controller**

Create `app/controllers/instance_admin/household_invites_controller.rb`:

```ruby
module InstanceAdmin
  class HouseholdInvitesController < ApplicationController
    before_action :authorize_instance_admin!
    before_action :set_household_invite, only: %i[revoke resend reinvite]

    def create
      invite = HouseholdInvite.new(household_invite_params.merge(created_by: Current.user))

      unless invite.save
        return redirect_to instance_admin_path, alert: invite.errors.full_messages.to_sentence
      end

      unless deliver_invite_later(invite)
        return redirect_to instance_admin_path, alert: t(".delivery_failed")
      end

      redirect_to instance_admin_path, notice: t(".created_and_sent")
    end

    def revoke
      @household_invite.revoke!

      redirect_to instance_admin_path, notice: t(".revoked")
    end

    def resend
      unless @household_invite.acceptable?
        return redirect_to instance_admin_path, alert: t(".unavailable")
      end

      unless deliver_invite_later(@household_invite)
        return redirect_to instance_admin_path, alert: t(".delivery_failed")
      end

      redirect_to instance_admin_path, notice: t(".queued")
    end

    def reinvite
      if @household_invite.acceptable?
        return redirect_to instance_admin_path, alert: t(".unavailable")
      end

      fresh_invite = HouseholdInvite.create!(
        email_address: @household_invite.email_address,
        created_by: Current.user
      )

      unless deliver_invite_later(fresh_invite)
        return redirect_to instance_admin_path, alert: t(".delivery_failed")
      end

      redirect_to instance_admin_path, notice: t(".queued")
    end

    private
      def set_household_invite
        @household_invite = HouseholdInvite.find_by!(token: params[:token])
      end

      def household_invite_params
        params.expect(household_invite: [ :email_address ])
      end

      def deliver_invite_later(household_invite)
        HouseholdInvitesMailer.invite(household_invite).deliver_later
        true
      rescue StandardError => error
        Rails.logger.warn("Household invite mail enqueue failed: #{error.class}: #{error.message}")
        false
      end
  end
end
```

Add locale entries under `instance_admin.household_invites`:

```yaml
    household_invites:
      create:
        created_and_sent: "Household invite created and email queued."
        delivery_failed: "Household invite created, but the email could not be queued."
      reinvite:
        delivery_failed: "Fresh household invite created, but the email could not be queued."
        queued: "Fresh household invite email queued."
        unavailable: "This household invite cannot be re-invited."
      resend:
        delivery_failed: "Household invite email could not be queued."
        queued: "Household invite email queued."
        unavailable: "This household invite cannot be resent."
      revoke:
        revoked: "Household invite revoked."
```

- [ ] **Step 4: Run the management controller tests to verify they pass**

Run:

```bash
bin/rails test test/controllers/instance_admin_household_invites_controller_test.rb
```

Expected: all management controller tests pass.

- [ ] **Step 5: Write failing instance-admin view tests**

Add to `test/controllers/instance_admin_controller_test.rb`:

```ruby
  test "shows household invite management to instance admins" do
    admin = users(:one)
    admin.update!(instance_admin: true)
    sign_in_as(admin)
    invite = household_invites(:active_household_invite)

    get "/instance_admin"

    assert_response :success
    assert_select "[data-testid=instance-admin-household-invites]" do
      assert_select "form[action=?]", instance_admin_household_invites_path
      assert_select "input[name=?][type=email]", "household_invite[email_address]"
      assert_select "input[value=?]", household_invite_url(invite.token)
      assert_select "form[action=?]", resend_instance_admin_household_invite_path(invite.token)
      assert_select "form[action=?]", revoke_instance_admin_household_invite_path(invite.token)
    end
  end
```

- [ ] **Step 6: Run the instance-admin view test to verify it fails**

Run:

```bash
bin/rails test test/controllers/instance_admin_controller_test.rb
```

Expected: failure because the household invite section is not rendered yet.

- [ ] **Step 7: Load invites in the dashboard and render the section**

Modify `app/controllers/instance_admin_controller.rb#index`:

```ruby
    @household_invite = HouseholdInvite.new
    @household_invites = HouseholdInvite.includes(:created_by, :accepted_by, :workspace).order(created_at: :desc).limit(25)
```

Add locale entries under `instance_admin.index`:

```yaml
      household_invites: "Household invites"
      household_invites_intro: "Invite someone to create their own separate household on this private instance."
      household_invite_email: "Email"
      household_invite_email_placeholder: "new-owner@example.com"
      create_household_invite: "Send household invite"
      household_invite_url: "Invite URL"
      household_invite_status: "Status"
      household_invite_actions: "Actions"
      household_invite_active: "Active"
      household_invite_closed: "Closed"
      household_invite_any_workspace: "Creates separate household"
      resend_household_invite: "Resend"
      reinvite_household: "Re-invite"
      revoke_household_invite: "Revoke"
```

Add this section to `app/views/instance_admin/index.html.erb` after the top status cards and before health:

```erb
    <section data-testid="instance-admin-household-invites" class="border-b border-stone-200 py-8">
      <h2 class="text-xl font-bold text-stone-950"><%= t(".household_invites") %></h2>
      <p class="mt-2 max-w-3xl text-sm text-stone-600"><%= t(".household_invites_intro") %></p>

      <%= form_with model: @household_invite, url: instance_admin_household_invites_path, class: "mt-4 grid gap-4 md:grid-cols-[1fr_auto]" do |form| %>
        <div>
          <%= form.label :email_address, t(".household_invite_email"), class: "block text-sm font-medium text-stone-700" %>
          <%= form.email_field :email_address, required: true, placeholder: t(".household_invite_email_placeholder"), class: "mt-1 w-full rounded-md border border-stone-300 px-3 py-2 text-stone-950 shadow-sm focus:border-stone-900 focus:outline-none" %>
        </div>
        <div class="flex items-end">
          <%= form.submit t(".create_household_invite"), class: "w-full rounded-md bg-stone-950 px-5 py-3 text-sm font-semibold text-white shadow-sm hover:bg-stone-800 md:w-auto" %>
        </div>
      <% end %>

      <% if @household_invites.any? %>
        <div class="mt-6 overflow-x-auto rounded-lg border border-stone-200 bg-white shadow-sm">
          <table class="min-w-full divide-y divide-stone-200">
            <thead class="bg-stone-100">
              <tr>
                <th class="px-4 py-3 text-left text-sm font-semibold text-stone-700"><%= t(".household_invite_email") %></th>
                <th class="px-4 py-3 text-left text-sm font-semibold text-stone-700"><%= t(".household_invite_status") %></th>
                <th class="px-4 py-3 text-left text-sm font-semibold text-stone-700"><%= t(".household_invite_url") %></th>
                <th class="px-4 py-3 text-left text-sm font-semibold text-stone-700"><%= t(".household_invite_actions") %></th>
              </tr>
            </thead>
            <tbody class="divide-y divide-stone-100">
              <% @household_invites.each do |invite| %>
                <tr data-testid="instance-admin-household-invite-<%= invite.id %>">
                  <td class="px-4 py-3">
                    <p class="text-sm font-semibold text-stone-950"><%= invite.email_address %></p>
                    <p class="text-xs text-stone-600"><%= invite.workspace&.name || t(".household_invite_any_workspace") %></p>
                  </td>
                  <td class="px-4 py-3 text-sm text-stone-700"><%= invite.acceptable? ? t(".household_invite_active") : t(".household_invite_closed") %></td>
                  <td class="px-4 py-3">
                    <%= text_field_tag nil, household_invite_url(invite.token), readonly: true, class: "w-full rounded-md border border-stone-300 bg-stone-50 px-3 py-2 text-sm text-stone-700" %>
                  </td>
                  <td class="px-4 py-3">
                    <div class="flex flex-wrap gap-2">
                      <% if invite.acceptable? %>
                        <%= button_to t(".resend_household_invite"), resend_instance_admin_household_invite_path(invite.token), method: :post, class: "rounded-md border border-stone-300 px-3 py-2 text-sm font-semibold text-stone-900 hover:bg-stone-100" %>
                        <%= button_to t(".revoke_household_invite"), revoke_instance_admin_household_invite_path(invite.token), method: :patch, class: "rounded-md border border-stone-300 px-3 py-2 text-sm font-semibold text-stone-900 hover:bg-stone-100" %>
                      <% else %>
                        <%= button_to t(".reinvite_household"), reinvite_instance_admin_household_invite_path(invite.token), method: :post, class: "rounded-md border border-stone-300 px-3 py-2 text-sm font-semibold text-stone-900 hover:bg-stone-100" %>
                      <% end %>
                    </div>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      <% end %>
    </section>
```

- [ ] **Step 8: Run the admin tests to verify they pass**

Run:

```bash
bin/rails test test/controllers/instance_admin_household_invites_controller_test.rb test/controllers/instance_admin_controller_test.rb
```

Expected: all tests in both files pass.

- [ ] **Step 9: Commit the instance-admin management slice**

Run:

```bash
git add app/controllers/instance_admin/household_invites_controller.rb app/controllers/instance_admin_controller.rb app/views/instance_admin/index.html.erb config/locales/en.yml test/controllers/instance_admin_household_invites_controller_test.rb test/controllers/instance_admin_controller_test.rb
git commit -m "feat: manage household invites from instance admin"
```

---

### Task 4: Recipient Signup And Existing-User Acceptance

**Files:**
- Create: `app/controllers/household_invites_controller.rb`
- Create: `app/views/household_invites/show.html.erb`
- Modify: `config/locales/en.yml`
- Create: `test/controllers/household_invites_controller_test.rb`

- [ ] **Step 1: Write failing recipient flow tests**

Create `test/controllers/household_invites_controller_test.rb`:

```ruby
require "test_helper"

class HouseholdInvitesControllerTest < ActionDispatch::IntegrationTest
  test "invalid invite token displays unavailable state" do
    get household_invite_path("missing-token")

    assert_response :not_found
    assert_select "h1", I18n.t("household_invites.show.unavailable_title")
  end

  test "unauthenticated user can view household invite signup form" do
    invite = household_invites(:active_household_invite)

    get household_invite_path(invite.token)

    assert_response :success
    assert_select "h1", I18n.t("household_invites.show.title")
    assert_select "form[action=?]", signup_household_invite_path(invite.token)
    assert_select "input[name=?][readonly=readonly]", "user[email_address]"
    assert_select "input[name=?]", "workspace[name]"
  end

  test "invite signup creates account and separate owned household" do
    invite = household_invites(:active_household_invite)

    assert_difference -> { User.count }, 1 do
      assert_difference -> { Workspace.count }, 1 do
        assert_difference -> { Membership.owner.count }, 1 do
          post signup_household_invite_path(invite.token), params: {
            user: {
              email_address: invite.email_address,
              display_name: "New Owner",
              password: "password",
              password_confirmation: "password"
            },
            workspace: { name: "New Household" }
          }
        end
      end
    end

    user = User.find_by!(email_address: invite.email_address)
    workspace = invite.reload.workspace
    assert_redirected_to root_path
    assert_equal "New Owner", user.display_name
    assert_equal "New Household", workspace.name
    assert_equal workspace, user.active_workspace
    assert_equal "owner", user.membership_for(workspace).role
    assert_nil invite.created_by.membership_for(workspace)
    assert_equal user, invite.accepted_by
    assert invite.accepted_at.present?
    assert user.sessions.exists?
  end

  test "invite signup rejects mismatched email without creating household" do
    invite = household_invites(:active_household_invite)

    assert_no_difference -> { User.count } do
      assert_no_difference -> { Workspace.count } do
        post signup_household_invite_path(invite.token), params: {
          user: {
            email_address: "other-owner@example.com",
            password: "password",
            password_confirmation: "password"
          },
          workspace: { name: "Other Household" }
        }
      end
    end

    assert_response :unprocessable_entity
    assert_nil invite.reload.accepted_at
  end

  test "invite signup rejects existing account email without accepting invite" do
    invite = household_invites(:active_household_invite)
    invite.update!(email_address: users(:one).email_address)

    assert_no_difference -> { User.count } do
      assert_no_difference -> { Workspace.count } do
        post signup_household_invite_path(invite.token), params: {
          user: {
            email_address: users(:one).email_address,
            password: "password",
            password_confirmation: "password"
          },
          workspace: { name: "Duplicate Household" }
        }
      end
    end

    assert_response :unprocessable_entity
    assert_nil invite.reload.accepted_at
  end

  test "signed-in matching user can accept invite and create separate household" do
    invite = household_invites(:active_household_invite)
    user = User.create!(email_address: invite.email_address, password: "password")
    sign_in_as(user)

    assert_difference -> { Workspace.count }, 1 do
      assert_difference -> { Membership.owner.count }, 1 do
        post accept_household_invite_path(invite.token), params: {
          workspace: { name: "Existing Account Household" }
        }
      end
    end

    workspace = invite.reload.workspace
    assert_redirected_to root_path
    assert_equal "Existing Account Household", workspace.name
    assert_equal workspace, user.reload.active_workspace
    assert_equal "owner", user.membership_for(workspace).role
    assert_nil invite.created_by.membership_for(workspace)
  end

  test "signed-in mismatched user cannot accept invite" do
    invite = household_invites(:active_household_invite)
    user = User.create!(email_address: "other-owner@example.com", password: "password")
    sign_in_as(user)

    assert_no_difference -> { Workspace.count } do
      post accept_household_invite_path(invite.token), params: {
        workspace: { name: "Wrong Household" }
      }
    end

    assert_redirected_to household_invite_path(invite.token)
    assert_nil invite.reload.accepted_at
  end
end
```

- [ ] **Step 2: Run recipient flow tests to verify they fail**

Run:

```bash
bin/rails test test/controllers/household_invites_controller_test.rb
```

Expected: controller/view failures because recipient handling does not exist.

- [ ] **Step 3: Implement the public controller**

Create `app/controllers/household_invites_controller.rb`:

```ruby
class HouseholdInvitesController < ApplicationController
  allow_unauthenticated_access only: %i[show signup]

  def show
    @household_invite = HouseholdInvite.find_by(token: params[:token])

    unless @household_invite&.acceptable?
      @household_invite = nil
      response.status = :not_found
    else
      prepare_invite_signup
    end
  end

  def accept
    @household_invite = HouseholdInvite.find_by(token: params[:token])

    unless @household_invite&.acceptable_for?(Current.user)
      return redirect_to household_invite_path(params[:token]), alert: t(".unavailable")
    end

    @workspace = Workspace.new(workspace_params)
    @household_invite.accept!(Current.user, workspace: @workspace)

    redirect_to root_path, notice: t(".accepted", workspace: @workspace.name)
  rescue ActiveRecord::RecordInvalid
    prepare_invite_signup
    render :show, status: :unprocessable_entity
  end

  def signup
    @household_invite = HouseholdInvite.find_by(token: params[:token])

    unless @household_invite&.acceptable?
      return redirect_to household_invite_path(params[:token]), alert: t("household_invites.accept.unavailable")
    end

    @user = User.new(invite_signup_params)
    @workspace = Workspace.new(workspace_params)

    unless @household_invite.acceptable_for?(@user)
      @user.errors.add(:email_address, t(".email_mismatch"))
      return render :show, status: :unprocessable_entity
    end

    ActiveRecord::Base.transaction do
      @user.save!
      @household_invite.accept!(@user, workspace: @workspace)
    end

    start_new_session_for(@user)
    redirect_to root_path, notice: t(".created", workspace: @workspace.name)
  rescue ActiveRecord::RecordInvalid
    render :show, status: :unprocessable_entity
  end

  private
    def invite_signup_params
      params.expect(user: [ :email_address, :display_name, :password, :password_confirmation ])
    end

    def workspace_params
      params.expect(workspace: [ :name ])
    end

    def prepare_invite_signup
      @user ||= User.new(email_address: @household_invite.email_address)
      @workspace ||= Workspace.new(kind: :household, default_currency: "EUR")
      session[:return_to_after_authenticating] = household_invite_url(@household_invite.token) unless authenticated?
    end
end
```

Add locale entries:

```yaml
  household_invites:
    accept:
      accepted: "Created %{workspace}."
      unavailable: "This household invite is not available."
    signup:
      created: "Account created. Created %{workspace}."
      email_mismatch: "does not match this invite"
    show:
      accept: "Create household"
      body: "This invite creates a new household for %{email}."
      create_account: "Create account and household"
      dashboard: "Go to dashboard"
      email_bound: "This invite is for %{email}."
      email_label: "Email"
      eyebrow: "Household invite"
      household_name_label: "Household name"
      household_name_placeholder: "Morning Flat"
      password_confirmation_label: "Confirm password"
      password_label: "Password"
      sign_in: "Already have an account? Sign in"
      signup_error: "Could not create your account and household."
      title: "Create your household"
      unavailable_body: "Ask an instance admin for a fresh household invite link."
      unavailable_eyebrow: "Invite unavailable"
      unavailable_title: "This household invite is not available"
      username_label: "Username (optional)"
```

- [ ] **Step 4: Add the recipient view**

Create `app/views/household_invites/show.html.erb`:

```erb
<main class="min-h-screen bg-stone-50">
  <section class="mx-auto flex min-h-screen max-w-3xl items-center px-6 py-10">
    <div class="w-full rounded-lg border border-stone-200 bg-white p-8 shadow-sm">
      <% if @household_invite %>
        <p class="text-sm font-semibold uppercase text-stone-600"><%= t(".eyebrow") %></p>
        <h1 class="mt-2 text-3xl font-bold text-stone-950"><%= t(".title") %></h1>
        <p class="mt-3 text-stone-700"><%= t(".body", email: @household_invite.email_address) %></p>
        <p class="mt-2 text-sm text-stone-600"><%= t(".email_bound", email: @household_invite.email_address) %></p>

        <% if alert = flash[:alert] %>
          <p class="mt-5 rounded-md bg-red-50 px-3 py-2 text-sm font-medium text-red-700" id="alert"><%= alert %></p>
        <% end %>

        <% if authenticated? %>
          <% if @workspace&.errors&.any? || @household_invite.errors.any? %>
            <div class="mt-5 rounded-md bg-red-50 px-3 py-2 text-sm text-red-700">
              <p class="font-semibold"><%= t(".signup_error") %></p>
              <ul class="mt-2 list-disc pl-5">
                <% Array(@workspace&.errors&.full_messages).each do |message| %>
                  <li><%= message %></li>
                <% end %>
                <% @household_invite.errors.full_messages.each do |message| %>
                  <li><%= message %></li>
                <% end %>
              </ul>
            </div>
          <% end %>

          <%= form_with model: @workspace, url: accept_household_invite_path(@household_invite.token), class: "mt-6 space-y-4" do |form| %>
            <div>
              <%= form.label :name, t(".household_name_label"), class: "block text-sm font-medium text-stone-700" %>
              <%= form.text_field :name, required: true, placeholder: t(".household_name_placeholder"), class: "mt-1 block w-full rounded-md border border-stone-300 px-3 py-2 text-stone-950 shadow-sm focus:border-stone-900 focus:outline-none" %>
            </div>

            <%= form.submit t(".accept"), class: "rounded-md bg-stone-950 px-5 py-3 text-sm font-semibold text-white shadow-sm hover:bg-stone-800" %>
          <% end %>
        <% else %>
          <%= form_with model: @user, url: signup_household_invite_path(@household_invite.token), class: "mt-6 space-y-4" do |form| %>
            <% if @user.errors.any? || @workspace&.errors&.any? %>
              <div class="rounded-md bg-red-50 px-3 py-2 text-sm text-red-700">
                <p class="font-semibold"><%= t(".signup_error") %></p>
                <ul class="mt-2 list-disc pl-5">
                  <% @user.errors.full_messages.each do |message| %>
                    <li><%= message %></li>
                  <% end %>
                  <% Array(@workspace&.errors&.full_messages).each do |message| %>
                    <li><%= message %></li>
                  <% end %>
                </ul>
              </div>
            <% end %>

            <div>
              <%= form.label :email_address, t(".email_label"), class: "block text-sm font-medium text-stone-700" %>
              <%= form.email_field :email_address, required: true, autocomplete: "username", readonly: true, class: "mt-1 block w-full rounded-md border border-stone-300 px-3 py-2 text-stone-950 shadow-sm focus:border-stone-900 focus:outline-none read-only:bg-stone-100" %>
            </div>

            <div>
              <%= form.label :display_name, t(".username_label"), class: "block text-sm font-medium text-stone-700" %>
              <%= form.text_field :display_name, autocomplete: "nickname", class: "mt-1 block w-full rounded-md border border-stone-300 px-3 py-2 text-stone-950 shadow-sm focus:border-stone-900 focus:outline-none" %>
            </div>

            <%= fields_for :workspace, @workspace do |workspace_form| %>
              <div>
                <%= workspace_form.label :name, t(".household_name_label"), class: "block text-sm font-medium text-stone-700" %>
                <%= workspace_form.text_field :name, required: true, placeholder: t(".household_name_placeholder"), class: "mt-1 block w-full rounded-md border border-stone-300 px-3 py-2 text-stone-950 shadow-sm focus:border-stone-900 focus:outline-none" %>
              </div>
            <% end %>

            <div>
              <%= form.label :password, t(".password_label"), class: "block text-sm font-medium text-stone-700" %>
              <%= form.password_field :password, required: true, autocomplete: "new-password", maxlength: 72, class: "mt-1 block w-full rounded-md border border-stone-300 px-3 py-2 text-stone-950 shadow-sm focus:border-stone-900 focus:outline-none" %>
            </div>

            <div>
              <%= form.label :password_confirmation, t(".password_confirmation_label"), class: "block text-sm font-medium text-stone-700" %>
              <%= form.password_field :password_confirmation, required: true, autocomplete: "new-password", maxlength: 72, class: "mt-1 block w-full rounded-md border border-stone-300 px-3 py-2 text-stone-950 shadow-sm focus:border-stone-900 focus:outline-none" %>
            </div>

            <div class="flex flex-col gap-3 sm:flex-row sm:items-center">
              <%= form.submit t(".create_account"), class: "rounded-md bg-stone-950 px-5 py-3 text-sm font-semibold text-white shadow-sm hover:bg-stone-800" %>
              <%= link_to t(".sign_in"), new_session_path, class: "text-sm font-semibold text-stone-700 underline hover:no-underline" %>
            </div>
          <% end %>
        <% end %>
      <% else %>
        <p class="text-sm font-semibold uppercase text-stone-600"><%= t(".unavailable_eyebrow") %></p>
        <h1 class="mt-2 text-3xl font-bold text-stone-950"><%= t(".unavailable_title") %></h1>
        <p class="mt-3 text-stone-700"><%= t(".unavailable_body") %></p>
        <div class="mt-6">
          <%= link_to t(".dashboard"), dashboard_path, class: "inline-flex rounded-md border border-stone-300 px-5 py-3 text-sm font-semibold text-stone-900 hover:bg-stone-100" %>
        </div>
      <% end %>
    </div>
  </section>
</main>
```

- [ ] **Step 5: Run recipient flow tests to verify they pass**

Run:

```bash
bin/rails test test/controllers/household_invites_controller_test.rb
```

Expected: all recipient flow tests pass.

- [ ] **Step 6: Commit the recipient flow slice**

Run:

```bash
git add app/controllers/household_invites_controller.rb app/views/household_invites/show.html.erb config/locales/en.yml test/controllers/household_invites_controller_test.rb
git commit -m "feat: accept household invites"
```

---

### Task 5: Documentation And Status

**Files:**
- Modify: `docs/instance-admin.md`
- Modify: `docs/workspace-core.md`
- Modify: `docs/status.md`

- [ ] **Step 1: Update docs**

In `docs/instance-admin.md`, add a section after `## Scope`:

```markdown
## Household Invites

Instance admins can invite a person by required email address to create their own separate household while public registration remains disabled. These invites are instance-scoped, email-bound, and distinct from workspace member invites.

Accepting a household invite creates a new `Workspace` with the recipient as `owner`. The inviting instance admin is not added as a member of that household. Active invites can be revoked or resent; closed invites can be re-invited with a fresh token.
```

In `docs/workspace-core.md`, add to the Invite Flow section:

```markdown
Instance-admin household invites are separate from workspace invites. A household invite is email-required and creates a brand-new household owned by the recipient; it never adds the recipient to the inviter's active workspace.
```

In `docs/status.md`, update the workspace/registration bullet to include:

```markdown
instance-admin email invites for creating separate new households while public registration remains disabled
```

- [ ] **Step 2: Review docs diff**

Run:

```bash
git diff -- docs/instance-admin.md docs/workspace-core.md docs/status.md
```

Expected: docs describe the separation between workspace member invites and instance-admin household invites.

- [ ] **Step 3: Commit docs**

Run:

```bash
git add docs/instance-admin.md docs/workspace-core.md docs/status.md
git commit -m "docs: document household invites"
```

---

### Task 6: Full Verification And Local Server

**Files:**
- No new code files unless tests reveal needed fixes.

- [ ] **Step 1: Run focused invite/admin tests**

Run:

```bash
bin/rails test test/models/household_invite_test.rb test/mailers/household_invites_mailer_test.rb test/controllers/instance_admin_household_invites_controller_test.rb test/controllers/instance_admin_controller_test.rb test/controllers/household_invites_controller_test.rb test/controllers/workspace_invites_controller_test.rb
```

Expected: all focused tests pass with zero failures and zero errors.

- [ ] **Step 2: Run the full Rails test suite**

Run:

```bash
bin/rails test
```

Expected: full suite passes with zero failures and zero errors.

- [ ] **Step 3: Start the local development server**

Run:

```bash
bin/rails server -p 3001 -b 0.0.0.0
```

Expected: server listens on port `3001` and is reachable on the network host/DNS configured for local Roastnode development.

- [ ] **Step 4: Final status**

Check:

```bash
git status --short
```

Expected: no unintended files. If schema/docs/code changes remain uncommitted, commit them with a descriptive message before final handoff.
