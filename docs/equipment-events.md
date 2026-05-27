# Equipment Events

Equipment Events records maintenance and service history for workspace equipment.

## Included Now

- Workspace-scoped equipment events.
- Affected equipment selection for one or more grinder or machine records.
- Multiple event types per event, so one maintenance session can record actions like grinder cleaning and machine backflush together.
- Event logging, editing, and deletion by owners, admins, and members.
- Viewer read-only access.
- Equipment detail pages with recent events, recent brews, usage analytics, maintenance marker distribution, and service counters.
- Archived equipment is hidden from new event logging while remaining visible in historical event detail pages.
- Existing affected archived equipment remains available when editing an old event.
- Workspace recent activity entries for equipment events.
- Private photo management on equipment events, including viewing, download, primary selection, cropping, removal, and additive upload while editing.

## Event Types

An equipment event stores event types in `event_types`. The legacy `event_type` column stores the first selected type for compatibility and simple ordering/filtering.

- `grinder_cleaning`
- `grinder_deep_cleaning`
- `machine_descaling`
- `machine_backflush`
- `burr_change`
- `other`

## Timeline Rules

The dashboard Recent activity section shows:

- brews
- equipment events
- manual inventory adjustments

It deliberately hides automatic brew inventory adjustments because the brew itself is already the user-facing activity.

## Data Model

- `EquipmentEvent` belongs to `Workspace` and `User`.
- `EquipmentEventItem` joins an event to affected `Equipment`.
- An event must include at least one affected equipment item.
- An event must include at least one event type.
- All selected equipment must belong to the event workspace.
- `EquipmentStatistics` owns grinder/machine usage analytics for equipment detail pages. Keep it scoped through `current_workspace.equipment.find(params[:id])`.

## Corrections And Delete

Equipment event edit reuses the create form. Updates replace event type selections and affected equipment links, and add new photos without replacing existing photos.

Equipment event deletion lives in the event detail danger zone. It removes the event, its join rows, and attached photos. Equipment records, brews, and equipment analytics remain intact except that the deleted event no longer contributes to service counters.

## Equipment Analytics

Equipment detail pages now show:

- total brews using the equipment
- total bean-in grams through the equipment
- average rating and channeling rate
- optional date range filters for brew-derived usage analytics
- brews and grams since the latest relevant service event
- brews-by-day bars
- maintenance marker counts by event type

Relevant service events are grinder cleaning, grinder deep cleaning, and burr changes for grinders; machine descaling and backflush for machines.

Date range filters are inclusive and apply to brew-derived usage analytics: total brews, total bean-in grams, average rating, channeling, brews-by-day bars, and recent brews. Service counters, last service, recent events, and maintenance marker counts stay current equipment-history views.

## Deferred

- Thumbnail variants.
- Maintenance reminders.
- Interactive ECharts usage charts.
- Import/export mapping for equipment events.
