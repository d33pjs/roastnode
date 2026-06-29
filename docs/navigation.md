# Navigation

Roastnode detail pages should cross-link records wherever that helps a household move through its coffee history.

## Included Now

- Dashboard latest coffee hero cards are wrapped in one link to the record detail page. Brew records link to brew details; External Coffee records link to external coffee details.
- Dashboard `View all` links open all-time mixed coffee history from Latest coffee and all-time activity history from Recent activity.
- Mixed coffee history is available at `/coffees`, defaults to compact cards, can switch to hero cards while preserving pagination, and can filter All, Brews, or External. The legacy `/brews` route remains available for compatibility.
- Activity history is available at `/activity` and uses dashboard-style activity cards.
- Hero card internals do not emit links, because the shared partial is used inside the dashboard link.
- The global Gear navigation item opens the Gear overview page, which groups equipment cards and preparation tool cards in separate sections.
- The Gear overview page owns the "Log maintenance" entry point for equipment events.
- Equipment and preparation-tool create/edit/show pages use Gear as their normal back-link target, and successful create/update/archive/reopen/delete actions return to Gear so the older split equipment/tool indexes do not become the main flow.
- Brew detail fields below the hero card link beans, grinders, machines, and preparation tools.
- Successful brew logging redirects to the brew detail page, which is the saved-brew screen for post-brew corrections such as taste/rating and private serving metadata. The detail page includes a visible heading so it is distinguishable from the dashboard on mobile.
- Brew detail pages show read-only related photo groups for the bean, grinder, machine, and selected preparation tools when photos exist.
- Equipment event detail pages link affected equipment names to equipment detail pages.
- Preparation tools have detail pages and brew detail tool links should point to those pages when the current tool record still exists.
- Back links use the shared `shared/back_link` partial as icon-only left-arrow buttons with `aria-label` and `title` text for accessibility and desktop hover. When the browser provides a same-origin previous page, the shared link returns there with a neutral accessible "Back" label; direct visits, refreshes, self-referrers, external referrers, and share workflow referrers fall back to the explicit path passed by the view so share create/edit flows cannot loop. Brew log creation and brew detail pages opt out of previous-page behavior and always target the dashboard.
- Detail action groups use Material-symbol icon buttons with desktop hover titles. Pages with more than two actions keep the full icon strip on desktop, while mobile shows the primary action directly and collapses secondary actions into a More menu so users do not have to discover horizontal scrolling.

## Agent Notes

- Use `dashboard_path` for explicit dashboard/back-to-dashboard fallback links because `root_path` can honor a user landing preference and redirect somewhere else.
- Keep links scoped through records already loaded from `current_workspace`; do not add global finders for convenience.
- Keep hero-card internals link-free. Use cross-links in the detail sections below the hero instead.
