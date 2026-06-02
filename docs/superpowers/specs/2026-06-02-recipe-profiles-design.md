# Recipe Profiles Design

## Goal

Let a household turn a good logged espresso brew into an editable recipe/profile, use that recipe as a visible target guide while logging future brews, compare actual brews against the recipe with a subtle Hero Brew Card ghost line, and share/import recipes through privacy-safe public pages and portable JSON.

## Scope

- Add household/workspace-scoped recipes created from existing brews.
- Keep the v1 UI espresso-first, while making recipe records method-aware.
- Let writers edit exact target values copied from a source brew.
- Add a private Recipes area with index, detail, edit, import, export, sharing, and "Log with this recipe" actions.
- Add recipe-guided espresso logging that preserves normal brew defaults and adds a visible target guide.
- Store a recipe snapshot on brews logged with a recipe.
- Render a faint recipe ghost line and target timing guides on the Hero Brew Card for recipe-guided brews.
- Add explicit public recipe sharing through curated snapshots.
- Add single-file Roastnode recipe JSON export/import without media.

## Explicitly Deferred

- Standalone blank recipe authoring as the primary path.
- Non-espresso recipe UI.
- Target ranges. V1 target values are exact.
- Machine-specific programmable profile file import/export.
- Automatic matching or creation of beans, grinders, machines, or preparation tools during recipe import.
- Recipe media import/export bundles.
- Recipe comments, reactions, public analytics, or public recipe indexes.
- Structured pressure/flow phase authoring.
- Public recipe photo galleries or selected recipe media.

## Data Model

`Recipe` is workspace scoped and belongs to the user who created it. It may point to a local source `Brew` for provenance, but imported recipes can be fully unlinked.

The recipe stores editable target data as a profile snapshot, initialized from a source brew:

- brew method
- title and description/public note
- source brew provenance, including source brew id when local
- bean snapshot: name, display name, roaster, origin, process, roast details, tasting notes, public note, and public links
- grinder snapshot: name, model, public note, and public links
- machine snapshot: name, model, public note, and public links
- preparation tool snapshots and public links
- grind setting
- bean-in grams
- ground-out grams
- dose grams
- beverage grams
- brew temperature Celsius
- preinfusion seconds
- first-drip seconds
- total time seconds
- taste balance and rating context from the source brew
- one short target-guide note or "watch for" note
- optional pressure/profile note

V1 pressure/profile information is secondary. It records one optional manual note such as "full pressure, stable gauge". There is no structured pressure phase editor in v1; the product center is the data already present in a normal Roastnode brew log.

When a brew is logged with a recipe, the brew stores:

- the selected `recipe_id` when it belongs to the same workspace
- a full recipe snapshot used at the time of brewing

This snapshot is used for historical comparisons and the Hero Brew Card ghost. If the household recipe changes later, older brews keep comparing against the exact target they used.

Recipe-guided logging does not overwrite the normal espresso form defaults. Opening "Log with this recipe" keeps the existing last-brew/default behavior intact and only adds recipe guide context plus the brew-time recipe snapshot.

## Private Recipes Area

Recipes get first-level app navigation near the active coffee workflow.

The private recipe index shows household recipes with:

- title
- bean/roaster snapshot
- key targets
- source rating or source brew context when available
- public/share state
- actions for eligible users

The private recipe detail page shows:

- target guide preview
- full target profile
- bean, grinder, machine, and preparation tool snapshots
- source brew provenance when local or imported
- "Log with this recipe"
- edit action for writers
- public sharing controls
- export JSON action

Creating a recipe from a brew is available from the brew detail page for workspace writers. The form is prefilled from that brew's measured data, but the recipe target values are editable before saving.

Imported recipes create unlinked recipe records from a single Roastnode JSON file. Import preserves shared names, target data, notes, links, and provenance. It does not create or mutate local beans, equipment, preparation tools, brews, or media.

Access rules:

- Workspace writers can create recipes, edit recipes, log with recipes, import JSON, export JSON, and manage public recipe shares.
- Owners and admins can manage any workspace recipe.
- Viewers can read private recipes but cannot create, edit, import, export, share, or log new brews.
- All recipe lookup and mutation must be scoped through `current_workspace`.

## Guided Logging

The recipe-guided logging page uses the normal espresso brew form and normal defaults. Recipe values are not written into form fields unless the user types them manually.

On desktop, the page uses a two-column layout:

- left: normal espresso form
- right: sticky recipe target guide

On mobile, the guide becomes a compact top strip with expandable details.

The default guide is intentionally minimal and practical:

- Set grinder to the target grind setting.
- Watch bean-in and dose targets.
- Use the target temperature.
- Watch preinfusion and first-drip timing.
- Stop at the target total time and beverage yield.
- Show one short "watch for" note.

Full recipe details are available in an expandable area so pressure notes, tools, machine notes, links, and bean context do not crowd the fast logging flow.

When the recipe-guided brew is saved, the resulting brew detail page uses the stored brew-time recipe snapshot for comparison.

## Hero Card Ghost

Recipe-guided brews render a subtle "ghost" comparison in the Hero Brew Card chart.

The ghost should:

- use the brew-time recipe snapshot, not the live recipe
- appear as a faint target curve or timing guide
- emphasize target total time, preinfusion, first drip, and yield when those values exist
- stay understated enough that the card remains screenshot-friendly
- avoid adding target text to every top metric card

Detailed actual-vs-target comparison can appear below the Hero Brew Card on the brew detail page. The main card should stay dense and polished rather than becoming a comparison table.

The current chart remains illustrative, not sampled telemetry. Recipe ghost rendering compares stored totals and timing markers, not second-by-second flow data.

## Public Recipe Sharing

Public recipe sharing follows the same privacy posture as public brew sharing.

`PublicRecipeShare` is workspace scoped and belongs to one private `Recipe`. It stores an unlisted random public token, enabled/disabled state, optional password digest, title, creator/editor metadata, selected public fields, and a JSON snapshot used by the public page.

The public page renders from the snapshot only. It must not read live private workspace records for display content.

The public snapshot may include:

- recipe title and public description
- target guide fields
- bean, grinder, machine, and preparation tool snapshots
- source brew provenance and rating/taste context
- public links
- workspace name and user display label

The public snapshot and page must not include:

- private notes
- user email addresses
- invite tokens or invite links
- raw private media URLs
- Active Storage signed blob or variant URLs
- raw attachment IDs in rendered public HTML
- original uploaded filenames
- raw share tokens in logs
- equipment/tool costs
- backup, export, admin, session, environment, or infrastructure data

Public recipe pages show target instructions first. Source brew provenance appears alongside or below the targets to explain why the recipe is credible, without turning the page into a normal brew share.

Disabled shares and unknown tokens return not found. Password-protected shares use a password gate before rendering public HTML.

V1 public recipe pages do not include recipe photo galleries or selected media. If a future slice adds public recipe media, it must use opaque public media handles and the same password-gated allowlist model as public brew sharing.

## JSON Export And Import

V1 recipe portability is a single JSON file.

Export includes:

- schema name and version
- recipe title and description/public note
- method
- target profile values
- optional pressure/profile note
- bean, grinder, machine, and preparation tool snapshots
- public links
- source brew provenance
- generated-at timestamp

Export does not include media files, private notes, raw local record IDs except optional source provenance for same-instance context, signed URLs, or private workspace data.

Import validates the schema and creates an unlinked workspace recipe snapshot. It should fail closed on malformed JSON, unsupported versions, invalid URLs, or unsafe link schemes. Import should not create beans, grinders, machines, preparation tools, brews, photos, public shares, or media attachments.

## Tests

Tests must cover:

- recipes are workspace scoped
- cross-workspace users cannot view or mutate another workspace's recipes
- writers can create a recipe from a brew in their workspace
- viewers cannot create, edit, import, export, share, or log with recipes
- owners/admins can manage workspace recipes
- recipe target values are editable and exact
- recipe-guided logging preserves normal brew defaults and does not overwrite form fields
- brews logged with a recipe store a recipe snapshot
- recipe snapshots on brews stay stable after the live recipe is edited
- Hero Brew Card ghost renders from the brew-time recipe snapshot
- private recipe index/detail pages do not leak cross-workspace records
- JSON export includes target/profile data and excludes private notes/media internals
- JSON import creates an unlinked recipe without creating beans, equipment, tools, brews, or media
- public recipe shares render only from snapshot data
- disabled and unknown public recipe shares return not found
- password-protected public recipe shares gate public HTML
- private notes, raw media URLs, signed URLs, attachment IDs, emails, invite tokens, and equipment/tool costs do not appear in public recipe HTML

## Documentation

Add durable product documentation for recipes after implementation. Update:

- `docs/README.md`
- `docs/status.md`
- `docs/coffee-core.md`
- `docs/brew-card.md`
- a new dedicated `docs/recipe-profiles.md`
- `AGENTS.md` if recipes add new workspace/privacy rules future agents must see early
