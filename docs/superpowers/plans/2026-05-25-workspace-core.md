# Workspace Core Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build Roastnode's workspace ownership boundary with memberships, roles, active workspace selection, dashboard, member list, and invite links.

**Architecture:** Add focused Active Record models for workspaces, memberships, and invites, plus small policy objects and conventional Rails controllers. The root page routes authenticated users into onboarding or the active workspace dashboard while unauthenticated users still see the public landing page.

**Tech Stack:** Rails 8.1, Active Record, Minitest, Hotwire-ready server-rendered ERB, Tailwind CSS.

---

## File Structure

- Create migrations for user profile fields, workspaces, memberships, and workspace invites.
- Create `app/models/workspace.rb`, `app/models/membership.rb`, and `app/models/workspace_invite.rb`.
- Modify `app/models/user.rb` and `app/models/current.rb` for active workspace helpers.
- Create `app/policies/workspace_policy.rb`.
- Create `app/controllers/workspace_onboardings_controller.rb`, `workspaces_controller.rb`, `memberships_controller.rb`, and `workspace_invites_controller.rb`.
- Modify `app/controllers/application_controller.rb` with current workspace helpers and a small access-denied redirect helper.
- Replace the authenticated portion of `app/views/home/index.html.erb` with a dashboard/onboarding branch.
- Create views under `app/views/workspace_onboardings`, `app/views/workspaces`, `app/views/memberships`, and `app/views/workspace_invites`.
- Add fixtures for workspaces, memberships, and invites.
- Add model and controller tests.

## Task 1: Workspace Data Model

**Files:**
- Create: `db/migrate/*_add_workspace_fields_to_users.rb`
- Create: `db/migrate/*_create_workspaces.rb`
- Create: `db/migrate/*_create_memberships.rb`
- Create: `db/migrate/*_create_workspace_invites.rb`
- Create: `app/models/workspace.rb`
- Create: `app/models/membership.rb`
- Create: `app/models/workspace_invite.rb`
- Modify: `app/models/user.rb`
- Modify: `app/models/current.rb`
- Test: `test/models/workspace_invite_test.rb`
- Test fixtures: `test/fixtures/workspaces.yml`, `test/fixtures/memberships.yml`, `test/fixtures/workspace_invites.yml`

- [ ] Write model tests for invite validity and role assignment.
- [ ] Run model tests and confirm they fail because models/tables are missing.
- [ ] Add migrations, associations, enums, validations, and helper methods.
- [ ] Run `bin/rails db:migrate` and `bin/rails test test/models/workspace_invite_test.rb`.
- [ ] Commit with `git commit -m "Add workspace core data model"`.

## Task 2: Policy And Active Workspace Helpers

**Files:**
- Create: `app/policies/workspace_policy.rb`
- Modify: `app/controllers/application_controller.rb`
- Modify: `app/models/user.rb`
- Test: `test/models/workspace_policy_test.rb`

- [ ] Write policy tests for owner/admin/member/viewer permissions.
- [ ] Run policy tests and confirm they fail because the policy is missing.
- [ ] Add `WorkspacePolicy` and controller helpers for `current_workspace`, `current_membership`, and `authorize_workspace_admin!`.
- [ ] Run `bin/rails test test/models/workspace_policy_test.rb`.
- [ ] Commit with `git commit -m "Add workspace authorization helpers"`.

## Task 3: Onboarding And Dashboard

**Files:**
- Create: `app/controllers/workspace_onboardings_controller.rb`
- Create: `app/views/workspace_onboardings/new.html.erb`
- Create: `app/views/workspaces/show.html.erb`
- Modify: `app/controllers/home_controller.rb`
- Modify: `app/views/home/index.html.erb`
- Modify: `config/routes.rb`
- Modify: `config/locales/en.yml`
- Test: `test/controllers/workspace_onboardings_controller_test.rb`
- Test: `test/controllers/home_controller_test.rb`

- [ ] Write controller tests for onboarding, owner assignment, active workspace, and dashboard rendering.
- [ ] Run tests and confirm failures.
- [ ] Implement onboarding create flow and dashboard branch.
- [ ] Run targeted controller tests.
- [ ] Commit with `git commit -m "Add workspace onboarding dashboard"`.

## Task 4: Workspace Switcher And Member List

**Files:**
- Create: `app/controllers/workspaces_controller.rb`
- Create: `app/controllers/memberships_controller.rb`
- Create: `app/views/memberships/index.html.erb`
- Modify: `app/views/workspaces/show.html.erb`
- Modify: `config/routes.rb`
- Modify: `config/locales/en.yml`
- Test: `test/controllers/workspaces_controller_test.rb`
- Test: `test/controllers/memberships_controller_test.rb`

- [ ] Write tests for switching active workspace, rejecting non-member switches, and member list isolation.
- [ ] Run tests and confirm failures.
- [ ] Implement switch action and member list through the active workspace.
- [ ] Run targeted controller tests.
- [ ] Commit with `git commit -m "Add workspace switching and members"`.

## Task 5: Workspace Invites

**Files:**
- Create: `app/controllers/workspace_invites_controller.rb`
- Create: `app/views/workspace_invites/index.html.erb`
- Create: `app/views/workspace_invites/show.html.erb`
- Modify: `app/views/workspaces/show.html.erb`
- Modify: `config/routes.rb`
- Modify: `config/locales/en.yml`
- Test: `test/controllers/workspace_invites_controller_test.rb`

- [ ] Write tests for owner/admin invite creation, member denial, revocation, invalid token display, and acceptance.
- [ ] Run tests and confirm failures.
- [ ] Implement invite index/create/revoke/show/accept actions.
- [ ] Run invite controller tests.
- [ ] Commit with `git commit -m "Add workspace invite links"`.

## Task 6: Documentation And Final Verification

**Files:**
- Modify: `AGENTS.md`
- Modify: `docs/setup.md`
- Modify: `docs/README.md` if helpful

- [ ] Document that future domain records must be workspace-scoped.
- [ ] Run `bin/rails test`.
- [ ] Run `env RUBOCOP_CACHE_ROOT=tmp/rubocop_cache bin/rubocop`.
- [ ] Browser-smoke onboarding/dashboard/invite if the server is running.
- [ ] Commit with `git commit -m "Document workspace core"`.

