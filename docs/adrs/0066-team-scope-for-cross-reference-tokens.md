---
status: proposed
date: 2026-07-31
deciders: ["kengu"]
consulted: []
informed: []
---

# ADR-0066: Give the token model a team scope, and decide what "the team" means in a brief

## Context and problem statement

Every other entity a plan names is reachable from a markdown field. A plan, an
exercise, a station and a role-play all have a token scope
(`lib/utils/plan_field_names.dart`), so prose can refer to them without copying
their names. **Teams do not.** A plan carries a `teams` list, the app renders team
names throughout, and `{{plan.teamCount}}` now says how many there are — but
nothing can name one.

The 2026 LSOR conversion shows what that costs. Its station missions are written
as orders given to a team, and the booklet writes the team as a literal
placeholder:

> (AL) Lag 2.X: stisøk fra IPP i {{station.loc.ipp.position}} til Bua …

That `2.X` appears **39 times**. It is not a typo and not laziness: paper cannot
compute, so the author wrote a wildcard for whoever actually stands there and
filled it in by hand on the day. It is the same shape as every other hand-rolled
derived value this repo has now chased out of prose — a value the format knows and
the document had to fake — except that here there is no token to reach for, so
`analyze` cannot even point at it.

The reason there is no token is not an oversight in the table. It is that **the
brief has no team in context to resolve one against.**

* A brief is rendered once per plan and audience (`render_plan --audience=…`).
  The template has no team roster, no per-team section, and mentions teams once,
  in a heading.
* A station's `mission` is shared by every team that visits it. Under a rotation,
  that is all of them — four teams pass station 2f in four different rounds.
  "Which team is this text about?" has no single answer at station scope.
* So `{{team.name}}` cannot be added the way `{{station.duration}}` was. The
  facet is trivial; the context it resolves in does not exist yet.

Two further facts constrain any answer. `Team` carries only `uuid`, `index`,
`name` and an optional `numberOfMembers` — there is little to expose beyond a
name. And the rotation already knows exactly which team is at which station in
which round, since that is what `schedule` derives; nothing needs inventing to
*find* the team, only to decide what a rendered document is *for*.

## Decision drivers

* An author writing an order must be able to name its recipient without typing a
  literal. That is the whole point of the token model, and this is the one entity
  it omits.
* A rendered brief must stay honest about who it is for. A document that says
  "Lag 2.1" to a reader who is not in 2.1 is worse than one that says "the team".
* `analyze` should be able to flag a hand-typed team name, which it cannot do
  while there is no token that would have been correct instead.
* No archive, wire-format or `contentHash` change (ADR-0007, ADR-0059). Teams are
  already in the format; this is about rendering and references.
* The picker's contract holds: a token offered is a token the renderer resolves at
  that scope (`plan_field_tokens.dart`), so a facet that resolves only sometimes
  cannot simply be listed.
* Whatever is chosen must not multiply the brief surface without a reason a user
  asked for. Per-team rendering is a product decision, not a token decision.

## Considered options

* **Option A — Do nothing.** Teams stay unreferenceable; authors keep typing
  literals or wildcards.
* **Option B — A generic team scope.** Add `{{team.label}}`, resolving to a
  role-neutral phrase ("laget" / "the team") rather than a specific team. No
  per-team rendering, no schedule lookup.
* **Option C — Per-team rendering.** `render_plan --team=<n>` renders the brief
  for one team, and `{{team.name}}`/`{{team.index}}` resolve from it. A plan with
  four teams produces four participant briefs.
* **Option D — Round-aware resolution.** `{{team.name}}` resolves per round from
  the rotation, so a station section renders once per visiting team.
* **Option E — Author-declared recipients.** A station field declares which team
  it addresses, and the token resolves from that declaration.

## Decision outcome

**Recommended: Option B now, Option C as a separate decision when the product
wants it.** Not chosen here — Option C changes what `render` produces and how many
documents a course day involves, which is a UI/UX question in the same class as
ADR-0062's, and it should be decided with the app's brief-sharing flow in view
rather than as a side effect of adding a token.

Option B is the part that is safe to do independently and that fixes the
observed damage. `{{team.label}}` gives the LSOR author the thing they were
reaching for: "**{{team.label}}**: stisøk fra IPP …" renders as "Laget: stisøk fra
IPP …", correct for every reader of that station, in every round, forever. It
needs no team in context, so it resolves at plan, exercise, station and role-play
scope alike, and it is one localized label rather than a lookup.

It also unlocks the `analyze` half. Once a correct alternative exists, a station
field containing a literal team name — matched against `plan.teams[*].name`, the
way the derived-schedule check matches round starts — can be warned about with a
hint that names the token. Without Option B there is nothing to suggest, and a
warning with no remedy is noise.

What Option B deliberately does not do is let a document address one team
specifically. If a plan genuinely needs that — a plan where teams do different
things, which is also ADR-0062's territory — Option C or E is the answer, and both
should wait for that need to be real rather than anticipated.

### Consequences

* Good: the one gap in the token model closes, and the most-repeated literal in
  the first converted plan gets a correct form.
* Good: no rendering-surface change. One brief per audience, as today.
* Good: `analyze` gains a check it cannot currently justify.
* Good: works at every scope, so an author never has to ask whether a team is in
  context here.
* Bad: `{{team.label}}` is a *label*, not a reference — it names no specific team,
  which will read as a half-measure to anyone who expected `{{team.name}}`. The
  name should therefore not be `team.name`: reserving that for the per-team case
  keeps Option C available without a rename, and makes the difference visible at
  the call site.
* Bad: a scope with exactly one facet looks odd in the table and in the picker.
  Accepted: the alternative is a facet in the `plan` scope, which would be lying
  about what it refers to.
* Bad: it does not help a plan that assigns different tasks to different teams.
  That is real and out of scope; see ADR-0062.
* Bad: the LSOR document's `2.X` carries information Option B drops — the "2."
  prefix is that course's team-numbering convention. Nothing is lost that the plan
  knows, since the plan's own team names carry it, but an author converting such a
  booklet has to accept a generic label where the paper had a half-specific one.

## Pros and cons of the options

### Option A — Do nothing
* Good: nothing to build.
* Bad: leaves 39 literals in the first real plan with no correct alternative, and
  leaves `analyze` unable to say anything about them.

### Option B — A generic team scope
* Good: resolves everywhere, no context needed, no rendering change; unlocks the
  analyze check.
* Bad: cannot address a specific team; a one-facet scope.

### Option C — Per-team rendering
* Good: the honest answer for a plan whose teams differ, and the rotation already
  knows who is where.
* Bad: multiplies briefs by team count on every surface that renders one — CLI,
  MCP, app share sheet, ADR-0044's site preview — and each needs to answer "which
  team?" in its own UI. A product decision.
* Bad: an unanswered `--team` makes `{{team.name}}` unresolvable, so the picker
  would offer a token that fails half the time.

### Option D — Round-aware resolution
* Good: maximally precise; no author input needed.
* Bad: a station section would render once per visiting team, so a four-team
  rotation quadruples the station's prose in a single document. That is a
  rendering model change, not a token.

### Option E — Author-declared recipients
* Good: expresses "this order is for team 2.1" exactly.
* Bad: puts a rotation fact into authored data, where it can contradict the
  derived schedule — the class of duplication ADR-0059 forbids a migration from
  creating and this whole line of work has been removing.

## Links

* Related ADRs: [ADR-0062](./0062-authored-rounds-for-non-uniform-exercises.md),
  [ADR-0059](./0059-drill-schema-migration-ladder.md),
  [ADR-0063](./0063-per-field-brief-visibility.md),
  [ADR-0044](./0044-render-preview-on-site.md)
* Related code: `lib/utils/plan_field_names.dart`,
  `lib/views/widgets/plan_field_tokens.dart`,
  `lib/services/brief/brief_renderer.dart`, `lib/models/team.dart`
* Origin: 39 occurrences of the literal placeholder "Lag 2.X" in the 2026 LSOR
  course booklet converted into the source format — a wildcard the author wrote
  because the format offered no token.
