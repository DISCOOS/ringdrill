# DESIGN-008 follow-up 02 — prev/next section commands

You are working in the RingDrill repository. Small follow-up to DESIGN-008. Read `docs/design/008-plan-variables-and-section-navigated-editor.md` for context. The section-navigated shell `lib/views/widgets/section_navigated_form.dart` (Stage 3) drives the flag-on Program editor.

## The change

Add **previous / next section** commands to the right of the section switcher, complementing it: the dropdown jumps freely, the arrows step sequentially without opening the menu. They cycle the **active** sections in order (`widget.sections`), never the addable ones. Clamp at the ends — the "previous" control is disabled on the first section, "next" on the last — rather than wrapping, so position is legible.

Placement: on compact, two icon buttons (`Icons.chevron_left` / `Icons.chevron_right`) in the `AppBar` actions, immediately right of the switcher title and before the overflow and Save. On medium/expanded, put them in the detail-pane header row (`_WideBody`), next to the section label and its overflow. The rail already shows every section on wide, so the arrows are secondary there, but include them for consistency.

## Ground rules

* Localized tooltips via ARB (`formSectionPrevious`, `formSectionNext`), then `make i18n`.
* Disabled at the ends: `onPressed: null` on the boundary control (standard Material disabled state is fine for a bounded prev/next).
* State lives in `_SectionNavigatedFormState._selectedId` already — move it by index within `widget.sections`.
* Shell-only change; the flag-off path does not use this widget. No `AppFlags` work.
* No new lint suppressions. `flutter analyze` and `flutter test` before green.

## Scope

Two steps.

### Step 1. Prev/next in the shell

In `section_navigated_form.dart`:

* Add `_selectPrevious()` / `_selectNext()` that move `_selectedId` to the adjacent entry in `widget.sections`, clamped (no-op at the ends).
* Compact: add the two `IconButton`s to the `AppBar.actions`, left of the existing overflow + Save, each disabled (`onPressed: null`) at its boundary, with the ARB tooltips.
* Wide: add the same two controls to the `_WideBody` detail-pane header `Row`, before/after the label and overflow as reads best.
* Guard the single-section case: with one active section both controls are disabled.

Add `formSectionPrevious` and `formSectionNext` to `app_en.arb` / `app_nb.arb` (Norwegian "Forrige seksjon" / "Neste seksjon"). Run `make i18n`.

Files expected in this commit:

* `lib/views/widgets/section_navigated_form.dart`
* `lib/l10n/app_en.arb`, `lib/l10n/app_nb.arb`, regenerated `lib/l10n/app_localizations*.dart`

Run `git status`. Commit: `feat(views): add prev/next section commands to SectionNavigatedForm`.

### Step 2. Tests

Extend the `SectionNavigatedForm` tests under `test/views/`:

* At the first section, "previous" is disabled and "next" advances to the second.
* At the last section, "next" is disabled and "previous" goes back.
* In the middle, both work and land on the expected sections.
* Arrows traverse only active sections, never the addable ones.
* With a single active section, both are disabled.
* Works at both compact and wide widths.

Run `flutter analyze`. `flutter test test/views/`. Then the full suite.

Files expected in this commit:

* test file(s) under `test/views/`

Run `git status`. Commit: `test(views): cover prev/next section navigation`.

## Verification

1. `flutter analyze` clean; `flutter test` no new failures.
2. `make i18n` idempotent after commit.
3. `git diff --stat main` (since the prior tip) touches only `lib/views/…`, `lib/l10n/…`, `test/views/…`.
4. Clean tree gate and diff sanity as in the stage prompts.

## Deliverables

Two Conventional Commits (English) on `design-008`, clean tree. This is a contained follow-up; no ADR.
