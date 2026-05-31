# Passkey Authentication Design

Date: 2026-05-31

## Goal

Add passkey support to Roastnode as an optional per-user authentication upgrade. Users can sign in with the browser's passkey account picker, can require passkey verification after password sign-in, and can keep password reset as the emergency recovery path.

## Scope

Included:

- Passkey registration for signed-in users from Profile.
- Browser-picker passkey sign-in without typing an email address first.
- Existing email/password sign-in remains available.
- Optional per-user passkey second factor after password sign-in.
- Password reset disables the passkey second-factor requirement as the recovery path, while preserving registered passkeys.
- User-owned passkey management: list, rename, delete, and last-used visibility.
- Current-password confirmation for adding a passkey, changing the second-factor setting, or deleting the last passkey.
- WebAuthn configuration for the instance origin and optional relying-party ID.
- Documentation for origin/RP ID stability in self-hosted production installs.

Deferred:

- Instance-wide mandatory passkey enforcement.
- Passwordless accounts without an emergency password-reset recovery path.
- Admin-assisted passkey recovery, impersonation, or account reset flows.
- Workspace-level passkey policy.
- Public registration changes.
- Native mobile app passkey integration.

## Approach

Use the `webauthn` Ruby gem for server-side WebAuthn ceremonies and cryptographic verification. Keep Rails' existing `User`, `Session`, and signed-cookie session model. Passkeys add another way to reach `start_new_session_for(user)`; they do not replace the session table.

Add a `PasskeyCredential` model owned by `User`. It stores the credential ID, public key, sign counter, user-facing nickname, and `last_used_at`. Add `User#webauthn_user_id` as a stable random WebAuthn user handle and `User#passkey_second_factor_enabled` as the opt-in second-factor flag.

Configure WebAuthn in `config/initializers/webauthn.rb` with:

- `rp_name`: `Roastnode`
- allowed origin from `ROASTNODE_WEBAUTHN_ORIGIN`
- optional RP ID from `ROASTNODE_WEBAUTHN_RP_ID`

Development can default to `http://localhost:3001`. Production should require an explicit origin, because WebAuthn credentials are bound to the origin/RP ID and hostname changes can strand existing passkeys.

Registration creates discoverable credentials so the browser can show an account picker during login. The creation options should request `residentKey: "required"` / `requireResidentKey: true` and require user verification. Registration requires a signed-in session and current password confirmation because it adds a credential that can later sign in.

## Controllers

### `PasskeyCredentialsController`

Authenticated Profile surface for managing the current user's passkeys.

- Profile edit renders the registered passkey list and account-security controls.
- `new_options`: generate and store a registration challenge.
- `create`: verify the returned WebAuthn credential and save it.
- `update`: rename a passkey.
- `destroy`: delete a passkey.
- `update_second_factor`: enable or disable the per-user second-factor flag.

Users can only manage their own passkeys. Enabling or disabling passkey second factor requires current password confirmation. Enabling passkey second factor requires at least one registered passkey. Deleting the last passkey automatically disables passkey second factor and requires current password confirmation.

### `PasskeySessionsController`

Unauthenticated passkey login surface.

- `new_options`: generate assertion options with empty `allowCredentials` for the browser account picker.
- `create`: verify the returned assertion, find the stored credential by credential ID, update `sign_count` and `last_used_at`, then call `start_new_session_for(user)`.

Unknown credential IDs, canceled ceremonies, and verification failures should all use generic failure messages that do not reveal whether an account exists.

### `PasskeySecondFactorsController`

Post-password second-factor surface.

- Password auth checks `User.authenticate_by` as today.
- If the user has `passkey_second_factor_enabled`, do not create a `Session` row yet.
- Store `session[:pending_passkey_user_id]`, the challenge, and a generated-at timestamp.
- Generate assertion options scoped to that user's credentials.
- Successful passkey verification consumes the pending state and creates the real session.

Pending second-factor state expires after 10 minutes and is cleared on failure, sign-out, or successful verification.

## User Flows

### Add First Passkey

A signed-in user opens Profile, chooses Add passkey, confirms their current password, and completes the browser passkey prompt. The app saves the credential, shows it in the passkey list, and leaves passkey second factor disabled until the user explicitly enables it.

### Sign In With Passkey

An unauthenticated user opens the sign-in page and chooses Sign in with passkey. The browser shows the account picker for discoverable Roastnode credentials. After local user verification, the server verifies the assertion and starts a normal Rails session.

### Password Sign-In Without Passkey 2FA

A user who has not enabled passkey second factor signs in with email and password exactly as today. Passkeys are optional and do not block the password flow.

### Password Sign-In With Passkey 2FA

A user who enabled passkey second factor submits correct email/password credentials. Instead of creating a real session, the app shows a passkey verification step. Successful verification starts the session. Failed or canceled verification returns to sign-in with a generic message.

### Lost Passkeys

A user who loses every passkey uses the existing password-reset email flow. After setting a new password, the app destroys existing sessions as today and clears `passkey_second_factor_enabled`. Stored passkey credentials remain listed so the user can delete stale entries after signing in with the new password.

## Security Notes

- Passkey registration must require current password confirmation.
- Changing the passkey second-factor setting must require current password confirmation.
- Deleting the last passkey must require current password confirmation because it also disables second factor.
- Passkey second factor is opt-in per user, not instance-wide.
- Password reset is the emergency recovery path and clears only the second-factor requirement.
- Credentials are user-owned, not workspace-owned.
- Do not log passkey credential IDs, public keys, challenges, session IDs, reset tokens, passwords, or raw WebAuthn payloads.
- Challenge values must be single-use and tied to the ceremony type.
- Registration, passkey-login, and second-factor challenges expire after 10 minutes.
- Browser-picker sign-in must use discoverable credentials. Post-password second factor can scope `allowCredentials` to the pending user's passkeys.
- Use user verification for passkey registration and authentication.
- Fail closed on WebAuthn verification errors, including sign-count verification errors in v1.
- Rate-limit passkey assertion endpoints similarly to password sign-in.
- Existing workspace authorization remains unchanged because passkeys only affect authentication.

## UI Notes

The sign-in page should show the passkey action near the existing password form without hiding password login. Profile should keep passkey controls in the account/security area, not on coffee/product surfaces. Email addresses remain acceptable here because this is account UI, matching `docs/account-privacy.md`.

## Tests

- `PasskeyCredential` belongs to a user and credential IDs are unique.
- Users cannot manage another user's passkeys.
- First passkey registration creates `webauthn_user_id` when needed.
- Registration requires a signed-in user and current password confirmation.
- Browser-picker passkey login creates a normal Rails session.
- Unknown credential ID does not reveal account existence.
- Password login still works for users without passkey second factor.
- Password login for a second-factor-enabled user does not create a `Session` until passkey verification succeeds.
- Passkey second-factor challenge is scoped to the pending user.
- Enabling passkey second factor requires at least one passkey.
- Deleting the last passkey requires current password confirmation and disables passkey second factor.
- Enabling or disabling passkey second factor requires current password confirmation.
- Password reset disables `passkey_second_factor_enabled`, destroys sessions, and keeps passkey credential rows.
- Workspace-scoped pages remain accessible only after a real session exists.

## Documentation

Update:

- `docs/status.md` once the slice ships.
- `docs/account-privacy.md` with Profile/account placement for passkey controls.
- `docs/setup.md` with local WebAuthn origin defaults.
- `docs/production-self-hosting.md` with `ROASTNODE_WEBAUTHN_ORIGIN`, optional `ROASTNODE_WEBAUTHN_RP_ID`, HTTPS expectations, and hostname/RP ID migration warnings.

## References

- `webauthn` Ruby gem: https://github.com/cedarcode/webauthn-ruby
- Discoverable credential browser-picker behavior: https://web.dev/articles/webauthn-discoverable-credentials
