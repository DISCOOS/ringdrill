You are working in the RingDrill repository. Implement the **shared addable-field form pattern** across the entity forms (follow-up item 13, which also closes item 7). The authoritative specs:

- `docs/design/brief-template.md` (DESIGN-004, Accepted) — read the **amended "Where the data is edited"** section (base fields + addable optional fields, the RolePlay reference) and the **Field mapping** tables for the per-field booklet labels.
- `docs/prompts/DESIGN-006-followups.md` — items 13 and 7.

If this prompt contradicts the specs, the specs win; stop and ask.

## Concept

`RolePlayFormScreen` already ships the pattern: base fields always visible, plus optional sections that start hidden, with an `Icons.add` button per not-yet-added section and a remove affordance on each added field (`_Section` / `_activeSections`, plain multi-line `TextFormField`s). Generalize that into one reusable component and apply it to every entity form so the new DESIGN-004 markdown fields are editable in-app.

**This is UI-only.** All the markdown fields already exist on the models (`Program`, `Exercise`, `Station`, `RolePlay`) as sidecar `@JsonKey(includeFromJson:false, includeToJson:false)` fields that `DrillFile` reads/writes as `.md` files. **No model change, no codegen for models, no schema bump, no drill-format change.** Saving an entity with a field set persists it through the existing path.

## What this is, and is not

**In scope:** a reusable "optional sections" widget; a new `ProgramFormScreen`; adding the optional markdown sections to `ExerciseFormScreen` and `StationFormScreen`; `RolePlayFormScreen` adopting the shared widget; the section-label l10n keys.

**Out of scope:** no new model fields, no `SilentWitness` / tause vitner (item 8), no rich-text editor library (plain multi-line `TextFormField` per section, as the RolePlay reference does — the `appflowy_editor` idea in DESIGN-004 is explicitly not adopted), no change to the brief renderer or audience.

## Ground rules

Read `AGENTS.md`. The ones that bite:

- **Localize.** Each optional section needs a label. Use the Norwegian booklet labels from DESIGN-004's field-mapping tables (e.g. exercise: "Metode", "Læringsmål", "Øvingsmomenter", "Ordreformat", "Tips til gjennomføring", "Samband"; station: "Utstyrsbehov", "Situasjon", "Oppdrag", "Administrasjon og forsyninger", "Kritiske spørsmål", "Forslag til svar", "Notater"; program: "Generelt om spill og øvingsledelse", "Talegrupper", "Før hver post"). Add keys to both arb files and run `make build`.
- **CLI Flutter-free, mobile-safe imports, no new Sentry.** Widget-layer only.
- **Match existing Dart style.** No new lint suppressions without an inline reason.
- **Verify before claiming green.** `flutter analyze` and `flutter test` at the end of each step.

## Investigate before you wire (do this first, no commit)

1. `RolePlayFormScreen` (`lib/views/roleplay_form_screen.dart`): the `_Section` enum, `_activeSections`, `_addSection`, `_labelFor`/`_controllerFor`, and the build code that renders active sections + the add-buttons. This is the reference to extract.
2. The existing base forms: `ExerciseFormScreen`, `StationFormScreen` (today name/description/position), and how each is opened (`openFormSurface`) and persisted (`ProgramService.saveExercise` / `saveStation` / `saveRolePlay`).
3. The plan-edit path: `renamePlan`/`renameActivePlan` (name only today) and how a `Program`'s `description` + brief fields would be saved (`ProgramService` program save path / `_repo`). The overview (DESIGN-006 stage 3, read-only) is the intended entry point — tapping it should open `ProgramFormScreen`.

Append a short note to `docs/prompts/DESIGN-006-addable-forms-handoff.md` (create it) before step 1.

## Steps

### Step 1 — `refactor(widget)`: extract a reusable optional-sections component

Pull the addable-section pattern out of `RolePlayFormScreen` into a reusable widget (e.g. `lib/views/widgets/optional_field_sections.dart`). It takes a list of section specs (id, localized label, `TextEditingController`), the set of active section ids, and `onAdd`/`onRemove` callbacks; it renders each active section as a labeled multi-line `TextFormField` with a remove affordance, then a wrap of `Icons.add` buttons for the not-yet-added sections. The parent owns the controllers and the active set (so it can build/save the entity). Refactor `RolePlayFormScreen` to use it with no behaviour change.

Gates green. Commit.

### Step 2 — `feat(program)`: ProgramFormScreen

Add `lib/views/program_form_screen.dart`: base **name** (required) and **description**, plus the optional-sections component for `briefIntroMd`, `commsMd`, `beforeRoundMd`. Pops the updated `Program`; the caller persists via the program save path. Wire an entry point from the read-only overview (tap, or a small edit affordance) per DESIGN-006; keep the existing AppBar-title quick-rename. Locally-created plans can now get a description and brief content — this closes item 7.

Gates green. Commit.

### Step 3 — `feat(exercise)`: optional sections on ExerciseFormScreen

Add the optional-sections component to `ExerciseFormScreen` for `methodMd`, `learningGoalsMd`, `trainingFocusMd`, `orderFormatMd`, `executionTipsMd`, `commsMd`, below the existing base fields. No change to the existing fields or save flow beyond carrying the new values through `copyWith`.

Gates green. Commit.

### Step 4 — `feat(station)`: optional sections on StationFormScreen

Add the optional-sections component to `StationFormScreen` for `equipmentMd`, `situationMd`, `missionMd`, `logisticsMd`, `criticalQuestionsMd`, `leaderAnswersMd`, `directorNotesMd`, below name/description/position. Carry the values through `copyWith` on save.

Gates green. Commit.

### Step 5 — `test` + `docs`: cover the forms and update DESIGN-004

Widget tests under `test/`: the optional-sections component adds/removes a section; `ProgramFormScreen` edits name/description and a brief field and pops the updated `Program`; an exercise and a station form round-trip one optional field each. Mark items 13 and 7 resolved in `docs/prompts/DESIGN-006-followups.md`, and update DESIGN-004's "Where the data is edited" note from "amend planned" to "implemented" with a one-line changelog.

Gates green. Commit.

## When you finish or get stuck

- Append a closing entry to `docs/prompts/DESIGN-006-addable-forms-handoff.md`.
- Off-scope findings become new numbered follow-ups in `docs/prompts/DESIGN-006-followups.md`.
- If a step is blocked (e.g. no program save path for `description`/brief fields), write a one-paragraph note to `docs/prompts/DESIGN-006-addable-forms-blockers.md` and exit rather than guessing.
- These are additive and post-release-unit, so each may be pushed once green.
