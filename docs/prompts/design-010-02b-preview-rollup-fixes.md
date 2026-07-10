# Implement DESIGN-010 — Prompt 2b: preview and rollup fixes

You are working in the RingDrill repository, on `design-010` (stage 2 landed: the per-section preview toggle and the section rollup). This is a small **views + l10n** follow-up fixing three issues found in stage 2. [ADR-0048](../adrs/0048-flutter-free-field-resolver.md) and `docs/design/010-inline-preview-and-resolve-scope.md` are authoritative. Read `AGENTS.md` rule 9.

Two clear affordances, kept distinct after this:

* **The AppBar eye** = per-section preview: flip the *current section's* token-aware field(s) to rendered markdown in place. Labelled "Forhåndsvis"/"Rediger".
* **The rollup toggle** (base section) = expand the post/marker's rendered sections read-only. Relabelled "Vis/Skjul detaljer" here (see below).

**No model, renderer, or schema change.**

## Fixes

### Fix 1. The per-section eye must work on the base section

Today the base section (name, position, and the station **description** / "Postbeskrivelse") passes `preview: null` to `SectionNavigatedForm`, so the eye is disabled there — while markdown sections wire it and preview fine. That is why the eye looks "always disabled": the base section is the landing section. Wire the base section into per-section preview so the eye is enabled there and flips its token-aware body field to rendered, exactly as other sections do.

* The base section's **structural** fields stay editable regardless of preview: the name field and the `PositionFormField` are not text-preview targets. Only the token-aware markdown body (the station `description`; the exercise's / roleplay's equivalent base text field where one exists) flips to rendered when preview is on.
* Give the base `FormSection` a non-null `preview`/`onPreviewChanged` (tracked in the same `_previewSections` set, keyed by the base section id), and pass `preview:` to the description `RingDrillTextArea` in `_buildStationSectionBody` (and the exercise/roleplay base bodies).
* Where a base section genuinely has no previewable text field, leave `preview: null` (eye disabled) — that is correct, not a bug.

Files: `lib/views/station_form_screen.dart`, `lib/views/exercise_form_screen.dart`, `lib/views/roleplay_form_screen.dart`. `flutter analyze` + `flutter test test/views/`. Commit: `feat(views): enable per-section preview on the base section body`.

### Fix 2. Align the roleplay rollup indentation with the station editor

In the roleplay editor the rollup sections render with a large left indent; in the station editor they sit near the left edge. Align the roleplay rollup to the station editor's layout — the two should be visually identical. Find the padding/composition delta between how the two editors call `withSectionRollup` (roleplay `roleplay_form_screen.dart` vs station `station_form_screen.dart`) and/or the rollup content padding in `section_rollup.dart`, and make them consistent.

Files: `lib/views/roleplay_form_screen.dart` (and `section_rollup.dart` if the padding lives there). `flutter analyze` + `flutter test test/views/`. Commit: `fix(views): align the roleplay rollup indentation with the station editor`.

### Fix 3. Relabel the rollup toggle "Vis/Skjul detaljer"

Reusing "forhåndsvisning" for the rollup collides with the per-section eye. Relabel the rollup toggle "Vis detaljer" / "Skjul detaljer" (nb) — "Show details" / "Hide details" (en). Not "brief" (the rollup is one post/marker's slice, not the exported document) and not per-editor "spill"/"post" (what is shown/hidden is the sections, editor-agnostic). "Detaljer" is the neutral, editor-agnostic word. Leave the per-section eye labels ("Forhåndsvis"/"Rediger") unchanged. Change the values in **both** `app_nb.arb` (Vis/Skjul detaljer) and `app_en.arb` (Show/Hide details) — do not leave the en string on the old wording; `make i18n`.

Files: `lib/l10n/*.arb` + regenerated localizations, and wherever the rollup toggle reads its label (`section_rollup.dart` / the editors). `flutter analyze` + `flutter test test/views/`. Commit: `feat(l10n): label the rollup toggle "Vis/Skjul detaljer"`.

### Tests (fold into each commit; final gate once)

* Base-section preview: on the station editor's base section the eye is **enabled**; toggling it renders the description resolved (markdown) while the name field and position stay editable; toggling back restores editing.
* Rollup alignment: a widget test (or golden, if the repo uses them) asserting the roleplay rollup content uses the same horizontal insets as the station rollup — at minimum, no extra indent wrapper.
* Label: the rollup toggle text is "Vis/Skjul detaljer", not "forhåndsvisning"; the per-section eye tooltip/label is still "Forhåndsvis"/"Rediger".

`flutter analyze`, `flutter test test/views/`, then the single final gate: full `flutter test` + `dart build cli`.

## Ground rules

* Reuse the stage-2 machinery (`_previewSections`, `SectionNavigatedForm`, `SectionRollup`, `resolveScopedField`). No new preview mechanism.
* View + l10n + test only. No model, renderer, or schema change. `make i18n` only when ARB changes.
* Keep the two affordances distinct: eye = per-section field preview ("Forhåndsvis"); rollup = "Vis/Skjul detaljer".
* **Test-loop discipline (rule 9):** per commit `flutter analyze` + `flutter test test/views/`; full `flutter test` + `dart build cli` **once at the end**.

## Verification (final gate — run once)

1. `flutter analyze` clean; full `flutter test` no new failures.
2. `make i18n` idempotent; `dart build cli` succeeds.
3. Manual smoke: in the Post editor's base section the eye is enabled and previews the Postbeskrivelse (name/position still editable); the roleplay rollup lines up with the station rollup; the collapsible toggle reads "Vis/Skjul detaljer".
4. `git diff --stat` touches `lib/views/…`, `lib/l10n/…`, `test/…` only.
5. Clean tree; localizations committed with ARB changes.

## Deliverables

Conventional Commits (English) on `design-010`, clean tree, targeted tests per commit, one full-suite gate at the end (rule 9). The final commit body notes the per-section eye now works on the base section (previewing the description while structural fields stay editable), the roleplay rollup is aligned with the station editor, and the rollup toggle is relabelled "Vis/Skjul detaljer" (nb) / "Show/Hide details" (en).

ADR-0048 and DESIGN-010 are authoritative. The read-only Post/Spill **detail-sheet viewers** are **stage 3**, not part of this fix. If enabling base-section preview needs more than wiring `preview`/`onPreviewChanged` and passing `preview:` to the body field, stop and report.
