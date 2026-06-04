# Footer Badge Configurator Design

Date: 2026-06-04

## Goal

Make the footer support links feel like a matched pair and let each household choose how Buy Me a Coffee appears on public shared pages.

The footer should always keep GitHub on the left. The right side should show the app version on normal signed-in app pages, or the configured Buy Me a Coffee support action on public shared pages.

## Approaches Considered

### Recommended: Configurable Official Badge Mode

Keep the existing simple Buy Me a Coffee link, and add an opt-in official badge mode. The official mode stores only household-controlled values such as slug and display text, then renders the Buy Me a Coffee script with fixed visual settings matching the approved badge snippet.

This is closest to the requested behavior while keeping third-party JavaScript explicit and opt-in.

### Local Lookalike Badge

Render a Roastnode-owned badge that visually resembles the Buy Me a Coffee badge, using the same slug and text. This avoids third-party JavaScript on public pages, but it is not the official widget the household requested.

### Script Snippet Storage

Store the full script snippet in workspace settings and render it as configured. This is too open-ended for a private household app because it would introduce arbitrary third-party script injection into public pages.

## Chosen Design

Add a Support badge configurator to household settings with:

- Display mode: simple link (`link`) or official badge (`official_badge`).
- Simple link URL: the existing Buy Me a Coffee URL field.
- Badge slug: used as `data-slug`, for example `d33p.js`.
- Badge text: used as `data-text`, for example `Buy me a coffee`.

The official badge mode renders the approved Buy Me a Coffee CDN script with fixed safe presentation settings:

- `data-name="bmc-button"`
- `data-color="#986338"`
- `data-emoji=""`
- `data-font="Comic"`
- `data-outline-color="#ffffff"`
- `data-font-color="#ffffff"`
- `data-coffee-color="#FFDD00"`

The script URL itself is not user-editable. Slug and text are escaped and validated before rendering.

## Footer Layout

The footer becomes a stable two-sided layout:

- Left: GitHub badge with a GitHub logo.
- Right: Buy Me a Coffee support action when a public share provides one, otherwise app version when version display is enabled.

GitHub and Buy Me a Coffee should share the same visual scale. The simple Buy Me a Coffee link should use the same badge shell as GitHub; the official badge should be wrapped so it aligns with the same footer row height.

On narrow screens, the two sides may wrap, but GitHub remains first and the support/version item remains second.

## Data And Validation

Workspaces keep the existing `buy_me_a_coffee_url` for simple-link mode. New fields store the badge mode, slug, and text.

Validation rules:

- Mode must be either `link` or `official_badge`.
- Simple link mode accepts the existing supported Buy Me a Coffee URL validation.
- Official badge mode requires a slug.
- Badge slug may contain letters, numbers, dot, underscore, and hyphen, up to 100 characters.
- Badge text is plain text, up to 80 characters.

When official mode is selected, public footer rendering uses the slug and text. When simple link mode is selected, public footer rendering uses the existing URL.

## Error Handling

Invalid settings should re-render household settings with inline validation errors and preserve the submitted values. Public pages should omit the Buy Me a Coffee action if the selected mode is incomplete.

The app should not log raw script snippets because users never enter snippets directly.

## Testing And Verification

Add model tests for mode, slug, text, and URL validation. Add controller tests proving household settings can update the new fields.

Update public brew and recipe page tests to cover the official badge script and the simple-link fallback. Update footer tests so GitHub remains present and the app version remains hidden on public shares.

Verify visually in the browser that the footer keeps GitHub left and version or Buy Me a Coffee right on desktop and mobile.
