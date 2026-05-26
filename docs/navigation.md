# Navigation

Roastnode detail pages should cross-link records wherever that helps a household move through its coffee history.

## Included Now

- Dashboard brew hero cards are wrapped in one link to the brew detail page.
- Hero card internals do not emit links, because the shared partial is used inside the dashboard link.
- Brew detail fields below the hero card link beans, grinders, machines, and preparation tools.
- Brew detail pages show read-only related photo groups for the bean, grinder, machine, and selected preparation tools when photos exist.
- Equipment event detail pages link affected equipment names to equipment detail pages.
- Preparation tools have detail pages and brew detail tool links should point to those pages when the current tool record still exists.
- Back links use the shared `shared/back_link` partial so they render as tap-friendly buttons on mobile.

## Agent Notes

- Use `dashboard_path` for explicit dashboard/back-to-dashboard links because `root_path` can honor a user landing preference and redirect somewhere else.
- Keep links scoped through records already loaded from `current_workspace`; do not add global finders for convenience.
- Keep hero-card internals link-free. Use cross-links in the detail sections below the hero instead.
