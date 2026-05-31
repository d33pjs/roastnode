# Invite Email And Mail Diagnostics Design

## Context

Roastnode currently supports private workspace invites as copyable token links. Email delivery is already configured for password resets in production, but invites do not yet send mail. If SMTP is misconfigured, the instance admin page can show generic Solid Queue failures, but operators do not get a focused view of recent mail delivery errors.

This slice adds email-backed invite resend/re-invite behavior while keeping copyable invite links as the manual fallback.

## Goals

- Let workspace owners and admins send invite emails for email-bound workspace invites.
- Let owners and admins resend an active email-bound invite.
- Let owners and admins re-invite after an invite is closed by creating a fresh invite with the same email and role.
- Surface recent mail delivery failures on the instance admin page with redacted error text.
- Keep invite tokens, job arguments, passwords, SMTP secrets, sessions, and signed URLs out of rendered admin diagnostics.

## Non-Goals

- Public registration.
- Instance-wide user management.
- Owner-role invites.
- Reusing accepted, expired, or revoked invite tokens.
- Exposing raw job arguments or full logs in the browser.
- Building a general log viewer.

## Recommended Approach

Use Rails mailers and Solid Queue as the delivery path, matching password reset mail. `WorkspaceInvitesController#create` should keep creating an invite and, when the invite has an email address, enqueue the invite email. The invite index should show:

- `Resend` for active email-bound invites.
- `Re-invite` for closed email-bound invites.
- No send action for blank-email invites; their existing copyable URL remains the fallback.

`Resend` sends the existing active token again. `Re-invite` creates a new invite in the active workspace with the same email address and role, created by the current user, and sends that fresh token. The old closed invite remains historical.

The instance admin page should add a mail diagnostics block near operations. It should show whether SMTP appears enabled from runtime settings and list recent failed mail jobs from Solid Queue. The row should include mailer/job class, queue, failure time, and a redacted/truncated error summary only. It must not render serialized job arguments because those can include Global IDs, email addresses, tokens, or other sensitive data.

## Data Flow

1. Owner/admin creates an email-bound invite.
2. Controller persists the invite under `current_workspace`.
3. Controller enqueues `WorkspaceInvitesMailer.invite(invite).deliver_later`.
4. If SMTP delivery fails in production, Solid Queue records the failed mail job.
5. Instance admin diagnostics read only failed job metadata and redacted error text.
6. Owner/admin can resend active email-bound invites or create a fresh replacement for closed email-bound invites.

## Authorization

Invite send, resend, revoke, and re-invite actions use the existing workspace admin boundary through `authorize_workspace_admin!` and `current_workspace.workspace_invites.find_by!(token: params[:token])`.

Instance mail diagnostics use the existing `authorize_instance_admin!` boundary.

## Error Handling

Enqueue failures during invite create/resend/re-invite should redirect back to the invite page with a clear alert and keep the invite record when it already exists. SMTP delivery failures after enqueueing are handled by Solid Queue and surfaced on the instance admin page.

Closed invite re-invite should not mutate the old invite. It creates a fresh token so accepted/revoked/expired links stay unavailable.

## Testing

- Controller tests for create with email enqueueing invite mail.
- Controller tests for active resend enqueueing the existing invite mail.
- Controller tests for closed invite re-invite creating a fresh invite and enqueueing mail.
- Controller tests that blank-email invites do not show send actions.
- Authorization tests proving members cannot resend or re-invite.
- Mailer tests proving the email contains the workspace name and invite URL.
- Instance operations tests proving mail diagnostics filter mail failures and redact secrets/tokens.
- Instance admin controller/view tests proving mail diagnostics are rendered only to instance admins.

## Documentation

Update `docs/workspace-core.md` to mention optional email delivery for email-bound invites and the copyable-link fallback. Update `docs/instance-admin.md` to describe the mail diagnostics scope and redaction rules.
