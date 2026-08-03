---
status: accepted
date: 2026-08-03
deciders: ["kengu"]
consulted: []
informed: []
---

# ADR-0068: Decide whether a cascaded field resolves in the borrowing scope

## Context and problem statement

Two mechanisms in the format meet and do not compose.

**A field cascades by entity.** A station with no `comms` of its own renders its
exercise's `comms`, falling back to the plan's. This is deliberate and documented: it
is why a station needs no `comms` to show talk groups, and why repeating them in
`logistics` produces two Comms-ish sections.

**A variable resolves by scope.** `{{var.talegruppe}}` resolves against the effective
variable map at the reading entity's scope — the plan's declared value, overlaid by the
exercise's `variableOverrides`, then the station's (ADR-0046).

Put together, a station that overrides a variable used by an *inherited* field does not
see its own value. The station borrowed the exercise's text, and that text resolves in
the exercise's scope.

Found while converting a real course booklet. Station 7b runs on a different talegruppe
from the rest of its exercise. The author set a `variableOverrides` on 7b, and the
Samband block on 7b kept showing the exercise's group. They worked around it by writing
`{{var.talegruppe}}` into 7b's `logistics`, which renders correctly — and produces a
talk group in the wrong section.

The question is not how to express 7b. It is whether a `variableOverrides` on a station
means what its name says for every field the station renders, or only for the fields the
station owns.

## Decision drivers

* A competent author set an override, got no effect, and found a workaround. That is the
  signal that the current behaviour reads as a defect rather than as a rule — whichever
  way the decision goes, the ambiguity is the problem.
* **Asked and answered badly, then re-answered.** The first enumeration counted `??`
  fallbacks and found one (`exercise.commsMd ?? plan.commsMd`, `brief_renderer.dart:691`),
  concluding this was a one-field change. That counted the wrong thing. What matters is
  a field **rendered in a scope other than the one it was authored in**, and a fallback
  is only one way to get there. `plan.beforeRoundMd` is the other: resolved with
  `_planVariables(plan)` at `brief_renderer.dart:670` and rendered inside *each
  exercise's* Organisation block, so an exercise overriding a variable it uses never sees
  its own value. Two instances, two mechanisms, one defect — which is why the fix is a
  rule and not a patch.
* Resolution has one implementation for the app and the CLI (ADR-0048). A change here
  must not give the two different answers.
* The workaround is worse than either outcome: it puts a talk group in
  *Administration and supplies*, where a reader looking for Samband will not find it.
* **Replicated.** A second conversion run hit the same trap independently, without having
  read this ADR, and reached the same wrong-section workaround. Two authors, one
  ambiguity, one bad outcome — which is the evidence that this is a design defect rather
  than one agent's mistake.

## Considered options

* **A — resolve a cascaded field in the borrowing entity's scope.** `{{var.x}}` in an
  inherited `comms` resolves against the station reading it.
* **B — leave it. Cascade borrows text; overriding requires owning the field.** 7b gets
  its own `comms`.
* **C — make the rule explicit either way and say so in the authoring guidance**, rather
  than leaving it as an emergent property of two features. Not an alternative to A or B:
  whichever is chosen has to be written down, because this behaviour was reached by
  composing two documented features and nothing documented the composition.

## Decision outcome

**A, generalised: a markdown field resolves in the scope it is rendered under, not the
scope it was authored in** — for every field and every variable, not for `comms` alone.
Plus C: the rule is stated in the authoring guidance rather than left to be discovered.

Scoping this to the one field that was reported would leave `before_round` wrong in the
same way and the next borrowed field wrong again, and would make "does my override
apply?" a question about which field an author happened to pick. A station's
`variableOverrides` should mean the same thing in every field that station renders.

The deciding argument is that B makes a field's name a lie. A station's
`variableOverrides` would mean "for the fields this station happens to own", which is
neither what it is called nor what ADR-0046 says it does — and an author cannot see
which fields those are without knowing the cascade. A is the only option where setting
an override does what setting an override looks like it does.

**The cost is narrower than it first appears.** An early draft of this ADR called it
"the same authored text renders differently per station", which overstates it. Three
things have to coincide for any divergence at all: the cascaded text references
`{{var.x}}`, the borrowing station overrides *that same* `x`, and its value differs.
Absent any one of them the station's effective map is the exercise's, so resolution is
byte-identical — which is every station in every plan today.

So the divergence is opt-in, not emergent: it happens exactly where an author asked for
it, on the variable they asked for it on. That is the argument *for* A, not a cost of it.

What genuinely remains is a legibility concern, and only in the rendered output: a
reader comparing two posts sees two values under one section heading, with nothing in
the brief saying which station overrode what. Mitigated by the variable being declared
once at plan level, and by the overriding station showing its own value in its own
variables section — but a reader of the printed brief has neither in front of them. That
is a documentation problem rather than a design one, which is why C rides along and is
not optional.

**Implementation is not yet designed.** It is bounded by *rendering position*, not by a
field list: every place the renderer emits text under an entity's section has to resolve
with that entity's variables. Two are known — `effectiveCommsMd` (four template slots)
and `beforeRoundMd` — and the audit is over the template slots rather than over `??`
operators, since that is what missed the second one.

**Settle one thing first.** No comms cascade was found on the app side at all —
`plan_view.dart:730` resolves `plan.commsMd` only. That may be benign (the app may
simply have no surface that shows an exercise's or a station's *effective* comms, in
which case there is nothing to keep in step) or it may mean the app and the brief
already disagree about the cascade itself, which is a defect independent of this ADR.
Establish which before implementing A, because it decides whether ADR-0048's
one-resolver constraint binds here or applies to the brief path alone.

## Links

* Related ADRs: [ADR-0046](./0046-plan-variables.md) (variables and scope overrides),
  [ADR-0048](./0048-flutter-free-field-resolver.md) (one resolver for app and CLI),
  [ADR-0063](./0063-per-field-brief-visibility.md) (per-field audiences, the other
  per-field rule a reader has to know)
* Related code: `lib/utils/plan_variables.dart` (`effectivePlanVariables`),
  `lib/services/brief/brief_renderer.dart` (the cascade), `lib/views/widgets/
  resolve_scoped_field.dart` (the editor's copy of resolution)
* Origin: converting `assets/example/2026 LSOR øvelseshefte.docx`, station 7b.
