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
  Last seen {{station.loc.lkp.utm}}.
```

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

`BriefAudience` has exactly two gates (`lib/services/brief/brief_audience.dart`):

* `director_notes` — instructor and director only. This is the one field the
  participant brief withholds.
* The real person cast as a marker (name, phone) — director only.

**Everything else renders for every audience, including participants** —
`leader_answers` and the role-play `behavior`/`background`/`props` among them.
So a spoiler is only actually withheld if it is in `director_notes`: where the
marker hides, how they behave under pressure, what to withhold, which room is
locked. Put it there, not in a role-play field, if a participant reading it would
spoil the station.

Note also that `director_notes` is **not** stripped at publish — only Staff is.
Real names, duty phone numbers and door codes in `director_notes` ship to the
open catalog. Keep operational contact details in plan variables so they are easy
to find and change before publishing.

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
| `{{plan.name}}`, `{{exercise.startTime}}`, `{{station.stationCode}}`, … | Fields of the enclosing scope. Call `schema`, or let `analyze_plan` list them. |

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

`{lat, lng}` in decimal degrees. The compiler stores them in the archive's own
order, so you never think about it. Latitude is range-checked, which catches the
classic swap: `{lat: 10.4, lng: 59.1}` is two valid numbers and a station in the
Indian Ocean.

It does **not** catch a bad conversion. A source document in this domain almost
always arrives in UTM — Norwegian SAR plans are written in zone 32V, and the
brief renders positions back as UTM — so every coordinate has to be converted
before it can be written here. A transposed digit or the wrong zone yields a
coordinate that is perfectly valid and in the wrong place, and nothing downstream
objects: the range check passes for anything on Earth, and `analyze` cannot know
where a station was meant to be. Convert in bulk with one reviewable step rather
than by hand per station, and spot-check a few against the source.

[ADR-0061](../../../docs/adrs/0061-utm-coordinate-input-in-source-format.md)
proposes accepting a UTM string directly wherever a position is taken, which
would remove this step. Until it lands, decimal degrees are the only accepted
form.

## Identity

`uuid` is optional everywhere it appears. Omit it and the compiler mints one;
`get_plan` always includes it, so an edited copy of a published plan rebuilds onto
the *same* plan rather than a duplicate. If you are editing, keep the uuids you
were given.
