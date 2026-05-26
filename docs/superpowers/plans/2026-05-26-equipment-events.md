# Equipment Events Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add first-class workspace equipment events and show them in the private workspace timeline and equipment detail pages.

**Architecture:** Add an `EquipmentEvent` model plus a join model for affected equipment. Follow existing workspace-scoped Rails controller/view patterns and keep all event creation behind `current_workspace_policy.write?`.

**Tech Stack:** Rails 8.1, Active Record, PostgreSQL, ERB views, Tailwind utility classes, Minitest.

---

## Files

- Create `db/migrate/20260526080000_create_equipment_events.rb`
- Create `db/migrate/20260526080100_create_equipment_event_equipment.rb`
- Create `app/models/equipment_event.rb`
- Create `app/models/equipment_event_equipment.rb`
- Modify `app/models/workspace.rb`
- Modify `app/models/user.rb`
- Modify `app/models/equipment.rb`
- Modify `config/routes.rb`
- Create `app/controllers/equipment_events_controller.rb`
- Modify `app/controllers/equipment_controller.rb`
- Modify `app/controllers/home_controller.rb`
- Create `app/views/equipment/show.html.erb`
- Create `app/views/equipment_events/new.html.erb`
- Create `app/views/equipment_events/show.html.erb`
- Modify `app/views/equipment/index.html.erb`
- Modify `app/views/workspaces/show.html.erb`
- Modify `config/locales/en.yml`
- Create `test/models/equipment_event_test.rb`
- Create `test/controllers/equipment_events_controller_test.rb`
- Modify `test/controllers/equipment_controller_test.rb`
- Modify `test/controllers/home_controller_test.rb`
- Create `test/fixtures/equipment_events.yml`
- Create `test/fixtures/equipment_event_equipment.yml`
- Add `docs/equipment-events.md`
- Update `docs/README.md`
- Update `AGENTS.md`

## Tasks

### Task 1: Data Model

- [ ] Write failing model tests for valid events, workspace consistency, and event/equipment joins.
- [ ] Add migrations for `equipment_events` and `equipment_event_equipment`.
- [ ] Add model associations, enum values, validations, and helper scopes.
- [ ] Add fixtures for a grinder cleaning event and a machine backflush event.
- [ ] Run `env PARALLEL_WORKERS=1 bin/rails test test/models/equipment_event_test.rb`.
- [ ] Commit with `git commit -m "Add equipment event data model"`.

### Task 2: Event Logging UI

- [ ] Write failing controller tests for new/create/show, member create access, viewer denial, and cross-workspace equipment rejection.
- [ ] Add `resources :equipment_events, only: %i[new create show]`.
- [ ] Build `EquipmentEventsController` using `current_workspace`.
- [ ] Build the new event form with event type, occurred at, affected equipment checkboxes, and notes.
- [ ] Build the event show page.
- [ ] Run `env PARALLEL_WORKERS=1 bin/rails test test/controllers/equipment_events_controller_test.rb`.
- [ ] Commit with `git commit -m "Add equipment event logging"`.

### Task 3: Equipment Detail Pages

- [ ] Write failing controller tests for equipment show isolation and event visibility.
- [ ] Add `show` to equipment routes and controller.
- [ ] Link equipment names from the equipment index to the detail page.
- [ ] Build the equipment detail view with recent brews, recent events, and simple usage counts.
- [ ] Run `env PARALLEL_WORKERS=1 bin/rails test test/controllers/equipment_controller_test.rb`.
- [ ] Commit with `git commit -m "Add equipment detail pages"`.

### Task 4: Timeline Integration

- [ ] Write failing home controller tests proving equipment events appear and brew inventory adjustments stay hidden.
- [ ] Load recent equipment events in `HomeController#load_dashboard`.
- [ ] Render equipment events in dashboard recent activity.
- [ ] Add dashboard action link for adding an equipment event.
- [ ] Run `env PARALLEL_WORKERS=1 bin/rails test test/controllers/home_controller_test.rb`.
- [ ] Commit with `git commit -m "Show equipment events in timeline"`.

### Task 5: Documentation And Verification

- [ ] Add `docs/equipment-events.md`.
- [ ] Update `docs/README.md` and `AGENTS.md`.
- [ ] Run `env PARALLEL_WORKERS=1 bin/rails test`.
- [ ] Run `env RUBOCOP_CACHE_ROOT=tmp/rubocop_cache bin/rubocop`.
- [ ] Run `bundle exec brakeman --quiet --no-pager --exit-on-warn --exit-on-error`.
- [ ] Smoke the running app on `http://miniknubbel.internal:3001`.
- [ ] Commit docs and any final fixes with `git commit -m "Document equipment events"`.
