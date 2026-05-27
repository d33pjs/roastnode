# Equipment Events Design

## Intent

Equipment Events lets a household record grinder and machine maintenance events and makes the workspace timeline more useful without adding reminders or recurring maintenance automation yet.

## Included Now

- Workspace-scoped equipment event records.
- Events created by signed-in workspace users with write access.
- One event can reference one or more equipment records from the same workspace.
- One event can include multiple event types for a single maintenance session.
- Equipment events can be edited or deleted by workspace writers.
- Equipment events support private photo management through the shared media flow.
- Dashboard quick action for adding an equipment event.
- Dashboard recent activity includes brews, equipment events, and manual inventory adjustments.
- Equipment detail pages show recent events, service counters, usage analytics, and maintenance marker distributions.

## Explicitly Deferred

- Maintenance reminders and notification schedules.
- Complex recurring maintenance rules.
- Beanconqueror import mapping for maintenance logs.
- Advanced ECharts analytics.

## Domain Model

`EquipmentEvent` records something that happened to equipment.

Fields:

- `workspace`
- `user`
- `event_types`
- `event_type` compatibility summary, storing the first selected type
- `occurred_at`
- `notes`
- `photos`, Active Storage attachments
- `primary_photo_attachment_id`

Supported event types for this slice:

- `grinder_cleaning`
- `grinder_deep_cleaning`
- `machine_descaling`
- `machine_backflush`
- `burr_change`
- `other`

`EquipmentEventItem` joins events to affected equipment records. The join supports events that affect both a grinder and a machine without creating duplicate timeline entries.

## Authorization And Isolation

- All queries go through `current_workspace`.
- Owners, admins, and members can create, edit, and delete equipment events.
- Viewers can read equipment and events but cannot manage them.
- Event creation rejects equipment IDs outside the active workspace.
- Event create/update requires at least one event type.

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
- editing event types, affected equipment, and additive photos
- danger-zone deletion removing event links but not equipment records
- dashboard timeline rendering equipment events
- equipment detail showing only active workspace events
