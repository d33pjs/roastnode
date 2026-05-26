# Roastnode Agent Guide

Roastnode is a private, self-hostable coffee tracking app for shared household workspaces. Treat the workspace as the ownership and authorization boundary.

## Current Direction

- Build a Rails monolith with Hotwire, Turbo, Stimulus, Tailwind CSS, PostgreSQL, Active Storage, and Solid Queue.
- Keep v1 private by default. Public and federation features are future work and must not leak household data.
- Prefer Rails-native, boring security patterns over custom cleverness.
- Store measurements in canonical metric units: grams, seconds, Celsius.
- Treat `Workspace` as the ownership boundary for domain data. Beans, equipment, brews, inventory, photos, and statistics should belong to a workspace unless a future ADR explicitly says otherwise.
- Keep documentation in `docs/` current as decisions land.

## Working Rules

- Do not create a nested `roastnode/` app directory. The Rails app lives at the repository root.
- Commit often with small, descriptive commits.
- Protect user changes. Do not revert unrelated local edits.
- Scope early implementation to foundation, authentication, workspaces, memberships, and private household flows.
- Use `current_workspace`, `current_membership`, and `current_workspace_policy` from `ApplicationController` instead of ad hoc workspace lookups in controllers.
- Add tests for authorization and workspace isolation whenever adding workspace-scoped behavior.
- Owners and admins can manage workspace settings and invite links. Members can write normal workspace data. Viewers are read-only.
- Do not build public account creation from invite links yet; current invite acceptance assumes the user is already signed in.
- Espresso brew logging requires an open bean. Default to the current user's last active brewed bean, then the first open bean. Redirect to bean creation when no open bean exists. Copy only curated setup fields from the user's last brew: bean, grinder, machine, bean weight, dose, beverage yield, grind setting, brew temperature, and pre-infusion. Keep ground-out weight, total time, first drip, rating, notes, channeling, and taste fresh.
- Preparation tools are method-scoped checklist records, not equipment. Brews snapshot selected preparation tool names and preselect active tools from the user's last brew.
- Recipes are deliberately deferred. Do not introduce recipe tables, recipe snapshots, or recipe-based defaults in Coffee Core work.
- Equipment events are first-class workspace records. Use them for grinder and machine maintenance history instead of burying maintenance in equipment notes. A single equipment event can have multiple `event_types`.
- Dashboard recent activity should include brews, equipment events, and manual inventory adjustments. Do not show automatic brew inventory adjustments as separate timeline entries.

## Local Development Intent

- Web server: prefer host port `3001`.
- PostgreSQL: prefer host port `5433` because another local project already owns `5432`.
- Docker Compose should run alongside other local projects without taking common host ports unnecessarily.
- The current Compose image is `postgres:17.5`, chosen because it is already available locally and avoids blocking setup on a Docker image pull.
