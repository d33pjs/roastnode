# Equipment Lifecycle

Equipment now has the same basic lifecycle shape as bean bags, but with "archive" language instead of "close". Equipment kinds include grinders, machines, and brewers.

## Editing And Photos

Owners and admins can create, edit, archive, reopen, delete, and manage photos for equipment from the equipment detail page. Members can view equipment and its history, but they cannot add or change equipment records or equipment photos.

Editing supports additive photos: newly uploaded files are attached without replacing existing equipment photos. Existing photos are shown on the edit page and still use the shared private media route.

The equipment index shows each item's primary photo when one is selected, falling back to an initial badge when no photo exists.

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
