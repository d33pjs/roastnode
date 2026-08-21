# Recipient Statistics Design

## Goal

Let a household analyze Brew activity independently by who logged it and who received it, while preserving the existing distinction between date-filtered Brew metrics and current Bean catalog facts.

## Dependency

This slice depends on the approved Brew recipient model with Self, Household member, and Guest kinds. It must not infer household recipients from legacy guest text.

## Filters

Statistics gains two independent selectors in addition to the existing date/timeframe controls.

Logged by offers All, every current household User, and former Users represented as Brew loggers in the active workspace. Labels use `User#display_label`, never email.

Served to offers:

- All recipients;
- Self-served, meaning every Brew whose recipient kind is Self;
- each current household User plus historical Users represented by Brew recipient data; and
- Guests, meaning every Brew whose recipient kind is Guest.

Selecting a specific person such as Petra includes:

- Self Brews where Petra is the logger; and
- Household-member Brews where another logger explicitly selected Petra as recipient.

Guest names are intentionally not separate analytics identities. The Guests option aggregates all Guest Brews.

## Query And Authorization Rules

`WorkspaceStatistics` accepts optional logger and recipient filters alongside its inclusive start/end dates. All Brew scopes begin from `current_workspace.brews`.

Logger identifiers must be associated with Brew history in the active workspace. Recipient identifiers must be either an active workspace User or a historical recipient/logger represented in that workspace's Brew history. A missing or unauthorized foreign-workspace identifier is rejected rather than silently ignored.

Timeframe shortcuts and manual dates preserve logger and recipient query parameters. Resetting people filters leaves the selected timeframe intact; resetting the full Statistics view restores the normal seven-day defaults.

## Metric Semantics

Every Brew-derived result uses the combined date, logger, and recipient scope:

- total Brews;
- total Bean In/consumption;
- average known Brew cost;
- grinder and machine leaders;
- channeling rate;
- taste, retention, and method distributions; and
- Brews-by-day and consumption-by-day series.

Current Bean/catalog results remain workspace-current and are not narrowed by dates or people:

- open Bean count;
- known Bean spend; and
- Bean breakdowns by roaster, origin, and process.

Those cards retain visible copy explaining that they are current inventory rather than filtered Brew results. External Coffees remain outside the dedicated Statistics service in this slice.

Empty filtered scopes render explicit no-data states. Leaders and averages do not show misleading values when no qualifying Brew exists.

## Presentation

The filter form groups time and people controls clearly, remains usable on mobile, and shows active selections in submitted controls. Quick timeframe links preserve both people selections. Filter labels use “Logged by” and “Served to” so actor and recipient cannot be confused.

The existing all-Coffees link remains an all-time navigation entry rather than pretending the mixed Coffee list supports every Statistics filter.

## Verification

Automated coverage includes:

- independent logger and recipient filters;
- combined logger, recipient, and date filters;
- Self aggregation;
- a named person matching their Self and member-recipient Brews;
- Guest aggregation without guest-name options;
- current/former household labels without email;
- foreign-workspace and unknown identifiers;
- timeframe/reset parameter preservation;
- all Brew-derived totals, costs, leaders, rates, distributions, and series;
- unfiltered current Bean/catalog metrics; and
- clear empty-result states.

## Documentation

Implementation updates `docs/statistics.md`, `docs/coffee-core.md`, and `docs/status.md` with recipient-aware filtering and the unchanged current-inventory boundary.
