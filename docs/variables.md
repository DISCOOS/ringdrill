# Variables and tokens

> This document is in English (AGENTS.md rule 12). Norwegian words appear only
> where they are UI labels quoted from the app.

This is the reference for the token systems an author can put inside RingDrill
markdown fields — a station description, a roleplay's background, a program
intro — and how those tokens resolve, both in the generated brief and in the
in-editor preview. It sits between the decision records that own the rules
([ADR-0046](./adrs/0046-plan-variables.md) plan variables,
[ADR-0047](./adrs/0047-scenario-locations-and-persons.md) scenario locations
and persons, [ADR-0048](./adrs/0048-flutter-free-field-resolver.md) the shared
resolver) and the day-to-day question "what can I type in this field, and why
did it come out literal?". For the brief *template* itself — the
`.md.mustache` files and their own placeholders — see
[`template.md`](./template.md).

## Two kinds of token

A markdown field can contain two token families, and they are resolved by two
different mechanisms in a fixed order:

1. **Plan variables** — `{{var.<name>}}`. Author-defined values declared once
   on the plan. Resolved by a dedicated substitution pass.
2. **Cross-references** — `{{program.*}}`, `{{exercise.*}}`, `{{station.*}}`,
   `{{roleplay.*}}`, and the scenario tokens `{{station.loc.<slug>}}` /
   `{{station.person.<slug>}}`. Read-only projections of the surrounding
   entities. Resolved by a mustache pass against a context the caller
   assembles.

The `var.` prefix is what keeps the two apart: a plan variable can never
collide with a derived field, and a `var.*` lookup is always routed through the
variable resolver, never mustache (ADR-0046).

## Plan variables — `{{var.<name>}}`

A variable is an author-defined value declared **once** on the `Program` and
referenced from any markdown field as `{{var.<name>}}`, so editing it in one
place updates every brief that uses it. Identity is plan-global: `Exercise`
and `Station` may override a variable's *value* for their subtree (a
`variableOverrides` map keyed by name) but never declare new names.

The reference key is the variable's `name`, a slug matching
`^[a-z][a-z0-9_]*$`. Renaming a variable is therefore a plan-wide refactor
(every `{{var.old}}` is rewritten to `{{var.new}}` behind a confirmation);
deleting one that is still referenced is blocked.

### Resolution chain

`{{var.frekvens}}` resolves at render time by walking outward from the field:
the station's override if the field belongs to a station and the key is set,
otherwise the enclosing exercise's override, otherwise the program's declared
default. The chain is `program → exercise → station`; a roleplay reads through
its station's overrides.

### Types

Every variable has a declared `type` (DESIGN-008 follow-up 11) that drives the
editor input, validation and the canonical stored encoding. `string` is the
back-compatible default, so a variable written before types existed loads and
renders exactly as before.

| Type       | Canonical stored value            | Rendered as                          |
|------------|-----------------------------------|--------------------------------------|
| `string`   | free text                         | as-is                                |
| `number`   | decimal string, `.` separator     | locale decimal                       |
| `time`     | 24-hour `HH:MM`                   | localized time                       |
| `date`     | ISO `yyyy-MM-dd`                  | localized date                       |
| `duration` | whole minutes as an integer       | `"45 min"` / `"1 t 30 min"`          |
| `location` | see below                         | place text + position copy chip      |

Formatting is always canonical → formatted at render time, so the brief, the
slash-menu previews and the override tables' parenthesized defaults all read
the same.

A `location` variable carries more than a scalar: a place text plus a
coordinate (the `Location` geo shape minus `kind`). Its value lives in a
structured `VariableLocation` (`place` + nullable `LatLng`), not in the string
`value`. It exposes the same facets as a scenario location —
`{{var.<name>.place}}`, `{{var.<name>.position}}` — and the bare
`{{var.<name>}}` renders place + position.

### Validation states

Three states, deliberately kept distinct (ADR-0046):

- **Undeclared reference** — `{{var.x}}` where `x` is not declared. An error:
  red token in the editor, save blocked.
- **Declared but empty** — resolves to an empty string everywhere in the
  chain. A soft warning (amber token, visible placeholder in the brief), not a
  block: "blank default, filled per exercise" is a valid authoring state.
- **Invalid for type** — a default or override that does not read as its
  declared type. Blocks save, surfaced inline on the offending field.

## Cross-reference tokens

These are read-only projections of the entities around the field. The
authoritative catalog of what each scope offers is
`lib/views/widgets/plan_field_tokens.dart` (`PlanFieldTokens`), which mirrors
the `refContext` maps the renderer builds — a token the picker offers is always
one the renderer can resolve at that scope.

Each scope cascades on top of the ones above it, so a station field can also
reference `{{exercise.*}}` and `{{program.*}}`, and a roleplay field can
reference everything up to `{{program.*}}`.

### Program — available in every field

| Token | Description |
|-------|-------------|
| `{{program.name}}` | The plan's name. |
| `{{program.description}}` | The plan's description. |

### Exercise — the enclosing exercise; available in exercise, station and roleplay fields

| Token | Description |
|-------|-------------|
| `{{exercise.name}}` | The exercise's name. |
| `{{exercise.numberOfTeams}}` | Number of teams. |
| `{{exercise.numberOfRounds}}` | Number of rotation rounds. |
| `{{exercise.startTime}}` | Start clock time (`HH:MM`). |
| `{{exercise.endTime}}` | End clock time (`HH:MM`). |
| `{{exercise.timeLabel}}` | Clock-time span, e.g. `08:30–10:30`. |
| `{{exercise.durationLabel}}` | Total duration with per-round breakdown, e.g. `2 timer (60 min pr oppdrag)`. |
| `{{exercise.executionTime}}` | Execution phase length, in minutes. |
| `{{exercise.evaluationTime}}` | Evaluation phase length, in minutes. |
| `{{exercise.rotationTime}}` | Rotation (move) phase length, in minutes. |
| `{{exercise.phaseBreakdown}}` | The three phase lengths as `execution \| evaluation \| rotation`, in minutes. |

### Station — the enclosing station; available in station and roleplay fields

| Token | Description |
|-------|-------------|
| `{{station.name}}` | The station's name. |
| `{{station.stationCode}}` | The station's numbered code, e.g. `3.1`. In-editor preview leaves it empty — the code needs the program's numbering, which no view scope carries, so it fills in only once the brief is generated. |
| `{{station.position}}` | The station's coordinate (default UTM format, [ADR-0050](./adrs/0050-per-output-format-chip-formatting.md)), as a copy chip in the brief or an actionable (open-in-maps) chip in the app. |
| `{{station.variantSuffix}}` | The station's optional variant suffix. |

`{{station.description}}` is intentionally *not* offered: it is the field the
author edits in the station's own base section, so referencing it there would
recurse on itself (DESIGN-009 follow-up 4c).

### Roleplay — the open roleplay; available only in roleplay fields

| Token | Description |
|-------|-------------|
| `{{roleplay.name}}` | The marker's role name. |
| `{{roleplay.age}}` | The marker's age. |
| `{{roleplay.description}}` | The marker's appearance/description. |
| `{{roleplay.position}}` | The marker's coordinate (default UTM format), as a copy chip in the brief or an actionable (open-in-maps) chip in the app. |

As with `station.description`, `{{roleplay.name}}` is excluded from the
roleplay's own name field (self-referential there) but available in its
behavior, background and props fields.

### Scenario tokens — station locations and persons

A station carries its own named locations and persons (ADR-0047). Fields on
that station, and on the roleplays linked to it, can reference them by slug
with an optional dotted facet path. These resolve only when a station is in
scope. `<slug>` is the location's or person's own slug.

| Token | Description |
|-------|-------------|
| `{{station.loc.<slug>}}` | A named location; the bare token renders its default (place text plus a position copy chip). |
| `{{station.loc.<slug>.place}}` | The location's place text (an address). |
| `{{station.loc.<slug>.label}}` | The location's label. |
| `{{station.loc.<slug>.position}}` | The location's coordinate (default UTM format, [ADR-0050](./adrs/0050-per-output-format-chip-formatting.md)), as a copy chip in the brief or an actionable (open-in-maps) chip in the app. |
| `{{station.person.<slug>}}` | A named person; the bare token renders the effective (portrayer-aware) name. |
| `{{station.person.<slug>.name}}` | The person's name. |
| `{{station.person.<slug>.age}}` | The person's age. |
| `{{station.person.<slug>.gender}}` | The person's gender. |
| `{{station.person.<slug>.description}}` | The person's appearance/description. |
| `{{station.person.<slug>.loc.<facet>}}` | The person's own linked location, with any of the location facets above. |

## The copy-chip and action-chip convention

Positions, addresses and phone numbers resolve through a `ChipFormatter`
(ADR-0050, [DESIGN-013](./design/013-actionable-field-chips.md)) chosen per
output format — the resolver never hardcodes one rendering:

- **`CopyChipFormatter`** (the default) — every value is an **inline-code
  chip**, the value wrapped in backticks. Used by the brief and by the
  non-interactive exports (PDF, DOCX, once they exist). The rich renderer (the
  brief and the in-app detail cards) turns each chip into a tappable copy
  pill; a plain surface (a title, a list row) strips the backticks so the raw
  value reads as ordinary text.
- **`ActionChipFormatter`** — the app preview (and, later, the HTML brief). A
  position or phone chip additionally encodes a launch target as a markdown
  link with an internal, structured `ringdrill://chip?action=...` URI, which
  the app's markdown renderer wires to a tap action (open a map, dial a
  number) while the copy icon still copies the plain value. An address stays
  a copy chip in every formatter — it has no reliable launch target.

So `{{station.position}}` resolves to `` `32V 601234 6643210` `` — a copy pill
in the brief, an open-in-maps pill in the app preview, plain text in a title.
The same applies to `{{roleplay.position}}`, a location variable's `.position`
facet, and (in the brief, director audience only) an actor's phone number,
whose surrounding parentheses are folded into the chip so the copied value
stays the bare number.

`{{{positionValue}}}` is a *template-level* value, not a field token — see
[`template.md`](./template.md#the-copy-chip-and-action-chip-convention).

## How resolution runs

All resolution goes through one Flutter-free resolver,
`lib/services/brief/field_resolver.dart` (`resolveField`, ADR-0048). The brief
renderer and the in-editor preview call the same code, so the preview is the
brief. One field is resolved by running this pipeline repeatedly until the
string stops changing, bounded by `maxResolvePasses` (10):

1. **Variable substitution** — every `{{var.*}}` is replaced (declared →
   value, undeclared → the unknown-variable placeholder). No `{{var.*}}` ever
   reaches the mustache pass.
2. **Scenario tokens** — `{{station.loc/person.*}}` are resolved when a
   scenario station is supplied.
3. **Mustache cross-reference pass** — the remaining `{{program/exercise/
   station/roleplay.*}}` are rendered against the assembled context.

The loop is what makes *nested* tokens work: a variable value that itself
contains `{{station.name}}`, or a `{{program.name}}` that expands to something
containing `{{var.year}}`, only appears after the pass that injected it, and
the next pass resolves it. A genuinely circular reference never converges and
is left as visible literal text once the cap is hit, rather than hanging.

### The all-or-nothing gotcha

The mustache pass is **all-or-nothing per field**. It is non-lenient: a single
token that references a scope absent from the context throws, and the resolver
catches it and returns the field's *pre-mustache* text — with **every**
cross-reference token in that field left literal, not just the missing one.

This is the honest, bounded limitation ADR-0048 accepts (a partial context
resolves to the brief's unknown-reference behaviour, never a crash), but it has
a sharp edge: if a surface renders a field that mixes a resolvable token with
one whose scope it forgot to provide, the *whole* field falls back to literal.
A background field containing both `{{roleplay.name}}` and
`{{exercise.numberOfTeams}}` shows both tokens raw if the editor provided a
`RoleplayScope` but no `ExerciseScope`.

Because a legitimate literal fallback (e.g. an orphaned `{{station.*}}` in a
roleplay with no linked station) and a missing-scope bug look identical from
inside the resolver, the swallowed failure is surfaced through the
`onResolveFieldError` hook rather than vanishing. The app routes it to Sentry
(behind the analytics-consent gate, in debug and release); tests assert on it.

## The scope model (view layer)

The brief renderer assembles the resolution context from the loaded `Program`.
The live app instead reads it from the widget tree through a cascade of
`InheritedWidget` scopes, and hands the resolver plain data — the resolver
itself never reads a `BuildContext` (ADR-0048, DESIGN-010).

| Scope           | Carries                                             |
|-----------------|-----------------------------------------------------|
| `PlanScope`     | program facets + the declared variables (mandatory) |
| `ExerciseScope` | the enclosing exercise                              |
| `StationScope`  | the station's facets + its locations/persons        |
| `RoleplayScope` | the roleplay's own facets (name/age/description/UTM)|

`resolveScopedField(context, ...)` reads whichever scopes are present above the
field and builds the context from them; the read-only display widget
`RingDrillText` (`.plain` / `.rich`) uses it. For an eager label built
imperatively per item, where there is no scoped subtree to read from — a map
marker caption, a search result — `resolveModelField(context, ..., exercise:,
station:, roleplay:)` takes the models explicitly instead. Both share one set
of facet builders, so they never drift.

The consequence of the all-or-nothing gotcha, restated as a rule: **a surface
must provide every scope whose tokens its fields may reference.** A detail
viewer or editor that shows exercise/station/roleplay fields provides the whole
cascade; the roleplay and station editors provide `ExerciseScope` even though
they do not edit the exercise, precisely so an `{{exercise.*}}` token does not
take the rest of the field down with it. `openFormSurface` re-provides the
ancestor scopes across a Navigator push, since a pushed route lands outside the
calling context's `InheritedWidget` ancestry.

## See also

- [`template.md`](./template.md) — the brief template format and its own
  placeholders.
- [ADR-0046](./adrs/0046-plan-variables.md) — plan variables (model,
  namespace, resolution, validation, typed variables).
- [ADR-0047](./adrs/0047-scenario-locations-and-persons.md) — station
  locations and persons.
- [ADR-0048](./adrs/0048-flutter-free-field-resolver.md) — the shared
  Flutter-free resolver.
- [DESIGN-010](./design/010-inline-preview-and-resolve-scope.md) — inline
  preview and the resolve-scope cascade.
- [DESIGN-013](./design/013-actionable-field-chips.md) — actionable field
  chips (tap-to-call, open-in-maps) and the `place`/`position` facet model.
- [ADR-0050](./adrs/0050-per-output-format-chip-formatting.md) — the
  `ChipFormatter` strategy and the `ringdrill://chip` encoding.
- [`glossary.md`](./glossary.md) — domain vocabulary.
