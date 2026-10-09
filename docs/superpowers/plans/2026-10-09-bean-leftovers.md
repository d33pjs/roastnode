# Bean Leftovers Implementation Plan

**Goal:** Weigh remaining inventory, carry leftovers into a matching bag, and inspect private waste rankings.

**Architecture:** Extend the inventory ledger with target weighing and paired transfer rows. Use a small transactional transfer service and the existing Beans finish endpoint. Add aggregation to WorkspaceStatistics and a server-rendered ranking partial.

**Tech Stack:** Rails 8.1, PostgreSQL, ERB, existing Hotwire/Tailwind.

## Constraints

Work on main; preserve workspace isolation, writer policy, private data, original bag sizes/costs, and existing export/backup compatibility. User explicitly requests no further questions and authorizes release/deployment.

## Tasks

- [x] Add failing tests to inventory model/controller for locked localized target weighing, no-op, invalid and zero targets, current-value copy, and workspace/viewer restrictions. Extend InventoryAdjustment and its form/controller, then run `bin/rails test test/models/inventory_adjustment_test.rb test/controllers/inventory_adjustments_controller_test.rb`.
- [x] Add transfer service/controller tests for matching destinations, stock opening, duplication, finished source leftovers, total conservation, retries, rollbacks, privacy and isolation. Add GET finish page and transactional paired ledger entries, refresh affected shares and emit existing safe activity events. Adjust finished usage for net transfers. Run focused bean/transfer tests.
- [x] Add statistics service/controller tests for leftovers, trashed grounds, channeling, unknowns and combined filters. Render three private per-bag rankings with units/sample counts and clear filter scope. Run focused statistics tests.
- [x] Update inventory/statistics/status documentation; verify transfer export/backup round trips. Run full Rails/JavaScript suites, RuboCop and security checks. Request independent code review and address material findings.
- [ ] Commit and push main; verify Gitea CI and GitHub mirror. Publish v0.9.30 with the requested feature changelog, verify release image artifacts, pull the Ansible repository on Santiago, deploy only Roastnode using the immutable digest, and check application health/version. Start local `roastnode-dev` tmux server.
