# Formatting And Numeric Input

Roastnode stores measurements in canonical metric units: grams, seconds, and Celsius.

## Decimal Entry

Decimal measurement fields accept both dot and comma decimal separators. The server normalizes submitted values through `LocalizedNumberParser`, so values such as `18.2`, `18,2`, `18,2g`, `93,5°C`, and `14,90 €` are treated as the same numeric values.

Decimal measurement inputs should be rendered as `type="text"` with `inputmode="decimal"`. Avoid HTML `number` inputs for decimal measurements because browsers vary in their support for comma decimal entry.

## Profile Formatting

Profile-level display preferences for number, time, and currency formatting are still a product-design slice. Currency is currently a workspace setting, so future per-user currency display needs a clear decision about whether it is only formatting or actual conversion.
