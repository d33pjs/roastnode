# Workspace Core Design

Date: 2026-05-25

## Goal

Implement Roastnode's first product layer after authentication: private household workspaces with memberships, roles, active workspace selection, a signed-in dashboard, member visibility, and invite-link creation/acceptance.

## Scope

This slice builds the ownership and authorization boundary that later beans, equipment, recipes, brews, inventory, photos, imports, exports, and stats must use.

Included:

- `Workspace` model with household-first defaults.
- `Membership` model connecting users to workspaces with roles: owner, admin, member, viewer.
- `WorkspaceInvite` model with copyable token links for private installs without SMTP.
- Active workspace tracking on `User`.
- First-user onboarding that creates a household workspace.
- Workspace dashboard as the authenticated root page.
- Workspace switcher for users in multiple workspaces.
- Member list.
- Invite creation, revocation, and acceptance for authenticated users.
- Simple policy objects for workspace-scoped authorization.
- Tests for workspace isolation, role authorization, invite role assignment, and active workspace selection.

Deferred:

- Public registration controls.
- Email delivery for invites.
- Account creation from invite links.
- Ownership transfer and workspace deletion.
- Full instance admin UI.
- Beans, equipment, recipes, brews, photos, imports, exports, and stats.

## Approach

Use a Rails monolith with conventional Active Record associations and server-rendered Hotwire-compatible pages. Authorization starts with small local policy objects rather than a dependency, because v1 only needs a few explicit role checks in this slice. If policies become repetitive later, the project can switch to Pundit-style integration while preserving the public authorization API.

The active workspace is stored on the user record so the selected workspace follows the user across sessions and devices. Controllers must derive workspace-scoped data through `Current.user` memberships and the active workspace helper, not raw ids.

## Data Model

### Users

Add:

- `display_name`
- `instance_admin`, default false
- `active_workspace_id`, optional foreign key to workspaces

Existing email/password authentication stays Rails-native.

### Workspaces

Fields:

- `name`
- `kind`, enum string with initial value `household`
- `default_currency`, default `EUR`

Workspace records are private by default. Future public/federated states are not modeled in this slice.

### Memberships

Fields:

- `user_id`
- `workspace_id`
- `role`, enum string: owner, admin, member, viewer

Constraints:

- one membership per user/workspace
- every workspace must have at least one owner in normal flows

### Workspace Invites

Fields:

- `workspace_id`
- `created_by_id`
- `accepted_by_id`, optional
- `role`
- `token`
- `email_address`, optional
- `expires_at`
- `revoked_at`
- `accepted_at`

Invites are valid when not expired, not revoked, and not accepted. Tokens are generated with `SecureRandom.urlsafe_base64`.

## User Flows

### First Sign-In

When a signed-in user has no memberships, the root page shows an onboarding form asking for the household workspace name. Creating it makes the user an owner and sets it as active.

### Dashboard

When the user has an active workspace, the root page shows:

- workspace name and kind
- current user email
- role in the active workspace
- quick links for members and invites
- placeholders for upcoming beans, equipment, and brew logging

### Workspace Switching

A signed-in user can switch among their workspaces. Switching stores `active_workspace_id` on the user only if they belong to that workspace.

### Members

Members page lists users in the active workspace with roles. Owner/admin can see invite actions; lower roles can only read the list.

### Invites

Owner/admin can create invite links for admin, member, or viewer roles. Owner invites are not created through this UI. A valid invite can be accepted by any authenticated user and creates or updates their membership in the invited workspace with the invite role.

## Authorization

Policy methods:

- owners and admins can manage members and invites
- members can read normal workspace data
- viewers are read-only
- users can only switch to workspaces where they have a membership
- invite acceptance grants only the role stored on the invite

Controllers must redirect to root with an alert when access is denied.

## Error Handling

- Invalid workspace creation re-renders onboarding.
- Invalid invite creation re-renders the invite page.
- Invalid, expired, revoked, or accepted invite links show an explanatory page.
- Unauthorized actions redirect to the dashboard with an alert.

## Testing

Add model and controller tests covering:

- first workspace creation assigns owner and active workspace
- user cannot access another workspace's members page
- member cannot create invites
- owner/admin can create invite links
- invite acceptance creates membership with the intended role
- viewer remains read-only
- active workspace switch rejects non-member workspace ids

## Documentation

Update setup/agent docs to state that new development users must create a workspace after sign-in and that all future domain models must be workspace-scoped.

