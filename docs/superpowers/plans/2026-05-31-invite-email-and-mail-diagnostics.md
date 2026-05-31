# Invite Email And Mail Diagnostics Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add email-backed workspace invite send/resend/re-invite actions and focused mail delivery diagnostics on the instance admin page.

**Architecture:** Use a dedicated `WorkspaceInvitesMailer` for invite email content and keep `WorkspaceInvite` as the invite token boundary. Extend `WorkspaceInvitesController` with admin-only send actions and extend `InstanceOperationsSnapshot` with SMTP status plus filtered Solid Queue mail failure rows. Keep diagnostics read-only and redacted.

**Tech Stack:** Rails 8.1, Action Mailer, Active Job/Solid Queue, Hotwire server-rendered ERB, Minitest.

---

## File Structure

- Create `app/mailers/workspace_invites_mailer.rb` for invite email delivery.
- Create `app/views/workspace_invites_mailer/invite.html.erb` and `app/views/workspace_invites_mailer/invite.text.erb` for mail bodies.
- Create `test/mailers/workspace_invites_mailer_test.rb` for mail rendering coverage.
- Modify `config/routes.rb` to add member `resend` and `reinvite` invite routes.
- Modify `app/controllers/workspace_invites_controller.rb` to enqueue mail on create/resend/re-invite.
- Modify `app/views/workspace_invites/index.html.erb` to show resend/re-invite actions only for email-bound invites.
- Modify `app/services/instance_operations_snapshot.rb` to expose SMTP status and recent mail failures.
- Modify `app/views/instance_admin/index.html.erb` to render mail diagnostics.
- Modify `config/locales/en.yml` for new UI and mail copy.
- Modify `test/controllers/workspace_invites_controller_test.rb`, `test/services/instance_operations_snapshot_test.rb`, and `test/controllers/instance_admin_controller_test.rb`.
- Modify `docs/workspace-core.md`, `docs/instance-admin.md`, and `docs/status.md`.

## Task 1: Invite Mailer

**Files:**
- Create: `app/mailers/workspace_invites_mailer.rb`
- Create: `app/views/workspace_invites_mailer/invite.html.erb`
- Create: `app/views/workspace_invites_mailer/invite.text.erb`
- Create: `test/mailers/workspace_invites_mailer_test.rb`
- Modify: `config/locales/en.yml`

- [ ] **Step 1: Write the failing mailer test**

Add `test/mailers/workspace_invites_mailer_test.rb`:

```ruby
require "test_helper"

class WorkspaceInvitesMailerTest < ActionMailer::TestCase
  test "invite email includes workspace name and invite link" do
    invite = workspace_invites(:member_invite)
    invite.update!(email_address: "friend@example.com")

    mail = WorkspaceInvitesMailer.invite(invite)

    assert_equal [ "friend@example.com" ], mail.to
    assert_equal "Join #{invite.workspace.name} on Roastnode", mail.subject
    assert_includes mail.text_part.body.to_s, invite.workspace.name
    assert_includes mail.text_part.body.to_s, workspace_invite_url(invite.token)
    assert_includes mail.html_part.body.to_s, workspace_invite_url(invite.token)
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/mailers/workspace_invites_mailer_test.rb`

Expected: fail with missing `WorkspaceInvitesMailer`.

- [ ] **Step 3: Implement the mailer and templates**

Implement `WorkspaceInvitesMailer#invite(workspace_invite)`, assign `@workspace_invite`, and send to `workspace_invite.email_address` with subject `Join <workspace> on Roastnode`. Templates include the workspace name, role, and `workspace_invite_url(@workspace_invite.token)`.

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/mailers/workspace_invites_mailer_test.rb`

Expected: pass.

## Task 2: Invite Send, Resend, And Re-Invite

**Files:**
- Modify: `config/routes.rb`
- Modify: `app/controllers/workspace_invites_controller.rb`
- Modify: `app/views/workspace_invites/index.html.erb`
- Modify: `config/locales/en.yml`
- Modify: `test/controllers/workspace_invites_controller_test.rb`

- [ ] **Step 1: Write failing controller tests**

Add tests proving:

```ruby
assert_enqueued_email_with WorkspaceInvitesMailer, :invite do
  post workspace_invites_path, params: { workspace_invite: { email_address: "Friend@Example.com", role: "member" } }
end
```

Add tests for:

- Active email-bound invite renders a resend form and POST `resend_workspace_invite_path(invite.token)` enqueues mail without creating a new invite.
- Closed email-bound invite renders a re-invite form and POST `reinvite_workspace_invite_path(invite.token)` creates one fresh invite and enqueues mail for that fresh invite.
- Blank-email invite renders no resend/re-invite form.
- Workspace member POSTing resend/re-invite is redirected and does not enqueue mail or create invites.

- [ ] **Step 2: Run test to verify failures**

Run: `bin/rails test test/controllers/workspace_invites_controller_test.rb`

Expected: fail with missing routes/actions/UI.

- [ ] **Step 3: Implement routes, controller actions, and view actions**

Add `post :resend` and `post :reinvite` member routes. Authorize both with `authorize_workspace_admin!`. Use `current_workspace.workspace_invites.find_by!(token: params[:token])`.

Create helper methods:

```ruby
def deliver_invite_later(workspace_invite)
  return true if workspace_invite.email_address.blank?

  WorkspaceInvitesMailer.invite(workspace_invite).deliver_later
  true
rescue StandardError => error
  Rails.logger.warn("Workspace invite mail enqueue failed: #{error.class}: #{error.message}")
  false
end
```

`resend` sends only acceptable email-bound invites. `reinvite` creates a new invite only for closed email-bound invites with the same email and role. The index view shows the correct button per invite state.

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/controllers/workspace_invites_controller_test.rb`

Expected: pass.

## Task 3: Instance Mail Diagnostics

**Files:**
- Modify: `app/services/instance_operations_snapshot.rb`
- Modify: `app/views/instance_admin/index.html.erb`
- Modify: `config/locales/en.yml`
- Modify: `test/services/instance_operations_snapshot_test.rb`
- Modify: `test/controllers/instance_admin_controller_test.rb`

- [ ] **Step 1: Write failing diagnostics tests**

In `test/services/instance_operations_snapshot_test.rb`, extend the fake queue reader with mail failures and assert:

- SMTP status is `:ok` when runtime settings expose SMTP settings.
- SMTP status is `:attention` when SMTP is disabled.
- `mail_failures` includes only mailer-related failed jobs.
- error text redacts `password=`, `token=`, `secret=`, and truncates.

In `test/controllers/instance_admin_controller_test.rb`, assert the admin page includes the mail diagnostics section and redacted failure text.

- [ ] **Step 2: Run test to verify failures**

Run: `bin/rails test test/services/instance_operations_snapshot_test.rb test/controllers/instance_admin_controller_test.rb`

Expected: fail with missing methods/view.

- [ ] **Step 3: Implement diagnostics**

Add `MailFailureRow = Data.define(:id, :class_name, :queue_name, :failed_at, :error_message)`. Add `mail_status` using `runtime_settings.smtp_settings`. Add `mail_failures(limit: 5)` that filters recent queue failures to class names or errors containing `Mailer`, `ActionMailer`, `MailDeliveryJob`, or `ActionMailer::MailDeliveryJob`, maps only safe metadata, and uses existing redaction.

Render a mail card and a small failure table in the operations section.

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/services/instance_operations_snapshot_test.rb test/controllers/instance_admin_controller_test.rb`

Expected: pass.

## Task 4: Docs And Verification

**Files:**
- Modify: `docs/workspace-core.md`
- Modify: `docs/instance-admin.md`
- Modify: `docs/status.md`

- [ ] **Step 1: Update docs**

Document optional invite email delivery, resend/re-invite behavior, copyable-link fallback, SMTP status diagnostics, and redaction boundaries.

- [ ] **Step 2: Run targeted tests**

Run: `bin/rails test test/mailers/workspace_invites_mailer_test.rb test/controllers/workspace_invites_controller_test.rb test/services/instance_operations_snapshot_test.rb test/controllers/instance_admin_controller_test.rb`

Expected: pass.

- [ ] **Step 3: Run full test suite**

Run: `env PARALLEL_WORKERS=1 bin/rails test`

Expected: pass.

- [ ] **Step 4: Start local development server**

Run: `bin/rails server -p 3001 -b 0.0.0.0`

Expected: server starts and remains available for browser checking.
