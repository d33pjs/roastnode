# Workspace Core

Workspace Core is the first real Roastnode product slice after Rails foundation and authentication. It establishes the private household boundary that later coffee features must use.

## Model

- `Workspace` owns shared coffee data. The first supported kind is `household`; `roaster`, `cafe`, and `community` are reserved for later.
- `Membership` connects a `User` to a `Workspace` with one role.
- `User#active_workspace` stores the current workspace for dashboard and scoped actions.
- `WorkspaceInvite` stores token links for adding signed-in users to a workspace.

## Roles

- `owner`: full workspace control.
- `admin`: can manage members and invites.
- `member`: can write normal workspace data.
- `viewer`: read-only access.

Use `WorkspacePolicy` for role checks. Controllers should prefer the helper methods exposed by `ApplicationController`: `current_workspace`, `current_membership`, and `current_workspace_policy`.

Workspace export is owner-only in the current slice. Admins can manage invites and shared coffee data, but they do not see the JSON export link unless that policy is intentionally changed later.

## Invite Flow

Owners and admins can open the workspace dashboard and use **Invites** to create links for the `admin`, `member`, or `viewer` roles. Invite links can be revoked and expire automatically.

Invite acceptance currently requires an already signed-in user. Public signup-from-invite is intentionally deferred so the first workspace flow stays private and Rails-native.

## Implementation Notes

- New domain tables should include `workspace_id` unless they are intentionally global.
- Query domain records through `current_workspace` in controllers to avoid cross-workspace leaks.
- Add authorization and isolation tests for every workspace-scoped controller.
- Exports should use `current_workspace` as their scope and avoid accepting workspace IDs from params.
- Keep copy and docs clear that v1 is private; public profiles, federation, and roaster-facing workflows are future work.
