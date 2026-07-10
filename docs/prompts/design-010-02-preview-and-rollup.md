# Implement DESIGN-010 — Prompt 2: preview and rollup

You are working in the RingDrill repository, on `design-010` (stage 1 landed: the Flutter-free field resolver, `PlanScope` program facets, `ExerciseScope`, and `openFormSurface` re-provision). This stage is the first **visible** payoff: an in-editor preview so an author sees resolved tokens without saving and opening the brief. It has two faces sharing one primitive — a per-section preview toggle and a read-only rollup of all sections. [ADR-0048](../adrs/0048-flutter-free-field-resolver.md), `docs/design/010-inline-preview-and-resolve-scope.md` ("Preview mode", "Section rollup under the default section", "Settled decisions") and [ADR-0030](../adrs/0030-wide-screen-master-detail-layout.md) are authoritative. Read `AGENTS.md` rule 9.

**No model, ARB (beyond toggle labels), renderer, or schema change.** This consumes the stage-1 cascade in the view layer.

## The primitive

"Resolve a field string against the scopes, render it read-only." Both faces use it:

* A widget reads `PlanScope` (variables + program facets), `ExerciseScope` (exercise facets) and `StationScope` (locations/persons + the station's own facets), plus the field's own `overrides`, assembles the field-resolver's context, and calls `lib/services/brief/field_resolver.dart`.
* The resolved markdown renders via `BriefMarkdown` (`lib/views/widgets/brief_markdown.dart`), matching the brief; a single-line field renders as resolved `Text`.

**Scope gap to close first.** Stage 1 put program facets on `PlanScope` and exercise facets on `ExerciseScope`, but `StationScope` still carries only locations/persons — it does **not** carry the station's own facets (`station.name`, `station.stationCode`, `station.position.utm`, `station.description`, `station.variantSuffix`), nor the roleplay's own (`roleplay.name`/`age`/`signalement`/`position.utm`). Without them, `{{station.name}}` etc. would not resolve in preview. Extend the scope(s) so the resolver has the full `refContext` the brief builds. `stationCode` needs the exercise number / `program.stationNumberFormat`; supply it best-effort (from `ExerciseScope`/`PlanScope` if available) and leave it to the placeholder if not — do not duplicate the renderer's numbering math if it is awkward; note what you did.

**Liveness expectation (from stage 1):** `exercise.*` facets come from the last-saved `Exercise`, not live keystrokes, and `ExerciseScope` exists only for a saved exercise. That is fine here — preview is for a post/marker's own text, not the exercise's own timing fields being typed. Do not try to make `exercise.*` live in this stage.

## Settled decisions (DESIGN-010)

* Preview toggle is **per section**, remembered per section within the session (not editor-wide, not across scopes).
* Rollup is an **inline continuation** on narrow (one scroll: fields, then the resolved sections) and a **side-by-side pane** on wide (edit left, preview right — master/detail, ADR-0030), behind its own toggle, default off.
* Each rendered section in the rollup is **tap-to-edit**: tapping jumps to that section in the `SectionNavigatedForm` switcher.
* Preview/rollup render for a **single audience** (use the viewer role from settings, default director) — not per-audience.

## Scope

Four commits.

### Commit 1. Resolution-context assembly + station/roleplay facets on the scope

Add a small view-layer helper that, given a `BuildContext` and a field string (+ the field's `overrides`), reads the scopes, assembles the field-resolver context, and returns resolved markdown. Extend `StationScope` (and the roleplay editor's provision of it) to carry the station's own `refContext` facets and, in the roleplay editor, the roleplay's own facets, so the resolver sees the same context the brief builds. No visible change yet.

Files: `lib/views/widgets/station_scope.dart`, a resolution helper (co-locate with `ringdrill_text_field.dart` or a small util), the station/roleplay editors' scope wiring. `flutter analyze` + `flutter test test/views/`. Commit: `feat(views): assemble field-resolver context from the scope cascade`.

### Commit 2. Per-section preview toggle

Give `RingDrillTextField`/`RingDrillTextArea` a `preview` state and add a toggle to the section chrome in `SectionNavigatedForm` (e.g. an eye in the section bar). In preview, a markdown area renders resolved via `BriefMarkdown`; a single-line field renders resolved `Text`. The toggle is per section, its state remembered per section for the session. Live with a debounce (resolution is cheap string work). Edit state is unchanged (chips + insertion menu).

Files: `lib/views/widgets/ringdrill_text_field.dart`, `lib/views/widgets/section_navigated_form.dart`, ARB for the toggle labels ("Forhåndsvis"/"Rediger"), `make i18n`. `flutter analyze` + `flutter test test/views/`. Commit: `feat(views): per-section preview toggle for token-aware fields`.

### Commit 3. Rollup under the default section

In the exercise, station and roleplay editors' base section, add a read-only rollup of the active sections, each resolved via the helper and stacked in order, behind its own toggle (default off). Narrow: inline continuation beneath the structural fields. Wide: a side-by-side live-preview pane using the master/detail split (ADR-0030). Each rendered section is tap-to-edit → jumps to that section in the switcher. Built per section from the field resolver, not from `BriefRenderer.render()`.

Files: `section_navigated_form.dart` (or a rollup widget), the three editor screens, ARB for the rollup toggle ("Vis forhåndsvisning"/"Skjul forhåndsvisning"), `make i18n`. `flutter analyze` + `flutter test test/views/`. Commit: `feat(views): read-only section rollup under the default section`.

### Commit 4. Tests

* Context assembly: a field with `{{var.*}}`, `{{program.name}}`, `{{exercise.name}}`, `{{station.loc/person.*}}` and `{{station.name}}`/`{{station.position.utm}}` resolves in preview to the same text the brief produces for the same working state; an undeclared/unresolved token shows the brief's placeholder.
* Preview toggle: flipping a section shows the rendered markdown and back to the editable field; the choice is remembered per section within the session; a single-line field previews as resolved text.
* Rollup: the default section's rollup lists the active sections resolved; narrow renders inline, wide renders as a side pane (drive via `WindowSizeClass`); tapping a rendered section navigates to it in the switcher.

`flutter analyze`, `flutter test test/views/`, then the single final gate: full `flutter test` + `dart build cli`.

Files: test files under `test/views/`. Commit: `test(views): cover preview resolution, the toggle and the rollup`.

## Ground rules

* Reuse the stage-1 field resolver and scopes, `BriefMarkdown`, `SectionNavigatedForm`, `WindowSizeClass`/master-detail (ADR-0030). No new resolution logic, no second resolver.
* View + l10n + test only. No model, renderer, or schema change. `make i18n` only when ARB changes.
* Preview and rollup are **read-only**; editing stays in the field's edit state and per section.
* **Test-loop discipline (rule 9):** per commit `flutter analyze` + `flutter test test/views/`; full `flutter test` + `dart build cli` **once at the end**.

## Verification (final gate — run once)

1. `flutter analyze` clean; full `flutter test` no new failures.
2. `make i18n` idempotent; `dart build cli` succeeds.
3. Manual smoke (narrow and wide, nb and en): toggling a section to preview shows resolved markdown that matches the brief (`{{station.position.utm}}`, `{{var.*}}`, `{{station.person.x.name}}` all resolved); the default-section rollup shows the whole post/marker resolved (inline on narrow, side pane on wide); tapping a rollup section jumps to it; editing is unchanged when preview is off.
4. `git diff --stat` touches `lib/views/…`, `lib/l10n/…`, `test/…` only. No model, renderer, or schema change.
5. Clean tree; localizations committed with ARB changes.

## Deliverables

Conventional Commits (English) on `design-010`, clean tree, targeted tests per commit, one full-suite gate at the end (rule 9). The final commit body notes the editor now previews resolved tokens (per-section toggle and a default-section rollup) via the stage-1 resolver and scopes, that `StationScope` now carries the station/roleplay own facets, and that `exercise.*` reflects the last-saved exercise (not live).

ADR-0048 and DESIGN-010 are authoritative. The `RingDrillText`/display-surface upgrade and the Post/Spill detail sheets are **stage 3**, and leaf fields are **stage 4** — both out of scope here. If assembling the station `refContext` needs more than extending `StationScope` (e.g. the `stationCode` numbering), stop and report rather than duplicating renderer math.
