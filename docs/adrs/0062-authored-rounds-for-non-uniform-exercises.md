---
status: proposed
date: 2026-07-30
deciders: ["kengu"]
consulted: []
informed: []
---

# ADR-0062: Author an exercise's rounds explicitly when they are not uniform

## Context and problem statement

An exercise's schedule is derived from `startTime`, `numberOfRounds` and the
three phase durations, with every round occupying the same cycle
`executionTime + evaluationTime + rotationTime` (`ExerciseSchedule`,
`lib/models/schedule.dart`). One cycle, multiplied. That assumption holds for a
ring exercise, which is what the model was built for, and it is how most of a
course day is actually run.

It does not hold for the rest of the day. Converting the 2026 LSOR course booklet
found that **three of its seven exercises** cannot be expressed:

* **Øvelse 4** — two posts, but all four teams work one post at a time, each team
  on its own patient coordinate, then all move together. Not a rotation.
* **Øvelse 6** — one post, all teams in the same action.
* **Øvelse 7** — four posts whose executions run 70, 100, 75 and 75 minutes, and
  whose last two posts run **concurrently**: teams split, half on post c, half on
  post d, both starting 23:45.

The documented workaround for the first two is `numberOfTeams: 1`, meaning "the
real teams are grouped into one" — it is in the authoring skill and it is what
the conversion used. It costs accuracy in the brief, which then labels a merged
four-team group `Lag 2.1`, but the schedule stays right.

Øvelse 7 has no workaround. Modelled as one exercise it needs a single cycle for
four rounds that do not share one, and its derived window comes out 20:15–02:35
against a real 20:15–01:15 — 80 minutes of time that does not exist. The
conversion shipped it with the wrong grid and a note in `execution_tips` telling
the reader not to trust it, which is the correct thing to do and also an
admission that the format could not carry the plan.

Splitting Øvelse 7 into two or three model exercises fixes the timing and breaks
something else. Station codes derive from position — exercise index plus station
index, rendered `7a`…`7d` under `stationNumberFormat: alpha` — so a split
renumbers posts c and d to `8a` and `8b`, discarding the labels the booklet, the
participants and the veiledere all use. Writing `7c)` into the station name
instead double-numbers it (`8a 7c) Assistanse turgåer`), which is precisely the
mistake ADR-0059's derived numbering exists to prevent. Derived numbering is
therefore what forces a booklet's phase group into one model exercise, and one
model exercise is what forces a single cycle onto phases that do not share one.

The wire format is not the obstacle. `Exercise.schedule` is already a
`List<List<SimpleTimeOfDay>>` — one `[roundStart, executionEnd, evaluationEnd]`
triple per round (ADR-0007) — so an archive can already describe rounds of
differing lengths. Only the derivation, and therefore the source format, insists
they be identical. `schedule.dart` is the single implementation of that
derivation and says so: "If you change the phase model here, that is the whole
change: there is nothing else to keep in step."

## Decision drivers

* A derived schedule is not decorative: it drives the brief and the exercise
  player. A wrong one is worse than an absent one, because the reader cannot tell
  it is wrong.
* The uniform case must stay as terse as it is now. Most exercises are ring
  exercises and `numberOfRounds` plus three durations is the right way to say so.
* Numbering stays derived from list position; names stay opaque and unparsed
  (ADR-0059). A fix must not reintroduce authored numbering.
* The format stays authored-fields-only — the schedule remains derived, not
  written (ADR-0058).
* The `.drill` wire format and the round-trip `contentHash` invariant must hold
  (ADR-0007, ADR-0059).
* Real plans are the specification. Three of seven exercises in the first real
  booklet converted is not an edge case.

## Considered options

* Option A — Status quo: document the limitation in the authoring skill and let
  authors put the real timeline in `execution_tips`.
* Option B — An optional authored `rounds:` list on the exercise, where each
  entry may carry its own phase durations and may name the stations active in
  that round.
* Option C — Per-round phase durations only, with no way to express concurrency.
* Option D — An authored display `code` on exercises and stations, so a booklet
  phase group can be split across several model exercises and still render
  `7a`…`7d`.
* Option E — Split such exercises and accept the renumbering.

## Decision outcome

Chosen option: **Option B**, because it makes a round the authored unit instead
of a multiplier, which is the one change that covers both failures — unequal
round lengths and concurrent posts — without touching numbering, the wire format
or the terse uniform case.

`numberOfRounds` and the three durations remain, and remain the whole story when
every round is the same. When they are not, an exercise may instead list its
rounds:

```yaml
rounds:
  - executionTime: 70
  - executionTime: 100
  - executionTime: 75
    stations: [3, 4]   # posts c and d run concurrently
```

A round inherits any duration it does not state from the exercise. A round that
names `stations` restricts that round's rotation to them, so two stations and two
teams in one round means the two run side by side — the same mechanism as an
exercise with `numberOfTeams: 2` and one round, generalized to a single round of
a longer exercise. `ExerciseSchedule` walks the list accumulating a running
start instead of multiplying one cycle, and `endTime` becomes the sum. Since
`Exercise.schedule` is already per-round, the archive absorbs the result
unchanged.

The timing half and the concurrency half are separable in implementation: the
first is confined to `schedule.dart` and its two callers, while the second also
touches team-to-station assignment. If the second grows beyond that, it gets its
own ADR rather than expanding this one.

### Consequences

* Good: a plan's derived schedule can match the clock the course actually runs
  on, so the brief stops contradicting itself and `execution_tips` stops being a
  place to warn readers off the computed grid.
* Good: concurrent posts become expressible, so a booklet's phase group stays one
  exercise and keeps its derived `7a`…`7d` codes.
* Good: numbering, names and the round-trip invariant are untouched; the schedule
  stays a derived field.
* Good: the uniform case is unchanged — existing documents and every plan in the
  catalog keep building byte-identically, since `rounds:` is optional.
* Bad: two ways to say how long an exercise runs, and a precedence rule between
  them to document and validate (`rounds:` and `numberOfRounds` together must be
  rejected, or one must clearly win).
* Bad: `decompile` has to choose. Emitting `rounds:` always would make every
  document more verbose than the author wrote; emitting it only when rounds
  differ means the decompiler inspects the schedule to decide shape.
* Bad: per-round `stations` is a second way to control rotation alongside
  `numberOfTeams`, and the two can be made to contradict each other, so
  `analyze` needs a rule for it.
* Bad: the exercise player assumes rounds are interchangeable in length in
  places; a non-uniform exercise will surface those assumptions.

## Pros and cons of the options

### Option A — Status quo, documented
* Good: no change to format, compiler, wire or app.
* Good: honest, if the limitation is written down where authors will hit it.
* Bad: leaves a known-wrong derived schedule in a shipped plan, mitigated only by
  prose the reader may not reach.
* Bad: the workaround for grouped teams (`numberOfTeams: 1`) already misreports
  the team in the brief, and this compounds it.

### Option B — Authored `rounds:` list
* Good: one concept covers unequal durations and concurrency.
* Good: wire format already supports the result; one derivation to change.
* Bad: a second shape for exercise timing, with a precedence rule.
* Bad: `decompile` must decide when to emit it.

### Option C — Per-round durations only
* Good: the smallest possible change, entirely inside `schedule.dart`.
* Bad: does not fix Øvelse 7, the case that motivated this. Four sequential
  rounds of 70/100/75/75 still total 395 minutes against a real 300, because the
  error is concurrency, not duration.
* Bad: would need a second ADR almost immediately, for the same exercise.

### Option D — Authored display codes
* Good: needs no change to the schedule model at all; splitting an exercise
  becomes free and every timing problem dissolves into ordinary exercises.
* Bad: reintroduces authored numbering as a first-class field, against ADR-0059's
  central principle that a code is derived from position and never authored.
* Bad: an exercise code alone is insufficient — station letters restart per
  exercise, so a split phase group would collide (`7a`, `7b`, then `7a` again)
  unless station codes are authored too. That is the whole numbering scheme back
  in the author's hands.

### Option E — Split and accept renumbering
* Good: expressible today, with no format change.
* Bad: throws away the codes the domain uses to refer to its own posts, in a
  booklet where `7c` is how a veileder names a post out loud.
* Bad: silently changes the meaning of a published plan's labels if applied to an
  existing one.

## Links

* Related ADRs: [ADR-0058](./0058-source-format-and-plan-compiler.md),
  [ADR-0059](./0059-drill-schema-migration-ladder.md),
  [ADR-0007](./0007-drill-file-format.md),
  [ADR-0056](./0056-player-modes-exercise-station-roleplay.md)
* Related code: `lib/models/schedule.dart` (`ExerciseSchedule`),
  `lib/models/exercise.dart` (`schedule`, `endTime`),
  `lib/services/plan_service.dart` (`generateSchedule`),
  `lib/data/source/source_fields.dart`
* Origin: converting `assets/example/2026 LSOR øvelseshefte.docx`, where Øvelse
  4, 6 and 7 could not be expressed as uniform rotations.
