# Cupping Requests

Cupping Requests let a workspace writer share a saved Espresso with its intended recipient for tasting feedback. Another current household member receives the ordinary authenticated private Brew URL. A Guest receives an unlisted bearer URL at `/c/:token`; the public capability is separate from any permanent `PublicBrewShare` for the same Brew.

## Eligibility And Lifecycle

The saved Brew page shows **Share for cupping** only for Espresso served to either another current household member or a Guest. Self-recipient Espresso and every Quick Drip are ineligible. A household recipient must still be a current member when the page renders; the shared private URL remains governed by normal authentication, workspace membership, and write permissions.

Guest Espresso creation and serving corrections synchronize a one-per-Brew `CuppingRequest` in the same transaction as the Brew change. Existing Guest Espressos were backfilled. Changing an eligible Brew away from Guest destroys its request and revokes its bearer URL; changing it back creates a new request and token. Deleting the Brew also deletes the request. Unknown, malformed, revoked, deleted, non-Guest, and non-Espresso bearer URLs return `404 Not Found`.

On coarse-pointer/mobile browsers, the action uses the native share sheet when available and falls back to copying. On desktop-class pointers it copies the URL and briefly reports success or failure. The mobile action is pinned immediately before Edit; desktop keeps it in the normal action row.

## First Access And Feedback

Creating, copying, or sending a Guest URL does not start its clock. The first successful public page access records `opened_at`, sets one deadline exactly 24 hours later, records the access Activity event, and schedules expiration. Later visits do not extend the deadline. Row locking makes concurrent first visits converge on the same deadline and one access event.

While the window is open, the guest can repeatedly set or clear:

- Espresso taste balance, including the explicit **Not sure yet** state;
- an optional whole-number rating from 1 through 5; and
- one private comment, limited to 2,000 characters.

Taste and rating update the authoritative Brew. The comment belongs to `CuppingRequest`, not `Brew#notes`, and appears only in the private **Guest feedback** section on the Brew detail page. A successful submission updates the Brew, comment, cupping snapshot, affected permanent public Brew snapshots, affected public Bean comparison snapshots, and Activity events in one transaction. Invalid input or any refresh failure rolls everything back. Unchanged values emit no mutation event.

The page displays a JavaScript-enhanced `HH:MM:SS` countdown from the server deadline. The server remains authoritative: a write at or after the deadline is rejected even if a browser clock still shows time. Expired pages keep the curated Brew presentation readable but replace the form with an expired message. Feedback writes are rate-limited to 20 attempts per 10 minutes for each token-digest/remote-IP pair.

## Expiration And Queue Recovery

`CuppingRequestExpirationJob` receives the expected deadline, locks the request, and closes it only when that deadline is still current and has arrived. It records `closed_at` and the closure Activity event at the authoritative deadline. Early, stale, duplicate, and revoked-request jobs are no-ops.

Expiration dispatch records an in-progress lease and a successful enqueue marker. Failed enqueues clear the lease so they can be retried. In production, `CuppingRequestExpirationRecoveryJob` runs every minute: it directly closes overdue open requests and reschedules future requests whose dispatch was never recorded or whose five-minute dispatch lease became stale. This recovery is required because Solid Queue jobs are operational state and are not restored from backups.

## Public Snapshot And Media Boundary

The public page renders the stored public-safe Brew snapshot rather than arbitrary live private records. The Guest's private name is not inserted into the snapshot; private notes, private links, emails, costs and purchase data, Cup style, raw database or attachment IDs, original filenames, and Active Storage or private-media URLs are not public.

Automatic cupping snapshots select no Brew, Bean, equipment, or preparation-tool photos. Only the snapshotted workspace logo and logger avatar may be served, and only while each attachment is still the current authorized identity image. Public HTML uses request-specific opaque media handles. The media controller accepts only those handles and safe browser-raster JPEG, PNG, GIF, or WebP content; stale, forged, non-image, and unsupported-variant requests return not found.

Controllers find requests by a digest of the presented token. Request paths, redirect locations, bearer tokens, media handles, feedback comments, and private Guest names are filtered from application logs. The bearer URL still grants anonymous read access and, during the open window, anonymous write access to the three feedback fields; share it only with the intended guest.

## Activity Audit

Cupping events use the Brew as their subject, so private Activity cards link back to the private Brew. They have no `actor_id`; `actor_kind` is the tightly restricted `guest` value and `actor_label` is the bounded private Guest name, falling back to `Guest`.

The ledger records first access; taste set/change/clear; rating set/change/clear; comment added/updated without comment contents; and automatic closure. Each event includes a normalized remote IP in allowlisted metadata. This is the narrow exception to the normal Activity prohibition on IP addresses. Later successful access or feedback updates the request's most recently observed IP, which the closure event uses. Workspace JSON and instance backups preserve these authorized Activity rows and their IP metadata.

## Browser Locale

The public controller reads weighted `Accept-Language` preferences, including regional tags. It selects German when `de` is the preferred supported language, English when `en` is preferred, and English for missing or unsupported languages. The public Espresso presentation, feedback controls, validation and rate-limit errors, saved confirmation, countdown labels, and expired state are complete in English and German. This does not change the signed-in application's locale behavior.

## Workspace Export And Instance Backup

The owner-only workspace JSON includes the private comment as `cupping_feedback_comment` on its Brew row. Its top level deliberately has no `cupping_requests` collection, token, token digest, deadline, or request state. Brew CSV omits the comment and capability. The media ZIP's embedded workspace JSON includes the comment under the same rule, but cupping requests add no media files.

Instance-admin readable and full backups serve a different disaster-recovery purpose. They preserve workspace-scoped cupping request rows, including the bearer token/digest, safe snapshot, private comment, access/deadline/closure state, most recent IP, and timestamps, so existing links and Activity history survive a restore. Validation rejects cross-workspace or non-Guest/non-Espresso relationships, duplicate or mismatched tokens, invalid timestamps/IP/comments, unsafe snapshot shapes, and identity media outside the archived current logo/avatar catalog.

Restore clears archived expiration enqueue markers and leases. It reschedules only open requests with a future deadline after the restore transaction; recurring recovery handles dispatch failure and overdue state. Closed or expired links remain readable but cannot accept feedback.

## Verification Guidance

Changes in this area should cover eligibility and transactional synchronization; private versus bearer URLs; first-access timing, exact expiry, concurrency, stale/duplicate jobs, and recovery; feedback validation, clearing, rollback, rate limiting, and snapshot refresh; English/German browser selection; Activity actor/IP/value contracts without comment content; snapshot-only rendering and negative privacy assertions; opaque safe-raster identity media; request-log filtering; workspace export exclusion; and readable/full backup validation and restore scheduling.

The focused regression surface is:

```bash
bin/rails test test/models/cupping_request_test.rb test/services/cupping_requests test/jobs/cupping_request_expiration_job_test.rb test/jobs/cupping_request_expiration_recovery_job_test.rb test/controllers/public_cupping_requests_controller_test.rb test/controllers/public_cupping_media_controller_test.rb test/controllers/brews_controller_test.rb test/services/activity test/presenters/activity/presenter_test.rb test/services/workspace_export_builder_test.rb test/services/instance_backup_builders_test.rb test/services/instance_backup_restore_test.rb
```
