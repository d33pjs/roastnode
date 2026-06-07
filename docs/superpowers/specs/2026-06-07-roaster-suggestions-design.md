# Roaster Suggestions Design

## Intent

Bean entry should make repeated roaster names easier to reuse without turning the roaster field into a closed list. When a user types part of a roaster name, the bean form suggests matching roasters already used in the active workspace. For example, typing `bad` can suggest `Kaffeemanufaktur Bad Wildbad`.

## Included Now

- Search-while-type suggestions for the bean form's `roaster_name` field on new and edit screens.
- Suggestions come from distinct non-blank roaster names on all beans in the active workspace, including stock, open, finished, used-up, and archived bags.
- Matching is case-insensitive substring search, not only prefix search.
- Selecting a suggestion fills the normal free-text roaster field.
- Users can still type and save any roaster name that is not suggested.
- Workspace isolation is enforced by querying through `current_workspace`.
- Viewer users cannot access bean write screens and therefore do not use the suggestion UI.

## Explicitly Deferred

- Global/shared roaster directories across workspaces.
- Creating separate roaster records.
- Suggesting bean names, origins, processes, or purchase sources.
- Fuzzy typo matching beyond case-insensitive substring search.

## Interaction Rules

The roaster field remains the source of truth. Suggestions are helper UI only and do not change validation, persistence, or public sharing snapshots.

The suggestion list should stay small and readable. Blank queries return no suggestions, duplicate names collapse to one option, and results are limited to a small number of alphabetically sorted names.

## Testing Notes

Tests must cover:

- substring matching returns `Kaffeemanufaktur Bad Wildbad` for a query like `bad`
- matching is workspace-scoped
- blank roaster names are excluded
- blank queries return no suggestions
- normal bean creation still accepts arbitrary roaster text
