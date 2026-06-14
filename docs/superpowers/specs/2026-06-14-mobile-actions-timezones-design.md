# Mobile Actions And Timezones Design

## Context

Roastnode detail pages currently place several text buttons in a horizontally scrollable action strip. On mobile this can hide important actions such as Edit. Shared back links also include fallback-specific wording such as "Back to beans", which makes compact subpage headers noisy. Brew Hero Cards recently include bean processing in the compact bean descriptor, but the desired card should omit processing while keeping the rest of the card unchanged.

Date/time fields are also offset for CEST users because the app has timestamp format preferences but no real timezone preference. Rails still runs in its default UTC zone, and browser `datetime-local` values do not carry a timezone.

## Goals

- Remove bean processing from private Hero Brew Card bean descriptors only.
- Keep other bean metadata and public/share pages unchanged unless they explicitly use the same private Hero Card helper.
- Replace shared visible back-link wording with an icon-only back control that keeps accessible labels and desktop hover text.
- Prevent hidden horizontal scrolling for detail-page action controls on mobile.
- Use Material Symbols-style icons for visible action controls.
- Add per-user timezone support so display, edit forms, and submitted `datetime-local` values use the active user's IANA timezone.
- Keep timestamps stored as normal Rails UTC instants in PostgreSQL.

## Non-Goals

- No broad redesign of all form submit buttons, danger-zone buttons, or table/list management controls.
- No conversion of public pages to viewer-local browser timezone behavior.
- No migration of existing timestamp values; existing records are already stored as instants and should render in the selected user timezone.
- No external Google Fonts dependency at runtime. Icons should be self-hostable through inline symbols/helpers or local assets.

## UI Design

The shared back link becomes a fixed-size icon button with Material Symbols `arrow_back`. The link still resolves through the existing referrer-safe fallback logic, but visible text is removed. The old label remains available as `aria-label` and `title`, so screen readers and desktop mouse users still get the full destination context.

Detail action areas use a hybrid icon-first pattern:

- With one or two actions, show icon-only buttons directly.
- With three or more actions, desktop can show the direct icon strip, while mobile shows a primary visible action plus a `more_vert` menu for overflow actions.
- Menus use native `<details>`/`<summary>` like the existing app navigation, so they work without adding a heavy JS dependency.
- Each icon button and menu item has an accessible label and desktop hover title. Menu items keep text labels because menu choices should not require icon memory.

The first implementation applies this pattern to the known problematic detail action bars: bean detail and brew detail. Shared helper/partial structure should make it straightforward to extend to other detail pages later without changing this slice's behavior.

## Timezone Design

Add `users.time_zone` with a default of `Europe/Berlin`, because the current product/user context is CEST and current records are being interpreted two hours behind. Validate it against `ActiveSupport::TimeZone`.

Wrap authenticated requests in `Time.use_zone(Current.user.time_zone)` so Rails form builders, parsing, `Time.current`, and `profile_timestamp` use the current user's timezone. Unauthenticated/public requests keep the application default. Profile gets a timezone select alongside number and time format preferences.

For `datetime-local` fields, Rails will render the timestamp in the current `Time.zone`, and submitted timezone-less strings will parse in that same zone. This preserves UTC storage while matching the user's wall-clock intent.

## Testing

- Helper/model tests for Hero Card descriptors: origin and roast level remain, process is omitted.
- Controller/view tests for shared back links: visible label is removed, `aria-label`/`title` remain.
- Controller/view tests for bean and brew action areas: no mobile horizontal scroll classes on the detail action container, icon buttons/menu controls have accessible labels, and hidden actions remain reachable in markup.
- Model/profile tests for supported timezone validation and profile form/update behavior.
- Request/controller tests showing a Berlin user sees and submits `datetime-local` values without the UTC two-hour offset.

## Documentation

Update:

- `docs/brew-card.md` to say private Hero Cards show origin/roast-level descriptors without processing.
- `docs/navigation.md` to describe icon-only shared back links with accessible labels.
- `docs/formatting.md` to document per-user timezone behavior for timestamp display and `datetime-local` forms.
- `docs/status.md` if the implemented slice materially changes the built feature summary.
