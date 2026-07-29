---
status: open
severity: medium
discovered: 2026-07-29
resolved: null
related_adrs: ["ADR-0035"]
---

# DEBT-0013: An exercise has a time of day but no day

## What

`Exercise.startTime` and `endTime` are `SimpleTimeOfDay` — a clock face with no date. Anything needing an absolute instant has to guess which day the face belongs to, and every guess so far has been made independently at the call site. Four separate bugs came from that in one sweep, all fixed, all the same mistake.

The remaining debt is the modelling gap itself: a plan spanning more than one day cannot say so.

## Where

* `lib/models/exercise.dart` — `startTime`/`endTime`, and `windowAt`, which is the current answer to "which day".
* `lib/services/exercise_service.dart` — resolves the window once per run, anchored on `_startedOn`.
* `lib/views/widgets/schedule_card.dart` — `scheduleWindowSummary`, which now takes the span modulo a day.
* `lib/data/plan_repository.dart:352` — sorts `Session`s by `Session.startTime`, also a clock face, though sessions carry real `startedAt`/`endedAt` `DateTime`s that would sort exactly.

## Why it is debt

Bugs already paid for, kept here so the next reader knows the shape:

* Starting a 23:00 exercise at 00:30 waited 22.5 hours instead of resuming 90 minutes in. The rollover pushed the *end* to tomorrow and left the start on today, so "now" fell before a window it was inside.
* The plan list read "20:15 - 01:15 | 19 timer" — 24h minus the real 5h, the difference taken across one calendar day.
* `scheduleWindowSummary` rendered `(-22 h)` on four surfaces for the same reason.
* The coordinator's pending countdown printed "0 sec" for any wait under an hour: `DateTimeX.fromMinutes` built a `DateTime` whose hour and minute *fields* were the remaining hours and minutes, then took its distance from the wall clock.

Each was cheap to fix in isolation, which is exactly the risk: the model invites a per-call-site guess, every guess looks reasonable, and a wrong one produces a plausible number rather than a crash. "19 timer" and "(-22 h)" both shipped.

What is *not* yet solved is multi-day. `Exercise.index` gives an explicit order (ADR-0035), and a day can be inferred from it by walking the list and advancing whenever the next start falls before the previous end. That covers a single night — 23:00 then 01:00 is unambiguous once the sequence is known. It cannot cover a plan spanning days with a gap: an exercise weekend with Saturday 09:00 and Sunday 09:00 shows no backwards step, so inference puts both on the same day.

Nothing needs that today. The runtime window resolves against the actual clock, so a *running* exercise behaves correctly whichever day it belongs to, and ordering is explicit rather than derived from time. The gap becomes real the moment something needs a plan's absolute timeline.

## Suggested fix

Not before there is a consumer. Picking the semantics of a persisted field with nothing reading it means guessing, and it is a wire change.

When one appears — multi-day scheduling, "what is next" across a weekend, grouping sessions by day — prefer an **explicit day offset on the exercise** over inferring it from the order:

* Inference is a heuristic that fails silently on precisely the multi-day plans that motivate it, and a wrong day is much harder to notice than a missing field.
* An offset is additive: `@Default(0) int dayOffset`, absent in existing files, so it reads back unchanged.

Route every new consumer through `Exercise.windowAt` rather than resolving times at the call site. That is the seam the four fixes converged on, and it is where an offset would be applied once.

Two smaller items that can be done independently:

* Sort sessions by `startedAt` rather than `startTime`, since the exact instant is already stored.
* Consider whether `SimpleTimeOfDay` should be harder to misuse — every one of the four bugs involved converting one to a `DateTime`, or subtracting two, at a call site.

## Links

* Related ADRs: [ADR-0035](../adrs/0035-exercise-ordering.md) — explicit exercise order, which supplies the sequence any inference would need.
* Related code: `lib/models/exercise.dart` (`windowAt`, `scheduledDuration`), `test/models/exercise_window_test.dart`, `test/services/exercise_service_midnight_test.dart`.
