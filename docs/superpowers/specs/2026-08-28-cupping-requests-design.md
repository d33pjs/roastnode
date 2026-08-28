# Cupping Requests Design

## Goal

Let a household member quickly share a saved Espresso made for someone else and let an anonymous guest provide time-limited taste, rating, and private comment feedback without exposing the private workspace.

Quick Drip is outside this feature. Espressos recorded for the logger themself do not show the cupping-share action.

## Approved Direction

Use a dedicated `CuppingRequest` record rather than adding temporary feedback state to `PublicBrewShare`. A cupping request owns its opaque bearer token, public-safe Brew snapshot, feedback window, guest comment, most recently observed guest IP, and closure state. Its public page reuses the visual structure of the existing public Brew page while keeping permanent public-share configuration independent.

Rejected alternatives:

- Extending `PublicBrewShare` would couple permanent publishing, optional passwords, selected photos, and a temporary anonymous write capability. Creating a cupping request could unexpectedly alter an existing public share.
- A stateless signed URL would not provide a durable home for the guest comment, first-access timing, IP-aware audit events, or idempotent automatic closure.

## Eligibility And Share Behavior

The saved Brew detail page exposes one cupping-share action only when the Brew is Espresso and its recipient is either another current household member or a Guest.

- Another household member receives the ordinary authenticated private Brew URL. Existing workspace authentication, membership, and write permissions continue to govern the page and its controls. No cupping request or public capability is created for this path.
- A Guest receives an unlisted cupping URL backed by `CuppingRequest`.
- A self-recipient Espresso and every Quick Drip show no cupping-share action.

On mobile, the cupping-share action opens the native share sheet. On a desktop-class pointer, it copies the URL and briefly reports that it was copied. In the mobile header, the action is pinned immediately to the left of the existing Edit pencil; remaining secondary actions stay in the overflow menu. Desktop keeps the complete icon action row.

New Guest Espressos receive a cupping capability as part of the successful Brew transaction. Existing Guest Espressos are backfilled so old saved brews can use the same action. Changing serving details from Guest to another recipient revokes the capability. Changing an eligible Espresso to Guest creates one. Deleting the Brew deletes its request.

## Public Page And Feedback Window

The guest page is an unauthenticated, unlisted bearer page. It renders a curated snapshot in the existing public Espresso page style and adds one feedback panel containing:

- the normal five-position Espresso taste balance from very sour through neutral to very bitter;
- the normal optional 1–5 rating; and
- one internal guest comment limited to 2,000 characters.

The comment is stored separately from `Brew#notes` so guest feedback cannot overwrite or become confused with the logger's private notes. It appears in a private Guest feedback section on the Brew detail page. Comment text is never copied into Activity metadata or the ordinary public Brew snapshot.

The first successful guest page access starts a 24-hour feedback window and schedules its closure. Preparing or sending the URL does not consume the window, and later visits do not extend it. Taste, rating, and comment are editable during the same window. At expiry, all three controls are replaced by a concise timeout message while the curated Brew page remains readable.

A browser countdown displays the server-provided deadline as `HH:MM:SS`. JavaScript improves the display only; every write performs a server-side locked/expired check. Expired writes do not change the Brew or comment and do not emit mutation activity.

The closure job receives the expected deadline, locks the request, and records closure only if that deadline is still current and the request has not already closed. Duplicate or stale jobs are no-ops.

## Snapshot And Privacy Boundary

The cupping page renders from a stored public-safe snapshot built with the existing public Brew snapshot rules. It does not read arbitrary live private Brew, Bean, equipment, tool, workspace, or user fields for presentation.

Automatic cupping snapshots select no Brew, Bean, equipment, or tool photos. Public-safe identity media already permitted by the snapshot contract may be served only through request-specific opaque media handles and safe-raster checks. The page never exposes raw attachment IDs, original filenames, Active Storage URLs, signed private media URLs, private notes, private links, costs, purchase details, emails, raw database IDs, or bearer tokens in application logs.

The Guest's private name is not inserted into the public snapshot. It is used only inside the private workspace and as the private Activity actor label. Blank Guest names fall back to `Guest`.

Unknown, revoked, deleted, non-Guest, non-Espresso, or malformed bearer URLs return `404 Not Found`. Guest feedback writes are rate-limited to 20 submissions per 10 minutes for each token-digest/remote-IP pair. Public controllers look up requests by a digest of the presented token, and request-log filtering redacts cupping tokens and media handles.

Guest feedback updates the authoritative `Brew#taste_balance` and `Brew#rating`. The Brew update, private guest comment update, cupping snapshot rebuild, affected ordinary public Brew/Bean snapshot refreshes, and all resulting Activity events commit in one transaction. Any validation or refresh failure rolls back the entire submission.

## Activity Audit

New Brew events snapshot a recipient-aware subject label, such as `Espresso with Roma for Alex`. Existing historical events retain their already stored labels.

Cupping audit actions use the Brew as their subject so every activity card links to the corresponding private Brew. Anonymous events have no `actor_id`; they use an explicitly validated `guest` actor kind and the Brew's bounded private Guest label. The actions are:

- first guest page access;
- initial taste selection and later taste change, with safe old/new scale values;
- initial rating and later rating change, with safe old/new 1–5 values;
- comment added and comment updated, without comment contents;
- automatic feedback-window closure.

Each anonymous action records a normalized remote IP in its allowlisted action metadata. This is a narrow exception to the general Activity rule that excludes IP addresses. The UI displays the IP with the event, and workspace/backup exports preserve it under the existing Activity authorization boundary. Automatic closure uses the most recently observed IP. Because closure is scheduled only after first access, an observed IP is available.

One feedback submission may change multiple fields. It emits one event for each changed concern: taste, rating, and comment. Submitting unchanged values emits no mutation event.

Only the first successful page access creates the access activity event, preventing refreshes from flooding the append-only ledger. Later successful requests may update the request's most recent IP for a truthful closure event without extending the deadline.

## Localization

The public cupping controller chooses German when the browser's `Accept-Language` preferences select `de`; it chooses English for `en` and as the fallback for every other language. The public Espresso presentation, feedback form, countdown labels, validation messages, saved confirmation, and expired state have complete English and German copy. Private application locale behavior is unchanged.

## Error Handling And Concurrency

The first-access transition, feedback submission, and automatic closure lock the `CuppingRequest` row before testing state. Concurrent first visits produce one deadline, one scheduled closure, and one access event. Concurrent feedback submissions serialize and calculate old/new activity values from committed state. A submission arriving at or after the deadline is rejected even if the browser still displays time remaining because of clock skew.

Public access recording and feedback mutation failures are not swallowed. A failed activation renders a generic unavailable response without leaking exceptions. Failed feedback returns the localized form with safe validation feedback. Scheduled job failures follow the existing Solid Queue retry behavior, while idempotency prevents duplicate closure events. The closure Activity event uses the authoritative feedback deadline as `occurred_at`, even when queue execution happens later.

## Export, Backup, And Lifecycle

Workspace JSON preserves the private guest comment but does not export the cupping bearer token. Instance backup formats preserve the private comment and cupping request state needed to retain existing read-only links and Activity history after restore. CSV exports do not add the private comment. Media ZIP behavior is unchanged because cupping requests do not select private record photos.

Restores validate workspace/Brew ownership, token uniqueness, Espresso/Guest eligibility, bounded comment length, deadline ordering, and safe snapshot structure. A restored open request reschedules closure; a restored closed or expired request remains read-only.

## Verification

Implementation follows test-first red/green cycles and covers:

- eligibility for Guest, household-member, self, and Quick Drip recipients;
- mobile action order, native mobile sharing, and desktop clipboard behavior;
- capability creation, serving-change revocation/creation, deletion, and historical backfill;
- first-access deadline creation, countdown data, non-extension, exact expiry, stale-job idempotency, and concurrent activation;
- valid taste, rating, and bounded comment updates plus expired, invalid-token, rate-limit, and rollback paths;
- recipient-aware Brew activity and every anonymous cupping activity action, actor label, IP, values, subject link, and comment-content exclusion;
- English, German, browser-language selection, and English fallback;
- snapshot-only rendering and negative assertions for private notes, links, costs, emails, guest names, tokens, raw IDs, filenames, and private media URLs;
- ordinary public Brew/Bean snapshot refreshes after accepted guest feedback;
- workspace export and full/readable backup round trips; and
- the complete Rails test suite, RuboCop, Brakeman, schema consistency, and migration reversibility checks.

## Documentation

Implementation adds a focused `docs/cupping-requests.md` product document and updates `docs/README.md`, `docs/status.md`, `docs/coffee-core.md`, `docs/public-brew-sharing.md`, `docs/activity-audit.md`, `docs/workspace-export.md`, and `docs/backup-system.md` where their contracts change.
