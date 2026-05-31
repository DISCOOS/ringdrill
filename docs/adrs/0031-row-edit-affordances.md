---
status: proposed
date: 2026-05-31
deciders: ["@kengu"]
consulted: []
informed: []
---

# ADR-0031: Row edit affordances use swipe and long-press; pencil reserved for AppBar

## Context and problem statement

Row-level edit is inconsistent today. `station_list_view.dart` and `roleplays_view.dart` ship `Dismissible(endToStart)` swipe-to-edit. `teams_view.dart` has no edit affordance. `coordinator_screen.dart` station and team rows route through tap → `ContextSheet` → AppBar pencil only.

The reflex when adding edit to more rows is to drop `IconButton(Icons.edit)` into each row's trailing slot. The slot is already busy (badges, switches, drag handles, expansion chevrons), pencil-in-row competes with the AppBar pencil for the meaning of "edit", and the chrome reads noisy. We need one rule before contributors start sprinkling `Icons.edit` ad-hoc.

## Decision drivers

* One gesture vocabulary across `ListTile`, `ExpansionTile`, `ExpandableTile`.
* `Icons.edit` keeps its meaning as the detail-screen edit action; reusing it in lists dilutes the signal.
* Trailing slot stays free for content widgets.
* Preserve the existing swipe-to-edit pattern.
* Coexist with [ADR-0026](./0026-sheet-based-context-navigation.md): tap is reserved for read.

## Considered options

* **Option A: Swipe and long-press on rows; pencil reserved for AppBar. (chosen)**
* **Option B: Swipe and trailing row pencil; no long-press.**
* **Option C: Trailing row pencil only; drop the swipe.**
* **Option D: Swipe only; no in-place gesture.**

## Decision outcome

Chosen option: **Option A**. Keeps `Icons.edit` AppBar-only, preserves the swipe, and adds an in-place gesture without consuming row real estate.

### Rule

1. Row edit affordances are `Dismissible(direction: DismissDirection.endToStart, confirmDismiss: ...)` and/or `onLongPress`. `confirmDismiss` returns `false` so the row is not removed.
2. `IconButton(Icons.edit)` (or any other pencil icon) must not appear inside row widgets (`ListTile`, `ExpansionTile`, `ExpandableTile`, `Card` wrappers, etc.).
3. `IconButton(Icons.edit)` lives in detail screens' `AppBar.actions` and overflow menus only. Reference: `lib/views/station_screen.dart:117-128`.
4. Both gestures call the same private edit handler and inherit the disabled-state rule from `station_screen.dart:117-128` (`_isStarted` guard + `localizations.stopExerciseFirst` snackbar).
5. When swipe is unavailable (rare; e.g. inside a horizontally swipeable container), long-press alone is sufficient.

### Implementation pattern

For `ListTile`-based rows:

```dart
ListTile(
  onTap: () => /* open ContextSheet (read) */,
  onLongPress: () => _openForm(entity),
)
```

For `ExpandableTile` rows:

```dart
ExpandableTile(
  onLongPress: () => _editStation(stationIndex),
  ...
)
```

`ExpandableTile.onLongPress` shares the row `InkWell` with `onTap`, so tap-to-expand still fires without an outer gesture wrapper.

### Sites bound by this rule

| Site                                    | Before                                   | After                                                    |
|-----------------------------------------|------------------------------------------|----------------------------------------------------------|
| `station_list_view.dart` rows           | Dismissible swipe                        | Dismissible swipe + `ExpandableTile.onLongPress`         |
| `roleplays_view.dart` rows              | Dismissible swipe                        | Dismissible swipe + `ExpandableTile.onLongPress`         |
| `teams_view.dart` rows                  | tap-opens-sheet only                     | Dismissible swipe + `ListTile.onLongPress`               |
| `coordinator_screen.dart` station rows  | tap-opens-sheet only                     | Dismissible swipe + `ExpandableTile.onLongPress`         |
| `coordinator_screen.dart` team rows     | tap-opens-sheet only                     | `ExpandableTile.onLongPress` (no swipe today)            |
| `program_view.dart` exercise card       | Dismissible (primary bg, no label)       | Dismissible (`secondaryContainer` bg + `editExercise` label) |
| Detail screens' `AppBar.actions`        | `IconButton(Icons.edit)`                 | unchanged                                                |

Out of scope: chart cells, table cells, map markers, brief-view sections, settings rows.

### Consequences

* Good: One gesture vocabulary for every editable row.
* Good: `Icons.edit` retains its meaning as the detail-screen edit signal, and the trailing slot stays free for content widgets.
* Good: Built-in `ListTile.onLongPress` and `ExpandableTile.onLongPress` make per-site cost one line.
* Bad: Long-press is less discoverable than a visible icon. Mitigation: swipe-to-edit already exists in two views, so users have precedent for non-tap gestures, and the AppBar pencil remains reachable in two interactions.

## Pros and cons of the options

### Option A — Swipe and long-press, no row pencil

* Good: Single gesture vocabulary, preserves the swipe, frees the trailing slot.
* Bad: Long-press less discoverable than an icon.

### Option B — Swipe and trailing row pencil

* Good: Most discoverable.
* Bad: Trailing slot is busy in coordinator rows. Pencil-in-row competes with the AppBar pencil. Doesn't scale to dense `ExpansionTile` titles.

### Option C — Pencil only, drop swipe

* Good: One affordance.
* Bad: Regresses an existing pattern. Loses the wider hit target swipe gives small rows.

### Option D — Swipe only

* Good: Zero new code.
* Bad: No on-row gesture where swipe is unavailable. Doesn't help users unaware that swipe-to-edit is supported.

## Links

* Related ADRs:
  * [ADR-0026](./0026-sheet-based-context-navigation.md) — tap-opens-sheet semantics that long-press bypasses for a direct edit path.
  * [ADR-0028](./0028-feature-first-views-layout.md) — gesture vocabulary survives the feature-first refactor.
  * [ADR-0030](./0030-wide-screen-master-detail-layout.md) — same gestures apply inside the master pane.
* Related prompts:
  * `docs/prompts/quick-wins-edit-affordances.md` — first PR under this convention.
* Related code:
  * `lib/views/station_list_view.dart:262-311` — reference Dismissible implementation.
  * `lib/views/station_screen.dart:117-128` — reference AppBar pencil + `_isStarted` disabled-state.
  * `lib/views/widgets/expandable_tile.dart` — `onLongPress` parameter.
