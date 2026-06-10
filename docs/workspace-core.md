# Workspace Core

Workspace Core is the first real Roastnode product slice after Rails foundation and authentication. It establishes the private household boundary that later coffee features must use.

## Model

- `Workspace` owns shared coffee data. The first supported kind is `household`; `roaster`, `cafe`, and `community` are reserved for later.
- `Membership` connects a `User` to a `Workspace` with one role.
- `User#active_workspace` stores the current workspace for dashboard and scoped actions.
- `User#default_landing_screen` stores whether `/` should open the dashboard or the espresso form.
- `WorkspaceInvite` stores token links for adding signed-in or newly-created users to a workspace. Controllers look up invite URLs by `token_digest`, not raw token values.
- Workspace settings currently include the household/workspace name and default currency.

## Roles

- `owner`: full workspace control.
- `admin`: can manage members and invites.
- `member`: can write normal workspace data such as beans, brews, inventory corrections, and maintenance logs, but cannot manage household settings, invites, exports, imports, or gear records.
- `viewer`: read-only access.

Use `WorkspacePolicy` for role checks. Controllers should prefer the helper methods exposed by `ApplicationController`: `current_workspace`, `current_membership`, and `current_workspace_policy`.

Workspace export is owner-only in the current slice. Admins can manage invites and shared coffee data, but they do not see the JSON export link unless that policy is intentionally changed later.

## Invite Flow

Owners and admins can open the workspace dashboard and use **Invites** to create links for the `admin`, `member`, or `viewer` roles. Invite links can be revoked and expire automatically.

Signed-in users can accept an invite directly. People without an account can create one from a valid invite page, optionally set a username/display label while choosing their password, join the invited workspace in the same flow, and start a session. This is still private invite-only signup, not public registration.

Invites with `email_address` are email-bound: only a user account with that normalized email address can accept them. Blank-email invites remain "anyone with the link" invites.

Email-bound invites queue an invite email when created. Owners and admins can resend an active email-bound invite or re-invite from a closed email-bound invite, which creates a fresh token with the same email and role. Blank-email invites keep the copyable-link fallback and do not offer send actions.

Instance-admin household invites are separate from workspace member invites. They create a brand-new household for the recipient and never join the recipient to the inviting admin's active workspace.

Workspace member invites and instance-admin household invites are bearer URLs. Request logs redact `/workspace_invites/:token...` and `/household_invites/:token...`, and SQL lookups use SHA-256 token digests so raw invite tokens are not used as query predicates.

Workspace member invite management and instance-admin household invite management show when an invite has been accepted, including the accepting account when still available and the acceptance timestamp.

## Member Management

Owners can manage admins, members, and viewers from the active workspace members page. Admins can manage members and viewers only. Members and viewers can read the member list but cannot change roles or remove members.

Ownership transfer is owner-only. The selected member becomes owner and the previous owner becomes admin. Normal member-management actions must preserve at least one owner.

Removing a member clears that user's active workspace if it pointed at the removed workspace.

## Settings

Owners and admins can edit the active workspace through `/workspace/edit`. Owners also see the workspace deletion danger zone there. The settings route is singleton and scoped through `current_workspace`; do not add a workspace ID to that flow unless multi-workspace admin requirements change.

## Implementation Notes

- New domain tables should include `workspace_id` unless they are intentionally global.
- Query domain records through `current_workspace` in controllers to avoid cross-workspace leaks.
- `root_path` is the user's preferred landing screen. Use `dashboard_path` for explicit "Back to dashboard" links.
- Add authorization and isolation tests for every workspace-scoped controller.
- Workspace settings should continue to use `authorize_workspace_admin!`.
- Workspace deletion should remain owner-only and must clear stale `active_workspace_id` values before destroying the workspace.
- Exports should use `current_workspace` as their scope and avoid accepting workspace IDs from params.
- Keep copy and docs clear that v1 is private; public profiles, federation, and roaster-facing workflows are future work.
