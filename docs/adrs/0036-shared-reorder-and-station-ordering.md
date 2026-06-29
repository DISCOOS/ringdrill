---
status: accepted
date: 2026-06-29
deciders: ["@kengu"]
consulted: []
informed: []
---

# ADR-0036: Extract a shared reorder section and let stations be reordered in the Stations segment and coordinator

## Context and problem statement

[ADR-0035](./0035-exercise-ordering.md) gave exercises an explicit `index` and a reorder UI: an order list header with one-shot sort actions and a reorder toggle that switches the list into a `ReorderableListView`. That logic currently lives inline in `_ExercisesListHeader` and the reorder/default list builders in [`program_view.dart`](../../lib/views/program_view.dart).

Two gaps surfaced once that shipped:

1. **Stations cannot be reordered.** The visiting order of stations is meaningful, but there is no way to change it. Stations already carry an `index` and sort on it, exactly like exercises did before ADR-0035 — they are missing only the UI and the persistence path.
2. **The coordinator station list is inconsistent with the Stations segment.** The station rows in [`coordinator_screen.dart`](../../lib/views/coordinator_screen.dart) use `leading: accent.indicator` and never show the `StationNumberBadge` that the Stations segment renders, so the same station reads differently in the two places.

Rebuilding the ADR-0035 reorder machinery a second time for stations (and a third for any future list) would duplicate non-trivial UI state. The reorder header, the mode toggle, the gesture suspension and the `ReorderableListView` wiring are identical across lists; only the row content, the available sorts and the persistence callback differ.

Markers are explicitly out of scope: a marker already references its station through `RolePlay.stationIndex`, so its order follows its post rather than being set independently. There is no separate marker order to manage.

## Decision drivers

* The reorder UI from ADR-0035 is list-agnostic except for row rendering, sort actions and persistence. Extracting it removes duplication and keeps the three lists behaving identically.
* Stations are identified positionally by `Station.index`, and several things key off that index: the rotation math in `ExerciseX.teamIndex` / `stationIndex`, the schedule, the map marker ids, and `RolePlay.stationIndex`. Reordering must keep those references pointing at the same logical station.
* Station order feeds the live rotation, so reordering during a running exercise would scramble where teams are sent. Reorder must be unavailable while running.
* [ADR-0017](./0017-decouple-stations-from-rounds.md) scoped station structural edits to exercise setup. Allowing reorder in the Stations segment and the coordinator extends that, so this ADR has to say so explicitly.
* The coordinator and Stations segment should render a station the same way, including the number badge ([ADR-0034](./0034-configurable-numbering-formats.md)).

## Considered options

* **Option A: Extract a shared `ReorderableSection` widget; use it for exercises, Stations-segment stations and coordinator stations; reorder updates `Station.index` and remaps dependent references (chosen).**
* **Option B: Copy the ADR-0035 reorder code into the station surfaces.** No new abstraction, but the same UI state is maintained in three places.
* **Option C: Give stations a stable uuid and reorder by an order field separate from the rotation index.** Cleanest reference model, but a much larger change to the station model, the drill schema and the rotation math.

## Decision outcome

Chosen option: **Option A**. It removes the duplication ADR-0035 would otherwise spawn, ships station reorder where it is wanted, and keeps station references intact by remapping on reorder rather than restructuring the model. Option B entrenches duplication; Option C is a model overhaul disproportionate to the need, and can be revisited if positional station indices become painful elsewhere.

### Shared `ReorderableSection` widget

A new widget under `lib/views/widgets/` owns everything that is list-agnostic in the ADR-0035 implementation:

* The order header: the anchor label, an optional list of one-shot sort actions (each a label + callback), and the reorder / done toggle (`OutlinedButton.icon` with the rounded-rectangle shape, not a stadium — per ADR-0035's chosen layout).
* The mode flag and the swap between a plain list (default) and a `ReorderableListView` (reorder mode), including suspending row tap/swipe/long-press while reordering and relying on the framework's "move up/down" semantics for accessibility.
* The deferred-commit behaviour from ADR-0035: drags mutate an in-memory working copy synchronously, and `onReorder` fires once when the user leaves reorder mode rather than on every drop, so a dropped row never snaps back while an async save races the animation.

It is parameterised by: `itemCount`, a row builder for default mode, a row builder (or trailing drag-handle hook) for reorder mode, an `onReorder` callback, an optional `sortActions` list, the anchor label, and an `enabled` flag (false hides the toggle, e.g. while running). `_ExercisesListHeader` and the two list builders in `program_view.dart` are refactored to use it so exercises gain nothing new but lose their bespoke copy.

Sort actions stay per-call-site: exercises keep start-time and alphabetical sorts; stations expose alphabetical only (start time is not a station property) — or no one-shot sort at all if that reads cleaner, with the manual reorder toggle always present.

### Station reorder and reference remapping

Reordering writes new `Station.index` values to reflect the new order, persisted on the owning `Exercise` through `ProgramService.saveExercise`. Because stations are referenced positionally, a reorder computes the old→new index permutation and applies it to everything keyed on station index in the same write:

* `RolePlay.stationIndex` is remapped so each marker follows its post (the "markers follow their stations" rule). The marker lists re-sort to the new station order as a consequence; markers themselves get no reorder UI.
* The rotation math and schedule are recomputed for the new order via the existing `ProgramService.generateSchedule` path, the same recompute used elsewhere when stations change.
* Map marker ids (`MapMarkerSpec<int>` built from `station.index`) follow naturally because they are derived from the stations on each build.

### Where stations can be reordered

* **Stations segment** (`StationListView`): full reorder, mirroring the Exercises segment.
* **Coordinator** (`coordinator_screen.dart`): reorder allowed only when the exercise is not running. The `ReorderableSection` `enabled` flag is wired to the live state, so the reorder toggle is hidden (or disabled) while a session is live, protecting the rotation. This refines [ADR-0017](./0017-decouple-stations-from-rounds.md): station reorder is no longer confined to exercise setup, but structural add/remove stays as ADR-0017 left it.

### Coordinator station badge

The coordinator station rows gain the `StationNumberBadge` in the `leading` slot, fed by `Numbering.station(program.stationNumberFormat, …)` exactly as the Stations segment does, so a station reads identically in both places. This is a small consistency fix folded into this ADR rather than carried as a separate one.

### Consequences

* Good: One reorder implementation behind a shared widget; exercises, Stations-segment stations and coordinator stations all use it.
* Good: Station visiting order becomes user-editable where it makes sense, and the same station renders consistently across surfaces.
* Good: Markers need no reorder surface — they follow their post for free once `stationIndex` is remapped.
* Good: Reorder-while-running is structurally prevented, protecting the live rotation.
* Bad: Station reorder must remap every index-keyed reference in one transaction; a missed reference (a marker left pointing at the wrong post) is a silent data bug, so this needs focused tests.
* Bad: Extends ADR-0017's "structural edits live in setup" boundary, which has to be communicated so the scoping rule is not assumed elsewhere.
* Bad: Positional `Station.index` remains the identity mechanism; Option C's stable-uuid model is deferred, so future reference types will also need remapping.

## Pros and cons of the options

### Option A — Shared widget + index remap

* Good: Removes duplication, ships the wanted feature, keeps references intact without a model overhaul.
* Good: `enabled` flag cleanly gates reorder by live state.
* Bad: Remapping is error-prone and needs tests; positional identity persists.

### Option B — Copy the reorder code per surface

* Good: No new abstraction.
* Bad: Same reorder state maintained in three places; fixes and a11y tweaks must be repeated.

### Option C — Stable station uuid + separate order field

* Good: References survive reorder without remapping; cleanest long-term identity.
* Bad: Touches the station model, the drill schema, the rotation math and every station reference; far larger than the problem.

## Links

* Related ADRs:
  * [ADR-0035](./0035-exercise-ordering.md) — exercise reorder; the source of the UI being extracted.
  * [ADR-0034](./0034-configurable-numbering-formats.md) — the station number badge added to the coordinator.
  * [ADR-0017](./0017-decouple-stations-from-rounds.md) — station structural edits in setup; refined here for reorder.
  * [ADR-0018](./0018-roleplayer-data-model.md) — `RolePlay.stationIndex`, the reference remapped on reorder.
* Related code:
  * `lib/views/widgets/` — new `ReorderableSection` widget.
  * `lib/views/program_view.dart` — refactor `_ExercisesListHeader` and the list builders onto it.
  * `lib/views/station_list_view.dart` — Stations-segment station reorder.
  * `lib/views/coordinator_screen.dart` — station reorder gated by live state, plus the `StationNumberBadge`.
  * `lib/services/program_service.dart` — station reorder writing `Station.index`, remapping `RolePlay.stationIndex`, recomputing the schedule.
</content>
