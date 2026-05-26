# Equipment Events Design

## Intent

Equipment Events is the next Roastnode slice after Coffee Core. It lets a household record grinder and machine maintenance events and makes the workspace timeline more useful without adding reminders, photos, or advanced analytics yet.

## Included Now

- Workspace-scoped equipment event records.
- Events created by signed-in workspace users with write access.
- One event can reference one or more equipment records from the same workspace.
- Dashboard quick action for adding an equipment event.
- Dashboard recent activity includes brews, equipment events, and manual inventory adjustments.
- Equipment detail pages show recent events and basic usage context.

## Explicitly Deferred

- Photos on equipment events.
- Maintenance reminders and notification schedules.
- Complex recurring maintenance rules.
- Beanconqueror import mapping for maintenance logs.
- Advanced ECharts analytics.

## Domain Model

`EquipmentEvent` records something that happened to equipment.

Fields:

- `workspace`
- `user`
- `event_type`
- `occurred_at`
- `notes`

Supported event types for this slice:

- `grinder_cleaning`
- `grinder_deep_cleaning`
- `machine_descaling`
- `machine_backflush`
- `burr_change`
- `other`

`EquipmentEventItem` joins events to affected equipment records. The join is required so later slices can support events that affect both a grinder and a machine without changing the public model.

## Authorization And Isolation

- All queries go through `current_workspace`.
- Owners, admins, and members can create equipment events.
- Viewers can read equipment and events but cannot create them.
- Event creation rejects equipment IDs outside the active workspace.

## Timeline Rules

Recent activity is a private workspace timeline preview.

It includes:

- brews
- equipment events
- manual inventory adjustments

It does not include automatic brew inventory adjustments because those are already represented by the brew entry.

## Equipment Detail

Each equipment item gets a detail page. The page shows:

- identity and notes
- linked recent brews
- linked recent equipment events
- simple usage counters

For grinders, usage focuses on grams ground and brews since the last cleaning or burr change event. For machines, usage focuses on brews since the last machine cleaning/descaling/backflush event.

## Testing Notes

Tests must cover:

- event model validation and workspace consistency
- controller authorization for members versus viewers
- cross-workspace equipment IDs being rejected
- dashboard timeline rendering equipment events
- equipment detail showing only active workspace events
