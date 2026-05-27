---
id: DESIGN-004
title: Exercise brief template
status: Accepted
started: 2026-05-25
accepted: 2026-05-25
owners: ["kengu"]
related_code:
  - lib/models/exercise.dart
  - lib/models/station.dart
  - lib/models/role_play.dart
  - lib/models/actor.dart
  - lib/models/program.dart
related_designs:
  - exercise-player.md
  - stations-tab.md
  - roleplays-tab.md
related_adrs:
  - 0018-roleplayer-data-model.md
  - 0022-markdown-content-as-files.md
  - 0023-brief-theme-tokens.md
---

# Exercise brief template

> This document is in English. Field names, audience identifiers, helper names and code symbols are English throughout. The Norwegian labels that appear in tables and snippets are quoted from the `nb` template or from the source LSOR booklet.

## TL;DR

A new feature renders an **exercise brief** as a markdown document, generated from RingDrill data through a versioned **template**. v1 ships one template (`ringdrill-standard-v1`, `nb` locale). Rich-text fields are added to `Program`, `Exercise`, `Station`, `RolePlay` and `Actor` to hold the long-form content that today lives only in a manually maintained Word document. Per [ADR-0022](../adrs/0022-markdown-content-as-files.md), the markdown content lives as `.md` files inside the drill archive rather than as JSON strings. Entities remain the source of truth. The brief is a projection, rendered on demand.

## Rationale

LSOR (a Norwegian Red Cross search-and-rescue training program) maintains a ~50-page Word booklet that mirrors every exercise, station, marker and rotation. Names, UTM positions, radio channels and rotation times appear in three to five places, and again in external map systems and printouts. When an entity changes, updates must be propagated by hand.

RingDrill already owns the structured data. The fragmented tab UI is good for editing one entity at a time but poor for reading the whole picture. The brief closes that gap. The booklet becomes a render target instead of a manually edited master.

## Goals

1. Replace the LSOR booklet as the authoritative reading surface so that changes in RingDrill flow into the document automatically.
2. Provide three audience-tailored views from the same data: `participant`, `instructor` and `director`.
3. Make templates first-class so additional templates can be added (per discipline, per organization, branded) without changing the renderer or the data model.
4. Keep entities as the single source of truth.

## Non-goals

* **No bidirectional editing in v1.** Long-form content is edited per-field on the entity. A markdown editor on each field replaces a markdown parser over the rendered document.
* **No template editor in the app.** Templates are `.md.mustache` files in `assets/templates/`. Adding or editing one is a code change.
* **No template marketplace.** When Teams accounts arrive, a team can select a built-in template id. Custom uploads are out of scope.
* **No live preview pane in the form.** The brief opens in its own route.
* **No native PDF export in v1.** Browser print is good enough.

## Concepts

### Templates

A `Template` has an id, version, locale, scope and an asset path. v1 registers one entry in code:

```
ringdrill-standard-v1, locale=nb, scope=system, asset=assets/templates/ringdrill-standard-v1.nb.md.mustache
```

`TemplateRegistry` is the lookup service. The renderer takes a template id, never a filename. `Exercise.templateId` is nullable. Null falls through to the system default. When Teams accounts arrive, an org-level default is consulted before the system default.

### Audience

The same template produces three documents based on a `BriefAudience` parameter:

| Audience      | Director notes | Actor PII | Other markers |
|---------------|---------------:|----------:|--------------:|
| `participant` | no             | no        | name only     |
| `instructor`  | yes            | no        | yes           |
| `director`    | yes            | yes       | yes           |

Mustache sections (`{{#if_director}}...{{/if_director}}` and `{{#if_instructor_or_director}}...{{/if_instructor_or_director}}`) gate audience-specific blocks. One template, three render parameters.

The audience IDs are intentionally distinct from the session-runtime roles (`coordinator`, `observer`, `roleplayer`) defined in [ADR-0019](../adrs/0019-roleplayer-participant-role.md). Session roles govern what a device can do live. Brief audience governs what content is visible to a reader. The two axes overlap in practice (the same person is often both `coordinator` at run-time and `director` audience pre-exercise) but are orthogonal concepts.

The English audience IDs remain `participant`, `instructor` and `director` in code, in ARB keys and in template booleans. The `nb` template and the audience-picker UI map them to Norwegian labels that match LSOR practice: `participant` -> "Deltaker", `instructor` -> "Veileder", `director` -> "Øvelsesleder". `instructor` does not become "Instruktør" because that term carries an authoritative-teacher connotation absent from how veiledere actually work in the field.

### Cross-references in rich text

A rich-text field needs to refer to data that lives elsewhere ("the IPP at &lt;UTM&gt;"). v1 uses inline mustache expressions inside the field content:

```mustache
... mellom IPP ({{station.position.utm}}) og badestranden ved Verdens Ende.
```

The expression is resolved at brief-generation time. When the cast changes, `{{roleplay.actor.realName}}` re-resolves automatically. Rich text is stored as raw markdown, not a tree, so the editor never normalizes `{{` and `}}` away.

### Document structure

`Program` is the document root and contains a list of exercises. Each `Exercise` contains a list of stations. The template iterates exercises, then stations under each exercise, and renders a top-level table of contents.

### Storage

Markdown content lives as `.md` files in the `.drill` archive ([ADR-0022](../adrs/0022-markdown-content-as-files.md)). Entity classes still expose plain `String?` fields. `DrillFile` reads and writes the files transparently. The schema bumps from 1.1 to 1.2.

## Field mapping

Columns in the tables below:

* **Booklet field** — label as it appears in the LSOR Word document, quoted in source language (Norwegian) with an English gloss.
* **Source** — where the rendered value comes from.
* **Status** — `existing`, `new`, `derived`, or `deferred` (out of scope for v1).

### Program

| Booklet field                    | Source                                | Status   |
|----------------------------------|---------------------------------------|----------|
| Title                            | `program.name`                        | existing |
| Subtitle                         | `program.description`                 | existing |
| Org logo                         | `program.org.logo`                    | deferred |
| Table of contents                | derived from exercises + stations     | derived  |
| Intro ("Generelt om spill...")   | `program.briefIntroMd` (new)          | **new**  |
| Comms ("Talegrupper")            | `program.commsMd` (new)               | **new**  |

`briefIntroMd` and `commsMd` are program-level because the same intro and channels apply to every exercise.

### Exercise

| Booklet field                  | Source                                                                                       | Status   |
|--------------------------------|----------------------------------------------------------------------------------------------|----------|
| Title                          | `exercise.name`                                                                              | existing |
| Tid (duration)                 | derived                                                                                      | derived  |
| Metode (method)                | `exercise.methodMd` (new)                                                                    | **new**  |
| Læringsmål (learning goals)    | `exercise.learningGoalsMd` (new)                                                             | **new**  |
| Øvingsmomenter (training focus)| `exercise.trainingFocusMd` (new)                                                             | **new**  |
| Organisering (ring config)     | derived (`numberOfRounds`, `executionTime`, `evaluationTime`, `rotationTime`, `numberOfStations`, `numberOfTeams`) | derived |
| Organisering (schedule)        | derived (`schedule`)                                                                         | derived  |
| Ordreformat (order format)     | `exercise.orderFormatMd` (new)                                                               | **new**  |
| Tips til gjennomføring         | `exercise.executionTipsMd` (new)                                                             | **new**  |
| Samband (comms)                | `exercise.commsMd` (new), falls back to `program.commsMd`                                    | **new**  |

`exercise.commsMd` overrides `program.commsMd` when non-null.

### Station

| Booklet field                            | Source                                                       | Status   |
|------------------------------------------|--------------------------------------------------------------|----------|
| Title                                    | derived (parent name + index + `station.variantSuffix` (new))| mixed    |
| Post placement (UTM)                     | `station.position`                                           | existing |
| Tid (duration)                           | derived                                                      | derived  |
| Utstyrsbehov (equipment)                 | `station.equipmentMd` (new)                                  | **new**  |
| Situasjon (situation)                    | `station.situationMd` (new)                                  | **new**  |
| Oppdrag (mission, incl. "Utførelse")     | `station.missionMd` (new)                                    | **new**  |
| Samband (comms)                          | inherits from exercise                                       | derived  |
| Administrasjon og forsyninger (logistics)| `station.logisticsMd` (new)                                  | **new**  |
| Kritiske spørsmål (critical questions)   | `station.criticalQuestionsMd` (new)                          | **new**  |
| Forslag til svar (leader Q&A)            | `station.leaderAnswersMd` (new)                              | **new**  |
| Right-column "TIPS OG NOTATER"           | `station.directorNotesMd` (new)                              | **new**  |

The booklet's right-hand "TIPS OG NOTATER" column holds notes for instructors and the director. The audience filter hides `directorNotesMd` from `participant` briefs.

### RolePlay

| Booklet field             | Source                                  | Status   |
|---------------------------|-----------------------------------------|----------|
| Title (role name)         | `roleplay.name`                         | existing |
| Markørspill (behavior)    | `roleplay.behavior`                     | existing |
| Background                | `roleplay.background`                   | existing |
| Signalement (description) | `roleplay.signalement`                  | existing |
| Age                       | `roleplay.age`                          | existing |
| Position                  | `roleplay.position`                     | existing |
| Props / hand-overs        | `roleplay.propsMd` (new)                | **new**  |

The existing fields `behavior`, `background` and `actor.notes` migrate from JSON strings to `.md` files in schema 1.2 ([ADR-0022](../adrs/0022-markdown-content-as-files.md)). Content is preserved on migration.

### Actor (PII, `director` audience only)

| Booklet field    | Source            | Status   |
|------------------|-------------------|----------|
| Real name        | `actor.realName`  | existing |
| Phone            | `actor.phone`     | existing |
| Personal notes   | `actor.notes`     | existing |

### Summary of new fields

```dart
// Program
@JsonKey(includeFromJson: false, includeToJson: false) String? briefIntroMd;
@JsonKey(includeFromJson: false, includeToJson: false) String? commsMd;

// Exercise
@JsonKey(includeFromJson: false, includeToJson: false) String? methodMd;
@JsonKey(includeFromJson: false, includeToJson: false) String? learningGoalsMd;
@JsonKey(includeFromJson: false, includeToJson: false) String? trainingFocusMd;
@JsonKey(includeFromJson: false, includeToJson: false) String? orderFormatMd;
@JsonKey(includeFromJson: false, includeToJson: false) String? executionTipsMd;
@JsonKey(includeFromJson: false, includeToJson: false) String? commsMd;
String? templateId;

// Station
String? variantSuffix;
@JsonKey(includeFromJson: false, includeToJson: false) String? equipmentMd;
@JsonKey(includeFromJson: false, includeToJson: false) String? situationMd;
@JsonKey(includeFromJson: false, includeToJson: false) String? missionMd;
@JsonKey(includeFromJson: false, includeToJson: false) String? logisticsMd;
@JsonKey(includeFromJson: false, includeToJson: false) String? criticalQuestionsMd;
@JsonKey(includeFromJson: false, includeToJson: false) String? leaderAnswersMd;
@JsonKey(includeFromJson: false, includeToJson: false) String? directorNotesMd;

// RolePlay
@JsonKey(includeFromJson: false, includeToJson: false) String? propsMd;
```

All `*Md` fields are nullable and excluded from JSON. `DrillFile` reads and writes them as `.md` files. `templateId` and `variantSuffix` are short structural fields and stay in JSON. Empty fields render as omitted sections, not empty headings.

## Template anatomy

The v1 template is one mustache file in `nb` locale at `assets/templates/ringdrill-standard-v1.nb.md.mustache`. The snippet below is illustrative.

```mustache
# {{program.name}}

{{#program.description}}_{{program.description}}_{{/program.description}}

{{> toc}}

{{#program.briefIntroMd}}
## Generelt om spill og øvingsledelse

{{{program.briefIntroMd}}}
{{/program.briefIntroMd}}

{{#program.commsMd}}
## Talegrupper

{{{program.commsMd}}}
{{/program.commsMd}}

{{#exercises}}
## {{name}}

| | |
|-|-|
| Tid           | {{durationLabel}} |
| Metode        | {{{methodMd}}} |
| Læringsmål    | {{{learningGoalsMd}}} |
| Øvingsmomenter| {{{trainingFocusMd}}} |
| Organisering  | {{{setupLabel}}} |
| Ordreformat   | {{{orderFormatMd}}} |
| Tips til gjennomføring | {{{executionTipsMd}}} |

{{#stations}}
### {{exerciseNumber}}{{stationLetter}} – {{name}}{{#variantSuffix}} – {{variantSuffix}}{{/variantSuffix}}

**Post {{exerciseNumber}}{{stationLetter}} plassering:** {{position.utm}}

#### Tid
{{durationLabel}}

#### Utstyrsbehov
{{{equipmentMd}}}

{{#roleplays}}
#### Markørspill ({{name}})
{{{behavior}}}
{{#propsMd}}

**Rekvisita:** {{{propsMd}}}
{{/propsMd}}
{{#if_director}}{{#actor}}

**Markør:** {{realName}}{{#phone}} ({{phone}}){{/phone}}
{{/actor}}{{/if_director}}
{{/roleplays}}

#### Situasjon
{{{situationMd}}}

#### Oppdrag
{{{missionMd}}}

#### Samband
{{{effectiveCommsMd}}}

#### Administrasjon og forsyninger
{{{logisticsMd}}}

#### Kritiske spørsmål
{{{criticalQuestionsMd}}}

#### Forslag til svar på spørsmål fra lagleder
{{{leaderAnswersMd}}}

{{#if_instructor_or_director}}
{{#directorNotesMd}}
> **Notater til instruktør/øvingsledelse**
>
> {{{directorNotesMd}}}
{{/directorNotesMd}}
{{/if_instructor_or_director}}

{{/stations}}
{{/exercises}}
```

`{{{...}}}` is unescaped mustache, used for fields that already contain markdown.

Renderer helpers exposed to the template:

* `durationLabel` — total duration with units, localized per template.
* `setupLabel` — the ring-configuration string (e.g. `4 x (15 | 10 | 5)`) plus per-round wall-clock times.
* `exerciseNumber`, `stationLetter` — derived from indices in the program and exercise (`a = 0`, `b = 1`, ...).
* `position.utm` — `LatLng` formatted as `32V 0580414E 6552008N`. Formatter already exists in `lib/utils/projection.dart`.
* `effectiveCommsMd` — exercise's `commsMd` with a fallback to the program's `commsMd`.

## Render example

Source data for one station, followed by the rendered output. Content is Norwegian because the `nb` template is in use.

### Source data (excerpt)

```dart
final exercise = Exercise(
  uuid: 'ex-3',
  name: 'Øvelse 3 – Øve PIK + taktisk tankegang',
  startTime: SimpleTimeOfDay(hour: 8, minute: 30),
  numberOfTeams: 4,
  numberOfRounds: 4,
  numberOfStations: 4,
  executionTime: 60,
  evaluationTime: 15,
  rotationTime: 5,
  methodMd: 'Gruppevis øving utendørs',
  learningGoalsMd: '''
Etter gjennomført øvelse skal deltakerne
- kunne planlegge oppdraget taktisk ut fra situasjon og oppdrag
- kunne iverksette oppdraget
- kunne lede mannskaper under utførelsen
''',
  commsMd: '**Talegruppe:** RK-VFOLD-ØV2  \n**Telefon til KO:** 93258930',
);

final station = Station(
  index: 0,
  name: 'Demens',
  variantSuffix: null,
  position: LatLng(58.99, 10.43),  // -> 32V 0580414E 6552008N
  equipmentMd: 'Et stort hus til å gjennomføre hussøk i (bruk huset «Gamlestuen» på Eidene).',
  situationMd: '''
(AL) Anne Glemsk 39 år er meldt savnet fra Gamlehuset i {{station.position.utm}},
av pårørende kl 13.00 i dag. Sist sett på vei mot kjellertrappen kl 09.30.
''',
  missionMd: '''
(AL) Politiet ønsker at Røde Kors utfører søk etter savnet kvinne. Det er
avklart at før hussøk kan starte må området rundt huset finsøkes.

**Utførelse**

(AL) Lag 2.X gjennomfører finsøk på R25 først, deretter hussøk av søndre fløy.
''',
  logisticsMd: '(AL) Aksjonssekk etter stående ordre. KO sin posisjon er 32V 0580465E 6551894N.',
  criticalQuestionsMd: '''
(AL)
- Har gått seg fast? Dersom de går utenfor en vei kommer de sjelden langt før de
  setter seg ned.
- Hvilke klær har hun på?
''',
  leaderAnswersMd: '''
- Har vert savnet fire ganger før. Funnet i nærheten av barndomshjemmet.
- Bruker briller, kan ha gått fra dem.
''',
  directorNotesMd: 'Markør er utplassert. Det skal gjennomføres hussøk av «Søndre». Rom 105 er låst med vilje.',
);

final roleplay = RolePlay(
  uuid: 'rp-anne',
  name: 'Anne Glemsk',
  age: 39,
  signalement: '160 cm, grått hår, blå anorakk',
  behavior: '''
Du spiller en dement dame i god fysisk form. Noen karakteristiske trekk:
- Du svarer på navnet ditt, men er forvirret om hvor du er.
- Du går videre hvis du ikke blir snakket til etter 30 sekunder.
''',
  stationIndex: 0,
  position: LatLng(58.99, 10.43),
  actorUuid: 'actor-12',
);

final actor = Actor(uuid: 'actor-12', realName: 'Kari Hansen', phone: '99887766');
```

### Rendered output (`director` audience)

```markdown
### 3a – Demens

**Post 3a plassering:** 32V 0580414E 6552008N

#### Tid
60 min.

#### Utstyrsbehov
Et stort hus til å gjennomføre hussøk i (bruk huset «Gamlestuen» på Eidene).

#### Markørspill (Anne Glemsk)
Du spiller en dement dame i god fysisk form. Noen karakteristiske trekk:
- Du svarer på navnet ditt, men er forvirret om hvor du er.
- Du går videre hvis du ikke blir snakket til etter 30 sekunder.

**Markør:** Kari Hansen (99887766)

#### Situasjon
(AL) Anne Glemsk 39 år er meldt savnet fra Gamlehuset i 32V 0580414E 6552008N,
av pårørende kl 13.00 i dag. Sist sett på vei mot kjellertrappen kl 09.30.

#### Oppdrag
(AL) Politiet ønsker at Røde Kors utfører søk etter savnet kvinne. Det er
avklart at før hussøk kan starte må området rundt huset finsøkes.

**Utførelse**

(AL) Lag 2.X gjennomfører finsøk på R25 først, deretter hussøk av søndre fløy.

#### Samband
**Talegruppe:** RK-VFOLD-ØV2
**Telefon til KO:** 93258930

#### Administrasjon og forsyninger
(AL) Aksjonssekk etter stående ordre. KO sin posisjon er 32V 0580465E 6551894N.

#### Kritiske spørsmål
(AL)
- Har gått seg fast? Dersom de går utenfor en vei kommer de sjelden langt før de
  setter seg ned.
- Hvilke klær har hun på?

#### Forslag til svar på spørsmål fra lagleder
- Har vert savnet fire ganger før. Funnet i nærheten av barndomshjemmet.
- Bruker briller, kan ha gått fra dem.

> **Notater til instruktør/øvingsledelse**
>
> Markør er utplassert. Det skal gjennomføres hussøk av «Søndre». Rom 105 er
> låst med vilje.
```

The `participant` render of the same station drops the actor PII line and the director-notes blockquote.

## Behavior

### Where the brief lives

A **Brief** action on `ExerciseScreen` and the Exercise tab opens `/brief/:exerciseUuid` (single exercise) or `/brief/program/:programUuid` (whole program). The route is reachable but not in the bottom nav. It is a read mode for an exercise, the same way `ExercisePlayer` is a run mode.

### Presentation

The brief is presented as a **fullscreen modal bottom sheet**, not as a regular pushed route. The route still exists and is the canonical entry point so deep links, web-print URLs and future shareable brief links stay viable, but its only job is to open the sheet on first frame. Closing the sheet pops the route.

This applies on every platform, including web. A future "viewer" mode that renders the brief inline as a regular page (e.g. for embedding or for an external read-only audience) can be added later without changing how the in-app Brief is reached.

The sheet uses `showModalBottomSheet(isScrollControlled: true, useSafeArea: true)` with a `DraggableScrollableSheet` at `initialChildSize: 1.0`. The slim app bar from [ADR-0023](../adrs/0023-brief-theme-tokens.md) becomes the sheet's top bar, with two adjustments:

* A drag handle (4×40 px pill in `BriefTheme.borders.subtle`) sits centered above the title row. This handle is the only surface that responds to drag-to-dismiss. The handle area uses the parent `DraggableScrollableSheet` controller; the markdown body below uses its own scroll controller so a vertical drag inside the reading column scrolls the text rather than dismissing the sheet.
* A close button (`Icons.close`) replaces the back arrow in the leading slot. Closing pops the underlying route as well, keeping the URL in sync with the visible state.

Audience selector, search and print actions stay where ADR-0023 put them. The reading-column max-width (720 px) and the wide-vs-narrow TOC rules apply inside the sheet exactly as they would on a route-rendered page.

### Where the data is edited

Each new field gets a markdown editor on the relevant form screen:

* `ProgramFormScreen`: `briefIntroMd`, `commsMd`.
* `ExerciseFormScreen`: `methodMd`, `learningGoalsMd`, `trainingFocusMd`, `orderFormatMd`, `executionTipsMd`, `commsMd`. Grouped under a collapsible "Brief" section.
* `StationFormScreen`: all new station fields, grouped the same way.
* `RolePlayFormScreen`: `propsMd`. The existing `behavior` and `background` fields are reinterpreted as markdown.

**Editor library: `appflowy_editor` primary, `super_editor` backup.** Both are native-Flutter, document-first editors with first-class markdown import/export. Their mental model is "writing a document", which matches how the brief renders. `appflowy_editor` wins on production maturity (it powers the AppFlowy app on desktop and mobile) and on a polished out-of-the-box UX (slash-commands, drag handles, blocks). `super_editor` is leaner and is the fallback if AppFlowy struggles with our mustache syntax or with several editor instances on the same form.

Rejected:

* `flutter_quill` — toolbar/Quill.js lineage projects a form-field feel that fights the document output.
* `html-editor-enhanced` — WebView-based with HTML output. The brief pipeline is markdown end-to-end, and several WebViews on one form are expensive and fragile.
* Plain `TextField` with a live-preview tab — workable but hostile to authors who do not read raw markdown.

### Render targets

* In-app viewer: `markdown_widget`, wrapped in `BriefMarkdown` and themed by `BriefTheme` per [ADR-0023](../adrs/0023-brief-theme-tokens.md). A TOC sidebar shows on wide screens, the audience selector sits in a slim app bar.
* Print: the same markdown under a print stylesheet that hides chrome and forces page breaks between exercises.

## Visual design

The Brief view is the only reading surface in RingDrill. Every other screen is a working surface where Material accents earn their weight by marking actions. The Brief earns its weight by getting out of the way. Its visual language is therefore intentionally distinct from the rest of the app. The full token set, palette values, typography scale and layout numbers live in [ADR-0023](../adrs/0023-brief-theme-tokens.md). This section captures the user-facing design decisions that ride along with that ADR so a reader of DESIGN-004 sees the whole picture.

### Reference look

The reference is the [Zudoku](https://zudoku.dev) docs-site family, with [Mintlify](https://mintlify.com) as a secondary cross-check. Both share four traits that the Brief adopts:

* Near-monochrome body text with low-saturation neutrals. No bright primary color anywhere in the reading column.
* A slim, near-flat app bar separated from the canvas by a 1px subtle border, not a filled primary surface.
* Links that match body text and are distinguished only by a faint underline.
* A constrained reading column (~720 px) centered on a wider canvas.

The Brief inherits these in both light and dark mode. Light mode uses a white canvas with slate-700 body text. Dark mode uses a near-black canvas (`#0B0F17`) with slate-300 body text. The exact values are in ADR-0023; nothing in the Brief is derived from `Theme.of(context).colorScheme`.

### Sidebar TOC rules

The wide-screen layout has one TOC sidebar (240 px) on the left. The sidebar lists at most two heading levels:

1. Exercise (`## {{name}}`)
2. Station (`### {{exerciseNumber}}{{stationLetter}} – {{name}}`)

Per-station metadata that today is rendered as `#### Tid`, `#### Utstyrsbehov`, etc. is split into two categories. One-line metadata becomes inline bold (`**Tid:** 60 min.`) so it does not appear in the outline. Multi-paragraph content keeps the `####` heading because its outline entry pays for itself. The audit lives in the renderer-helpers table in the next section.

The audience selector and the search action live in the app bar, not in the sidebar. The sidebar is purely navigational.

### In-document TOC

The mustache template emits a `## Innholdsfortegnelse` block at the top of the document, but the renderer hides it on wide screens via a `wideTocSidebar` parameter ([ADR-0023, "Renderer signature change"](../adrs/0023-brief-theme-tokens.md)). On narrow screens the sidebar is hidden and the in-doc TOC takes over. Wide-screen readers see the sidebar, narrow-screen readers see the inline TOC. They never see both.

### Audience selector

`SegmentedButton<BriefAudience>` in the app bar on wide screens, at the top of the body on narrow screens. The audience IDs and Norwegian labels are the same as in the Audience subsection above (`participant` -> "Deltaker", `instructor` -> "Veileder", `director` -> "Øvelsesleder"). The styling per ADR-0023 uses `BriefTheme.text.body` for unselected segments and `BriefTheme.surfaces.sidebar` as the fill for the selected segment, with `BriefTheme.text.heading` on top. No Material primary fill.

### Headings that produce outline entries

The sidebar only exists on wide screens. On narrow screens there is no sidebar at all; the in-doc TOC takes its place. The "Sidebar TOC entry" column below describes the wide layout.

| Markdown level | Source                                              | Sidebar TOC entry |
|----------------|-----------------------------------------------------|-------------------|
| `# `           | `program.name`                                      | no (one per doc)  |
| `## `          | `exercise.name`                                     | yes               |
| `## `          | "Innholdsfortegnelse"                               | hidden on wide, rendered on narrow without sidebar |
| `## `          | "Generelt om spill og øvingsledelse" (when present) | yes               |
| `## `          | "Talegrupper" (when present)                        | yes               |
| `### `         | station heading                                     | yes               |
| `#### `        | "Markørspill", "Situasjon", "Oppdrag", "Samband", "Administrasjon og forsyninger", "Kritiske spørsmål", "Forslag til svar..." | yes (under station) |
| inline bold    | "Tid", "Utstyrsbehov" (one-liner metadata)          | no                |

`#### Tid` becomes `**Tid:** {{durationLabel}}`. `#### Utstyrsbehov` keeps the heading when the field is multi-paragraph, but the line that follows is no longer a separate heading. The `_renderer_` helpers table earlier in this document is unchanged; only the template emission shape changes.

### Code spans

UTM coordinates and radio identifiers render as inline code (`` `32V 0580414E 6552008N` ``, `` `RK-VFOLD-ØV2` ``) so they stand out from prose without using color. The mustache template wraps `position.utm` and the comms identifiers in backticks. `BriefTheme.code` styles the result.

### Light vs. dark

Both modes are first-class. The Brief is read on phones in daylight (light) and on desktops at night (dark) in roughly equal measure based on the target audience. ADR-0023's acceptance criterion is that both modes look intentional, not auto-inverted. The hardcoded palette values in that ADR are the contract.

## Deferred decisions

1. **Bidirectional editing.** Editing rendered markdown back into structured fields is a future design.
2. **Wiki-style `[[ref:...]]` references.** v1 uses inline mustache. A `[[ref:]]` chip is a v2 UX upgrade.
3. **Branding.** When Teams accounts arrive, a team selects a brand (logo, color, colophon). The template will reference `{{org.logo}}` etc. with sensible fallbacks.
4. **Per-discipline templates.** v1 ships one. The registry can grow without the renderer changing.
5. **Native PDF export.** Browser print is the v1 escape hatch.
6. **Localized templates beyond `nb`.** An `en` variant arrives when the catalog hosts English-language programs.

## Open questions

1. **Editor risks to verify in prototype.** Two risks to validate before committing to `appflowy_editor`: (a) markdown roundtrip stability when content contains mustache `{{...}}` expressions, especially around autoformatting triggers, and (b) performance and focus behaviour with several editor instances on one form (`StationFormScreen` will host seven `*Md` fields). If either fails on a target platform, switch to `super_editor`.
2. **`commsMd` on `Program`, `Exercise`, or both.** The proposed both-with-override reflects the LSOR booklet, but if the same channel is always used across a season, the exercise-level field becomes dead UI. Worth checking against one or two more real programs.
3. **`Program.briefIntroMd` shape.** Free-form text is simpler. A structured list (e.g. ring-rotation instructions as discrete bullets) would let other templates reuse the bullets. The LSOR booklet has both.
4. **Multiple roleplays per station.** The model already supports it. Confirm whether the renderer needs to surface an iteration index so the template can label markers ("Markør 1", "Markør 2").

## Implementation notes

Each stage is a separate PR.

**Stage 1a — Archive format (ADR-0022).** Bump schema to 1.2. Extend `DrillFile` read/write to handle `.md` files. Update `netlify/functions/drills-upload.js` to accept `'1.2'`. Migrate existing `behavior`, `background` and `actor.notes` to file form on next save.

**Stage 1b — Data model.** Add the new `String?` fields, all annotated `@JsonKey(includeFromJson: false, includeToJson: false)`. Run `make build`. Update `ProgramX.computeContentHash` to include the new fields. Lock down eager-load order in tests so identical content hashes the same regardless of file order.

**Stage 2 — Template engine.** Add a `mustache_template` dependency. Register `ringdrill-standard-v1` in `TemplateRegistry`. Add `BriefRenderer` under `lib/services/`. Unit-test against a fixture program.

**Stage 3 — Brief route.** Add `/brief/...` routes. The route opens the brief as a fullscreen modal bottom sheet on first frame and pops itself when the sheet closes (see Presentation above). Sheet content uses `markdown_widget` wrapped by `BriefMarkdown` and themed by `BriefTheme` ([ADR-0023](../adrs/0023-brief-theme-tokens.md)). Add the audience toggle in the slim sheet top bar. Sidebar TOC on wide screens, in-doc TOC on narrow screens, never both at the same time. Template emits `**Tid:**` inline instead of `#### Tid`. Drag-to-dismiss is wired only to the drag handle, not the markdown body.

**Stage 4 — Form fields.** Add the per-section editors. Group under a collapsible "Brief" section on each form.

**Stage 5 — Print stylesheet.** Web-only print CSS. Hide chrome, force page breaks between exercises.

A "Brief" action on existing list rows is deferred until the route works end-to-end.

## References

* `2026 LSOR øvelseshefte.docx` — source booklet the v1 `nb` template targets. Not checked into the repo (contains PII).
* [ADR-0018](../adrs/0018-roleplayer-data-model.md) — publishable `RolePlay` vs. local `Actor` split. The audience filter relies on it.
* [ADR-0022](../adrs/0022-markdown-content-as-files.md) — markdown content stored as `.md` files in the drill archive. Drives the storage model for the new fields.
* [ADR-0023](../adrs/0023-brief-theme-tokens.md) — `BriefTheme` token set and `BriefMarkdown` wrapper for the in-app viewer. Locks in the docs-site look in both light and dark mode.
* [DESIGN-002](./stations-tab.md) — Stations tab. The brief route is a parallel read surface.
* [DESIGN-003](./roleplays-tab.md) — RolePlays tab. The brief surfaces roleplays under their station.
