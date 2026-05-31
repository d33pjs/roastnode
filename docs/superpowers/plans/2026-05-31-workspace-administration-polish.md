# Workspace Administration Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add safe active-workspace member management, ownership transfer, and owner-only workspace deletion.

**Architecture:** Put role-change, member-removal, and transfer invariants in `WorkspaceMembershipManager`, then keep controllers thin and scoped through `current_workspace`. Add owner-only workspace deletion to the singleton workspace controller and clear `active_workspace_id` before destroying a workspace.

**Tech Stack:** Rails 8.1, Active Record, Minitest integration/model tests, Hotwire-friendly server-rendered ERB, Tailwind CSS.

---

## File Structure

- Create `app/services/workspace_membership_manager.rb`: centralizes membership mutation authorization, last-owner protection, transfer, and active-workspace cleanup.
- Create `test/services/workspace_membership_manager_test.rb`: verifies service behavior independently of controller routing.
- Modify `app/controllers/memberships_controller.rb`: add update and destroy actions scoped to `current_workspace.memberships`.
- Modify `app/controllers/workspaces_controller.rb`: add transfer ownership and destroy actions, plus owner authorization.
- Modify `app/controllers/application_controller.rb`: expose owner-only authorization helper.
- Modify `app/policies/workspace_policy.rb`: add `owner?`.
- Modify `config/routes.rb`: add `memberships#update`, `memberships#destroy`, `workspace#transfer_ownership`, and `workspace#destroy`.
- Modify `app/views/memberships/index.html.erb`: add role forms, remove buttons, and owner transfer form when allowed.
- Modify `app/views/workspaces/edit.html.erb`: add owner-only deletion danger zone.
- Modify `config/locales/en.yml`: add notices, alerts, labels, and confirmation copy.
- Modify `test/controllers/memberships_controller_test.rb`: cover controller permissions, isolation, and rendered controls.
- Modify `test/controllers/workspaces_controller_test.rb`: cover ownership transfer and workspace deletion.
- Modify `docs/workspace-core.md`, `docs/workspace-settings.md`, `docs/status.md`, and ignored `docs/open-topics.md`: record completed behavior and remove the completed private v1 item.

---

### Task 1: Membership Manager Service

**Files:**
- Create: `app/services/workspace_membership_manager.rb`
- Create: `test/services/workspace_membership_manager_test.rb`

- [ ] **Step 1: Write failing service tests**

Add `test/services/workspace_membership_manager_test.rb`:

```ruby
require "test_helper"

class WorkspaceMembershipManagerTest < ActiveSupport::TestCase
  test "owner can change non owner role" do
    manager = WorkspaceMembershipManager.new(workspace: workspaces(:household), actor_membership: memberships(:owner))

    result = manager.update_role(memberships(:member), "viewer")

    assert result.success?
    assert_equal "viewer", memberships(:member).reload.role
  end

  test "admin can only change member and viewer roles" do
    workspace = workspaces(:household)
    admin_user = User.create!(email_address: "admin-service@example.com", password: "password")
    admin = Membership.create!(workspace:, user: admin_user, role: "admin")
    viewer_user = User.create!(email_address: "viewer-service@example.com", password: "password")
    viewer = Membership.create!(workspace:, user: viewer_user, role: "viewer")
    manager = WorkspaceMembershipManager.new(workspace:, actor_membership: admin)

    assert manager.update_role(memberships(:member), "viewer").success?
    assert_equal "viewer", memberships(:member).reload.role

    assert manager.update_role(viewer, "member").success?
    assert_equal "member", viewer.reload.role

    result = manager.update_role(admin, "viewer")
    assert_not result.success?
    assert_equal :unauthorized, result.error
    assert_equal "admin", admin.reload.role
  end

  test "last owner cannot be demoted or removed" do
    manager = WorkspaceMembershipManager.new(workspace: workspaces(:household), actor_membership: memberships(:owner))

    demotion = manager.update_role(memberships(:owner), "admin")
    removal = manager.remove(memberships(:owner))

    assert_not demotion.success?
    assert_equal :last_owner, demotion.error
    assert_not removal.success?
    assert_equal :last_owner, removal.error
    assert_equal "owner", memberships(:owner).reload.role
  end

  test "ownership transfer promotes target and demotes actor" do
    manager = WorkspaceMembershipManager.new(workspace: workspaces(:household), actor_membership: memberships(:owner))

    result = manager.transfer_ownership(memberships(:member))

    assert result.success?
    assert_equal "admin", memberships(:owner).reload.role
    assert_equal "owner", memberships(:member).reload.role
  end

  test "removing a member clears their active workspace only when needed" do
    workspace = workspaces(:household)
    user = users(:two)
    user.update!(active_workspace: workspace)
    manager = WorkspaceMembershipManager.new(workspace:, actor_membership: memberships(:owner))

    result = manager.remove(memberships(:member))

    assert result.success?
    assert_nil user.reload.active_workspace
    assert_not Membership.exists?(memberships(:member).id)
  end
end
```

- [ ] **Step 2: Run service tests to verify RED**

Run: `bin/rails test test/services/workspace_membership_manager_test.rb`

Expected: FAIL with `NameError: uninitialized constant WorkspaceMembershipManager`.

- [ ] **Step 3: Implement the service**

Create `app/services/workspace_membership_manager.rb`:

```ruby
class WorkspaceMembershipManager
  Result = Struct.new(:success, :error, keyword_init: true) do
    def success?
      success
    end
  end

  ADMIN_MANAGED_ROLES = %w[member viewer].freeze
  OWNER_ASSIGNABLE_ROLES = %w[admin member viewer].freeze

  def initialize(workspace:, actor_membership:)
    @workspace = workspace
    @actor_membership = actor_membership
  end

  def update_role(target_membership, role)
    role = role.to_s
    return failure(:invalid_role) unless Membership.roles.key?(role)
    return failure(:last_owner) if target_membership.owner? && role != "owner" && sole_owner?(target_membership)
    return failure(:unauthorized) unless can_update_role?(target_membership, role)

    target_membership.update!(role:)
    success
  end

  def remove(target_membership)
    return failure(:last_owner) if target_membership.owner? && sole_owner?(target_membership)
    return failure(:unauthorized) unless can_remove?(target_membership)

    target_user = target_membership.user
    target_membership.destroy!
    target_user.update!(active_workspace: nil) if target_user.active_workspace_id == workspace.id
    success
  end

  def transfer_ownership(target_membership)
    return failure(:unauthorized) unless actor_membership&.owner?
    return failure(:transfer_self) if target_membership.id == actor_membership.id

    Membership.transaction do
      target_membership.update!(role: "owner")
      actor_membership.update!(role: "admin")
    end

    success
  end

  private
    attr_reader :workspace, :actor_membership

    def can_update_role?(target_membership, role)
      return false unless same_workspace?(target_membership)

      if actor_membership&.owner?
        return false if target_membership.owner?

        OWNER_ASSIGNABLE_ROLES.include?(role)
      elsif actor_membership&.admin?
        ADMIN_MANAGED_ROLES.include?(target_membership.role) && ADMIN_MANAGED_ROLES.include?(role)
      else
        false
      end
    end

    def can_remove?(target_membership)
      return false unless same_workspace?(target_membership)

      if actor_membership&.owner?
        !target_membership.owner?
      elsif actor_membership&.admin?
        ADMIN_MANAGED_ROLES.include?(target_membership.role)
      else
        false
      end
    end

    def same_workspace?(membership)
      membership.workspace_id == workspace.id
    end

    def sole_owner?(membership)
      membership.owner? && workspace.memberships.owner.where.not(id: membership.id).none?
    end

    def success
      Result.new(success: true)
    end

    def failure(error)
      Result.new(success: false, error:)
    end
end
```

- [ ] **Step 4: Run service tests to verify GREEN**

Run: `bin/rails test test/services/workspace_membership_manager_test.rb`

Expected: PASS.

- [ ] **Step 5: Commit service**

```bash
git add app/services/workspace_membership_manager.rb test/services/workspace_membership_manager_test.rb
git commit -m "Add workspace membership manager"
```

---

### Task 2: Membership Routes And Controller Actions

**Files:**
- Modify: `config/routes.rb`
- Modify: `app/controllers/memberships_controller.rb`
- Modify: `test/controllers/memberships_controller_test.rb`

- [ ] **Step 1: Write failing controller tests**

Append to `test/controllers/memberships_controller_test.rb`:

```ruby
  test "owner can update member role" do
    sign_in_as(users(:one))

    patch membership_path(memberships(:member)), params: { membership: { role: "viewer" } }

    assert_redirected_to memberships_path
    assert_equal "viewer", memberships(:member).reload.role
  end

  test "admin can update member and viewer roles but not admins" do
    workspace = workspaces(:household)
    admin = User.create!(email_address: "admin-controller@example.com", password: "password")
    admin_membership = Membership.create!(workspace:, user: admin, role: "admin")
    admin.update!(active_workspace: workspace)
    other_admin = Membership.create!(workspace:, user: User.create!(email_address: "other-admin@example.com", password: "password"), role: "admin")
    sign_in_as(admin)

    patch membership_path(memberships(:member)), params: { membership: { role: "viewer" } }
    assert_redirected_to memberships_path
    assert_equal "viewer", memberships(:member).reload.role

    patch membership_path(other_admin), params: { membership: { role: "viewer" } }
    assert_redirected_to memberships_path
    assert_equal "admin", other_admin.reload.role
    assert_equal "admin", admin_membership.reload.role
  end

  test "owner can remove non owner member" do
    users(:two).update!(active_workspace: workspaces(:household))
    sign_in_as(users(:one))

    delete membership_path(memberships(:member))

    assert_redirected_to memberships_path
    assert_not Membership.exists?(memberships(:member).id)
    assert_nil users(:two).reload.active_workspace
  end

  test "member cannot update or remove memberships" do
    actor = users(:two)
    actor.update!(active_workspace: workspaces(:household))
    sign_in_as(actor)

    patch membership_path(memberships(:owner)), params: { membership: { role: "viewer" } }
    assert_redirected_to memberships_path
    assert_equal "owner", memberships(:owner).reload.role

    delete membership_path(memberships(:owner))
    assert_redirected_to memberships_path
    assert Membership.exists?(memberships(:owner).id)
  end

  test "membership from another workspace cannot be changed or removed" do
    sign_in_as(users(:one))

    patch membership_path(memberships(:other_owner)), params: { membership: { role: "viewer" } }
    assert_redirected_to memberships_path
    assert_equal "owner", memberships(:other_owner).reload.role

    delete membership_path(memberships(:other_owner))
    assert_redirected_to memberships_path
    assert Membership.exists?(memberships(:other_owner).id)
  end
```

- [ ] **Step 2: Run controller tests to verify RED**

Run: `bin/rails test test/controllers/memberships_controller_test.rb`

Expected: FAIL with no route/action for membership update or destroy.

- [ ] **Step 3: Add routes and controller actions**

Change `config/routes.rb`:

```ruby
resources :memberships, only: %i[index update destroy]
```

Update `app/controllers/memberships_controller.rb`:

```ruby
class MembershipsController < ApplicationController
  before_action :set_membership, only: %i[update destroy]

  def index
    if invalid_active_workspace?
      Current.user.update!(active_workspace: nil)
      return redirect_to root_path, alert: t("authorization.denied")
    end

    unless current_workspace_policy.read?
      Current.user.ensure_active_workspace!
      return redirect_to root_path, alert: t("authorization.denied")
    end

    load_memberships
  end

  def update
    result = membership_manager.update_role(@membership, membership_params[:role])
    redirect_to memberships_path, flash_for(result, success_key: ".updated")
  end

  def destroy
    result = membership_manager.remove(@membership)
    redirect_to memberships_path, flash_for(result, success_key: ".removed")
  end

  private
    def invalid_active_workspace?
      Current.user.active_workspace.present? &&
        !Current.user.memberships.exists?(workspace: Current.user.active_workspace)
    end

    def load_memberships
      @memberships = current_workspace.memberships.includes(:user).order(:role, "users.email_address")
      @transfer_memberships = @memberships.reject { |membership| membership.id == current_membership.id }
    end

    def set_membership
      @membership = current_workspace.memberships.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      redirect_to memberships_path, alert: t("authorization.denied")
    end

    def membership_manager
      @membership_manager ||= WorkspaceMembershipManager.new(
        workspace: current_workspace,
        actor_membership: current_membership
      )
    end

    def membership_params
      params.require(:membership).permit(:role)
    end

    def flash_for(result, success_key:)
      if result.success?
        { notice: t(success_key) }
      else
        { alert: t("workspace_membership_manager.errors.#{result.error}") }
      end
    end
end
```

- [ ] **Step 4: Add locales for controller messages**

In `config/locales/en.yml`, under `memberships`, add:

```yaml
    update:
      updated: "Member role updated."
    destroy:
      removed: "Member removed."
```

Add top-level:

```yaml
  workspace_membership_manager:
    errors:
      invalid_role: "Choose a supported role."
      last_owner: "A workspace must keep at least one owner."
      transfer_self: "Choose another member to transfer ownership."
      unauthorized: "You cannot manage that member."
```

- [ ] **Step 5: Run membership controller tests to verify GREEN**

Run: `bin/rails test test/controllers/memberships_controller_test.rb`

Expected: PASS.

- [ ] **Step 6: Commit membership actions**

```bash
git add config/routes.rb app/controllers/memberships_controller.rb config/locales/en.yml test/controllers/memberships_controller_test.rb
git commit -m "Add workspace member management actions"
```

---

### Task 3: Ownership Transfer And Workspace Deletion

**Files:**
- Modify: `config/routes.rb`
- Modify: `app/policies/workspace_policy.rb`
- Modify: `app/controllers/application_controller.rb`
- Modify: `app/controllers/workspaces_controller.rb`
- Modify: `test/controllers/workspaces_controller_test.rb`

- [ ] **Step 1: Write failing workspace controller tests**

Append to `test/controllers/workspaces_controller_test.rb`:

```ruby
  test "owner can transfer ownership to another member" do
    sign_in_as(users(:one))

    patch transfer_ownership_workspace_path, params: { membership_id: memberships(:member).id }

    assert_redirected_to memberships_path
    assert_equal "admin", memberships(:owner).reload.role
    assert_equal "owner", memberships(:member).reload.role
  end

  test "admin cannot transfer ownership" do
    workspace = workspaces(:household)
    admin = User.create!(email_address: "transfer-admin@example.com", password: "password")
    admin_membership = Membership.create!(workspace:, user: admin, role: "admin")
    admin.update!(active_workspace: workspace)
    sign_in_as(admin)

    patch transfer_ownership_workspace_path, params: { membership_id: memberships(:member).id }

    assert_redirected_to root_path
    assert_equal "admin", admin_membership.reload.role
    assert_equal "member", memberships(:member).reload.role
  end

  test "owner can delete active workspace with exact confirmation" do
    workspace = workspaces(:household)
    users(:one).update!(active_workspace: workspace)
    users(:two).update!(active_workspace: workspace)
    bean_id = beans(:open_household).id
    sign_in_as(users(:one))

    delete workspace_path, params: { confirmation: workspace.name }

    assert_redirected_to root_path
    assert_not Workspace.exists?(workspace.id)
    assert_not Bean.exists?(bean_id)
    assert_nil users(:one).reload.active_workspace
    assert_nil users(:two).reload.active_workspace
  end

  test "workspace deletion requires exact confirmation" do
    workspace = workspaces(:household)
    sign_in_as(users(:one))

    delete workspace_path, params: { confirmation: "wrong name" }

    assert_redirected_to edit_workspace_path
    assert Workspace.exists?(workspace.id)
  end

  test "admin cannot delete workspace" do
    workspace = workspaces(:household)
    admin = User.create!(email_address: "delete-admin@example.com", password: "password")
    Membership.create!(workspace:, user: admin, role: "admin")
    admin.update!(active_workspace: workspace)
    sign_in_as(admin)

    delete workspace_path, params: { confirmation: workspace.name }

    assert_redirected_to root_path
    assert Workspace.exists?(workspace.id)
  end
```

- [ ] **Step 2: Run workspace controller tests to verify RED**

Run: `bin/rails test test/controllers/workspaces_controller_test.rb`

Expected: FAIL with missing transfer route and missing destroy action.

- [ ] **Step 3: Add routes, policy helper, and controller actions**

Change `config/routes.rb`:

```ruby
resource :workspace, only: %i[edit update destroy] do
  patch :transfer_ownership
end
```

Update `app/policies/workspace_policy.rb`:

```ruby
  def owner?
    membership&.owner? || false
  end
```

Update `app/controllers/application_controller.rb`:

```ruby
    def authorize_workspace_owner!
      return if current_workspace_policy.owner?

      redirect_to root_path, alert: t("authorization.denied")
    end
```

Update `app/controllers/workspaces_controller.rb`:

```ruby
class WorkspacesController < ApplicationController
  before_action :set_workspace, only: :switch
  before_action :authorize_workspace_admin!, only: %i[edit update]
  before_action :authorize_workspace_owner!, only: %i[transfer_ownership destroy]

  def edit
    @workspace = current_workspace
  end

  def update
    @workspace = current_workspace

    if @workspace.update(workspace_params)
      redirect_to dashboard_path, notice: t(".updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def transfer_ownership
    membership = current_workspace.memberships.find(params[:membership_id])
    result = WorkspaceMembershipManager.new(
      workspace: current_workspace,
      actor_membership: current_membership
    ).transfer_ownership(membership)

    if result.success?
      redirect_to memberships_path, notice: t(".transferred")
    else
      redirect_to memberships_path, alert: t("workspace_membership_manager.errors.#{result.error}")
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to memberships_path, alert: t("authorization.denied")
  end

  def destroy
    @workspace = current_workspace

    unless params[:confirmation] == @workspace.name
      return redirect_to edit_workspace_path, alert: t(".confirmation_mismatch")
    end

    Workspace.transaction do
      User.where(active_workspace_id: @workspace.id).update_all(active_workspace_id: nil)
      @workspace.destroy!
    end

    redirect_to root_path, notice: t(".destroyed")
  end

  def switch
    if Current.user.memberships.exists?(workspace: @workspace)
      Current.user.update!(active_workspace: @workspace)
      redirect_to root_path, notice: t(".switched", name: @workspace.name)
    else
      Current.user.ensure_active_workspace!
      redirect_to root_path, alert: t("authorization.denied")
    end
  end

  private
    def set_workspace
      @workspace = Workspace.find(params[:id])
    end

    def workspace_params
      params.require(:workspace).permit(:name, :default_currency, :logo, :banner)
    end
end
```

- [ ] **Step 4: Add locales**

Under `workspaces`, add:

```yaml
    destroy:
      confirmation_mismatch: "Type the workspace name to confirm deletion."
      destroyed: "Workspace deleted."
    transfer_ownership:
      transferred: "Workspace ownership transferred."
```

- [ ] **Step 5: Run workspace controller tests to verify GREEN**

Run: `bin/rails test test/controllers/workspaces_controller_test.rb`

Expected: PASS.

- [ ] **Step 6: Commit workspace ownership/deletion actions**

```bash
git add config/routes.rb app/policies/workspace_policy.rb app/controllers/application_controller.rb app/controllers/workspaces_controller.rb config/locales/en.yml test/controllers/workspaces_controller_test.rb
git commit -m "Add workspace ownership transfer and deletion"
```

---

### Task 4: Administration UI

**Files:**
- Modify: `app/views/memberships/index.html.erb`
- Modify: `app/views/workspaces/edit.html.erb`
- Modify: `config/locales/en.yml`
- Modify: `test/controllers/memberships_controller_test.rb`
- Modify: `test/controllers/workspaces_controller_test.rb`

- [ ] **Step 1: Write failing view/control tests**

Append to `test/controllers/memberships_controller_test.rb`:

```ruby
  test "owner sees member management controls and transfer form" do
    sign_in_as(users(:one))

    get memberships_path

    assert_response :success
    assert_select "form[action=?][method=post]", membership_path(memberships(:member))
    assert_select "input[name=_method][value=patch]"
    assert_select "form[action=?][method=post]", transfer_ownership_workspace_path
    assert_select "form[action=?][method=post]", membership_path(memberships(:member))
    assert_select "input[name=_method][value=delete]"
  end

  test "viewer does not see member management controls" do
    memberships(:member).update!(role: "viewer")
    users(:two).update!(active_workspace: workspaces(:household))
    sign_in_as(users(:two))

    get memberships_path

    assert_response :success
    assert_select "form[action=?]", membership_path(memberships(:owner)), count: 0
    assert_select "form[action=?]", transfer_ownership_workspace_path, count: 0
  end
```

Append to `test/controllers/workspaces_controller_test.rb`:

```ruby
  test "owner sees workspace deletion danger zone" do
    sign_in_as(users(:one))

    get edit_workspace_path

    assert_response :success
    assert_select "form[action=?][method=post]", workspace_path
    assert_select "input[name=_method][value=delete]"
    assert_select "input[name=confirmation]"
  end

  test "admin does not see workspace deletion danger zone" do
    workspace = workspaces(:household)
    admin = User.create!(email_address: "danger-admin@example.com", password: "password")
    Membership.create!(workspace:, user: admin, role: "admin")
    admin.update!(active_workspace: workspace)
    sign_in_as(admin)

    get edit_workspace_path

    assert_response :success
    assert_select "input[name=confirmation]", count: 0
  end
```

- [ ] **Step 2: Run view tests to verify RED**

Run: `bin/rails test test/controllers/memberships_controller_test.rb test/controllers/workspaces_controller_test.rb`

Expected: FAIL because forms are not rendered yet.

- [ ] **Step 3: Update memberships view**

Replace `app/views/memberships/index.html.erb` with a responsive table that keeps existing text and adds controls:

```erb
<main class="min-h-screen bg-stone-50">
  <section class="mx-auto max-w-5xl px-6 py-10">
    <div class="mb-8">
      <%= render "shared/back_link", label: t(".back"), path: dashboard_path %>
      <h1 class="mt-4 text-3xl font-bold text-stone-950"><%= t(".title") %></h1>
      <p class="mt-2 text-stone-700"><%= current_workspace.name %></p>
    </div>

    <div class="overflow-hidden rounded-lg border border-stone-200 bg-white shadow-sm">
      <table class="min-w-full divide-y divide-stone-200">
        <thead class="bg-stone-100">
          <tr>
            <th class="px-4 py-3 text-left text-sm font-semibold text-stone-700"><%= t(".email") %></th>
            <th class="px-4 py-3 text-left text-sm font-semibold text-stone-700"><%= t(".role") %></th>
            <% if current_workspace_policy.manage? %>
              <th class="px-4 py-3 text-left text-sm font-semibold text-stone-700"><%= t(".actions") %></th>
            <% end %>
          </tr>
        </thead>
        <tbody class="divide-y divide-stone-100">
          <% @memberships.each do |membership| %>
            <% can_owner_manage = current_workspace_policy.owner? && !membership.owner? %>
            <% can_admin_manage = current_membership.admin? && membership.member? || current_membership.admin? && membership.viewer? %>
            <% can_manage_membership = can_owner_manage || can_admin_manage %>
            <% role_options = current_workspace_policy.owner? ? %w[admin member viewer] : %w[member viewer] %>

            <tr>
              <td class="px-4 py-3 text-sm text-stone-900"><%= membership.user.email_address %></td>
              <td class="px-4 py-3 text-sm text-stone-700">
                <% if can_manage_membership %>
                  <%= form_with model: membership, url: membership_path(membership), method: :patch, class: "flex flex-wrap items-center gap-2" do |form| %>
                    <%= form.select :role, role_options.map { |role| [ role.humanize, role ] }, {}, class: "rounded-md border border-stone-300 px-3 py-2 text-sm text-stone-950 shadow-sm focus:border-stone-900 focus:outline-none" %>
                    <%= form.submit t(".update_role"), class: "rounded-md bg-stone-950 px-3 py-2 text-sm font-semibold text-white hover:bg-stone-800" %>
                  <% end %>
                <% else %>
                  <%= membership.role.humanize %>
                <% end %>
              </td>
              <% if current_workspace_policy.manage? %>
                <td class="px-4 py-3 text-sm text-stone-700">
                  <% if can_manage_membership %>
                    <%= button_to t(".remove"),
                      membership_path(membership),
                      method: :delete,
                      form: { data: { turbo_confirm: t(".remove_confirmation", user: membership.user.email_address) } },
                      class: "rounded-md border border-red-200 px-3 py-2 text-sm font-semibold text-red-700 hover:bg-red-50" %>
                  <% else %>
                    <span class="text-stone-500"><%= t(".not_manageable") %></span>
                  <% end %>
                </td>
              <% end %>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>

    <% if current_workspace_policy.owner? && @transfer_memberships.any? %>
      <div class="mt-8 rounded-lg border border-amber-200 bg-amber-50 p-6">
        <h2 class="text-xl font-semibold text-stone-950"><%= t(".transfer_title") %></h2>
        <p class="mt-2 text-sm text-stone-700"><%= t(".transfer_body") %></p>
        <%= form_with url: transfer_ownership_workspace_path, method: :patch, class: "mt-4 flex flex-wrap items-end gap-3" do |form| %>
          <div>
            <%= form.label :membership_id, t(".transfer_member"), class: "block text-sm font-medium text-stone-700" %>
            <%= form.select :membership_id,
              @transfer_memberships.map { |membership| [ "#{membership.user.email_address} (#{membership.role.humanize})", membership.id ] },
              {},
              class: "mt-1 rounded-md border border-stone-300 px-3 py-2 text-stone-950 shadow-sm focus:border-stone-900 focus:outline-none" %>
          </div>
          <%= form.submit t(".transfer_submit"),
            data: { turbo_confirm: t(".transfer_confirmation") },
            class: "rounded-md bg-amber-700 px-4 py-2 text-sm font-semibold text-white hover:bg-amber-800" %>
        <% end %>
      </div>
    <% end %>
  </section>
</main>
```

- [ ] **Step 4: Update workspace settings view**

In `app/views/workspaces/edit.html.erb`, after the settings form card, add:

```erb
    <% if current_workspace_policy.owner? %>
      <div class="mt-6 rounded-lg border border-red-200 bg-red-50 p-6 shadow-sm">
        <h2 class="text-xl font-semibold text-red-950"><%= t(".danger_title") %></h2>
        <p class="mt-2 text-sm text-red-800"><%= t(".danger_body", name: @workspace.name) %></p>
        <%= form_with url: workspace_path, method: :delete, class: "mt-4 space-y-3" do |form| %>
          <div>
            <%= form.label :confirmation, t(".confirmation_label", name: @workspace.name), class: "block text-sm font-medium text-red-950" %>
            <%= form.text_field :confirmation, required: true, class: "mt-1 w-full rounded-md border border-red-300 px-3 py-2 text-stone-950 shadow-sm focus:border-red-700 focus:outline-none" %>
          </div>
          <%= form.submit t(".delete_workspace"),
            data: { turbo_confirm: t(".delete_confirmation") },
            class: "rounded-md bg-red-700 px-5 py-3 text-sm font-semibold text-white shadow-sm hover:bg-red-800" %>
        <% end %>
      </div>
    <% end %>
```

- [ ] **Step 5: Add UI locales**

Under `memberships.index`, add:

```yaml
      actions: "Actions"
      not_manageable: "No actions"
      remove: "Remove"
      remove_confirmation: "Remove %{user} from this workspace?"
      transfer_body: "Transfer ownership to another member. Your role will become admin."
      transfer_confirmation: "Transfer ownership of this workspace?"
      transfer_member: "New owner"
      transfer_submit: "Transfer ownership"
      transfer_title: "Transfer ownership"
      update_role: "Update role"
```

Under `workspaces.edit`, add:

```yaml
      confirmation_label: "Type %{name} to confirm"
      danger_body: "Deleting %{name} removes the workspace and its beans, brews, equipment, invites, imports, exports, and media references. This cannot be undone."
      danger_title: "Delete workspace"
      delete_confirmation: "Delete this workspace and its data?"
      delete_workspace: "Delete workspace"
```

- [ ] **Step 6: Run view/control tests to verify GREEN**

Run: `bin/rails test test/controllers/memberships_controller_test.rb test/controllers/workspaces_controller_test.rb`

Expected: PASS.

- [ ] **Step 7: Commit administration UI**

```bash
git add app/views/memberships/index.html.erb app/views/workspaces/edit.html.erb config/locales/en.yml test/controllers/memberships_controller_test.rb test/controllers/workspaces_controller_test.rb
git commit -m "Add workspace administration controls"
```

---

### Task 5: Documentation And Private Open Topics

**Files:**
- Modify: `docs/workspace-core.md`
- Modify: `docs/workspace-settings.md`
- Modify: `docs/status.md`
- Modify: `docs/open-topics.md`

- [ ] **Step 1: Update workspace docs**

Update `docs/workspace-core.md`:

```markdown
## Member Management

Owners can manage admins, members, and viewers from the active workspace members page. Admins can manage members and viewers only. Members and viewers can read the member list but cannot change roles or remove members.

Ownership transfer is owner-only. The selected member becomes owner and the previous owner becomes admin. Normal member-management actions must preserve at least one owner.

Removing a member clears that user's active workspace if it pointed at the removed workspace.
```

Update `docs/workspace-settings.md` boundaries and included behavior to mention owner-only workspace deletion with typed-name confirmation.

- [ ] **Step 2: Update status and private topics**

In `docs/status.md`, update the workspace core bullet to mention member role management, ownership transfer, and workspace deletion.

In `docs/open-topics.md`, remove:

```markdown
- Workspace administration polish: workspace deletion, ownership transfer, richer member management, and any public/private registration settings chosen for private installs.
```

Keep:

```markdown
- Add Resend as a mailservice option.
```

- [ ] **Step 3: Verify docs do not expose private roadmap details**

Run: `rg -n "Good Next Slices|Still Missing For v1|Workspace administration polish|Add Resend|mailservice" docs/status.md docs/README.md AGENTS.md .gitignore`

Expected: no output.

- [ ] **Step 4: Commit documentation**

```bash
git add docs/workspace-core.md docs/workspace-settings.md docs/status.md
git commit -m "Document workspace administration polish"
```

`docs/open-topics.md` is ignored and should remain uncommitted.

---

### Task 6: Full Verification

**Files:**
- All modified files.

- [ ] **Step 1: Run focused tests**

Run: `bin/rails test test/services/workspace_membership_manager_test.rb test/controllers/memberships_controller_test.rb test/controllers/workspaces_controller_test.rb`

Expected: PASS.

- [ ] **Step 2: Run full test suite**

Run: `env PARALLEL_WORKERS=1 bin/rails test`

Expected: PASS.

- [ ] **Step 3: Inspect final status**

Run: `git status --short`

Expected: only ignored `docs/open-topics.md` may differ; tracked changes should be committed.
