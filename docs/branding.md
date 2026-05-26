# Branding Assets

Roastnode keeps application brand art under `app/assets/images/brand/`.

## Included Now

- `logo_font_white_bg.png` and `logo_only_white_bg.png` are the large source exports supplied by the project owner.
- `logo_wordmark_web.png` is the smaller app-ready wordmark used by `shared/_brand_wordmark`.
- `logo_mark_icon.png` is the smaller app-ready mark used for browser icons, PWA manifest icons, and the brew hero-card badge.
- `logo_font_transparent_bg.png` and `logo_only_transparent_bg.png` are currently RGB PNGs with a visible checkerboard baked into the pixels. Do not use them on app UI unless they are replaced with true alpha-transparent exports.

## Usage Notes

- Render the wordmark through `app/views/shared/_brand_wordmark.html.erb` so the source art is consistently cropped into a clean header logo.
- Render compact marks through `app/views/shared/_brand_mark.html.erb` when a small square badge is needed.
- Browser and app icons are resolved with `asset_path` in `app/views/layouts/application.html.erb` and `app/views/pwa/manifest.json.erb`; do not add new runtime external logo references.
- The legacy `public/icon.png` and `public/icon.svg` files are not used by the current layout.
