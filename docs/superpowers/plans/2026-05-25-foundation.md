# Roastnode Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a Rails 8.1 Roastnode application at the repository root with docs, Git history, PostgreSQL, Tailwind, Hotwire, authentication, and local ports that coexist with the existing project.

**Architecture:** Generate a conventional Rails monolith and keep early customization limited to local development defaults, documentation, and a bootable home route. Use PostgreSQL as the only database adapter and preserve Rails defaults for Hotwire, assets, test structure, and Rails-native authentication.

**Tech Stack:** Ruby 3.3.7, Rails 8.1.3, PostgreSQL, Hotwire/Turbo/Stimulus, Tailwind CSS, Active Storage, Solid Queue, Docker Compose.

---

## File Structure

- Create/modify root Rails files through `rails new .`.
- Modify `.ruby-version` to pin Ruby 3.3.7.
- Modify `Gemfile` to pin Rails 8.1.3 and add project gems only if generators do not include them.
- Modify `config/database.yml` for local PostgreSQL defaults and environment overrides.
- Create or modify `compose.yaml` for local services using host port `5433`.
- Create `docs/setup.md` for local setup, Docker Compose setup, ports, and troubleshooting.
- Create `app/controllers/home_controller.rb`, `app/views/home/index.html.erb`, and route `root "home#index"` if the generated app does not include a useful root.
- Run `bin/rails generate authentication` if available.

## Task 1: Toolchain And Rails Scaffold

**Files:**
- Create/modify: Rails app files generated at repository root
- Modify: `.ruby-version`
- Modify: `Gemfile`

- [ ] **Step 1: Pin the local Ruby**

Run: `rbenv local 3.3.7`
Expected: `.ruby-version` contains `3.3.7`.

- [ ] **Step 2: Install Rails 8.1.3 into the local Ruby if missing**

Run: `gem install rails -v 8.1.3`
Expected: `1 gem installed` or Rails 8.1.3 already available.

- [ ] **Step 3: Generate the app into the current directory**

Run: `rails _8.1.3_ new . --database=postgresql --css=tailwind --skip-jbuilder --skip-git --force`
Expected: Rails files are generated in the repository root without creating a nested `roastnode/` directory.

- [ ] **Step 4: Install bundle**

Run: `bundle install`
Expected: dependencies resolve under Ruby 3.3.7.

- [ ] **Step 5: Commit scaffold**

Run:

```bash
git add .
git commit -m "Create Rails application scaffold"
```

Expected: commit succeeds with Rails app files.

## Task 2: Local Database And Compose Defaults

**Files:**
- Modify: `config/database.yml`
- Modify/create: `compose.yaml`
- Create/modify: `.env.example`
- Create: `docs/setup.md`

- [ ] **Step 1: Configure local database defaults**

Set development and test database defaults:

```yaml
username: <%= ENV.fetch("POSTGRES_USER", "roastnode") %>
password: <%= ENV.fetch("POSTGRES_PASSWORD", "roastnode") %>
host: <%= ENV.fetch("POSTGRES_HOST", "localhost") %>
port: <%= ENV.fetch("POSTGRES_PORT", 5433) %>
```

Expected: `bin/rails db:prepare` connects to host port `5433` when using local Compose.

- [ ] **Step 2: Configure Compose ports**

Compose should publish:

```yaml
ports:
  - "5433:5432"
```

Expected: Roastnode Postgres can run next to the existing project on host port `5432`.

- [ ] **Step 3: Document setup**

Add `docs/setup.md` with native and Docker Compose setup commands, port choices, and troubleshooting for Ruby, Bundler, Rails, and PostgreSQL.

- [ ] **Step 4: Commit local setup**

Run:

```bash
git add config/database.yml compose.yaml .env.example docs/setup.md
git commit -m "Configure local development services"
```

Expected: commit succeeds.

## Task 3: Authentication And Bootable Home

**Files:**
- Create/modify: authentication generator files
- Create: `app/controllers/home_controller.rb`
- Create: `app/views/home/index.html.erb`
- Modify: `config/routes.rb`

- [ ] **Step 1: Generate Rails-native authentication**

Run: `bin/rails generate authentication`
Expected: Rails creates user, session, password reset, and authentication support files.

- [ ] **Step 2: Add a minimal home route**

Create `HomeController#index`, create a simple i18n-ready home view, and set `root "home#index"`.

- [ ] **Step 3: Prepare database**

Run: `bin/rails db:prepare`
Expected: development and test databases are created and migrated.

- [ ] **Step 4: Run tests**

Run: `bin/rails test`
Expected: all generated tests pass.

- [ ] **Step 5: Commit authentication and home**

Run:

```bash
git add .
git commit -m "Add authentication foundation"
```

Expected: commit succeeds.

## Task 4: Verification And Final Docs

**Files:**
- Modify: `docs/setup.md`
- Modify: `docs/README.md`
- Modify: `AGENTS.md` if setup commands change

- [ ] **Step 1: Run final verification**

Run:

```bash
bin/rails test
bin/rails routes
```

Expected: tests pass and the root route points to `home#index`.

- [ ] **Step 2: Check Git state**

Run: `git status --short`
Expected: only intentional documentation updates remain.

- [ ] **Step 3: Commit verification docs**

Run:

```bash
git add docs AGENTS.md
git commit -m "Document Roastnode setup"
```

Expected: commit succeeds if docs changed.

