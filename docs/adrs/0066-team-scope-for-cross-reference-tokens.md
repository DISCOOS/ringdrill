---
status: rejected
date: 2026-07-31
deciders: ["kengu"]
consulted: []
informed: []
---

# ADR-0066: A team scope for cross-reference tokens

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
* **Option F — A plan variable, plus guidance that points authors at it.** No new
  scope and no new token. The author declares `{{var.lag}}` in the plan's
  variables section (ADR-0046) and references it; the skill and the MCP
  instructions tell an agent to promote a repeated literal into one.

## Decision outcome

**Rejected, in favour of Option F.**

Option B — a `team` scope holding one facet, `{{team.label}}`, resolving to a
role-neutral phrase — does not pay for itself. Read plainly, that facet is a
string the author wants to write once and use in many places, which is the
definition of a plan variable (ADR-0046). The format already has that mechanism,
it already resolves at every scope, and `analyze` already validates a reference to
it.

The deciding argument is where it would be **edited**. Every other token resolves
from something the author edits somewhere: a plan's name in the plan editor, a
station's code in the station editor, a variable's value in the plan's variables
section. `{{team.label}}` resolves from a hardcoded localized string with no
editing surface at all — and "laget" is exactly the kind of word a course wants to
choose for itself ("laget", "patruljen", "mannskapet", "Lag 2.X"). Giving it a
token would mean either shipping a word the author cannot change, or inventing an
editing surface for a single string, and the only sensible home for that surface is
the variables section — which is to say, it is a variable.

So the LSOR booklet's 39 occurrences of `Lag 2.X` are already fixable today, with
no format change: declare a variable and reference it. The wildcard even survives
honestly — a variable has a default the author sets on the day, which is what
`2.X` was standing in for.

What was actually missing is not a token but **advice**. An agent transcribing a
document has no instinct for "this literal repeats, promote it", so it writes the
literal 39 times, and nothing in the skill or the MCP instructions tells it
otherwise. The derived-value guidance added alongside this ADR covers values the
*format* computes; it says nothing about values the *document* repeats. That gap is
the real finding here, and it is a paragraph of guidance rather than a scope.

Options C, D and E are not decided by this rejection. If a plan ever genuinely needs
to address one team specifically — a plan where teams do different things, which is
ADR-0062's territory — that is a per-team rendering decision and deserves its own
ADR. The analysis of them above stands as the record for whoever writes it.

### Consequences

* Good: no new scope, no new facet, no new editing surface. The token model stays
  the size it is.
* Good: the author gets a word they choose and can change, in the place they
  already change such words.
* Good: nothing blocks. The LSOR conversion's literals can be fixed with today's
  format.
* Good: the guidance generalises past teams. "Promote a repeated literal into a
  variable" covers a talegruppe, a duty phone number, a meeting place and a team
  designation with one rule, where a `team` scope would have covered exactly one.
* Bad: it stays the author's job to notice the repetition. A variable is only
  reached for by someone who thought of it, and guidance raises the odds without
  guaranteeing anything — which is why this is advisory and not a check.
* Bad: `analyze` cannot flag a hand-typed team name any more, because there is no
  single correct token to suggest. A repeated-literal detector is possible and
  deliberately not built here: the threshold for "worth a variable" is a judgement
  about the document, and a warning that fires on any thrice-repeated word would be
  noise. Left as a possible follow-up if the advisory version proves too weak.
* Bad: teams remain the one entity a markdown field cannot name. Accepted: naming a
  *specific* team is Option C's problem and needs the rendering decision first, and
  naming teams *generically* is a variable.

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

### Option F — A plan variable, plus guidance
* Good: zero format change; the mechanism, the validation and the editing surface
  all exist already.
* Good: the author owns the word, so a course can call its teams what it calls
  them.
* Good: one rule covers every repeated literal, not just teams.
* Bad: advisory only — nothing enforces it, and an author who never thinks of it
  keeps typing the literal.
* Bad: a variable is per-plan, so the same word has to be declared again in the
  next plan. A token would have been free everywhere. Cheap enough against the
  cost of a scope that cannot be edited.

## Links

* Related ADRs: [ADR-0046](./0046-plan-variables.md) — the mechanism this ADR was
  reinventing, [ADR-0062](./0062-authored-rounds-for-non-uniform-exercises.md),
  [ADR-0059](./0059-drill-schema-migration-ladder.md),
  [ADR-0063](./0063-per-field-brief-visibility.md),
  [ADR-0044](./0044-render-preview-on-site.md)
* Related code: `lib/utils/plan_field_names.dart`,
  `lib/views/widgets/plan_field_tokens.dart`,
  `lib/services/brief/brief_renderer.dart`, `lib/models/team.dart`
* Origin: 39 occurrences of the literal placeholder "Lag 2.X" in the 2026 LSOR
  course booklet converted into the source format — a wildcard the author wrote
  because the format offered no token.
