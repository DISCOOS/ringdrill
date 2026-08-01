---
status: proposed
date: 2026-07-30
deciders: ["kengu"]
consulted: []
informed: []
---

# ADR-0062: Express a non-uniform exercise as a mode plus station durations

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
* **The author must not be handed the arithmetic back.** Not needing to work out
  round times is most of what RingDrill is for. A fix that asks the author to
  compute, enumerate or translate what they already know into the model's terms
  has traded the product's central promise for expressiveness, and that is not a
  trade worth making — however terse the YAML looks.
* The editor must stay a form of scalar fields for the common case. An unbounded
  list of rounds, with inheritance rules to explain, is a different kind of
  surface from the one an exercise has today.

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
* **Option F — A mode plus station-owned durations.** An exercise states *how
  teams relate to posts* (`ring`, `together`, `split`); a station may state its
  own execution time where it differs; in `split`, the author places teams on the
  posts that run at once. Rounds are not authored at all — the round structure and
  every clock face follow.

## Decision outcome

Chosen option: **Option F**.

Option B was chosen first and is superseded here. It survives as an option below
because its reasoning about numbering and the wire format still holds; what it got
wrong is who does the work.

### Why Option B was wrong

`rounds:` does not make the author write clock times — durations go in, the
compiler derives the schedule. So it does not break the promise outright. It
breaks it in two subtler ways.

**It asks for a translation.** The booklet does not say "round 2 is 100 minutes".
It says **"post b takes 100 minutes"**. Every duration in the source document
belongs to a *post*. Under `rounds:` the author has to work out which round that
post is visited in and write the duration there — arithmetic, done by hand, of
exactly the kind this tool exists to remove. And the translation is only stable
while the rotation is: reorder the posts and every round entry is wrong, silently.

**It is enumerative where the format is declarative.** Today an exercise says
what it *is* — "four teams rotate through four posts, 15/10/5, four rounds" — and
the timeline falls out. `rounds:` says what *happens*, round by round. To state one
fact about one round of six, the author writes six entries. In the editor that is
four number fields becoming a list surface with per-round inheritance to explain,
which is the ergonomic cliff that stopped this ADR from being implemented for as
long as it has.

### The decision

Two authored facts, both declarative, neither a time.

**A mode on the exercise**, saying how teams relate to posts:

* `ring` — today's behaviour, and the default. Teams rotate; one team per post.
  Labelled **Ring Route** in the UI. "Ring Drill" is deliberately not the label: it
  names the whole domain this app is about — the product, and the kind of
  exercise-and-station plan it describes — and reusing it for one mode of one
  exercise would make the general term mean a specific thing.
* `together` — all teams work one post at a time and move on together.
* `split` — any number of posts running at once, with the teams divided between
  them, in groups that need not be the same size.

**One model, three presets.** There is a single structure underneath: a round is a
set of **groups**, and a group is one post with some teams on it. The modes are group
sizes. `ring` is every group holding exactly one team; `together` is one group
holding all of them; `split` is anything in between — four teams across three posts
is 2 + 1 + 1. None of the three is a different mechanism.

They stay three modes rather than one exposed group model because `ring` and
`together` are the two that can be **generated**. An author who picks `ring` assigns
nothing at all, which is the entire ergonomic argument: authoring cost rises with
irregularity and nowhere else. Exposing the group model directly would charge every
exercise for the existence of the odd one, which is the mistake `rounds:` made.

**In `split`, the team-to-post assignment is authored.** Which teams take the missing
child and which take the shoreline is a decision — competence, travel, who has the
dog — and the app has no basis for guessing it. This is the one place in the design
where the author assigns something by hand, and it is deliberate: it is a decision,
not a computation. `ring` and `together` derive their assignment and cost nothing.

**Two validation rules follow**, and both belong in `analyze` as well as in the
editor, so a document written by hand is not told less than the app tells:

* A team in two posts of the same parallel group is an **error**. The posts run at
  once; a team can be at one of them. Both placements are flagged rather than one,
  because neither is more wrong and the author is the one who knows which to drop.
* A team in no post of a group is a **warning**, promoted by `--strict`. Holding a
  team back is legitimate; with groups of unequal size it is also easy to do by
  accident.

**Unequal round lengths are already a consequence, not a fourth mode.** A round's
length is the execution time of the posts live in it, so rounds differ wherever the
posts do: `together` gives one round per post — Øvelse 7's 70/100/75 — and `split`
one round per group. `ring` alone keeps its rounds equal, and must: every post is
live in every round, so the longest sets all of them, and what varies is which teams
wait.

Two things still cannot be expressed, and neither belongs in the mode enum: the same
post taking different times on different visits, and phase durations varying by
round. The mode axis is *which teams are on which posts*; duration is an orthogonal
axis, wanted independently in all three modes. A fourth member mixing them would also
be the only mode that cannot be **generated**, which is the property the other three
depend on for costing nothing.

If a real plan needs either, the shape is a **per-round override composing with the
mode** — the mode decides who is where, the override adjusts that round's phases.
That is Option C, argued against above on ergonomic grounds and deliberately left
unbuilt: the booklet that produced three failing exercises did not need it, and "real
plans are the specification" is one of this ADR's own drivers. Recorded here so a
later reader finds the extension point rather than reopening the mode enum.

**Switching mode is not symmetric.** Leaving `ring` or `together` costs nothing,
since neither stored anything the author typed. Leaving `split` discards the groups
and their assignments, because a generated mode has nowhere to put hand-placed teams.
The confirmation says which case it is rather than offering one generic warning.

**An execution time on a station**, inherited from the exercise unless stated.
Written in the station editor, next to the post it belongs to, because that is
where the author already is when they know it.

Everything else stays derived. A round's length is the execution time of the
post(s) active in it, plus the exercise's evaluation and rotation. In `ring` with
unequal posts that means the round is as long as its longest active post and the
teams on shorter posts wait — which is what happens on the day, and is now shown in
the editor instead of discovered on the field.

**Shown as the round table, not as a new chart.** All three modes render the same
table the brief already prints (`{{exercise.roundTable}}`,
`rotationRoundTable`); `together` and `split` add a Station column, because in those
modes a round *is* a station or a group of them. An author who has read a brief has
already read this table, and there is one implementation to keep true rather than
two — the same argument ADR-0067 made for building the token browser on the existing
picker instead of a third bespoke layout.

How the three failing exercises read:

* **Øvelse 4, 6** — `together`. This also retires the `numberOfTeams: 1`
  workaround, which existed only to make the schedule come out right and which
  makes the brief label a merged four-team group `Lag 2.1`. A second, separate bug
  closed by the same change.
* **Øvelse 7** — posts a and b sequential, c and d as one concurrent group under
  `split`. Four station durations and one grouping. Derived window 20:15–01:15
  against today's 20:15–02:35.

Drawn in
[`docs/design/mockups/exercise-modes.html`](../design/mockups/exercise-modes.html),
which is the artefact to review before any of this is built: nine states, including
the ones that are easy to skip — an unequal ring with its idle time visible, the
inherited-versus-overridden station field, and what changing an exercise's mode
tells the author before they commit.

### Consequences

* Good: the author never states a time, a round or a round count. They state a
  mode and, where it differs, how long a post takes — both things they already
  know without computing anything. In `split` they also place teams, which is a
  decision they were going to make anyway.
* Good: authoring cost is proportional to irregularity. Nothing for a ring drill,
  nothing for an all-together exercise, one assignment per team only where the
  exercise genuinely is irregular.
* Good: the editor stays a form. One more field with three options on the
  exercise, one optional override on the station, and a grouping affordance that
  appears only in `split`. No list surface, no inheritance rules to teach.
* Good: the derived schedule becomes the thing the author *reads* instead of the
  thing they reproduce, in the representation they already know. Idle time, which
  the model has always implied and never shown, becomes visible — as a second small
  table rather than a new kind of graphic.
* Good: a plan's derived schedule can match the clock the course actually runs on,
  so `execution_tips` stops being a place to warn readers off the computed grid.
* Good: concurrent posts stay one exercise, keeping their derived `7a`…`7d` codes.
  Numbering, names and the round-trip invariant are untouched.
* Good: the uniform case is unchanged and every existing document still builds
  byte-identically — `ring` is the default and a station without its own duration
  inherits.
* Good: `numberOfTeams: 1` stops being the documented answer for a
  work-as-one-group exercise, so the brief stops misreporting the team.
* Bad: **both facts have to reach the archive**, since neither is recoverable from
  the derived schedule — the schedule holds times, not which posts were active or
  how teams were assigned. So this needs an ADR-0059 migration rung, where a
  timing-only `rounds:` would have needed none. The rung is additive (an absent
  mode reads as `ring`, an absent station duration inherits), which is the cheap
  kind.
* Bad: **the rotation math changes rather than accumulates.** `mode` alters
  team-to-station assignment, which ADR-0062 originally flagged as the half that
  grows beyond `schedule.dart`. That is now the main body of the work rather than
  a second phase.
* Bad: `numberOfRounds` becomes derived in `together` (one round per post) and
  partly so in `split`, so the field is authored in one mode and computed in
  another. The editor has to show that rather than hide it.
* Bad: idle time in an unequal `ring` is honest and unwelcome. An author who did
  not realise their posts were unequal will see waiting they did not know they had
  — which is the point, and will still read as the tool's fault.
* Bad: three modes is a taxonomy, and taxonomies acquire a fourth member. The
  mitigation is that the model underneath is general — a fourth preset would be a
  new way of *generating* groups, not a new kind of round — so a fourth member is
  cheap in a way a fourth special case would not be.
* Bad: `split` carries authored assignment data, so it needs a shape in the source
  format, a place in the archive, and two `analyze` rules. It is the most expensive
  third of this ADR and the only third that can be got wrong by an author rather
  than by the compiler.
* Bad: the app currently rebuilds an exercise from its scalar inputs on every save
  (`exercise_form_screen.dart`), so until the editor understands modes it would
  flatten a non-uniform exercise on the first LAGRE. That has to land with the
  format change, not after it.

## Pros and cons of the options

### Option A — Status quo, documented
* Good: no change to format, compiler, wire or app.
* Good: honest, if the limitation is written down where authors will hit it.
* Bad: leaves a known-wrong derived schedule in a shipped plan, mitigated only by
  prose the reader may not reach.
* Bad: the workaround for grouped teams (`numberOfTeams: 1`) already misreports
  the team in the brief, and this compounds it.

### Option B — Authored `rounds:` list *(chosen first, superseded)*
* Good: one concept covers unequal durations and concurrency.
* Good: the timing half needs no wire-format change at all — `Exercise.schedule`
  is already per-round, so `decompile` can compare the stored schedule against the
  uniform derivation and emit `rounds:` only when they differ. Option F cannot do
  that and needs a migration rung.
* Good: strictly smaller. The timing half is confined to `schedule.dart` and two
  callers.
* Bad: **it hands the author a translation.** Durations belong to posts in every
  source document; `rounds:` requires working out which round visits which post
  and writing the duration there, by hand, and re-doing it whenever the posts are
  reordered.
* Bad: **enumerative, where the rest of the format is declarative.** Six entries
  to say one thing about one round, and an unbounded list surface in an editor that
  is otherwise scalar fields.
* Bad: a second shape for exercise timing, with a precedence rule against
  `numberOfRounds` to document and validate.
* Bad: `decompile` must decide when to emit it.
* Bad: does nothing for the `numberOfTeams: 1` workaround, so the brief keeps
  misreporting a merged group.

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

### Option F — Mode plus station-owned durations
* Good: nothing authored is a time, a round or a round count; the facts are stated
  where the author already knows them.
* Good: one general model — a round is groups of teams on posts — with two of the
  three cases generated, so cost tracks irregularity.
* Good: the editor stays a form, and the common case gains one defaulted field.
* Good: closes the `numberOfTeams: 1` accuracy bug as a side effect.
* Good: makes idle time visible, which the model has always implied.
* Bad: needs a migration rung, because neither fact survives in the derived
  schedule.
* Bad: changes team-to-station assignment, which is the larger half of the work.
* Bad: `numberOfRounds` is authored in one mode and derived in another.
* Bad: a taxonomy of three, which invites a fourth.
* Bad: `split`'s assignment is authored data with its own validation rules, and the
  only part of the design an author can get wrong.

## Links

* Related ADRs: [ADR-0058](./0058-source-format-and-plan-compiler.md),
  [ADR-0059](./0059-drill-schema-migration-ladder.md),
  [ADR-0007](./0007-drill-file-format.md),
  [ADR-0056](./0056-player-modes-exercise-station-roleplay.md)
* Related code: `lib/models/schedule.dart` (`ExerciseSchedule`),
  `lib/models/exercise.dart` (`schedule`, `endTime`),
  `lib/services/plan_service.dart` (`generateSchedule`),
  `lib/data/source/source_fields.dart`,
  `lib/views/exercise_form_screen.dart` (rebuilds the exercise from its scalars on
  every save — the flattening hazard),
  `lib/views/station_form_screen.dart` (where a station's own duration is authored)
* Mockup: [`docs/design/mockups/exercise-modes.html`](../design/mockups/exercise-modes.html)
* Origin: converting `assets/example/2026 LSOR øvelseshefte.docx`, where Øvelse
  4, 6 and 7 could not be expressed as uniform rotations.
* Revised 2026-08-01: Option B replaced by Option F, on the grounds that
  `rounds:` gave the author arithmetic the tool exists to do for them. The problem
  statement and the numbering analysis are unchanged.
