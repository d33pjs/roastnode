# Grinder Guidance Implementation Plan

**Goal:** Compact Hero tools and make grinder guidance respond to the form while reflecting the household's shared grinder.

**Architecture:** Extend the current workspace-scoped PostgreSQL summaries and Stimulus controller. Keep physical-check state independent of input/reference matching. Use existing detail sections for tool overflow.

**Tech stack:** Rails, PostgreSQL, Stimulus, Tailwind; no new dependencies.

## Constraints

Stay on main, protect unrelated changes, use active-workspace scopes, preserve exact settings and draft/repeat values, and keep public data curated.

## Tasks

- [x] Add failing JS regressions: saved values match but input differs; input becomes green after copy/manual entry while physical reminder remains; long text hides the overlay.
- [x] Add failing service regressions for recent and average-rated rankings with sample counts, preserving bounded queries and workspace/method isolation.
- [x] Add failing controller regression for another household member's latest grinder setting as default.
- [x] Run `node --test test/javascript/brew_grinder_reminder_controller_test.mjs` and focused Rails tests; confirm expected failures.
- [x] Extend `BrewGrinderReminder::History` with recent/best arrays; augment SQL window aggregates/ranks to return the union of three bounded modes.
- [x] Serialize localized rating/date metadata in `BrewsHelper`; add a compact selector to `_grinder_history` and update English/German translations.
- [x] Separate form-match and physical-check state in the existing Stimulus controller; measure the input text against available width and update on resize.
- [x] Use existing shared last-use references in normal log defaults, leaving repeat/edit unchanged.
- [x] Limit tool chips to two and link overflow to full lists for private and public Heroes.
- [x] Update system regressions for green matching panels plus independent physical reminder; verify desktop/mobile, long strings, restore/discard, and both themes.
- [x] Run focused Rails/JS/system tests and RuboCop; review scope and privacy, update product docs/status, commit, and run `bin/dev` in `roastnode-dev` with LAN binding.

## Verification

Focused Rails checks passed 201 tests / 2281 assertions; JavaScript checks passed 22 tests; RuboCop inspected 406 files with no offenses. Browser checks passed 8 tests / 124 assertions and exercise live color/copy state, long-text overlay hiding, sorting, drafts, Back/Forward refresh, and twelve-tool private/public Heroes at 375px. Native anchors preserve the overflow destination. The development server runs in `roastnode-dev` on all interfaces, and `http://miniknubbel.local:3001/` returns HTTP 200.

## Follow-up: live household history

- [x] Reproduce another household member recording `1/3,0` while an existing form still holds `1/1,00`.
- [x] Add writer-only `/brews/grinder_history` JSON using active-workspace bags and the existing history service; return private/no-store data.
- [x] Refresh on connect/focus/visibility return and every 15 seconds while visible; preserve all form fields and drafts.
- [x] Abort superseded/disconnected requests; ignore late responses; show a red manual-check state for failures and five-second timeouts.
- [x] Cover cross-workspace authorization, exact two-phone values, race protection, timeout, disconnect, and hidden-page polling.
- [x] Run full Rails tests (1487 runs / 15012 assertions), JavaScript tests (29), browser tests (9 runs / 136 assertions), RuboCop (406 files), Brakeman, and both dependency audits.
