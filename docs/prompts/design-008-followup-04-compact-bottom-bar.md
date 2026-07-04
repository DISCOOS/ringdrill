# DESIGN-008 follow-up 04 — move compact section controls to a bottom bar

You are working in the RingDrill repository. Follow-up to DESIGN-008. Read `docs/design/008-plan-variables-and-section-navigated-editor.md` for context. The section-navigated shell is `lib/views/widgets/section_navigated_form.dart`.

## Why

On compact, the top `AppBar` is overcrowded: close, the section switcher (as the title), the overflow, prev/next (follow-up 02) and Save all compete for one row, so the section name truncates ("Varia…"). Move the whole section-navigation cluster into a `BottomAppBar`. The top bar then holds only close, a static title, and Save. The controls land in the thumb zone, and the section name gets room in the bottom selector.

This revises follow-up 02's compact placement — prev/next were added to the top `AppBar`; they now live in the bottom bar. **The wide (medium/expanded) master-detail layout is unchanged**: the rail already lists all sections and the detail-pane header already holds the label, prev/next and the overflow. Only the compact layout changes.

## Target layout (compact)

* **Top `AppBar`:** leading close (`Icons.close`), title = `widget.title` (the entity title, e.g. "Rediger plan") as plain `Text`, and Save as the only action. The title is no longer the switcher.
* **`BottomAppBar`:** left, the **section selector** — an `InkWell`/button showing the current section's label plus a chevron, opening the existing switcher sheet (`_openSwitcher`). Then **prev/next** `IconButton`s (clamped: disabled at the first/last active section, the follow-up 02 behavior, just relocated). A flexible spacer. Right, the **overflow `⋮`** offering "Fjern seksjon", shown only when `current.removable` (so Plan and Variabler show no overflow).

The section name lives in the bottom selector (full, untruncated); the top shows the entity. No duplication.

## Ground rules

* Compact only. Do not touch `_WideBody` / the rail — wide keeps its current chrome.
* Reuse the existing `_openSwitcher` sheet, `_selectPrevious`/`_selectNext`, `_removeCurrent`, and the `formSection*` ARB strings. Add a new string only if the bottom selector needs one beyond `formSectionSwitcherTooltip`.
* `WindowSizeClass.of(context).hasMasterDetail` already selects wide vs compact — branch the chrome on it as today.
* No new lint suppressions. `flutter analyze` and `flutter test` before green.

## Scope

Two steps.

### Step 1. Rework the compact chrome

In `section_navigated_form.dart`:

* Compact `AppBar`: title becomes `Text(widget.title)` (drop the `InkWell` switcher from the title slot). Actions: just the Save button. Remove the prev/next and overflow from the compact `AppBar`.
* Add a `bottomNavigationBar: wide ? null : _buildBottomBar(...)` to the `Scaffold`. The bottom bar (a `BottomAppBar`) contains, left to right: the section selector (opens `_openSwitcher`, shows `current.label` + `Icons.arrow_drop_down`), a small divider, prev/next `IconButton`s (disabled at the ends and when there is a single active section), `Spacer`, and the overflow `PopupMenuButton` shown only when `current.removable`.
* Keep the wide path exactly as it is (`_WideBody`, its header prev/next and overflow untouched).

Files expected in this commit:

* `lib/views/widgets/section_navigated_form.dart`
* `lib/l10n/*.arb` + regenerated localizations, only if a new string was needed (run `make i18n` if so)

Run `git status`. Commit: `feat(views): move compact section controls into a bottom bar`.

### Step 2. Tests

Update the `SectionNavigatedForm` tests under `test/views/` for the compact layout:

* The compact top `AppBar` shows the entity title and Save, and no longer hosts the switcher, prev/next or overflow.
* The bottom bar hosts the selector (tapping it opens the switcher sheet), prev/next (clamped at the ends, both disabled with a single section), and the overflow only when the current section is removable.
* Selecting, adding, prev/next and remove all still work through the bottom bar.
* The wide layout is unaffected (its existing tests still pass unchanged).

Run `flutter analyze`. `flutter test test/views/`. Then the full suite.

Files expected in this commit:

* test file(s) under `test/views/`

Run `git status`. Commit: `test(views): cover the compact bottom-bar section chrome`.

## Verification

1. `flutter analyze` clean; `flutter test` no new failures.
2. `make i18n` idempotent (if any string was added).
3. Manual smoke (`--dart-define=RINGDRILL_PLAN_VARIABLES=true`), narrow window: top bar shows the full entity title and Save, the section name is untruncated in the bottom selector, prev/next clamp, overflow appears only on removable sections. Wide window: unchanged.
4. `git diff --stat` since the prior tip touches only `lib/views/…`, `test/views/…` (and `lib/l10n/…` only if a string was added).
5. Clean tree gate and diff sanity as in the stage prompts.

## Deliverables

Two Conventional Commits (English) on `design-008`, clean tree. The final commit body notes that compact section navigation now lives in a bottom bar (top bar reduced to close + title + Save), that this supersedes follow-up 02's top-bar prev/next placement on compact, and that the wide layout is unchanged. Contained follow-up; no ADR.
