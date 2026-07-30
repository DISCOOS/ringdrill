---
status: accepted
date: 2026-07-31
deciders: ["kengu"]
consulted: []
informed: []
---

# ADR-0063: Give every staff role its own brief audience, and declare each field's audiences on the field

## Context and problem statement

Two problems meet here, and neither is fixable alone.

**The audiences do not match the roles.** `StaffRole` has four values —
`director` (Øvelsesleder), `instructor` (Veileder), `actor` (Markør) and `other`
(Annet) — and the app's role picker offers exactly those four.
`BriefAudience` has three, and they are a different three: `participant`,
`instructor`, `director`. `StaffRole.briefAudience` bridges the gap by
collapsing: an actor gets the **director** view, and `other` gets the
instructor view. So a markør reading the brief on their phone sees every other
marker's script, every station's withheld answers, and every other actor's name
and phone number. The role picker implies four views and delivers three.

**Visibility is decided in the template, not declared on the field.**
`BriefAudience` exposes exactly two gates — `includesDirectorNotes` (anyone but a
participant) and `includesActorPii` (director only) — applied by two mustache
conditionals. Every other field is unconditional and renders for everybody.
Rendering the converted 2026 LSOR course plan for `--audience=participant`
produces 14 "Markørspill" sections and 17 "Forslag til svar" sections. The
participant audience is not an in-app view — `StaffRole.briefAudience` notes that
participants do not use the app, and the picker omits them — so that render *is*
the handout printed for a trainee. It tells them where the marker hides and what
the marker does when found.

The second problem is the structural one:

* **It is undeclared.** The format cannot say who may see a field, so the
  authoring reference describes visibility by reading the template, and an agent
  generating a plan has nothing to consult. `leader_answers` is documented as
  "instructor-facing" and has never been withheld from anybody.
* **It fails open.** A markdown field added to `source_fields.dart` renders to
  every audience until somebody remembers to wrap it. On a format whose job
  includes withholding things, the safe direction is the other one.
* **It pushes authors into one field.** With `director_notes` the only gated
  prose, every kind of secret goes there whatever it is: the marker's behaviour,
  the answers to withhold, which room is locked, a note to the director.
  Converting the LSOR booklet did exactly that. It is a workaround for a missing
  declaration, and it destroys the structure the format otherwise has — a
  marker's script stops being a role-play field and becomes a paragraph in a
  blob.

## Decision drivers

* A participant must not see a spoiler by default. The printed handout has the
  widest and least controlled distribution of anything the tool produces.
* A markör should get their own scenario, not the director's whole plan. Giving
  staff more than their role needs is the same class of mistake as giving
  participants more than theirs.
* One set of roles. Two enums that must be kept in correspondence by a mapping
  function will drift, and this one already has.
* Visibility should be declared where the rest of the format is declared:
  `source_fields.dart` drives `build`, `decompile`, `analyze` and `schema`, so an
  author and an agent can both read it.
* Adding a field must force the decision, not inherit a permissive default.
* No change to the archive, the wire format or `contentHash` (ADR-0007,
  ADR-0059). This is what a render *includes*, not what a plan *contains*.
* The field table stays Flutter-free (ADR-0005).

## Considered options

* Option A — Status quo: document today's behaviour, tell authors to put
  anything sensitive in `director_notes`.
* Option B — Align `BriefAudience` with `StaffRole`, and declare per field the
  **set** of audiences that may see it, in `source_fields.dart`.
* Option C — Align the enums, but keep visibility in the template with a gate per
  case (`includesLeaderAnswers`, `includesRolePlay`, …).
* Option D — Keep three audiences and add per-field visibility only.
* Option E — Let the author set visibility per field instance in the document.

## Decision outcome

Chosen option: **Option B**.

`BriefAudience` gains `actor` and `other` so it mirrors `StaffRole` one-for-one,
keeping `participant` as the one audience with no staff role — a participant is
not staff, which is exactly why they are the audience that gets least.
`StaffRole.briefAudience` becomes the identity mapping and stops being a place
where a role can quietly borrow another's view.

Because the audiences now mirror roles, **they are not an ordered chain**. An
actor needs their own role-play script and none of the withheld answers; an
instructor needs the answers and the evaluation rubric. Neither contains the
other, so "minimum audience" cannot express it. Visibility is therefore a
declared **set** per field:

| Field | Scope | participant | actor | instructor | director |
|---|---|:-:|:-:|:-:|:-:|
| `intro`, `comms`, `before_round` | plan | ● | ● | ● | ● |
| `method`, `learning_goals`, `order_format` | exercise | ● | ● | ● | ● |
| `training_focus`, `execution_tips` | exercise | | | ● | ● |
| `equipment`, `situation`, `mission`, `logistics` | station | ● | ● | ● | ● |
| `critical_questions` | station | | | ● | ● |
| `leader_answers` | station | | | ● | ● |
| `director_notes` | station | | | ● | ● |
| `behavior`, `background`, `props` | roleplay | | ● | ● | ● |
| actor identity and phone | roleplay | | | ● | ● |

`BriefRenderer` omits a field the audience is not in from the mustache context,
so `{{#situationMd}}` finds nothing and the template needs no per-field
conditional — `if_instructor_or_director` disappears. There is **no default**: a
markdown field must state its set, so adding one is a decision rather than an
omission.

**Actor identity is the one row that cannot live in the field table.** Staff is a
local, private layer, stripped at publish and absent from the source format
(ADR-0047), so there is no `SourceField` to annotate. It keeps a dedicated gate
on `BriefAudience` — the present `includesActorPii`, widened from director-only to
instructor and director. A veileder supervises a team through a station and has to
coordinate with the markör standing at it: the course booklet's own standing
instruction is that veiledere look after the markörer and do not drive off without
them, which is impossible without being able to reach them. The same argument the
existing code already makes for actors ("they have to find and work with them")
applies at least as strongly to the role responsible for them.

Once role-play fields and `leader_answers` are gated where they belong, the
pressure to cram everything into `director_notes` goes away by itself: the
marker's script belongs in `behavior`, the intel to withhold in
`leader_answers`, and `director_notes` goes back to being notes for whoever runs
the station.

### Consequences

* Good: the printed participant brief stops carrying the marker's script and the
  withheld answers — the bug that motivated this.
* Good: a markör's brief narrows to what a markör needs, so handing a phone to a
  marker stops handing over the whole exercise.
* Good: one set of roles. `StaffRole.briefAudience` becomes the identity, so
  there is no mapping left to drift.
* Good: an author and a generating agent can read a field's audiences out of
  `schema`, so "will this leak?" is answerable before rendering.
* Good: a new markdown field cannot silently become participant-visible.
* Good: the template stops encoding policy, so the rules can be tested against
  the field table instead of by rendering and grepping.
* Good: no archive or `contentHash` change.
* Bad: participant briefs change output. That is the intent, but anyone who has
  distributed one has distributed more than they meant to, and pre-rendered
  briefs (ADR-0044's site preview) need regenerating.
* Bad: two audiences lose content they have today. An actor drops from the
  director view to their own scenario, and `other` — proposed here as the
  participant set, on ADR-0057's default-deny logic that "a role they do not name
  gets nothing" — drops from the instructor view. Both are deliberate reductions,
  and both are one line to revisit. Instructors gain rather than lose: actor
  contact details, which only the director had.
* Bad: **the instructor and director briefs become identical.** Actor identity was
  the last director-only content, so with it at instructor level nothing in the
  brief distinguishes the two audiences. They remain distinct for edit rights
  (ADR-0057) and player modes (ADR-0056), and the seam is worth keeping for
  content that genuinely is director-only later — a plan-wide staff roster, safety
  or risk notes, the ØVLE phone tree. But as of this ADR the distinction is
  latent, and that should be a decision rather than something a later reader
  discovers and mistakes for an oversight.
* Bad: this reverses the existing rationale for actors seeing each other's
  contact details. `StaffRole.briefAudience` grants an actor the director view
  today partly because "an actor needs other actors' contact details to work with
  them", and the matrix above withholds them. Plan-wide PII for every markör is
  over-broad — the markör at 3d does not need the number of the markör at 2f — but
  co-located markers are real: this booklet has two at 4b and one to two at 2f. If
  that case matters, the fix is a narrower cut (the actors cast to the same
  station) rather than restoring the whole director view.
* Bad: `critical_questions` at instructor level is a judgement call. They are
  prompts for evaluating whether a team leader thought of something, but they
  carry domain intel a participant would benefit from. An author who wants
  participants to have it can move it into `situation`.
* Bad: `director_notes` is visible from instructor, so the name overstates the
  restriction. ADR-0059's ladder permits a key rename, so `control_notes` stays
  available; renaming here would churn every document for a cosmetic gain.
* Bad: the source-format table takes on a rendering concern. It already carries
  `mdFileName` and wire keys, and the alternative — a second table in the brief
  layer keyed by field name — is the drift this repo has now fixed twice.
* Bad: an actor's brief still shows *every* role-play at their stations, not only
  the ones cast to them. That is an identity cut (`RolePlay.staffUuid`), not an
  audience one, and wants its own change.

## Pros and cons of the options

### Option A — Status quo, documented
* Good: no code change.
* Bad: leaves participants holding spoilers and markers holding the whole plan;
  documentation fixes neither.
* Bad: keeps `director_notes` as the only lever, so plans keep losing structure.

### Option B — Aligned audiences, per-field audience sets
* Good: fixes both problems with one model; declaration is readable from
  `schema`; fails closed.
* Bad: changes rendered output for participants, actors and `other`; annotating
  the whole table is one large change.

### Option C — Aligned audiences, a gate per case
* Good: smaller diff, familiar mechanism.
* Bad: policy stays in the template, so it stays undeclared and invisible to
  `schema` — the documentation problem is untouched.
* Bad: still fails open, and four audiences times a boolean per field is a
  combinatorial mess in mustache. Two gates became the whole model this way.

### Option D — Per-field visibility, three audiences
* Good: fixes the participant leak, which is the urgent half.
* Bad: leaves a markör on the director view, so the role picker still promises
  four views and delivers three.
* Bad: an ordered "minimum audience" reads naturally with three values and then
  has to be torn up when `actor` arrives, since actor and instructor are
  siblings.

### Option E — Per-instance visibility in the document
* Good: maximum author control, including one unusual station.
* Bad: every markdown field becomes "string or object", for a rare case.
* Bad: nothing can validate intent — forgetting on one station leaks on that
  station only, which is harder to notice than a systematic rule.
* Bad: it makes leaking an authoring mistake rather than a structural
  impossibility, which is the wrong place for this decision to live.

## Links

* Related ADRs: [ADR-0058](./0058-source-format-and-plan-compiler.md),
  [ADR-0047](./0047-scenario-locations-and-persons.md),
  [ADR-0057](./0057-role-gated-editing.md),
  [ADR-0056](./0056-player-modes-exercise-station-roleplay.md),
  [ADR-0044](./0044-render-preview-on-site.md),
  [ADR-0059](./0059-drill-schema-migration-ladder.md)
* Related code: `lib/services/brief/brief_audience.dart`,
  `lib/models/staff_role.dart`, `lib/services/brief/brief_renderer.dart`,
  `assets/templates/ringdrill-standard-v1.*.md.mustache`,
  `lib/data/source/source_fields.dart`
* Origin: rendering the converted 2026 LSOR course booklet for
  `--audience=participant`, which included every marker script in the plan.
