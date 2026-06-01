# Formatting And Numeric Input

Roastnode stores measurements in canonical metric units: grams, seconds, and Celsius.

## Decimal Entry

Decimal measurement fields accept both dot and comma decimal separators. The server normalizes submitted values through `LocalizedNumberParser`, so values such as `18.2`, `18,2`, `18,2g`, `93,5°C`, and `14,90 €` are treated as the same numeric values.

Decimal measurement inputs should be rendered as `type="text"` with `inputmode="decimal"`. Avoid HTML `number` inputs for decimal measurements because browsers vary in their support for comma decimal entry.

## Profile Formatting

Users can choose number and timestamp display preferences from Profile:

- `comma_decimal` displays values like `1.234,5`.
- `dot_decimal` displays values like `1,234.5`.
- `european_24h_seconds` displays timestamps like `26.05.2026 14:37:04`.
- `us_12h_seconds` displays timestamps like `05/26/2026 02:37:04 PM`.

Currency is still owned by the active workspace through `Workspace#default_currency`. Profile number formatting controls the amount display, but it does not perform currency conversion.

Displayed measurement units are compact: grams, seconds, and Celsius render without a space between number and unit, for example `18,2g`, `31s`, and `93°C`.
