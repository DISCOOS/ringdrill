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

**Implementation.** Bounded by *rendering position*, not by a field list: every place
the renderer emits text under an entity's section has to resolve with that entity's
variables. The audit ran over the template slots rather than over `??` operators, since
that is what missed the second instance. It found exactly the two already known and no
third:

| Template slot | Rendered under | Resolved with (before) | Resolved with (now) |
|---|---|---|---|
| `plan.name`, `plan.description`, `plan.briefIntroMd`, `plan.commsMd` | the plan | plan | unchanged |
| `name`, `methodMd`, `learningGoalsMd`, `trainingFocusMd`, `orderFormatMd`, `executionTipsMd`, `effectiveCommsMd` | an exercise | exercise | unchanged |
| `organisationBlock` (carries `plan.beforeRoundMd`) | an exercise | **plan** | exercise |
| `name`, `descriptionMd`, `equipmentMd`, `situationMd`, `missionMd`, `logisticsMd`, `criticalQuestionsMd`, `leaderAnswersMd`, `directorNotesMd` | a station | station | unchanged |
| `effectiveCommsMd` | a station | **exercise** | station |
| `behavior`, `background`, `propsMd` | a roleplay | station (a roleplay declares no overrides) | unchanged |

Mechanically, the cascade now selects the *authored* text and resolution runs once per
rendering scope: `_effectiveCommsMd` returns `exercise.commsMd ?? plan.commsMd`
unresolved, the exercise resolves it for its own Comms block, and each station resolves
the same source again through its own `resolveField` closure. `_organisationBlock` takes
the exercise's variable map and refContext instead of rebuilding the plan's.

Cross-references came along, because "the scope it is rendered under" is one context and
not two: a cascaded `comms` referencing `{{station.stationCode}}` now resolves per post.
That is strictly a gain — at the station slot the exercise's refContext is a subset of
the station's, so nothing that resolved before stops resolving. The exercise's own copy
of that block still has no station in scope and leaves such a token literal, which is
ADR-0048's all-or-nothing rule doing what it already does.

**The settled precondition.** The app has no surface that renders an entity's
*effective* comms, so there was nothing to keep in step and no pre-existing disagreement
about the cascade. `plan_view.dart:730` is the plan overview card showing the plan's own
fields at plan scope, and `exercise_description_rollup.dart:43` shows `exercise.commsMd`
— the exercise's own, deliberately: it is an authoring surface, and "this exercise has
written no comms" is what an editor needs to see, where "what will a reader of this post
be told" is what the brief answers. ADR-0048's one-resolver constraint binds at
`field_resolver.dart`, which is unchanged; the cascade itself is a brief-layer concern,
so A is implemented in `brief_renderer.dart` alone and the app and CLI cannot diverge.

### Consequences

* Good: an override does what setting an override looks like it does, in every field the
  entity renders. The reported station 7b needs its `variableOverrides` and nothing else.
* Good: the wrong-section workaround is no longer needed, so a talk group stops landing
  in *Administration and supplies*.
* Good: `before_round` is fixed by the same rule rather than left for the next author to
  rediscover, and a `{{exercise.*}}` token in it now resolves instead of staying literal.
* Good: no archive, `contentHash` or schema-shape change. The cascade selects the same
  text as before; only the scope it resolves in moved.
* Neutral: output is byte-identical for every plan authored before this change, since
  divergence needs the cascaded text to reference `{{var.x}}`, the borrowing entity to
  override that same `x`, and the values to differ. A regression test pins that.
* Bad: the same authored text can render two ways under one section heading, and the
  brief does not say which post overrode what. This is the legibility cost accepted
  above; it is why C is not optional, and the authoring guidance states it as a reason
  to override only where a post genuinely differs.
* Bad: resolution now runs once per station for the cascaded field rather than once per
  exercise. Immaterial at plan sizes (tens of stations, a bounded pass loop per field),
  and the price of the field meaning the same thing everywhere.

## Links

* Related ADRs: [ADR-0046](./0046-plan-variables.md) (variables and scope overrides),
  [ADR-0048](./0048-flutter-free-field-resolver.md) (one resolver for app and CLI),
  [ADR-0063](./0063-per-field-brief-visibility.md) (per-field audiences, the other
  per-field rule a reader has to know)
* Authoring guidance (option C): [`variables.md`](../variables.md) §"Where a field is
  rendered, not where it was written"; the `variableOverrides` field descriptions in
  `lib/data/source/source_fields.dart`, which is what an authoring agent reads out of
  `schema` (ADR-0065)
* Related code: `lib/utils/plan_variables.dart` (`effectivePlanVariables`),
  `lib/services/brief/brief_renderer.dart` (the cascade), `lib/views/widgets/
  resolve_scoped_field.dart` (the editor's copy of resolution)
* Origin: converting `assets/example/2026 LSOR øvelseshefte.docx`, station 7b.
