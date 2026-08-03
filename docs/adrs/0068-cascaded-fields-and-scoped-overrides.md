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
* `comms` is not the only cascading field. Whatever is decided applies to all of them,
  so the blast radius needs establishing before, not after. **Open question: enumerate
  them.**
* Resolution has one implementation for the app and the CLI (ADR-0048). A change here
  must not give the two different answers.
* The workaround is worse than either outcome: it puts a talk group in
  *Administration and supplies*, where a reader looking for Samband will not find it.

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

**A — a cascaded field resolves in the borrowing entity's scope**, plus C: the rule is
stated in the authoring guidance rather than left to be discovered.

The deciding argument is that B makes a field's name a lie. A station's
`variableOverrides` would mean "for the fields this station happens to own", which is
neither what it is called nor what ADR-0046 says it does — and an author cannot see
which fields those are without knowing the cascade. A is the only option where setting
an override does what setting an override looks like it does.

**The cost, accepted rather than dismissed:** the same authored text now renders
differently per station. That is powerful in the way that is hard to debug — a talk
group that changes depending on which post you are reading is the point here and would
be baffling in a field where nobody expected it. Two things keep it legible: the
variable is declared once at plan level so a reader has one place to look, and the
overriding station shows its own value in its own variables section. The mitigation is
documentation, which is why C rides along and is not optional.

**Implementation is not yet designed.** Accepting A settles what should happen, not what
it costs. First step is the open question above — enumerate the cascading fields — since
the change applies to all of them and the blast radius was never established. It must
also land in one place: the app and the CLI share one resolver (ADR-0048), and a
per-scope cascade implemented twice is exactly the drift that made
`{{exercise.roundTable}}` resolve in the brief and not in the editor.

## Links

* Related ADRs: [ADR-0046](./0046-plan-variables.md) (variables and scope overrides),
  [ADR-0048](./0048-flutter-free-field-resolver.md) (one resolver for app and CLI),
  [ADR-0063](./0063-per-field-brief-visibility.md) (per-field audiences, the other
  per-field rule a reader has to know)
* Related code: `lib/utils/plan_variables.dart` (`effectivePlanVariables`),
  `lib/services/brief/brief_renderer.dart` (the cascade), `lib/views/widgets/
  resolve_scoped_field.dart` (the editor's copy of resolution)
* Origin: converting `assets/example/2026 LSOR øvelseshefte.docx`, station 7b.
