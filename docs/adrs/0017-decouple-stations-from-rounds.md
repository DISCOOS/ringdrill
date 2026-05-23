---
status: accepted
date: 2026-05-23
deciders: ["@kengu"]
consulted: []
informed: []
---

# ADR-0017: Decouple number of stations from number of rounds in exercise setup

## Context and problem statement

Today an exercise has three configuration counters: `numberOfTeams`, `numberOfRounds` and an implicit `numberOfStations`. The implicit one is derived inside [`ProgramService.generateSchedule`](../../lib/services/program_service.dart): `ensureStations(localizations, numberOfRounds, stations)` always creates exactly `numberOfRounds` stations, so `stations.length == numberOfRounds` is a structural invariant. The form in [`ExerciseFormScreen`](../../lib/views/exercise_form_screen.dart) therefore validates `numberOfTeams <= numberOfRounds`. The underlying intent is "you cannot have more teams than stations" because the rotation math in [`exercise.dart`](../../lib/models/exercise.dart) reduces modulo `stations.length` and would otherwise map two teams to the same station in the same round.

This invariant blocks a real-world setup: a ring drill with one round, four teams and four stations. Each team starts at its own station, performs the drill once, and the exercise ends. With the current model the only way to get four stations is to request four rounds, which misrepresents the schedule.

The root cause is that "how many stops are physically prepared in the field" and "how many times the schedule advances" are two different concepts that the code conflates. This ADR separates them.

## Decision drivers

* The rotation math in `ExerciseX.teamIndex` and `ExerciseX.stationIndex` already operates correctly for any combination of teams, stations and rounds. The conflation lives entirely in setup-time generation and form validation.
* The drill-file schema ([ADR-0007](./0007-drill-file-format.md)) already stores `stations: List<Station>` directly. No schema bump is needed and existing exercises continue to load.
* The Stations tab design ([DESIGN-002](../design/stations-tab.md)) scopes station structural edits to exercise setup, so the change fits inside one surface.
* Default behaviour must match the common case ("every team visits every station") so users do not have to fill in a new field for typical configurations.

## Considered options

* **Option A: Add an explicit `numberOfStations` field defaulting to `numberOfTeams` (chosen).** Stations become a first-class field. Rounds become a multiplier on the rotation. Revisits when `numberOfRounds > numberOfStations` are allowed with a soft warning.
* **Option B: Derive stations from `max(numberOfTeams, numberOfRounds)`.** No new field, but the rule driving station count stays hidden and "more stations than teams or rounds" remains inexpressible.
* **Option C: Keep the invariant, just relax the form check.** Breaks the one-round-four-stations case because `ensureStations(numberOfRounds=1, ...)` still produces one station and three of four teams become orphans.
* **Option D: Move station management out of the exercise form into a dedicated UI.** Cleaner long term but much larger than what is needed to unblock the use case. Can land on top of Option A later.

## Decision outcome

Chosen option: **Option A**, because it makes the three counters independent, keeps the common case ergonomic through the `numberOfTeams` default, and surfaces revisits as a soft warning rather than blocking them.

### Model and code changes

* `ExerciseFormScreen` gains a third numeric field "Number of stations" / "Antall poster". It is pre-populated to `numberOfTeams` and follows that field until the user edits it manually. On an existing exercise the initial value comes from `stations.length` on the loaded exercise so a roundtrip through the form is loss-free.
* `ProgramService.generateSchedule` takes a `numberOfStations` parameter and calls `ensureStations(localizations, numberOfStations, stations)`. The internal assert becomes `numberOfTeams <= numberOfStations`.
* Form validation rules:
  * Stations must be `>= numberOfTeams`.
  * Teams must be `<= numberOfStations`.
  * Rounds must be `>= 1`, no upper bound from the model.
* No changes to rotation math in `lib/models/exercise.dart` and no drill-file schema bump.

### Soft notes in the form

When `numberOfRounds > numberOfStations` an inline informational note appears beneath the rounds field. Save stays enabled.

> Each team will revisit some stations. With N rounds and M stations every team passes through each station roughly N/M times.

A symmetric note covers `numberOfRounds < numberOfStations`:

> Each team will only visit N of M stations during this exercise.

Both notes use helper-text styling and are localized in `app_en.arb` and `app_nb.arb`.

### Consequences

* Good: One-round-four-stations and similar configurations become expressible.
* Good: Future readers of the rotation math see three independent counters instead of an implicit invariant.
* Good: No drill-file schema change. Older exercises round-trip unchanged.
* Bad: One more field on the form.
* Bad: The "stations follow teams until manually edited" rule is implicit per-session state and easy to get subtly wrong in implementation.
* Bad: The rotation-share text does not annotate revisits, so observers seeing the same station name twice for the same team may be momentarily confused. The setup-time warning is the only mitigation.

## Pros and cons of the options

### Option A — Explicit `numberOfStations` field, default to `numberOfTeams`

* Good: Three independent counters at every layer.
* Good: Default keeps muscle memory intact for the common case.
* Good: Revisits become an expressible configuration without losing safety, via the soft warning.
* Bad: One more form field.
* Bad: Implicit "follow teams" link is per-session state.

### Option B — Derive stations from `max(numberOfTeams, numberOfRounds)`

* Good: No new field.
* Bad: Cannot express more stations than the larger of teams and rounds.
* Bad: The rule driving station count is still hidden, which is the original problem in a different shape.

### Option C — Just relax the form check

* Bad: Breaks the headline use case.
* Bad: Leaves the structural invariant in place.

### Option D — Move station management out of the exercise form

* Good: Cleaner long-term separation between schedule and station configuration.
* Bad: Much larger change. DESIGN-002 already scopes Stations-tab ownership away from add/remove/reorder, so this option would need its own design. The natural follow-up to A is still D, but A is sufficient alone.

## Links

* Related ADRs:
  * [ADR-0007](./0007-drill-file-format.md) — drill file format. No schema bump required.
* Related designs:
  * [DESIGN-002](../design/stations-tab.md) — Stations tab. Defers structural changes to exercise setup.
* Related code:
  * `lib/models/exercise.dart` — rotation math, no changes.
  * `lib/services/program_service.dart` — `generateSchedule` and `ensureStations` parameter change.
  * `lib/views/exercise_form_screen.dart` — new field, new validators, soft-warning notes.
  * `lib/l10n/app_en.arb`, `lib/l10n/app_nb.arb` — new helper-text strings.
