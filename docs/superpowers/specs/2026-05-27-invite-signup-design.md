# Invite Signup Design

## Goal

Allow a person with a valid workspace invite link to create a Roastnode account and join that workspace in one flow. Account creation remains private-by-default: there is no public registration page, and invite signup is only available from an acceptable invite token.

## Scope

- Add account creation to the existing workspace invite show page for unauthenticated visitors.
- Keep signed-in invite acceptance working from the same page.
- Treat an invite with `email_address` as email-bound: only a user with that normalized email address can accept it.
- Keep blank-email invites as "anyone with the link" invites.
- Start a session for a newly-created invite user, set their active workspace, and redirect through `root_path`.

## Design

`WorkspaceInvite` stays the domain boundary for consuming invites. It gains a small email eligibility check used by both existing signed-in acceptance and new invite signup. `WorkspaceInvitesController#show` becomes available without a session so invite recipients can see the join screen. For unauthenticated visitors it stores the invite URL as the post-login return path, so people with existing accounts can sign in and come back.

The signup action validates the invite token, builds a user from email/password fields, checks the invite email binding, creates the user, accepts the invite, sets the active workspace, and starts a session. If the invite is unavailable, the user is returned to the invite page with the existing unavailable message. If the email is not eligible or the user is invalid, the invite page is re-rendered with validation feedback.

## Security Notes

- No account can be created without a currently acceptable invite.
- Invite token revocation, expiration, and single-use rules remain enforced by `WorkspaceInvite#accept!`.
- Email-bound invites compare normalized email addresses.
- Invite tokens, passwords, and session identifiers are not exposed in docs or views beyond the existing invite URL field on the owner/admin invite-management screen.

## Tests

- Unauthenticated visitors can see a valid invite and submit the signup form.
- Invite signup creates the user, membership, accepted invite marker, active workspace, and session.
- Email-bound invites reject mismatched signup emails.
- Email-bound invites reject mismatched signed-in users.
- Blank-email invites continue to allow any signed-in or newly-created user.
