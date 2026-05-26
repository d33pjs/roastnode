# Typography

Roastnode self-hosts Genos as its global app font.

## Included Now

- Variable Genos roman and italic TrueType font files under `app/assets/fonts/genos/`.
- The upstream `OFL.txt` license file stored next to the font files.
- Tailwind theme font tokens set to Genos for sans and mono text.
- `@font-face` declarations in the application layout, using `asset_path` so font URLs are digest-stamped.
- Base CSS forcing text, form controls, buttons, and code-like text to inherit Genos.

## License Notes

Genos is from `googlefonts/genos` and is licensed under the SIL Open Font License 1.1.

The OFL allows the font to be bundled with software, including commercial software, as long as the license conditions are followed. Keep `app/assets/fonts/genos/OFL.txt` with the vendored font files.

## Agent Notes

- Do not add runtime links to Google Fonts.
- Keep `@font-face` declarations in `app/views/layouts/application.html.erb`, not the Tailwind build output, so Rails can resolve digest-stamped font assets with `asset_path`.
- Rebuild Tailwind after typography changes with `bin/rails tailwindcss:build`.
- If the font is modified or converted later, revisit the OFL requirements before renaming or redistributing the modified font.
