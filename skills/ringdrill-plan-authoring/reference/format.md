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

## The rotation

An exercise runs `numberOfRounds` rounds. Each round is
`executionTime + evaluationTime + rotationTime` minutes: the teams work, then get
feedback, then move. Every team is at a different station in a given round, and
all advance together.

`numberOfTeams` must be ≤ the number of stations. One round per station is a full
rotation, which is the usual intent.

You never write `schedule` or `endTime`. Both follow from the above.

## Markdown fields

Each takes a YAML block scalar (`|`), where the content is literal so markdown
needs no escaping:

```yaml
situation: |
  Kari Fiskeløs – fine search around the IPP within R25.
  Last seen {{station.loc.lkp.utm}}.
```

| Field | Scope | Holds |
|---|---|---|
| `intro` | plan | The brief's opening. Sets the frame for the whole plan. |
| `comms` | plan, exercise | Talk groups, phone numbers, call signs. |
| `before_round` | plan | What happens between rounds. |
| `method` | exercise | How the exercise is run pedagogically. |
| `learning_goals` | exercise | What participants should be able to do afterwards. |
| `training_focus` | exercise | What to watch for and evaluate. |
| `order_format` | exercise | The order template teams work to. |
| `execution_tips` | exercise | Practical notes for whoever runs it. |
| `equipment` | station | What the station needs on site. |
| `situation` | station | The scenario: who, where, when, what is known. |
| `mission` | station | The order the team is given. |
| `logistics` | station | Access, command post, transport. |
| `critical_questions` | station | What a good team leader should ask. |
| `leader_answers` | station | The answers to give if asked. Instructor-facing. |
| `director_notes` | station | Never shown to participants. |
| `behavior` | roleplay | How the marker acts. |
| `background` | roleplay | What the marker knows and has done. |
| `props` | roleplay | What the marker needs. |

A field you have nothing real to put in should be omitted, not filled with
something generic.

## Tokens

| Token | Resolves to |
|---|---|
| `{{var.<name>}}` | The variable's effective value at that scope. |
| `{{var.<name>.utm}}` / `.place` | Facets of a `location`-typed variable. |
| `{{station.loc.<slug>}}` | The location — its label and position. |
| `{{station.loc.<slug>.utm}}` | Just the coordinate, as UTM. |
| `{{station.person.<slug>}}` | The person's name. |
| `{{station.person.<slug>.age}}` | A person facet. |
| `{{plan.name}}`, `{{exercise.startTime}}`, `{{station.stationCode}}`, … | Fields of the enclosing scope. Call `schema`, or let `analyze_plan` list them. |

Scopes cascade **downwards** only: a `{{plan.*}}` token resolves inside a station
field, but `{{exercise.name}}` in a plan-level field has no exercise to resolve
against. `analyze_plan` distinguishes the two — "cannot resolve here" means the
scope is wrong, not the spelling.

## Coordinates

`{lat, lng}` in decimal degrees. The compiler stores them in the archive's own
order, so you never think about it. Latitude is range-checked, which catches the
classic swap: `{lat: 10.4, lng: 59.1}` is two valid numbers and a station in the
Indian Ocean.

## Identity

`uuid` is optional everywhere it appears. Omit it and the compiler mints one;
`get_plan` always includes it, so an edited copy of a published plan rebuilds onto
the *same* plan rather than a duplicate. If you are editing, keep the uuids you
were given.
