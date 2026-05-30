# First User And Password Change Design

Date: 2026-05-30

## Goal

Close two authentication gaps for private self-hosted installs: an empty Roastnode instance needs a way to create its first account, and signed-in users need a normal way to change their password.

## Scope

Included:

- First-user setup route available only while the database has no users.
- First-user account creation with email, password, and password confirmation.
- Automatic session creation after the first account is saved.
- `instance_admin` assignment for the first account.
- Redirect from first-user setup into the existing post-login household workspace onboarding when no workspace exists.
- Links from the public home page and sign-in page to setup only while the instance has zero users.
- Authenticated password change linked from the account/profile surface.
- Current-password verification before changing a signed-in user's password.
- Session cleanup after password change so other sessions are invalidated while the current browser remains signed in.

Deferred:

- Public registration after bootstrap.
- Creating the first household workspace in the first-user form.
- Instance-admin user management, impersonation, account deletion, or admin-triggered password resets.
- Configurable registration modes.

## Approach

Add a small `FirstUserSetupsController` with unauthenticated `new` and `create` actions. The controller is guarded by `User.exists?`: if any account exists, the setup page and submission redirect to sign-in. The `create` action saves a new `User` with `instance_admin: true`, starts a Rails-native session, and redirects to `root_path`. The existing home/dashboard logic will then render `workspace_onboardings/new` because the first account has no workspace yet.

Add a separate signed-in password-change controller instead of extending password reset. Password reset remains token-based and unauthenticated; password change is authenticated, requires the current password, and uses `has_secure_password` validations for the new password and confirmation. On success, all of the user's existing sessions are destroyed, then a fresh session is started for the current request so the user stays signed in on the current browser.

## Security Notes

- First-user setup must not be available once any user row exists, even if there are no workspaces.
- The first account becomes an instance admin because private self-hosted installs need an initial operator for backup and health surfaces.
- First-user setup does not weaken invite-only signup. After bootstrap, new accounts still require workspace invites.
- Password change must verify the current password. A logged-in session alone is not enough to change credentials.
- Passwords, password digests, session IDs, reset tokens, invite tokens, signed media URLs, and infrastructure secrets must not be logged or rendered.

## User Flows

### Empty Instance

An unauthenticated visitor opens `/` or `/session` on a fresh install. The page shows a setup link. Opening setup displays email, password, and confirmation fields. Submitting valid credentials creates the first account, signs it in, grants `instance_admin`, and redirects to the existing household workspace onboarding page.

### Existing Instance

Once any user exists, `/setup/first_user` redirects to sign-in and hidden setup links disappear from public auth pages. Additional account creation remains invite-only.

### Password Change

A signed-in user opens Profile, follows the password-change link, enters the current password and a new password twice, and submits. If the current password is wrong or the confirmation does not match, the form re-renders with an error and the password digest is unchanged. On success, other sessions are invalidated and the current browser remains signed in.

## Tests

- Empty instance shows first-user setup links on public home and sign-in.
- First-user setup page renders only when `User.none?`.
- First-user setup creates exactly one account, sets `instance_admin`, starts a session, and redirects to the existing workspace onboarding path through `root_path`.
- First-user setup rejects invalid user input and does not create an account.
- First-user setup redirects once any user exists.
- Signed-in users can open the password-change form from Profile.
- Password change requires the current password.
- Password change rejects mismatched confirmation.
- Successful password change updates the digest, invalidates other sessions, keeps the current browser signed in, and allows login with the new password.

## Documentation

Update setup documentation to mention first-run account creation before household onboarding. Update instance-admin documentation to state that the first account is the initial instance admin.
