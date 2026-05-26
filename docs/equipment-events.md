# Equipment Events

Equipment Events records maintenance and service history for workspace equipment.

## Included Now

- Workspace-scoped equipment events.
- Affected equipment selection for one or more grinder or machine records.
- Event logging by owners, admins, and members.
- Viewer read-only access.
- Equipment detail pages with recent events, recent brews, and simple service counters.
- Workspace recent activity entries for equipment events.

## Event Types

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
- All selected equipment must belong to the event workspace.

## Deferred

- Equipment event photos.
- Maintenance reminders.
- Advanced usage analytics and charts.
- Import/export mapping for equipment events.
