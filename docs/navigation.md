# Navigation

Roastnode detail pages should cross-link records wherever that helps a household move through its coffee history.

## Included Now

- Brew hero cards link bean names and bean photos to the bean detail page.
- Brew hero cards link grinder and machine pills to equipment detail pages.
- Brew hero cards link preparation-tool chips to the matching row anchor on the preparation tools list when the brew snapshot still has a live tool record.
- Brew detail fields link beans, grinders, machines, and preparation tools in the same way.
- Equipment event detail pages link affected equipment names to equipment detail pages.
- Back links use the shared `shared/back_link` partial so they render as tap-friendly buttons on mobile.

## Agent Notes

- Use `dashboard_path` for explicit dashboard/back-to-dashboard links because `root_path` can honor a user landing preference and redirect somewhere else.
- Keep links scoped through records already loaded from `current_workspace`; do not add global finders for convenience.
- Preparation tools currently have an index and creation flow, not individual detail pages. Link snapshots with `preparation_tools_path(anchor: dom_id(tool))` until a real tool detail route exists.
