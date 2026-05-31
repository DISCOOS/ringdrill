---
status: proposed
date: 2026-05-31
deciders: ["@kengu"]
consulted: []
informed: []
---

# ADR-0031: Row edit affordances use swipe and long-press; pencil reserved for AppBar

## Context and problem statement

Several lists in the app already let the user edit the row's underlying entity, but the affordance is inconsistent. `lib/views/station_list_view.dart` and `lib/views/roleplays_view.dart` wrap each row in a `Dismissible(endToStart, confirmDismiss: ...)` so a left-swipe opens the relevant form. `lib/views/teams_view.dart` has no edit affordance at all (a pre-existing gap, see ADR-0030 follow-ups). `lib/views/coordinator_screen.dart` exposes station and team rows that are visually editable but route only through tap → `ContextSheet` → blyant in the detail screen's AppBar.

When the quick-wins prompt for cross-tab editing was drafted in May 2026, the natural next step was to add `IconButton(Icons.edit)` to each row's trailing slot. That would have shipped pencil icons across `ListTile`, `ExpansionTile`, and `ExpandableTile` rows alongside the existing `Dismissible` swipe. The maintainer flagged this as a mistake: the trailing slot is already busy in several rows (badges, switches, drag handles, expansion chevrons), pencil-in-row competes with the AppBar pencil for the meaning of "edit", and adding pencils to a half-dozen widgets makes the row chrome noisy across the app.

We need a single rule for how editing surfaces on rows, before agents and contributors start sprinkling `Icons.edit` ad-hoc.

## Decision drivers

* One gesture vocabulary for editable rows across `ListTile`, `ExpansionTile`, `ExpandableTile`, regardless of which feature folder owns the row (see [ADR-0028](./0028-feature-first-views-layout.md)).
* Keep `Icons.edit` as a strong, unambiguous signal of "edit this detail entity" on detail screens — devalued if the same icon also appears in lists.
* Keep the trailing slot in rows free for content-bearing widgets (badges, switches, chevrons, position indicators, drag handles).
* Preserve the existing swipe-to-edit pattern that `station_list_view.dart` and `roleplays_view.dart` already ship.
* Coexist with ADR-0026's tap-opens-sheet semantics: edit must not be tap, because tap is reserved for read.
* Discoverable enough for first-time users without resorting to onboarding hints.

## Considered options

* **Option A: Swipe and long-press on rows; pencil reserved for AppBar. (chosen)** `Dismissible(endToStart)` for the swipe gesture, `onLongPress` for the in-place gesture, no `Icons.edit` inside row widgets. `IconButton(Icons.edit)` continues to live in detail screens' `AppBar.actions` and in overflow menus.
* **Option B: Swipe and trailing row pencil; no long-press.** Add `IconButton(Icons.edit)` to each row's trailing slot alongside the swipe.
* **Option C: Trailing row pencil only; drop the swipe.** Replace `Dismissible` in `station_list_view.dart` and `roleplays_view.dart` with a pencil button.
* **Option D: Swipe only; no in-place gesture.** Keep the status quo, accept that there is no on-row gesture besides the edge swipe.

## Decision outcome

Chosen option: **Option A**. It is the only option that keeps `Icons.edit` as the AppBar's exclusive vocabulary, preserves the existing swipe pattern, and gives the user a row-level in-place gesture that does not require trailing-slot real estate.

### Rule

1. Edit affordances on rows are either of, or both of:
   * `Dismissible(direction: DismissDirection.endToStart, confirmDismiss: ...)` for the swipe gesture, returning `false` from `confirmDismiss` so the row is not removed.
   * An `onLongPress` handler on the row.
2. `IconButton(Icons.edit)` (or any other pencil icon) **must not** appear inside `ListTile`, `ExpansionTile`, `ExpandableTile`, `Card` row wrappers, or any other list-row widget.
3. `IconButton(Icons.edit)` is the canonical edit affordance in detail screens' `AppBar.actions` and in overflow menus. Detail screens currently using this pattern: `lib/views/station_screen.dart:117-128`, `lib/views/roleplay_screen.dart`. The convention is extended to `lib/views/team_exercise_screen.dart` when team editing lands.
4. Both gestures call the same private edit handler (`_editStation`, `_editTeam`, `_openTeamForm`, etc.). The disabled-state rule from `station_screen.dart:117-128` (`_isStarted` guard + `localizations.stopExerciseFirst(...)` snackbar) applies to long-press just as it does to the AppBar pencil.
5. When swipe is unavailable because the trailing edge is already used (rare, but possible for rows inside a horizontally swipeable container), long-press is sufficient on its own.

### Implementation pattern

For `ListTile`-based rows, use the built-in parameter:

```dart
ListTile(
  onTap: () => /* open ContextSheet (read) */,
  onLongPress: () => _openForm(entity), // direct to form (edit)
  // no trailing IconButton(Icons.edit)
)
```

For `ExpandableTile` rows, use its built-in callback:

```dart
ExpandableTile(
  onLongPress: () => _editStation(stationIndex),
  ...
)
```

`ExpandableTile` owns the row `InkWell`, so keeping its optional
`onLongPress` callback beside `onOpen` and `onToggle` avoids repeated gesture
wrappers and preserves tap-to-expand behaviour.

### Sites bound by this rule

| Site                                    | Today                                 | After                                           |
|-----------------------------------------|---------------------------------------|-------------------------------------------------|
| `station_list_view.dart` rows           | Dismissible swipe                     | Dismissible swipe + `ExpandableTile.onLongPress` |
| `roleplays_view.dart` rows              | Dismissible swipe                     | Dismissible swipe + `ExpandableTile.onLongPress` |
| `teams_view.dart` rows                  | tap-opens-sheet only                  | Dismissible swipe + `ListTile.onLongPress`      |
| `coordinator_screen.dart` station rows  | tap-opens-sheet only                  | Dismissible swipe + `ExpandableTile.onLongPress` |
| `coordinator_screen.dart` team rows     | tap-opens-sheet only                  | `ExpandableTile.onLongPress` (no swipe today)   |
| `program_view.dart` exercise card       | Dismissible swipe                     | unchanged; `ExerciseCard` already conforms      |
| Detail screens' `AppBar.actions`        | `IconButton(Icons.edit)`              | unchanged; this is the only place pencil lives  |

Sites the rule does **not** apply to: chart cells, table cells, map markers, brief-view sections (read-only), settings rows (own widget pattern).

### Consequences

* Good: One gesture vocabulary for every editable row in the app. Future contributors and agents do not need to invent per-feature affordances.
* Good: `Icons.edit` retains its meaning as a strong "edit this detail entity" signal, undiluted by row-level repetition.
* Good: Trailing slot in rows stays free for content-bearing widgets — important for the dense expansion-tile bodies in `coordinator_screen.dart`.
* Good: Implementation cost per site is small. `ListTile.onLongPress` and `ExpandableTile.onLongPress` are built-in parameters.
* Good: The rule extends cleanly to the future feature-first layout from [ADR-0028](./0028-feature-first-views-layout.md): each feature folder applies the same gesture vocabulary.
* Bad: Long-press is less discoverable than a visible pencil icon, especially for users unfamiliar with mobile gesture conventions. We accept this trade-off because the Dismissible swipe already exists in two of the four affected views, so users already know to look for non-tap gestures here. The AppBar pencil remains visible once a row's detail sheet is open, so editing is never more than two interactions away.
* Bad: First-time users may not discover long-press without a hint. We do not add an onboarding tooltip in this ADR; if usability testing flags discoverability as a real problem, we revisit with a one-time hint banner.

## Pros and cons of the options

### Option A — Swipe and long-press, no row pencil

* Good: Single gesture vocabulary, preserves existing swipe, frees trailing slot, keeps AppBar pencil unambiguous.
* Bad: Long-press is less discoverable than a visible icon.

### Option B — Swipe and trailing row pencil, no long-press

* Good: Most discoverable; pencil is visually unambiguous.
* Bad: Trailing slot in coordinator-screen rows is busy (chevron + status). Pencil-in-row competes with AppBar pencil for the meaning of "edit". Adds visual noise to every editable list. Doesn't scale to `ExpansionTile` rows where the title row already crowds the trailing edge.

### Option C — Trailing row pencil only, drop swipe

* Good: One affordance, one place to look.
* Bad: Regresses an existing pattern that ships and works. Loses the edge-swipe shortcut that power users prefer. Loses the wider hit target swipe provides for small rows.

### Option D — Swipe only, no in-place gesture

* Good: Zero new code.
* Bad: Leaves the gap on rows where swipe is unavailable (some constrained layouts). Doesn't add a discoverable on-row gesture. Doesn't help users who do not realize swipe-to-edit is supported.

## Links

* Related ADRs:
  * [ADR-0026](./0026-sheet-based-context-navigation.md) — tap-opens-sheet semantics that long-press deliberately bypasses for a faster edit path.
  * [ADR-0028](./0028-feature-first-views-layout.md) — gesture vocabulary survives the upcoming feature-first refactor.
  * [ADR-0030](./0030-wide-screen-master-detail-layout.md) — same gestures apply to rows inside the master pane.
* Related prompts:
  * `docs/prompts/quick-wins-edit-affordances.md` — first PR to land under this convention.
* Related code:
  * `lib/views/station_list_view.dart:262-311` — reference implementation of the Dismissible pattern.
  * `lib/views/station_screen.dart:117-128` — reference implementation of the AppBar pencil and the `_isStarted` disabled-state rule.
  * `lib/views/coordinator_screen.dart` — primary site for the new `GestureDetector` long-press pattern.
  * `lib/views/teams_view.dart` — primary site for the new `ListTile.onLongPress` pattern.
