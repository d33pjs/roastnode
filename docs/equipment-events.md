# Equipment Events

Equipment Events records maintenance and service history for workspace equipment.

## Included Now

- Workspace-scoped equipment events.
- Affected equipment selection for one or more grinder or machine records.
- Multiple event types per event, so one maintenance session can record actions like grinder cleaning and machine backflush together.
- Event logging by owners, admins, and members.
- Viewer read-only access.
- Equipment detail pages with recent events, recent brews, usage analytics, maintenance marker distribution, and service counters.
- Workspace recent activity entries for equipment events.
- Basic private photos on equipment events.

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

## Equipment Analytics

Equipment detail pages now show:

- total brews using the equipment
- total bean-in grams through the equipment
- average rating and channeling rate
- brews and grams since the latest relevant service event
- brews-by-day bars
- maintenance marker counts by event type

Relevant service events are grinder cleaning, grinder deep cleaning, and burr changes for grinders; machine descaling and backflush for machines.

## Deferred

- Primary-photo selection and thumbnail variants.
- Maintenance reminders.
- Interactive ECharts usage charts.
- Import/export mapping for equipment events.
