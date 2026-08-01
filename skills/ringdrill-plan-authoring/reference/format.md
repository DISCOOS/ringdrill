# The source format — vocabulary and shape

Companion to `SKILL.md`. The authoritative field list is the `schema` tool;
this is the part a schema cannot carry: what the entities *mean* and why the shape
is what it is.

Names throughout mirror the frozen `.drill` wire keys rather than the app's Dart
class names, so a rename inside the app never changes this format.

## Entities

| Term | What it is |
|---|---|
| **Plan** | The whole document. Named, tagged, in one content language. Owns the variables. |
| **Exercise** | One drill: a set of stations plus the rotation over them. Has a start time, a team count, a round count and three phase durations. |
| **Ring route** | The rotation itself — teams moving between stations on a shared clock, one team per station. The default and only shape today. Not to be confused with **ring drill**, which names the whole domain: exercises, stations and the plans that hold them. |
| **Station** | A rotation post. Teams move between stations one round at a time. Has an administrative `position` (where the post is) and, optionally, scenario data. |
| **Location** | Station-owned scenario geography — a last known position, a command post. Addressed as `{{station.loc.<slug>}}`. Distinct from the station's own `position`. |
| **Person** | A station-owned *fictional* subject — the missing person, a witness. No real-world identity. Addressed as `{{station.person.<slug>}}`. |
| **RolePlay** | The role a marker enacts, portraying one of the station's persons. Nested under that station. |
| **Team** | A rotating group. `name` is free text; naming conventions vary by domain. Optional — the compiler generates as many as the largest `numberOfTeams`. |
| **Variable** | A value declared once on the plan and referenced as `{{var.<name>}}`. Exercises and stations override the value, never the name. |

Not in this format, on purpose: **Staff** (the real people cast as markers — a
local, private layer, stripped at publish) and **Sessions** (records of actual
runs).

## Numbering and display

Codes are derived from list position and rendered by the app, never authored
(ADR-0059). Two plan-level fields choose the shape:

| Field | Value | Renders as |
|---|---|---|
| `exerciseNumberFormat` | `hash` | `#2` |
| `stationNumberFormat` | `dotted` | `2.1`, `2.2`, … |
| | `alpha` | `2a`, `2b`, … |

`alpha` is what a booklet that labels its posts `1a`/`2f`/`7c` wants: model each
of its exercises as one exercise and its lettered sub-sections as that exercise's
stations, and the same labels come back out. That also means **splitting one
booklet exercise across two model exercises renumbers its later stations** — a
`7c` becomes an `8a` — which is worth knowing before you split one to fix its
timing.

`station.variantSuffix` is display-only: the brief appends it after the station
name (`7a – Assistanse turgåer – variant B`). It has no editable UI in the app and
nothing derives from it.

## The rotation

An exercise runs `numberOfRounds` rounds. Each round is
`executionTime + evaluationTime + rotationTime` minutes: the teams work, then get
feedback, then move. Every team is at a different station in a given round, and
all advance together.

`numberOfTeams` must be ≤ the number of stations. One round per station is a full
rotation, which is the usual intent.

You never write `schedule` or `endTime`. Both follow from the above.

### What the rotation cannot express

Every round is the same length: the schedule is one cycle multiplied
(`ExerciseSchedule` in `lib/models/schedule.dart`). So an exercise whose phases
genuinely differ in length has no honest form, and neither has one where two
stations run **concurrently**. Both occur in real course booklets — see
[ADR-0062](../../../docs/adrs/0062-authored-rounds-for-non-uniform-exercises.md).

Until that lands, there are two workarounds, and both cost something visible:

* **All teams working one station at a time** — a full-scale phase rather than a
  rotation. Use `numberOfTeams: 1`, with the real teams grouped into one. The
  schedule stays correct, but the brief then names that group after the first
  team ("Lag 2.1") instead of all of them, so say what is really happening in
  `method`.
* **Phases of unequal length, or stations running side by side** — no form is
  correct. Keep the *per-station* durations honest, since that is the number
  someone acts on, and put the real clock in `execution_tips` stating plainly
  that the derived grid and end time do not apply to this exercise. A reader who
  trusts a wrong schedule is worse off than one who has been told to ignore it.

## Markdown fields

Each takes a YAML block scalar (`|`), where the content is literal so markdown
needs no escaping:

```yaml
situation: |
  Kari Fiskeløs – fine search around the IPP within R25.
  Last seen {{station.loc.lkp.position}}.
```

**Break lines only at sentence ends.** A markdown field is prose someone edits in
the app, in a section editor that honours your newlines and then wraps again at its
own width — so a line hard-wrapped at 80 columns arrives as a ragged break
mid-sentence. Wrapping is invisible in the source and in the rendered brief, and
obvious in the editor, which is the one place it is never looked at while writing.
One sentence per line reads well in all three. Keep a list item or a table row on a
single line however long it gets, since a break inside one changes how markdown
reads it.

The **Renders under** column is the heading the brief puts the field under. It
matters while writing: a field whose own text opens with that same heading
renders it twice, and a `**Bold sub-heading**` inside one field that repeats
another field's heading reads as a duplicate section. Neither is an error
`analyze` can see — you only catch it by reading the brief.

| Field | Scope | Holds | Renders under |
|---|---|---|---|
| `intro` | plan | The brief's opening. Sets the frame for the whole plan. | "General notes on play and exercise control" |
| `comms` | plan, exercise | Talk groups, phone numbers, call signs. | "Talk groups" (plan), "Comms" (exercise, station) |
| `before_round` | plan | What happens between rounds. | inside each exercise's "Organisation", above the rotation table |
| `method` | exercise | How the exercise is run pedagogically. | "Method" |
| `learning_goals` | exercise | What participants should be able to do afterwards. | "Learning goals" |
| `training_focus` | exercise | What to watch for and evaluate. | "Training focus" |
| `order_format` | exercise | The order template teams work to. | "Order format" |
| `execution_tips` | exercise | Practical notes for whoever runs it. | "Execution tips" |
| `equipment` | station | What the station needs on site. | "Equipment" |
| `situation` | station | The scenario: who, where, when, what is known. | "Situation" |
| `mission` | station | The order the team is given. | "Mission" |
| `logistics` | station | Access, command post, transport. | "Administration and supplies" |
| `critical_questions` | station | What a good team leader should ask. | "Critical questions" |
| `leader_answers` | station | The answers to give if asked. | "Suggested answers to team leader questions" |
| `director_notes` | station | Never shown to participants. | a blockquote, "Notes for instructor/exercise control" |
| `behavior` | roleplay | How the marker acts. | "Role-play (*person*)" |
| `background` | roleplay | What the marker knows and has done. | "Role-play (*person*)" |
| `props` | roleplay | What the marker needs. | **Props:** within the role-play section |

A field you have nothing real to put in should be omitted, not filled with
something generic.

`comms` cascades: a station shows its exercise's `comms`, falling back to the
plan's. That is why a station needs no `comms` of its own to show talk groups,
and why repeating them in `logistics` produces two Comms-ish sections.

### Who sees what

There is one audience per staff role, plus `participant` — the printed handout,
and the audience that gets least, because a participant is not staff. Every
markdown field declares which of them may see it (ADR-0063), so this table is the
field's own property rather than a rule the renderer applies from outside:

| Field | participant / other | actor | instructor / director |
|---|:-:|:-:|:-:|
| `intro`, `comms`, `before_round` | ● | ● | ● |
| `method`, `learning_goals`, `order_format` | ● | ● | ● |
| `equipment`, `situation`, `mission`, `logistics` | ● | ● | ● |
| `behavior`, `background`, `props` | | ● | ● |
| `training_focus`, `execution_tips` | | | ● |
| `critical_questions`, `leader_answers` | | | ● |
| `director_notes` | | | ● |
| the real person cast as a marker | | ● | ● |

Read the columns as roles, not levels — they are not nested. An actor gets the
role-play fields and the cast's contact details, so co-located markers can find
each other, and none of the instructor-facing material they would otherwise be
holding while standing next to a participant. `other` — a staffing role the enum
does not name — gets the participant set, on the same default-deny logic that
governs edit rights.

So **put a spoiler in the field that owns it**, not in `director_notes`: the
marker's script in `behavior`, the intel to withhold in `leader_answers`, and
`director_notes` for what is genuinely a note to whoever runs the station. A
station whose whole scenario is one `director_notes` blob is an artefact of the
days when that was the only gated field.

A withheld field renders as nothing, and an audience that can see none of the
role-play fields gets no role-play section at all — otherwise the heading and the
marker's name would still announce that the station has one.

Note that `director_notes` is **not** stripped at publish — only Staff is. Real
names, duty phone numbers and door codes in `director_notes` ship to the open
catalog. Keep operational contact details in plan variables so they are easy to
find and change before publishing.

## Tokens

| Token | Resolves to |
|---|---|
| `{{var.<name>}}` | The variable's effective value at that scope. |
| `{{var.<name>.position}}` / `.place` | Facets of a `location`-typed variable — it projects onto the same shape as a station location, so it takes the same facets. |
| `{{station.loc.<slug>}}` | The location's `place` and coordinate — `place (32V …)` when it has both, otherwise whichever it has. |
| `{{station.loc.<slug>.position}}` | The coordinate alone, as a copy chip. |
| `{{station.loc.<slug>.place}}` / `.label` | The place text / the label. |
| `{{station.person.<slug>}}` | The person's name. |
| `{{station.person.<slug>.age}}` | A person facet. |
| `{{exercise.roundTable}}` | The rotation as a table, one row per round — derived, so it cannot go stale. |
| `{{plan.name}}`, `{{exercise.startTime}}`, `{{station.stationCode}}`, … | Fields of the enclosing scope. Call `schema`, or let `analyze_plan` list them. |

**A derived value belongs in a token, never in prose.** The rotation times, the
phase breakdown, a duration, a station code — all of them follow from fields the
author already set, so a copy typed into a markdown field is correct only until one
of those changes. The brief renders the rotation in its own *Organisering* block
already; `{{exercise.roundTable}}` exists for the rarer case where a section has to
show it inline. See *Rules that are not in the schema* in
[`SKILL.md`](../SKILL.md) for the table of what to write instead of what.

**A repeated literal belongs in a variable.** The other half of the same rule, for
values nothing derives: a talegruppe, a duty phone number, a meeting place, a team
designation. No token can exist for them — declare a variable and reference
`{{var.<slug>}}`, which the author can then change in one place. Three or more
fields carrying the same literal is the threshold worth acting on
([ADR-0066](../../../docs/adrs/0066-team-scope-for-cross-reference-tokens.md)
rejected a `team` scope for exactly this reason: it was a variable all along).

A location token prints `place` when the location has one, so prose that already
names the spot says it twice:

```yaml
# Don't — renders "the cabin at Gamlehuset, Eidene (32V 0580418E 6552006N)"
place: Gamlehuset, Eidene
situation: |
  Last seen at the cabin at {{station.loc.ipp}}.
```

Either drop `place` and let the token carry the coordinate alone, or let the
token carry the naming and keep it out of the prose.

**There is no `.utm` facet.** `utm` and `latlng` were renamed to the
format-agnostic `position` by
[ADR-0050](../../../docs/adrs/0050-per-output-format-chip-formatting.md), which
is also why `position` prints UTM: `CoordinateFormat` ships UTM only for now, and
is the seam for MGRS and the degree variants later.

An unrecognized facet does not fail at render — it falls back to the bare
rendering, so `{{station.loc.ipp.utm}}` still produces *something*, just
`place (32V …)` instead of the bare coordinate you asked for. `analyze` reports
it as a **warning** for that reason, naming the facet and what is available;
`--strict` promotes it to an error. Older documents and design notes still show
`.utm`, so migrate rather than copy.

Scopes cascade **downwards** only: a `{{plan.*}}` token resolves inside a station
field, but `{{exercise.name}}` in a plan-level field has no exercise to resolve
against. `analyze_plan` distinguishes the two — "cannot resolve here" means the
scope is wrong, not the spelling.

## Coordinates

Either notation, at every `position` (ADR-0061):

```yaml
position: { lat: 59.097921, lng: 10.397940 }
position: "32V 0580083E 6551794N"
```

The string form is what this domain actually reads and writes — a source booklet
carries UTM and the brief renders UTM back — so a coordinate can be copied out of
the source material unchanged and checked by eye against it. That matters more
than it sounds: a bad conversion is the one error class with no detection at all.
Latitude is range-checked, which catches the classic swap (`{lat: 10.4, lng: 59.1}`
is two valid numbers and a station in the Indian Ocean), but nothing can catch a
transposed digit — the result is a valid coordinate in the wrong place, and
`analyze` cannot know where a station was meant to be.

Two things to know about the string form:

* It is **metre precision**, so a plan authored in UTM and the same plan authored
  in decimal degrees agree on the ground but not to the last decimal, and their
  content hashes differ. Either is correct; do not mix notations for the same
  coordinate and expect identical hashes.
* `decompile` always emits `{lat, lng}`, because re-emitting UTM would either lose
  precision or guess a zone. A document authored in UTM comes back in decimal
  degrees. The rebuild is still byte-identical and preserves `contentHash`, so the
  round trip holds — it is the source *text* that changes notation, not the plan.

The compiler stores coordinates in the archive's own order (GeoJSON `[lng, lat]`),
so you never think about it.

## Identity

`uuid` is optional everywhere it appears. Omit it and the compiler mints one;
`get_plan` always includes it, so an edited copy of a published plan rebuilds onto
the *same* plan rather than a duplicate. If you are editing, keep the uuids you
were given.
