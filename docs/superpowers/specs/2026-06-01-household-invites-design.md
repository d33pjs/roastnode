# Household Invites Design

## Context

Roastnode is private by default. Public registration stays disabled after first-user setup, and new accounts currently join through workspace member invites. That works for adding someone to an existing household, but it does not let an instance admin invite a new person to create their own separate household.

This slice adds instance-admin household invites. A household invite is an instance-level bootstrap link for one email address. It creates a brand-new household owned by the recipient. It must never add the recipient to the inviter's active household.

## Goals

- Let instance admins invite a person by email to create their own new household.
- Keep household invites email-required and email-bound.
- Send the invite by email, with the invite URL still visible to instance admins for manual fallback.
- Let instance admins revoke active household invites, resend active email, and re-invite closed invites with a fresh token.
- Let recipients create an account from a valid invite, name their household, become owner of that household, and start a session.
- Let existing signed-in users with the invited email accept a valid household invite and create a new household they own.
- Keep public registration disabled; no account can be created without first-user setup or a valid invite.
- Keep invite tokens, passwords, sessions, signed media URLs, raw private media URLs, environment variables, and infrastructure secrets out of diagnostics and public pages.

## Non-Goals

- Adding a person to the instance admin's household.
- Letting instance admins pre-create or manage the invited person's household content.
- Blank "anyone with link" household invites.
- Owner/admin/member/viewer role selection for household invites; the recipient always becomes owner of the new household.
- General instance-wide user management, account deletion, impersonation, password reset by admin, or role changes.
- Public registration modes.
- Reusing accepted, revoked, or expired invite tokens.

## Recommended Approach

Add a separate `HouseholdInvite` model instead of overloading `WorkspaceInvite`. `WorkspaceInvite` remains workspace-scoped and means "join this existing workspace." `HouseholdInvite` is instance-scoped and means "create a new household."

`HouseholdInvite` should mirror the useful lifecycle pieces from workspace invites:

- required normalized `email_address`
- secure unique token
- `expires_at`
- `revoked_at`
- `accepted_at`
- `created_by_id` pointing at the instance admin
- optional `accepted_by_id`
- optional `workspace_id` for the household created when the invite is accepted

The instance admin page should add a household-invite section near the private registration status. It should include a required email form and a table of recent invites with email, status, invite URL, and actions. Active invites show `Resend` and `Revoke`; closed invites show `Re-invite`. Re-invite creates a fresh token for the same email and leaves the old invite as history.

Use a dedicated mailer, `HouseholdInvitesMailer`, so copy and routes are specific to new-household onboarding. Email delivery should use `deliver_later`, matching password reset and workspace invite mail.

## Recipient Flow

An unauthenticated recipient opens a valid household invite URL. The page shows that the invite is for their email address and presents an account-and-household form:

- account email, read-only and prefilled from the invite
- optional display name
- password and password confirmation
- household name

Submitting creates the user, creates a new `Workspace` with `kind: household` and default currency `EUR`, creates an owner membership for that user, records `accepted_by`, `accepted_at`, and `workspace` on the invite, sets the user's active workspace, starts a session, and redirects through `root_path`.

If the recipient already has an account, they sign in from the invite page. A signed-in user can accept the invite only when their normalized account email matches the invite email. Accepting creates a new household they own, sets it active, marks the invite accepted, and redirects through `root_path`.

Expired, revoked, accepted, missing, or mismatched-email invites render or redirect with the same unavailable/mismatch style as workspace invites. Closed links cannot create accounts or households.

## Data Flow

1. Instance admin submits a required email address on `/instance_admin`.
2. Controller creates a `HouseholdInvite` with `created_by: Current.user`.
3. Controller queues `HouseholdInvitesMailer.invite(invite).deliver_later`.
4. The invite email links to the public household invite route.
5. Recipient opens the route and either creates an account or signs in.
6. On acceptance, the app creates a new household and owner membership in one transaction.
7. The invite records the accepting user, accepted time, and created household.
8. Instance admin can see the closed invite but cannot reuse its token.

## Authorization

Household invite management is instance-admin-only through `authorize_instance_admin!`. Normal workspace owners and admins do not see or manage household invites unless they are also instance admins.

Public `show` and signup actions are unauthenticated, but only for valid household invite tokens. The signed-in accept action must compare normalized user email to the invite email before creating a household.

The created household is private to the recipient. The instance admin gains no membership in it unless the recipient later invites them through normal workspace invites.

## Error Handling

Email is required. Invalid email or persistence errors should keep the admin on `/instance_admin` with a visible alert and no invite email queued.

If mail enqueueing fails after the invite is created, the invite remains usable and the instance admin receives an alert that email could not be queued. Later SMTP delivery failures continue to surface through existing instance mail diagnostics without exposing job arguments or tokens.

Household creation and invite acceptance must be transactional. If user creation, workspace creation, membership creation, active-workspace update, or invite acceptance fails, no partial household should be left behind.

Re-invite must create a fresh invite and never mutate the accepted/revoked/expired token back into an active state.

## Testing

- Model tests for required normalized email, token/expiration defaults, acceptable state, email-bound acceptance, and closed-token rejection.
- Controller tests proving only instance admins can create, revoke, resend, and re-invite household invites.
- Controller tests proving invite creation enqueues `HouseholdInvitesMailer`.
- Controller tests proving active resend reuses the existing active invite and re-invite creates a fresh token for closed invites.
- Public invite tests for unavailable tokens, unauthenticated signup, email mismatch rejection, duplicate email rejection, and successful account plus household creation.
- Signed-in accept tests proving matching-email users can create a new household they own and mismatched users cannot.
- View tests proving instance admins see household invite management and normal users do not.
- Mailer tests proving the email includes the recipient email context and household invite URL.

## Documentation

Update `docs/instance-admin.md` to describe household invites as an instance-admin onboarding tool for creating separate households. Update `docs/workspace-core.md` to distinguish workspace member invites from household bootstrap invites. Update `docs/status.md` after implementation to list the shipped behavior.
