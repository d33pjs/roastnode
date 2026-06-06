# Public Brew Native Share Design

## Purpose

Make already-public brews easier to send from a phone without changing the public sharing workflow. The feature adds a native mobile share shortcut for enabled public brew shares in the private brew log UI.

## Scope

- Show a `Share` shortcut on compact Brew Log cards only when the brew has an enabled `PublicBrewShare`.
- Show the same shortcut in the brew detail action area next to the existing `Share publicly` management button when the share is enabled.
- Do not show the shortcut for disabled shares, unshared brews, viewers without private access, or public pages.
- Keep the existing `Share publicly` button as the place to create or manage public shares.

## Architecture

Use a small shared partial for the button and a focused Stimulus controller for client behavior. The partial receives a public URL and title, renders a normal button, and stores share metadata in data attributes. The controller calls `navigator.share` when available and falls back to copying the URL to the clipboard.

Compact Brew Log cards currently render as one large link, so the card will be reshaped into a non-link article with a primary link around the card body and a separate action area for the native-share button. This avoids invalid nested interactive elements and keeps the whole main card content navigable.

## Behavior

- Tapping `Share` on supported mobile browsers opens the OS share sheet with the public brew URL and title.
- On unsupported browsers, the button copies the public URL and temporarily changes its label to `Copied`.
- If the clipboard fallback fails, the button temporarily changes its label to `Copy failed`.
- The public URL comes from `public_brew_page_url(share.token)`.

## Testing

- Controller tests cover compact Brew Log rendering for enabled, disabled, and missing public shares.
- Controller tests cover brew detail rendering for enabled public shares.
- Asset tests cover the Stimulus controller paths for `navigator.share`, clipboard fallback, and temporary label reset.

