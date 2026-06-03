# Recipe Ingredients And Finished Photo Design

## Goal

Let a recipe describe the finished drink, not only the espresso extraction. A household can save targets such as grinder, dose, temperature, and timing, then add finishing ingredients like "200 ml matcha" and "1 shot honey", plus one finished-drink photo. Public recipe sharing shows those drink-building details while keeping media private unless the recipe owner explicitly includes the photo.

## Scope

- Add structured ingredients to recipe profiles.
- Add one optional finish note to recipe profiles.
- Add one optional finished-drink recipe photo.
- Let recipe creation from a source brew suggest reusing the source brew's primary photo, without auto-selecting or auto-publishing it.
- Show ingredients and finish note on private recipe detail, recipe edit, recipe-guided logging, and public recipe pages.
- Include ingredients and finish note in recipe JSON export/import.
- Let public recipe shares include the recipe photo only through an explicit selection in the public share form.

## Explicitly Deferred

- Ingredient pantry/inventory tracking.
- Nutrition, cost, or shopping-list behavior.
- Multiple recipe photos or photo galleries.
- Photos per ingredient or per step.
- Recipe media export/import bundles.
- Automatic publishing of any source brew or recipe photo.
- Non-espresso recipe methods.
- Rich step-by-step cooking workflows beyond the small finish note.

## Recipe Profile Data

Ingredients live in `recipe.profile["ingredients"]` as an ordered array of flexible rows:

```json
[
  { "amount": "200", "unit": "ml", "name": "matcha" },
  { "amount": "1", "unit": "shot", "name": "honey" }
]
```

Rules:

- `name` is required for a row to be kept.
- `amount` and `unit` are optional strings so casual units like `shot`, `splash`, `pinch`, or blank quantities work.
- Rows preserve order.
- Empty rows are ignored.
- Values are trimmed and length-limited.
- Numeric amounts are not normalized in v1; `1.5`, `1,5`, `1/2`, and `one` can all be stored as user text.

The finish note lives in `recipe.profile["finish_note"]` as a short free-form string, for example:

```json
"Add matcha after pulling the espresso, then stir in honey."
```

The espresso target fields remain the first-class core of the recipe. Ingredients are the "finish this drink" layer after the extraction target guide.

## Recipe Photo

Recipes get one optional finished-drink photo. Conceptually this is a recipe image, not a copied brew-log image.

Implementation reuses the existing private media patterns:

- `Recipe` can attach photos through Active Storage.
- The UI treats the primary recipe photo as the single finished-drink photo for v1.
- Uploading/reusing a source brew photo attaches the source blob to the recipe record instead of duplicating file bytes.
- Private recipe pages render recipe photos through `media_attachment_path`.
- Recipe media remains workspace private unless explicitly selected for a public recipe share.

When creating a recipe from a brew with photos, the form shows a small "Use source brew photo" option. It must not auto-copy the photo when the form opens. The user has to choose it.

## Private Recipe UI

Recipe create/edit gets an "Ingredients / finish" section below espresso targets:

- ingredient rows with amount, unit, and ingredient name
- add/remove row affordance
- finish note textarea
- recipe photo upload
- source brew photo suggestion when the source brew has a primary photo

Recipe detail keeps the current hierarchy:

1. Recipe identity and primary actions
2. Recipe target guide
3. Espresso/source details
4. Finish section with ingredients, finish note, and finished-drink photo

Recipe-guided brew logging keeps normal brew defaults unchanged. The guide area adds a compact finish card so someone logging with the recipe can see the drink-build instruction after the extraction markers.

## Public Recipe Sharing

Ingredients and finish note are public recipe content by default. They are included in the public recipe snapshot and rendered on the public recipe page whenever present.

The recipe photo is private by default. Public recipe share management gets an explicit checkbox for the recipe photo. If unchecked, the public snapshot and page omit all recipe media.

If checked:

- the selected attachment must belong to the recipe record
- the public snapshot may include enough internal attachment metadata for server-side allowlisting
- rendered public HTML must not expose raw attachment IDs
- media bytes must be served through an opaque per-share media handle
- password-protected recipe shares must gate media access the same way they gate public HTML

This mirrors public brew media privacy, but scoped to `PublicRecipeShare` and recipe-owned media. Do not reuse public brew media routes for recipe shares.

## JSON Export And Import

Recipe JSON export includes:

- `ingredients`
- `finish_note`

Recipe JSON export does not include:

- recipe photo files
- Active Storage attachment IDs
- signed media URLs
- source brew media references

Recipe import restores ingredients and finish note into the new recipe profile. It does not create or attach photos.

## Privacy And Authorization

- All private recipe photo attachment and source photo reuse must be workspace scoped.
- Writers can add/edit recipe ingredients and photos for recipes they can edit.
- Viewers can see private recipe ingredients/photos through normal recipe read access, but cannot mutate them.
- Public recipe pages render from `PublicRecipeShare` snapshots, not live private records.
- Public recipe pages may render selected recipe media only through opaque handles and the share's media allowlist.
- Public recipe sharing must not expose private notes, signed Active Storage URLs, raw media routes, raw attachment IDs in rendered HTML, original filenames, user emails, invite tokens, equipment/tool costs, or source brew private data.

## Tests

Tests must cover:

- recipe create stores ingredient rows and finish note
- recipe edit updates, reorders, and removes ingredient rows
- blank ingredient rows are ignored
- viewers cannot mutate ingredients or recipe photos
- recipe detail renders ingredients, finish note, and the finished-drink photo
- recipe-guided logging renders the finish card without changing brew defaults
- source brew primary photo can be reused only when it belongs to the same workspace source brew
- source brew photo is not auto-selected or auto-published
- recipe JSON export/import round-trips ingredients and finish note while excluding media
- public recipe snapshots include ingredients and finish note
- public recipe pages render ingredients and finish note
- public recipe share form can include or exclude the recipe photo
- public recipe pages and media routes do not render or expose unselected recipe photos
- password-protected public recipe shares gate selected recipe media
- public recipe HTML does not include raw attachment IDs, signed URLs, `media_attachment_path`, or Active Storage blob URLs
