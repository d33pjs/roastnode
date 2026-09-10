# Persona Statistics Implementation Plan

**Goal:** Add private, filtered statistics for makers, recipients, pairings, bean usage, and recorded cupping preferences.

**Architecture:** Reuse `WorkspaceStatistics`' filtered brew array. Aggregate in `WorkspacePersonaStatistics`, render an ERB partial, and enhance charts with a local Stimulus controller. No schema or public route changes.

**Tech Stack:** Rails, Minitest, ERB, Stimulus, Tailwind, locally vendored Chart.js.

## Global constraints

- Stay on main and protect unrelated edits.
- Every Brew counts once, including Quick Drip batches.
- Named guests group by trimmed case-insensitive name within this private workspace only.
- Numeric favorites use non-null Brew ratings and show sample counts.
- Date, logger, and recipient filters apply to all persona aggregates.
- Chart data contains aggregate values and safe labels only.

## Work

- [x] Add `test/services/workspace_persona_statistics_test.rb` covering identities, guests, bean ratings, filters, workspace isolation, historical users, and Quick Drip counts. Run `bin/rails test test/services/workspace_persona_statistics_test.rb` and confirm the missing `:personas` payload fails.
- [x] Create `app/services/workspace_persona_statistics.rb` with `initialize(brews:)` and `call`; integrate as `personas: WorkspacePersonaStatistics.new(brews:).call` in `WorkspaceStatistics#call`; eager-load `user` and `recipient_user`. Run the focused test and existing statistics service tests.
- [x] Implement `app/views/statistics/_personas.html.erb`, child partials as needed, `statistics_chart_controller.js`, helper methods and dedicated locale files. Add accessible maker/recipient rankings, stacked pairings, per-recipient beans and favorites, including explicit no-data states. Chart payload interface is documented in the implementation brief.
- [x] Extend controller tests for private persona sections, filter results, escaping, guest identities only in private statistics, and read-only access. Exercise Chart.js lifecycle and configuration with executable JavaScript tests if the existing tooling supports it.
- [x] Update `docs/statistics.md`, `docs/account-privacy.md`, and `docs/status.md` for the new private guest identity rule and rating semantics. Run full Rails tests, RuboCop, audit and Brakeman after the independent dependency update completes.
- [x] Inspect desktop/mobile and dark mode with actual chart rendering, commit scoped changes, and leave the LAN-accessible development server running in tmux.
