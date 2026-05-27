# Invite Signup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let valid invite recipients create an account and join the invited workspace without opening public registration.

**Architecture:** Reuse `WorkspaceInvite` as the invite-consumption boundary. Add an unauthenticated signup branch to `WorkspaceInvitesController` and the existing invite show view, with model-level email eligibility shared by signup and signed-in acceptance.

**Tech Stack:** Rails 8.1, Active Record, Rails authentication concern, Minitest integration/model tests, ERB, Tailwind CSS.

---

### Task 1: Centralize Invite Email Eligibility

**Files:**
- Modify: `app/models/workspace_invite.rb`
- Test: `test/models/workspace_invite_test.rb`

- [ ] Add tests proving an email-bound invite accepts only the matching normalized email and blank invites accept any user.
- [ ] Add `acceptable_for?(user)` and make `accept!(user)` raise unless the invite is acceptable for that user.
- [ ] Run `bin/rails test test/models/workspace_invite_test.rb`.

### Task 2: Add Invite Signup Route And Controller Action

**Files:**
- Modify: `config/routes.rb`
- Modify: `app/controllers/workspace_invites_controller.rb`
- Test: `test/controllers/workspace_invites_controller_test.rb`

- [ ] Add failing integration tests for unauthenticated invite signup success, email-bound mismatch, and mismatched signed-in acceptance.
- [ ] Allow unauthenticated access to `show` and `signup`.
- [ ] Add `post :signup` on invite member routes.
- [ ] Implement `WorkspaceInvitesController#signup` to create the user, accept the invite, set active workspace, start a session, and redirect to `root_path`.
- [ ] Run `bin/rails test test/controllers/workspace_invites_controller_test.rb`.

### Task 3: Render Signup UI On Invite Page

**Files:**
- Modify: `app/views/workspace_invites/show.html.erb`
- Modify: `config/locales/en.yml`
- Test: `test/controllers/workspace_invites_controller_test.rb`

- [ ] Show the existing accept button for signed-in users.
- [ ] Show an email/password signup form for unauthenticated users.
- [ ] Prefill email from email-bound invites and render the existing-account sign-in link.
- [ ] Add locale strings for the new signup labels and validation alerts.
- [ ] Run `bin/rails test test/controllers/workspace_invites_controller_test.rb`.

### Task 4: Update Durable Docs

**Files:**
- Modify: `docs/workspace-core.md`
- Modify: `docs/status.md`

- [ ] Replace the old "signed-in user required" invite note with the private invite-signup behavior.
- [ ] Move invite signup out of the open-items list in the status ledger.
- [ ] Run `env PARALLEL_WORKERS=1 bin/rails test`.
