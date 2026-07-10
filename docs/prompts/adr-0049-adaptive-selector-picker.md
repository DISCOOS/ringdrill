# Implement ADR-0049 — one adaptive selector picker

You are working in the RingDrill repository, on the branch carrying the roleplay Post/Person pickers (`design-010`). This is a **views + l10n** change: introduce one adaptive "pick one from a list" primitive and migrate the existing selectors onto it. [ADR-0049](../adrs/0049-adaptive-selector-surface.md) is authoritative. Read `AGENTS.md` (especially rule 9, test-loop discipline).

**No model, renderer, service, or schema change. No new dependency.**

Visual reference: [`docs/design/mockups/adaptive-selector-picker.html`](../design/mockups/adaptive-selector-picker.html) — the compact sheet and wide dialog frames, the search threshold, and the "+ Ny person" footer.

## The rule (ADR-0049)

A "pick one from a list" surface renders as a **bottom sheet on compact** and a **dialog on medium/expanded** — the same `WindowSizeClass.hasMasterDetail` split `openFormSurface` already uses for forms (ADR-0030). Reuse existing chrome: the sheet path is the current `showRingdrillActionSheet` (ADR-0027); the dialog path reuses the rounded form-dialog shell (NOT a bare `SimpleDialog`), width-capped for a list (~480) and height-capped (~70% of the viewport). Titles read "Velg …". A search field appears when the list is long.

## Step 1 — the primitive

Add `lib/views/widgets/ringdrill_picker.dart` with:

```dart
Future<T?> showRingdrillPicker<T>({
  required BuildContext context,
  required String title,
  required List<T> items,
  // Builds one row; call `onTap` to pick that item (the primitive pops with it).
  required Widget Function(BuildContext context, T item, VoidCallback onTap) itemBuilder,
  // Maps an item to the text the search field filters on. Null disables search.
  String Function(T item)? searchText,
  String? searchHint,
  // Show the search field only once the list is at least this long.
  int searchThreshold = 8,
  // Optional actions appended below the list (e.g. the "+ Ny person" row).
  List<Widget> footerActions = const [],
})
```

Behaviour:

* **Adaptive surface.** `WindowSizeClass.of(context).hasMasterDetail` decides: compact → `showRingdrillActionSheet` (existing drag-handle chrome); medium/expanded → a dialog reusing `showRingdrillFormDialog`'s rounded chrome (rounded 16, elevation, `insetPadding`), but constrained `maxWidth: 480` and `maxHeight: viewport.height * 0.7`. Factor the dialog shell so it and `showRingdrillFormDialog` share the rounded-`Dialog` construction rather than copy it.
* **Body** (same for both surfaces): a title header (`titleMedium`), an optional search field, then a `Flexible`/bounded scrollable `ListView` over the filtered items via `itemBuilder`, then `footerActions`. On the dialog path add a close (X) affordance in the header; the sheet path keeps its drag handle.
* **Search.** Rendered only when `searchText != null && items.length >= searchThreshold`. Reuse the cast picker's filter UX (a `TextField` with a search icon; lowercase `contains`), lifted into this primitive. Filtering is live.
* **Keyboard in the sheet.** On compact the search field raises the keyboard; ensure the sheet resizes (it already runs `isScrollControlled`, but verify `viewInsets`/`SafeArea` so the field and list stay visible and the list scrolls). Cover this in a test.
* **Selection.** `itemBuilder`'s `onTap` pops the surface with that item; dismissing without choosing resolves `null`.

`flutter analyze` + `flutter test test/views/`. Commit: `feat(views): adaptive selector picker (bottom sheet on compact, dialog on wide)`.

## Step 2 — migrate the roleplay Post and Person pickers

In `lib/views/roleplay_form_screen.dart`, replace `_showStationPicker` and `_showPersonPicker`'s `showDialog`/`SimpleDialog` bodies with `showRingdrillPicker`:

* Post: title "Velg post"; rows keep the station-number badge + name; search on.
* Person: title "Velg person"; rows keep the person name (slug fallback); the **"+ Ny person"** entry becomes a `footerActions` row that still calls `_createPersonViaForm()`; search on.
* Preserve current behaviour: the picked value flows through `_onStationChanged` / `_onPersonChanged`; the sentinel `_createPersonValue` path can go away now that create is a footer action.

`flutter analyze` + `flutter test test/views/roleplay_form_screen_person_test.dart test/views/roleplay_form_screen_relink_test.dart`. Commit: `refactor(roleplay): route Post/Person selection through the adaptive picker`.

## Step 3 — migrate the exercise picker

`lib/views/drill_player/exercise_picker_sheet.dart`: build `showExercisePickerSheet` on `showRingdrillPicker`. Title "Velg øvelse"; keep the exercise-number badge, name (variable-substituted), start–end subtitle, and the current-exercise check; search on. The public function signature stays.

`flutter analyze` + `flutter test test/views/`. Commit: `refactor(views): route the exercise picker through the adaptive picker`.

## Step 4 — migrate the cast (marker) picker

`lib/views/widgets/cast_picker_sheet.dart` already filters with a search field; route its surface through `showRingdrillPicker` (title "Velg markør") and drop its own duplicated search now that the primitive owns it. The cast picker also offers removing the current actor and returns a `CastPickerResult` — host that as a `footerActions` entry. If the result shape does not fit the primitive's `T`-returns-on-tap contract cleanly, keep the cast picker's bespoke body but still open it through the primitive's **adaptive surface** (so it too is a sheet on compact / dialog on wide) and note the exception in the commit body. Do not regress removal.

`flutter analyze` + `flutter test test/views/`. Commit: `refactor(views): route the cast picker through the adaptive picker`.

## Step 5 — l10n and tests

* Add picker titles + a search hint. Change **both** `app_nb.arb` and `app_en.arb`, then `make i18n`. Strings as (nb / en):
  * `pickerSelectStationTitle` — "Velg post" / "Select post"
  * `pickerSelectPersonTitle` — "Velg person" / "Select person"
  * `pickerSelectExerciseTitle` — "Velg øvelse" / "Select exercise"
  * `pickerSelectRolePlayTitle` — "Velg markør" / "Select marker"
  * `pickerSearchHint` — "Søk" / "Search"
  * Reuse an existing key instead only if an exact-meaning one already exists; otherwise add these.
* Tests (fold into the relevant commits above):
  * Adaptive surface: at a compact width the picker is a bottom sheet (`showModalBottomSheet` path / drag handle present); at an expanded width it is a `Dialog` (no drag handle). Use `tester.view.physicalSize` (not `setSurfaceSize` — it does not update `MediaQuery`; see the note in `section_rollup_indentation_test.dart`).
  * Search: with a list past the threshold, typing filters the rows; below the threshold no search field renders.
  * Roleplay: picking a Post/Person still updates the editor; "+ Ny person" still opens `PersonFormScreen`; the broken-reference and required-person behaviour is unchanged.
  * Keyboard: focusing the sheet's search field on compact does not throw and keeps the list visible.

## Ground rules

* View + l10n + test only. No model/renderer/service/schema change; no new package. `make i18n` only when ARB changes ([make build does not regenerate i18n]).
* Reuse existing chrome: `showRingdrillActionSheet` (compact) and the `showRingdrillFormDialog` rounded `Dialog` shell (wide) — do not invent a third style, and do not leave any `SimpleDialog` selector behind.
* All user-facing strings changed in both `app_nb.arb` and `app_en.arb` together; keep the pair conceptually equivalent.
* **Test-loop discipline (rule 9):** per commit `flutter analyze` + targeted `flutter test test/views/…`; run full `flutter test` + `dart build cli` **once** at the very end, not per commit.
* Conventional Commits, English, one concern per commit; `git status` clean at each commit.

## Verification (final gate — run once)

1. `flutter analyze` clean; full `flutter test` with no new failures.
2. `make i18n` idempotent; `dart build cli` succeeds.
3. Manual smoke at three widths (compact / medium / expanded): every selector — Post, Person, exercise, cast — is a bottom sheet on compact and a dialog on medium+expanded, with a title "Velg …", search on long lists, and "+ Ny person" working in the Person picker.
4. `git diff --stat` touches `lib/views/…`, `lib/l10n/…`, `test/…` only.
5. Clean tree; regenerated localizations committed with the ARB changes.

## Deliverables

Conventional Commits (English) on `design-010`, clean tree, targeted tests per commit, one full-suite gate at the end (rule 9). ADR-0049 is authoritative. If the cast picker's `CastPickerResult` (remove + pick) cannot ride the primitive's tap-returns-`T` contract, keep its body bespoke but still open it through the adaptive surface and say so in the commit body — do not force a model change to fit. If making the picker adaptive needs anything beyond views/l10n, stop and report.
