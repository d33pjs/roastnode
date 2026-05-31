# Workspace Administration Polish Design

Date: 2026-05-31

## Goal

Finish the v1 workspace administration surface with safe member management, ownership transfer, and workspace deletion for private household installs.

## Scope

Included:

- Role editing for active-workspace memberships.
- Member removal from the active workspace.
- Owner-only ownership transfer.
- Owner-only workspace deletion with typed-name confirmation.
- Protection against removing or demoting the last owner.
- Admin limits that keep admins from managing owners or other admins.
- Active-workspace cleanup when a membership or workspace is removed.
- Tests for authorization, workspace isolation, and owner-count invariants.

Deferred:

- Public registration modes.
- Billing, workspace visibility, or workspace kind changes.
- Instance-admin user management across all workspaces.
- Invitations by email delivery.
- Audit logs or undo for administrative actions.

## Approach

Keep the main administration surface on the existing members page. The page already represents the active workspace and is linked from the account menu, so expanding it avoids introducing a new admin area. The workspace settings page stays focused on identity settings and gets only the owner-only deletion danger zone.

Use singleton workspace routes for workspace-scoped destructive actions. Role changes and member removals use membership ids, but controllers must always look them up through `current_workspace.memberships` so ids from other workspaces cannot be modified.

Move membership mutation rules into a small service object or focused model methods. Controllers should ask whether an action succeeded, set flash messages, and redirect. The invariant checks should live close to the mutation so role updates, removals, and ownership transfer share the same safety rules.

## Authorization

Owners can:

- Change roles for admins, members, and viewers.
- Remove admins, members, and viewers.
- Transfer ownership to another active workspace member.
- Delete the active workspace.

Admins can:

- Change members and viewers between `member` and `viewer`.
- Remove members and viewers.

Admins cannot:

- Create, remove, demote, or promote owners.
- Manage other admins.
- Transfer ownership.
- Delete the workspace.

Members and viewers can read the members list but cannot see or submit member-management controls.

Every mutation must preserve at least one owner. A role change, member removal, or ownership transfer that would leave the workspace without an owner is rejected with an alert.

## User Flows

### Role Change

An owner opens Members, selects a new role for a non-owner membership, and submits. The membership updates and the page redirects back with a notice. If the target membership belongs to another workspace, it is not found through the scoped lookup. If the change would remove the last owner, the app redirects back with an alert.

An admin opens Members and can only change member/viewer memberships between `member` and `viewer`. Owner and admin rows render without admin controls.

### Member Removal

An owner or admin removes a membership they are allowed to manage. The membership is destroyed, the removed user's `active_workspace` is cleared if it pointed at this workspace, and the page redirects back with a notice.

A user cannot remove the last owner. If a sole owner tries to remove themself, the app rejects the request.

### Ownership Transfer

An owner chooses another active workspace member and confirms transfer. The selected member becomes `owner`. The current owner becomes `admin` unless they are transferring to themself, which is treated as a no-op with an alert.

Ownership transfer is owner-only. Admins cannot submit the transfer action.

### Workspace Deletion

An owner opens workspace settings, sees a danger zone, types the exact workspace name, and submits deletion. On success, the workspace and dependent workspace data are destroyed through existing associations. The deleting user's `active_workspace` is cleared, then the user is redirected to `root_path`; if they have no remaining workspaces, the existing root flow sends them to workspace onboarding.

If the typed confirmation does not match the workspace name, the settings page re-renders or redirects with an alert and the workspace remains unchanged.

## Data And Cleanup

`Workspace` already owns memberships, invites, imports, beans, equipment, brews, inventory adjustments, equipment events, preparation tools, logo, and banner. Deletion should rely on those associations unless implementation discovers a missing dependent relationship.

When a membership is removed, clear that user's `active_workspace` if it points at the removed workspace. Do not modify their memberships or active workspace for other households.

When a workspace is deleted, clear `active_workspace` for all users pointing at it before or during deletion so no user record keeps a stale workspace id.

## UI

The members page remains readable for everyone in the workspace. For owners and admins, each manageable row shows a role select and remove button. Rows the current actor cannot manage render as plain text.

The owner transfer control appears only to owners and lists active workspace members other than the current owner. It should be visually separate from normal role edits because transfer is higher impact.

The workspace settings page gets an owner-only danger zone. It uses typed-name confirmation and explicit destructive button styling.

Use existing Tailwind/Roastnode form and table styles. Keep controls compact and mobile-safe.

## Error Handling

- Unauthorized actions redirect to `root_path` with `authorization.denied`.
- Invalid role values are rejected.
- Cross-workspace membership ids are scoped out and redirect to `memberships_path` with `authorization.denied`.
- Last-owner violations redirect back with a specific alert.
- Deletion confirmation mismatch redirects or re-renders with a specific alert.
- Successful removal, role change, transfer, and deletion use notices.

## Tests

Add model or service tests for:

- Owner can change a non-owner role.
- Admin can change member/viewer roles only.
- Admin cannot manage owners or admins.
- Last owner cannot be demoted or removed.
- Ownership transfer promotes the target and demotes the previous owner to admin.
- Membership removal clears the removed user's active workspace when needed.
- Workspace deletion clears stale active workspace references and destroys dependent workspace records.

Add controller tests for:

- Owner role update, member removal, ownership transfer, and workspace deletion.
- Admin role update and member removal within limits.
- Member/viewer denied for all write actions.
- Cross-workspace membership id cannot be changed or removed.
- Controls render only for allowed actors.

## Documentation

Update:

- `docs/workspace-core.md` with member management, ownership transfer, deletion, and owner-count rules.
- `docs/workspace-settings.md` with the deletion danger zone.
- `docs/status.md` to mention workspace administration polish as built once implementation is complete.
- Ignored `docs/open-topics.md` to remove the completed v1 workspace administration item once implementation is complete.
