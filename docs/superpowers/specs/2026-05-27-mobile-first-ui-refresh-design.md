# Mobile-First UI Refresh Design

## Goal

Make Roastnode feel calm, modern, and mobile-first while preserving its private household workflow and existing Rails/Hotwire simplicity. The first implementation slice focuses on the global navigation structure, dashboard, and new espresso logging experience. The Hero Brew Card is explicitly out of scope and must not be changed.

## Approved Direction

Use one clean app navigation structure:

- Log
- Dashboard
- Beans
- Stats
- Gear
- Account
- Settings
- Sign out

Logging espresso remains the most prominent daily action, but it should exist in only one place. The mobile navigation should not use a fixed floating bottom bar because iOS Safari and installed web-app chrome cause it to jump during scroll. Mobile navigation should sit in normal page flow as a stable app header/menu. Desktop/tablet should use the same information architecture with roomier inline navigation.

The navigation groups are:

- Gear: equipment and preparation tools.
- Account: profile, members, workspace/household settings, and invites.
- Settings: import and export/data operations.

Dashboard-level action strips should not duplicate the global navigation. Beans owns adding another bag; Gear owns equipment and tool management.

Use the approved A2 visual language: Nordic hearth with a blue/fjord tint. The light theme is the default and uses warm off-white surfaces, blue-slate accents, restrained coffee ink, and occasional honey highlights. The dark theme uses soft blue-black surfaces rather than pure black. Theme choice is stored per user, not inferred only from browser settings.

## Dashboard

The dashboard should become a calm overview around the unchanged Hero Brew Cards:

- clearer page header and workspace identity
- primary action for logging espresso
- compact status tiles for current household state
- open beans list with primary bean photos
- recent activity timeline for brews, equipment events, and manual inventory adjustments
- mobile spacing designed around the bottom navigation

The dashboard should remain useful at phone width without hiding essential actions behind dense menus. Larger screens can show more secondary actions and data at once.

## Log Espresso

Use a one-page, shot-first form rather than a wizard. The order and grouping should support fast mobile logging:

1. Bean selector with primary bean photo and remaining inventory context.
2. Dose and grind fields: bean in, ground out, dose, and grind setting when visible.
3. Extraction fields: preinfusion, first drip, total time, beverage, obvious channeling, and photos.
4. Setup fields: grinder, machine, temperature, and preparation tools.
5. Taste fields: taste balance and rating.
6. Notes.

Beans, grinders, machines, and preparation tools should display their primary photos where available. The form must continue to honor `User#default_brew_focus_field`, `User#hidden_brew_field_names`, browser-local draft recovery, localized decimal parsing, and workspace write authorization.

## Theme Persistence

Add a per-user theme preference with a light default and dark option. The selected theme should affect the app shell and refreshed pages through shared CSS tokens/classes. It should be editable from Profile alongside the existing user display and formatting preferences.

The initial slice does not need live theme toggling without a form submit, automatic system-theme sync, or more than two themes.

## Technical Shape

Use Rails-native view partials and CSS rather than a new frontend framework. Introduce shared app-shell/navigation partials and reusable CSS tokens for surfaces, text, borders, and actions. Keep the work scoped to the app shell, dashboard, profile theme preference, and brew form.

The refresh should preserve existing authorization boundaries: workspace routes continue to use the active workspace and current membership, media previews use private media routes, and app UI should not expose email addresses on screenshot-friendly surfaces.

## Tests

Add or update tests for:

- persisted user theme validation and profile updates
- app shell navigation links for signed-in users
- dashboard rendering with open bean primary photos
- brew form ordering and image-backed selectors
- existing hidden brew fields and autofocus behavior

Run the focused tests for changed behavior and the serial Rails test suite when the slice is complete, since local parallel Rails tests currently have a native `pg` crash.

## Deferred

- Redesigning the Hero Brew Card.
- Full statistics page redesign.
- Live in-page theme toggle.
- Public sharing, federation, or unauthenticated media delivery.
- Recipe-related defaults or recipe snapshots.
