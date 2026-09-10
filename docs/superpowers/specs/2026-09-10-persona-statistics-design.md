# Persona statistics

Extend the private statistics page with coffee-making and receiving patterns. Reuse the existing date, logger, and recipient scope and locally bundled Chart.js. A separate personas CRUD system and a new chart dependency are unnecessary; the existing users and saved recipient names provide the requested identities.

## Counting and identity

Each Brew counts once, including Quick Drip batches; this is a count of logged preparations, not physical cups. The logger is the maker. A self brew belongs to its logger as recipient; an explicitly served household brew belongs to its recipient User. User identities remain distinct by ID internally, including historical users and duplicate display labels. All labels use `display_label`.

Named guests group by trimmed, case-insensitive saved name within the workspace, distinct from User identities. Unnamed guests form one bucket. Guest names are shown only on this authenticated page, extending the previous statistics rule at the user's explicit request. Existing guest filters remain combined; no new public identity or URL parameter is introduced. Guest-name grouping cannot distinguish two people with the same name.

## Presentation

Add maker and recipient rankings, a stacked maker-to-recipient chart with exact pairing counts, bean usage per recipient, and best-rated beans per recipient. Include useful sharing totals, distinct bean counts, and tasting coverage. Show full accessible values with every chart, mobile wrapping, light/dark theme support, and clear empty states. Charts load the local Chart.js bundle lazily and clean up on Turbo navigation.

Favorites average non-null Brew ratings from 1 to 5, grouped by recipient and Bean record. Guest cupping already writes this authoritative rating. A rating is attributed to the brew's recipient for this comparison, not claimed as verified authorship. Show sample counts; do not treat missing ratings as zero, and sort ties by sample size then label. Distinct bean bags remain distinct even when their names match.

## Architecture and verification

`WorkspaceStatistics` supplies its already filtered, eager-loaded brews to `WorkspacePersonaStatistics`. The latter returns only aggregate counts and safe labels; no serialized models, private notes, emails, media, or cupping capabilities enter chart payloads. No migrations or cached summaries are needed.

Verify maker/recipient identity, guest normalization, duplicate labels, ratings and missing ratings, self/other counts, Quick Drip semantics, date and people filter combinations, workspace isolation, viewer access, unauthenticated access, escaping, and empty states. Run existing statistics regressions plus the full Rails, style, and security checks after dependency upgrades. Inspect desktop and mobile charts before committing and leave `bin/dev` running in `roastnode-dev` tmux.
