# Bean weighing, leftovers, and waste statistics

The user authorized implementation, release, and deployment without further approval pauses.

Inventory adjustment retains signed deltas and adds an explicit Set remaining mode. Both modes show current inventory. Targets accept localized decimals including zero, reject negative/malformed values, and compute the stored delta against locked current inventory. An unchanged target succeeds without a fake ledger entry.

Finish bag opens a confirmation page showing remaining grams and matching active bags (same coffee history or normalized coffee/roaster identity, with the same grind state). The user can finish normally, move all leftovers to a matching open/stock bag, or duplicate a new bag and move leftovers there. Finished bags with leftovers also offer this transfer flow. Stock destinations open explicitly as part of the selected transfer. Repeated submissions never transfer twice. Locks, lifecycle validation, ledger entries, public snapshot refresh, and activity events share a transaction. Existing no-parameter finish requests remain supported.

Transfers store paired signed InventoryAdjustment rows with reason transfer, keeping total inventory unchanged. Original bag size and purchase price stay unchanged. Finished usage excludes net transferred grams. Existing export/backup formats preserve the new reason without a schema migration.

Private Statistics adds per-bag rankings for leftover grams in finished/archived bags (all-time current inventory), trashed grounds (positive measured ground weight minus dose), and channeling count with a known-result rate and sample count. Brew rankings respect dates and people filters; leftovers explicitly ignore them. Zero/unknown results have empty states; transferred leftovers are excluded. No new public fields.

Rejected alternatives: an automatic prompt when opening every bag interrupts unrelated work; inferring discarded coffee from generic negative corrections fabricates waste. A separate blending/product system is outside this small same-coffee transfer workflow.

Verify localized targets, zero/no-op/invalid cases, atomic and repeated transfers, stock and duplicate destinations, source/destination eligibility, viewer denial, workspace isolation, accurate filtered rankings, exports/backups, and mobile UI. Run Rails, JavaScript, lint/security checks before release v0.9.30, verify Gitea/GitHub sync and release assets, then run only the Roastnode playbook from Santiago and verify the deployed image/health.
