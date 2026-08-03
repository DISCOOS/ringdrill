# Brief templates

> This document is in English (AGENTS.md rule 12). Norwegian words appear only
> where they are UI labels quoted from the app or the source booklet.

This is the reference for the **brief template** — the versioned
`.md.mustache` file that turns RingDrill's structured data into a readable
exercise brief. It covers the template format, how templates are registered
and selected, the audiences they serve, and the placeholders a template author
writes. The decision behind it is [DESIGN-004](./design/brief-template.md);
the theming tokens are [ADR-0023](./adrs/0023-brief-theme-tokens.md); the
markdown-as-files storage is [ADR-0022](./adrs/0022-markdown-content-as-files.md).
For the tokens a *content* author types inside an entity's fields
(`{{var.*}}`, `{{station.*}}`, and the rest), see [`variables.md`](./variables.md).

## What a template is

A brief is a **projection**. The entities (`Program`, `Exercise`, `Station`,
`RolePlay`, `Actor`) stay the single source of truth; the brief is rendered
from them on demand through a template, never edited as a document itself.
Long-form content — a station's situation, a roleplay's background — lives as
`.md` files inside the drill archive (ADR-0022) and is fed into the template as
markdown.

A template is a mustache file under `assets/templates/`. Adding or changing one
is a code change: there is no in-app template editor and no template
marketplace. v1 ships a single family, `ringdrill-standard-v1`, with `nb`
(default) and `en` locale variants.

## Registration and selection

`TemplateRegistry` (`lib/services/brief/template_registry.dart`) is the lookup
service. A template **id** names a *family*; each family has one or more locale
variants that share the id but differ in `locale` and `assetPath`. Callers
always pass an id, never a path.

```
ringdrill-standard-v1
  ├─ nb  → assets/templates/ringdrill-standard-v1.nb.md.mustache   (default)
  └─ en  → assets/templates/ringdrill-standard-v1.en.md.mustache
```

`resolve(templateId, locale)` falls back to the system default family when the
id is null or unknown, and to the family's default locale (`nb`) when the
locale is null or has no matching variant. `Exercise.templateId` is nullable;
null falls through to the system default. `scope` is `system` for v1; `org` and
`team` defaults are consulted here first when Teams accounts arrive.

Adding a template means: drop a new `.md.mustache` in `assets/templates/`,
register it in `TemplateRegistry`, and (for a new asset path) add it to the
asset bundle in `pubspec.yaml`.

## Audiences

The same template produces three documents from one `BriefAudience`
(`lib/services/brief/brief_audience.dart`), which toggles which mustache
sections are active:

| Audience      | Norwegian label | Director notes | Actor PII (real name, phone) |
|---------------|-----------------|:--------------:|:----------------------------:|
| `participant` | Deltaker        | no             | no                           |
| `instructor`  | Veileder        | yes            | no                           |
| `director`    | Øvelsesleder    | yes            | yes                          |

The identifiers stay English in code; the Norwegian labels are the UI strings.
The two derived flags are `includesDirectorNotes` (everyone except
`participant`) and `includesActorPii` (`director` only), surfaced to the
template as the section flags below.

## The template language

Templates are [mustache](https://mustache.github.io/). Three constructs carry
almost everything:

- `{{value}}` — HTML/markdown-escaped output. Use for plain scalars that must
  not inject markup: a name, a code, a duration label.
- `{{{value}}}` — **unescaped** output. Use for any value that already *is*
  markdown — every `...Md` field, and pre-formatted values like
  `{{{positionValue}}}`. Escaping these would show literal backticks and
  asterisks instead of rendering them.
- `{{#section}}...{{/section}}` — a section, rendered when the value is truthy
  (or once per item for a list); `{{^section}}...{{/section}}` is the inverted
  form, rendered when it is falsy. Audience gating uses this:
  `{{#if_director}}...{{/if_director}}` and
  `{{#if_instructor_or_director}}...{{/if_instructor_or_director}}` wrap the
  blocks that only some audiences see, and omit a metadata row whose source
  field is null with `{{#methodMd}}...{{/methodMd}}`.

Note the contrast with [`variables.md`](./variables.md): the tokens *there*
(`{{var.*}}`, `{{station.*}}`) live inside an entity's field values and are
resolved by the field resolver **before** the value is placed into the
template context. The placeholders *here* are the template's own context keys,
resolved by the mustache engine when the template is expanded. A station's
`descriptionMd`, for example, has already had its `{{var.*}}` and
`{{station.*}}` tokens resolved by the time `{{{descriptionMd}}}` renders it.

## The render context

`BriefRenderer` (`lib/services/brief/brief_renderer.dart`) is the authoritative
source of the context shape — the keys below are a guide, not a spec, and the
renderer is where the list is kept current. The context nests program →
exercises → stations → roleplays, plus the audience flags.

A **station** exposes, among others:

| Key | Description |
|-----|-------------|
| `name` | The station's resolved name — cross-references and variables resolved, chip markup stripped (a heading is a plain surface), and its own `{{station.name}}` withheld so a self-reference cannot expand. See [`variables.md`](./variables.md#names-resolve-too--with-two-differences). |
| `stationCode` | The station's numbered code, e.g. `3.1`. |
| `stationAnchor` | The in-document link target for this station. |
| `variantSuffix` | The station's optional variant suffix. |
| `position` | Coordinate (default UTM format, [ADR-0050](./adrs/0050-per-output-format-chip-formatting.md)) as a copy chip. |
| `positionValue` | Pre-formatted "plassering" value — a UTM code chip, or a muted "no position" label. |
| `stationDurationLabel` | The per-station duration label. |
| `descriptionMd` | Resolved description (markdown). |
| `equipmentMd`, `situationMd`, `missionMd`, `logisticsMd`, `criticalQuestionsMd`, `leaderAnswersMd` | Resolved long-form markdown bodies. |
| `directorNotesMd` | Director's notes (director / instructor audiences only). |
| `effectiveCommsMd` | Effective communications block (markdown) — the exercise's `comms`, or the program's, resolved in *this station's* scope ([ADR-0068](./adrs/0068-cascaded-fields-and-scoped-overrides.md)), so a station's `variableOverrides` applies to the block it inherits. |
| `roleplays` | List of this station's roleplays (see below). |
| `if_director` | Section flag — true for the director audience (actor PII). |
| `if_instructor_or_director` | Section flag — true for instructor and director (director notes). |

A **roleplay** in that list exposes:

| Key | Description |
|-----|-------------|
| `name` | The marker's resolved role name. |
| `age` | The marker's age. |
| `signalement` | The marker's appearance/description. |
| `behavior`, `background`, `propsMd` | Resolved long-form markdown bodies. |
| `actor` | Sub-context, **director audience only**: `realName` and `phone` (phone as a copy chip). |
| `if_director` | Section flag — true for the director audience. |

An **exercise** exposes its own facets and metadata labels:

| Key | Description |
|-----|-------------|
| `durationLabel` | Total duration with per-round breakdown. |
| `setupLabel` | The organisation/setup label. |
| `methodMd`, `learningGoalsMd`, `trainingFocusMd`, `orderFormatMd`, `executionTipsMd`, `effectiveCommsMd` | Resolved long-form markdown blocks. |
| `organisationBlock` | The full Organisering block: conduct line, the program's `before_round`, and the rotation round list. The program's text, resolved in *this exercise's* scope ([ADR-0068](./adrs/0068-cascaded-fields-and-scoped-overrides.md)). |

## The copy-chip and action-chip convention

Positions, addresses and phone numbers render through a `ChipFormatter`
chosen per output format ([ADR-0050](./adrs/0050-per-output-format-chip-formatting.md),
[DESIGN-013](./design/013-actionable-field-chips.md)): a plain **inline-code
chip** — the value wrapped in backticks — for the brief and the
non-interactive exports (PDF, DOCX), or an **action chip** (tap-to-call /
open-in-maps, the copy icon retained) for the app preview and, later, the
HTML brief. `BriefRenderer` always passes the default (copy-chip) formatter,
so the template only ever sees the copy-chip markdown shape below; the
action-chip encoding is an app-only rendering concern (`brief_markdown.dart`),
invisible to the template.

Two shapes appear in the template:

- `{{{position}}}` (a station's/roleplay's coordinate) and an actor's
  `{{{phone}}}` — the bare value as a code chip, unescaped because it already
  contains markdown. Parentheses around a chip are folded *into* it so the
  pill and its brackets stay on one line and the copied text is the bare
  value.
- `{{{positionValue}}}` — a station-level convenience value pre-formatted for
  the "Post Nx plassering:" line: a `` `UTM` `` code chip when the station has a
  position, or a muted italic "no position" label when it does not. It is
  triple-braced because it already contains markdown.

All are pre-formatted in the renderer, so a template author writes the
placeholder and gets the pill; the chip styling itself is
[ADR-0023](./adrs/0023-brief-theme-tokens.md).

## Constraints (v1)

- No bidirectional editing: content is edited per-field on the entity, not by
  parsing the rendered brief back.
- No in-app template editor, no marketplace, no live preview pane (the brief
  opens in its own route; the per-field inline preview is a separate
  mechanism, see [`variables.md`](./variables.md)).
- No native PDF export; browser print is the export path.

## See also

- [`variables.md`](./variables.md) — the `{{var.*}}` and cross-reference
  tokens that resolve inside field values before they reach the template.
- [DESIGN-004](./design/brief-template.md) — the brief template decision
  (concepts, audiences, the full `nb`/`en` template walkthrough).
- [ADR-0022](./adrs/0022-markdown-content-as-files.md) — markdown content as
  `.md` files in the archive.
- [ADR-0023](./adrs/0023-brief-theme-tokens.md) — brief theming and the copy
  pill styling.
- [DESIGN-013](./design/013-actionable-field-chips.md) — actionable field
  chips (tap-to-call, open-in-maps) and the `place`/`position` facet model.
- [ADR-0050](./adrs/0050-per-output-format-chip-formatting.md) — the
  `ChipFormatter` strategy and the `ringdrill://chip` encoding.
