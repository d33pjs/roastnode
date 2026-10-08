# Grinder guidance and compact Hero tools

The Brew Log needs two independent signals. Compare the entered setting with the selected coffee's latest reference live: mismatches are red, matches green. Compare the shared grinder's last household use across methods with both the coffee reference and entered value to retain a physical-check reminder even after copying. Unknown history requires a manual check. No grinder and pre-ground beans suppress both signals. Preserve trimming/case normalization without guessing numerical equivalence.

New normal logs use the selected grinder's latest household setting, including a blank unknown value. Keep operator-specific bean/equipment defaults, restored drafts, recipe targets, and Repeat Good Brew behavior. Existing edits remain unchanged.

Put a red Double-check grinder reminder inside the input's unused right-hand space. Hide the overlay when text would collide, but retain the red outline and accessible description. Recalculate on input and resizing. Copying does not confirm physical adjustment.

Keep the selected coffee's latest reference visible. Below it, offer Recent, Best rated, and Most used in one compact selector with at most three settings. Default to Recent. Rank recent settings by latest occurrence, creation time, then ID. Rank best settings by average saved Brew rating, rated sample count, then recency; exclude unrated settings from that mode. Show average rating with sample count and last-use date. Compute these bounded summaries in PostgreSQL using existing workspace/history/grinder/method scopes.

Keep grinder/machine/brewer chips and show only the first two preparation tools in private Espresso and Quick Drip Heroes and the curated public Brew Hero. Truncate long chip labels. A + N more link reaches the complete tools list on the private detail or public product section. Saved tool snapshots and public privacy boundaries are unchanged.

Verify live typing/copying, cross-member defaults, draft restore/discard, unknown/hidden/pre-ground states, long input collision, ranking/sample counts/isolation, and mobile Hero bounds. No schema changes or new dependencies.

## Already-open phones

Household changes must also reach forms that remain open on another phone. Refresh the existing server-derived history at connect, app/window focus, visibility return, and every 15 seconds while visible. Add an authenticated writer-only JSON collection route scoped exclusively through current_workspace. Preserve every entered form value and selected control. Use private/no-store responses and no-store fetches. On failure or a five-second timeout, show an unavailable household-history warning instead of green reassurance; recover on a successful refresh. Cancel disconnected and superseded requests, and ignore their late responses. Test the precise wife `1/3,0` versus existing phone input `1/1,00` scenario with another User's recorded brew while the page remains open.
