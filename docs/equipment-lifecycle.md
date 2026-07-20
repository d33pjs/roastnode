# Equipment Lifecycle

Equipment now has the same basic lifecycle shape as bean bags, but with "archive" language instead of "close". Equipment kinds include grinders, machines, and brewers.

## Editing And Photos

Owners and admins can create, edit, archive, reopen, delete, and manage photos for equipment from the equipment detail page. Members can view equipment and its history, but they cannot add or change equipment records or equipment photos.

Editing supports additive photos: newly uploaded files are attached without replacing existing equipment photos. Existing photos are shown on the edit page and still use the shared private media route.

The equipment index shows each item's primary photo when one is selected, falling back to an initial badge when no photo exists.

## Machine Extraction Options

Owners and admins can configure which extraction controls a machine supports: pre-infusion, low-flow start, and flow control. These flags are machine-only settings and are cleared automatically when equipment is changed to a grinder or brewer. Existing machines are migrated with pre-infusion enabled so their current logging behavior stays available.

Selecting a machine on a new espresso log shows only that machine's supported controls. Pre-infusion and low-flow start are measured in whole seconds; flow control records whether it was used for the shot. These settings control future data entry rather than rewriting history, so brew correction forms continue to expose saved extraction values even when a machine option is later disabled.

Low-flow-start and flow-control values are private workspace log data in this slice. They are included in workspace exports and instance backups, but they are not added to curated public brew, bean, or recipe snapshots.

## Archive And Reopen

`Equipment#archived_at` marks archived grinders, machines, and brewers. Archived equipment remains visible on its detail page and in historical brews/events, but it is excluded from new brew logging and new equipment-event selection.

Existing brew correction forms include the currently selected grinder, machine, or brewer even if it has since been archived, so historical corrections can be saved without losing the old reference.

## Delete

Equipment deletion lives in the equipment detail danger zone. It deletes the equipment record and its photos/maintenance links, but preserves brew history:

- `grinder_brews` are kept and their `grinder_id` is cleared.
- `machine_brews` are kept and their `machine_id` is cleared.
- `brewer_brews` are kept and their `brewer_id` is cleared.
- `equipment_event_items` are removed through the existing dependent association.

Use `Equipment#destroy_with_history!` for destructive deletes so this behavior stays centralized.
