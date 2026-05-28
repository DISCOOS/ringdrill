# Implement ADR-0030

You are working in the RingDrill repository. Implement ADR-0030 ("Adopt a Material 3 master/detail layout on medium and expanded viewports, promote forms to modal dialogs and anchor the drill mini-player to the master column") end-to-end. The ADR lives at `docs/adrs/0030-wide-screen-master-detail-layout.md` and is **Accepted**. DESIGN-005 at `docs/design/wide-screen-layout.md` is the companion design doc with anatomy, copy, sizing rules and implementation steps.

This prompt covers ADR-0030 only. If you find unrelated defects, record them as follow-ups under `docs/prompts/` named `adr-0030-followup-NN-<slug>.md`. Do not bundle.

## Ground rules

Read `AGENTS.md` and follow every numbered rule. Non-negotiable for this change:

* `lib/views/shell/` is view-layer only. Not imported from `bin/`, `lib/services/`, `lib/models/`, `lib/data/` or `netlify/`.
* Mobile-safe imports. No `dart:html` or `package:web`.
* No third-party packages. `LayoutBuilder` and `MediaQuery` only.
* Localise every user-visible string. Add keys to `lib/l10n/app_en.arb` and `lib/l10n/app_nb.arb` together.
* Match existing Dart style. Run `dart format` before each commit.
* `test/widget_test.dart` is the known-broken default-template smoke test. Do not try to fix it.
* FAB placement on medium/expanded is **deferred**. Leave `NavigationRail.trailing` as today. Do not move the FAB.
* File grouping under `lib/views/shell/`, `lib/views/widgets/` etc. follows ADR-0028. The full ADR-0028 refactor has not been run yet, so today's `lib/views/` is mostly flat. Place **new** files in the ADR-0028 target folder (`shell/`); leave existing files where they are.

## Commits

Seven commits, in order, on the same working branch. Conventional Commits with scopes as listed. Suggested subjects:

1. `feat(shell): add WindowSizeClass and MasterDetailScope infrastructure`
2. `feat(sheet): add showRingdrillFormDialog and openFormSurface`
3. `feat(context-sheet): short-circuit show through MasterDetailScope`
4. `feat(shell): empty-pane widgets per list tab and l10n`
5. `refactor(shell): mount master/detail in MainScreen with mini-player anchored to master footer`
6. `refactor(shell): split Map tab into map and detail panes`
7. `refactor(forms): migrate form call sites to openFormSurface`

### Commit discipline (non-negotiable)

* After every step, `git status` and `git diff --stat`. No untracked or unstaged paths before claiming the step done.
* Each step lists the **files expected in that commit**. The commit must include every listed path. Generated outputs (`*.g.dart`, `app_localizations*.dart`) belong in the commit that triggered them.
* `make build` regenerations belong in the commit that triggered them.
* Never `git stash` or `git restore` to close a step.
* The Verification gate at the end requires `git status` to print a clean tree with no untracked or unstaged files.

## Scope

### Step 1. WindowSizeClass and MasterDetailScope

Create `lib/views/shell/window_size_class.dart`:

```dart
enum WindowSizeClass implements Comparable<WindowSizeClass> {
  compact,
  medium,
  expanded;

  static WindowSizeClass of(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w >= 840) return WindowSizeClass.expanded;
    if (w >= 600) return WindowSizeClass.medium;
    return WindowSizeClass.compact;
  }

  bool get hasRail => index >= WindowSizeClass.medium.index;
  bool get hasMasterDetail => index >= WindowSizeClass.medium.index;

  @override
  int compareTo(WindowSizeClass other) => index.compareTo(other.index);
}
```

Create `lib/views/shell/master_detail_scope.dart`:

* `MasterDetailScope` is an `InheritedNotifier<ValueNotifier<ContextSheetTarget?>>`. It exposes:
  * `static MasterDetailScope? maybeOf(BuildContext)` — pure read, no dependency registration. Used by `ContextSheetController.show` to decide whether to pane or sheet.
  * `static MasterDetailScope of(BuildContext)` — asserts non-null and registers a dependency.
  * `void setTarget(ContextSheetTarget? target)` — assigns the notifier value.
  * `ValueListenable<ContextSheetTarget?> get target`.
* The scope **does not own** the `ValueNotifier`. It is passed in from `MainScreen`, which mounts both `ContextSheet` (existing) and `MasterDetailScope` on the same `ValueNotifier` so the two stay in sync. Reuse the controller's existing notifier (`ContextSheetController._target`). Expose a getter on the controller if needed.

Master-pane widget `_MasterDetailPane` lives in the same file:

* `ValueListenableBuilder<ContextSheetTarget?>` over the notifier.
* When `target == null`, renders the active tab's empty-pane widget (Step 4). For now (this commit), render `const SizedBox.shrink()` and add a `TODO(adr-0030)` so Step 4 can wire the empty-pane.
* When `target != null`, renders the resolved body via the existing `_DefaultContextSheetBody`-equivalent factory. Reuse the `_DefaultContextSheetBody` logic by extracting it into a public `defaultContextSheetBody(BuildContext, ContextSheetTarget)` function in `context_sheet.dart` (no behavioural change, just visibility). Pane provides its own `ScrollController`.

Both widgets are not mounted in `MainScreen` yet. This step adds infrastructure only.

Tests at `test/views/shell/window_size_class_test.dart`:

* `WindowSizeClass.of` returns `compact` at 599, `medium` at 600 and 839, `expanded` at 840 and 1280. Use `MediaQuery` overrides in a test pump.
* `hasRail` and `hasMasterDetail` are true on `medium` and `expanded`, false on `compact`.

Files expected in this commit:

* `lib/views/shell/window_size_class.dart`
* `lib/views/shell/master_detail_scope.dart`
* `lib/views/widgets/context_sheet.dart` (extract `defaultContextSheetBody`)
* `test/views/shell/window_size_class_test.dart`

Run `git status`. Commit: `feat(shell): add WindowSizeClass and MasterDetailScope infrastructure`.

### Step 2. showRingdrillFormDialog and openFormSurface

Extend `lib/views/widgets/ringdrill_sheet.dart` with a third helper:

```dart
Future<T?> showRingdrillFormDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
});
```

Implementation:

* `showDialog<T>` with default scrim.
* Root widget `Dialog`, `clipBehavior: Clip.antiAlias`, `shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))`, `elevation: 8`, `insetPadding: const EdgeInsets.all(24)`.
* Body wrapped in `ConstrainedBox(constraints: BoxConstraints(maxWidth: 720, maxHeight: viewport.height * 0.88))` where `viewport = MediaQuery.sizeOf(context)`.
* No drag-handle. No close-X helper. The form's own AppBar owns dismiss.

Create `lib/views/shell/open_form_surface.dart`:

```dart
Future<T?> openFormSurface<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  if (WindowSizeClass.of(context).hasMasterDetail) {
    return showRingdrillFormDialog<T>(context: context, builder: builder);
  }
  return Navigator.of(context).push<T>(
    MaterialPageRoute(builder: (_) => builder(context)),
  );
}
```

Tests at `test/views/widgets/ringdrill_sheet_form_test.dart`:

* `showRingdrillFormDialog` opens a dialog whose body is constrained to 720 px max width on a 1024-wide pump and not artificially constrained on a 400-wide pump.
* Returned `Future<T>` resolves with `Navigator.pop(context, result)` from inside the form.

Tests at `test/views/shell/open_form_surface_test.dart`:

* Pumps at 400 px — `Navigator.canPop` becomes true (route push).
* Pumps at 1024 px — `ModalRoute.of(context)` finds a `DialogRoute` (dialog open).

Files expected in this commit:

* `lib/views/widgets/ringdrill_sheet.dart`
* `lib/views/shell/open_form_surface.dart`
* `test/views/widgets/ringdrill_sheet_form_test.dart`
* `test/views/shell/open_form_surface_test.dart`

Run `git status`. Commit: `feat(sheet): add showRingdrillFormDialog and openFormSurface`.

### Step 3. ContextSheetController short-circuit through MasterDetailScope

Edit `lib/views/widgets/context_sheet.dart`:

* In `ContextSheetController.show`, before opening the sheet:

  ```dart
  if (target is! BriefSheetTarget) {
    final scope = MasterDetailScope.maybeOf(context);
    if (scope != null) {
      scope.setTarget(target);
      _target.value = target;
      _isOpen = true;
      return; // pane handles rendering and dismissal
    }
  }
  // existing sheet path
  ```

* `close()` checks the same scope: if a `MasterDetailScope` was active for the current target, clear via `scope.setTarget(null)` and `_isOpen = false`. If a sheet was opened, pop as today.
* `replace(target)` assigns `_target.value = target` as today. If the active surface is the pane (no `_navigator` set), the pane rebuilds via the notifier.
* No `Navigator` work in the pane path.

Tests at `test/views/widgets/context_sheet_pane_test.dart`:

* With a `MasterDetailScope` mounted in the tree, `controller.show(StationSheetTarget(...))` does **not** open a `ModalRoute`. The pane renders the body.
* `controller.show(BriefSheetTarget(...))` opens a sheet even with the scope present.
* `controller.replace(...)` swaps the body without opening or closing a route.
* `controller.close()` clears the pane and does not call `Navigator.pop`.

Existing `test/views/widgets/context_sheet_test.dart` keeps passing because, without a scope in the tree, the sheet path is taken as today.

Files expected in this commit:

* `lib/views/widgets/context_sheet.dart`
* `test/views/widgets/context_sheet_pane_test.dart`

Run `git status`. Commit: `feat(context-sheet): short-circuit show through MasterDetailScope`.

### Step 4. Empty-pane widgets per list tab and l10n

Add five new l10n keys to both `lib/l10n/app_en.arb` and `lib/l10n/app_nb.arb`:

| Key                       | en                                  | nb                                    |
|---------------------------|-------------------------------------|---------------------------------------|
| `detailEmptyExercise`     | "Select an exercise"                | "Velg en øvelse"                      |
| `detailEmptyStation`      | "Select a station to see details"   | "Velg en post for å se detaljer"      |
| `detailEmptyRolePlay`     | "Select a role"                     | "Velg en markør"                      |
| `detailEmptyTeam`         | "Select a team"                     | "Velg et lag"                         |

Per [[Norwegian post = English station terminology]] — nb uses "post", en uses "station". Add the matching `@detailEmpty*` metadata entries (one-line descriptions).

Create `lib/views/shell/detail_empty_pane.dart` with one `StatelessWidget` per tab:

* `ExerciseDetailEmpty`, `StationDetailEmpty`, `RolePlayDetailEmpty`, `TeamDetailEmpty`.
* Each renders the tab's neutral icon (same icon used in `_buildDestinations`), 48 px, `colorScheme.outline`. Below: the localised copy, `theme.textTheme.bodyMedium`, `colorScheme.onSurfaceVariant`. Both centred vertically and horizontally. Padding 24 px.
* No CTA. No buttons.

Wire the right empty-pane widget into `_MasterDetailPane` (from Step 1). The pane needs to know which tab is active. Easiest: pass an `activeTab` field into the scope and let `_MasterDetailPane` switch on it. Alternative: take a `WidgetBuilder` for the empty state from the caller. Pick one and document it in a `///` doc comment.

Run `make build` to regenerate `app_localizations*.dart`.

Tests at `test/views/shell/detail_empty_pane_test.dart`:

* Each empty widget renders an icon and the matching localised string.

Files expected in this commit:

* `lib/l10n/app_en.arb`
* `lib/l10n/app_nb.arb`
* `lib/l10n/app_localizations*.dart` (generated)
* `lib/views/shell/detail_empty_pane.dart`
* `lib/views/shell/master_detail_scope.dart` (wires the empty-pane resolver)
* `test/views/shell/detail_empty_pane_test.dart`

Run `git status`. Commit: `feat(shell): empty-pane widgets per list tab and l10n`.

### Step 5. Mount master/detail in MainScreen and anchor the mini-player

Edit `lib/views/main_screen.dart`. Replace the `_wideScreen` boolean (set in `didChangeDependencies`) with reading `WindowSizeClass.of(context)` inside `build`. Remove the field.

Restructure `_buildNavRail` into a layout that mounts:

1. The `NavigationRail` on the left (today's rail, unchanged).
2. A `Master` column sized to `360 px` on `expanded`, `280 px` on `medium`. Inside: the existing `IndexedStack` from the compact path, sized to the master width (no longer full-bleed).
3. A `Detail` pane on the right: `_MasterDetailPane` from Step 1 / 4.
4. `DrillMiniPlayer` anchored to the bottom of the Master column. Visible only when `ExerciseService().isStarted`. Above safe-area. Top corners rounded 12 px. No side margin. Tap calls `_openDrillPlayer(context)` (existing helper).

Mount the `MasterDetailScope` over the body so the pane shares the controller's notifier.

Fallback: inside a `LayoutBuilder`, if `constraints.maxWidth - railWidth - masterWidth < 360`, render the compact body (full-bleed `IndexedStack` + sheet path) regardless of class. Affects 600–679 px.

Update `_buildBottomChrome`: it now renders the mini-player **only on compact**. On medium/expanded it returns the nav bar widget alone or `null` (per today's logic). The mini-player on medium/expanded is owned by the Master column.

Manual QA matrix for this commit (do before claiming done):

* 1280 × 800 (expanded): rail + 360 master + detail. Tap a station from Stations tab — detail fills. Tap close inside detail — pane resets to empty. Replace works.
* 720 × 1000 (medium): rail + 280 master + detail. Same behaviour.
* 650 × 1000 (medium fallback): rail + full-width tab + sheet (compact body fallback). Tap a station — sheet opens.
* 400 × 800 (compact): unchanged. Sheet for detail. Mini-player above nav bar.
* In every wide configuration, start an exercise — `DrillMiniPlayer` shows at the master footer. Tap it — coordinator sheet opens.
* Map tab on every size: it still renders the old way for this commit. Step 6 splits it.
* Brief: tap "Open brief" on `CoordinatorScreen` — opens fullscreen sheet on every size, including expanded. Pane is not used.

Files expected in this commit:

* `lib/views/main_screen.dart`
* `lib/views/shell/master_detail_scope.dart` (small adjustments if needed for `activeTab` plumbing)

Run `git status`. Commit: `refactor(shell): mount master/detail in MainScreen with mini-player anchored to master footer`.

### Step 6. Map tab split

Edit `lib/views/stations_view.dart` (the Map tab body). On medium and expanded, render an internal split inside the tab's pane:

* Left (map): existing map widget. Width: `(viewport - rail - detail) px` (the rest after detail). Detail target widths:
  * Expanded: detail ~1/3 of available pane width.
  * Medium: detail ~40% of available pane width.
* Right (detail): a `_MasterDetailPane` instance scoped to the Map tab. **No empty-pane copy** — render `const SizedBox.shrink()` when target is null.
* Fallback: if detail would be `< 360 px`, render the map full-bleed and route taps through the existing sheet path.
* Tapping a map marker calls `ContextSheet.of(context).show(StationSheetTarget(...))` as today. The short-circuit from Step 3 routes it to the pane.
* Tapping the same marker again: clear the pane. Implement this by comparing the incoming target with the current `_target.value` and clearing if equal.

`MasterDetailScope` on the Map tab uses its own notifier instance so the Map tab's selection is independent of the other tabs' panes. The cross-tab clear-on-switch behaviour from Step 5 (which clears the global pane on tab change) should also clear the Map tab's local pane.

Mini-player on the Map tab: anchored to the bottom of the map column (left side), same vertical position as on list tabs. Full map-column width.

Manual QA:

* Expanded: Map tab shows ~2/3 map, ~1/3 detail. Tap a station marker — detail fills. Tap the same marker — detail clears.
* Medium: ~60/40 split. Same behaviour.
* Medium fallback (e.g. 650 px): full-bleed map, sheet for marker tap.
* Compact: unchanged. Sheet for marker tap.

Files expected in this commit:

* `lib/views/stations_view.dart`
* possibly `lib/views/main_screen.dart` if the Map tab's pane needs a separate scope wired at the shell level

Run `git status`. Commit: `refactor(shell): split Map tab into map and detail panes`.

### Step 7. Migrate form call sites to openFormSurface

Mechanical rewrite of every form-opening `Navigator.push<...>(MaterialPageRoute(...))` in the view layer. For each site, replace:

```dart
final result = await Navigator.push<T>(
  context,
  MaterialPageRoute(builder: (_) => SomeFormScreen(...)),
);
```

with:

```dart
final result = await openFormSurface<T>(
  context,
  builder: (_) => SomeFormScreen(...),
);
```

Form widgets themselves are not modified. Their `AppBar.leading` may already be `Icons.arrow_back`. Audit each form and replace `Icons.arrow_back` with `Icons.close` to match the dialog dismiss affordance from ADR-0027. If the form has no explicit leading and relies on the default back-arrow, add an explicit `IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))` so compact and dialog look identical.

Sites to migrate (one rewrite each):

* `lib/views/main_screen.dart` — `MainScreen.showSettings` at line ~444 (`SettingsPage`) and the About push at line ~852 (`AboutPage`).
* `lib/views/program_view.dart` — line ~111 (`ExerciseFormScreen` edit), line ~299 (`ExerciseFormScreen` create).
* `lib/views/roleplays_view.dart` — line ~469 (`RolePlayFormScreen`), line ~505 (`ActorFormScreen`).
* `lib/views/station_list_view.dart` — line ~379 (`StationFormScreen` create).
* `lib/views/station_screen.dart` — line ~409 (`RolePlayFormScreen`), line ~488 (`RolePlayFormScreen`), line ~521 (`StationFormScreen`).
* `lib/views/roleplay_screen.dart` — line ~82 (`ActorFormScreen`).
* `lib/views/active_plan_actions.dart` — any `MaterialPageRoute` for form screens (audit).

Forms covered: `SettingsPage`, `AboutPage`, `ExerciseFormScreen`, `StationFormScreen`, `ActorFormScreen`, `RolePlayFormScreen`.

Audit pass after the rewrite:

```
grep -rn "MaterialPageRoute" lib/views/
```

The only matches should be inside `lib/views/shell/open_form_surface.dart` (the helper). Any other match in the view layer for a form-screen push is a missed migration. Non-form pushes (the install link handler, the map picker if it is screen-style) are out of scope unless they trip the grep.

Manual QA:

* Expanded: every form opens as a 720 px-wide modal dialog with rounded corners and an `Icons.close` leading. Save/cancel work, the master/detail body is still visible under the scrim.
* Medium ≥ 680: same as expanded.
* Medium fallback (< 680): forms push fullscreen.
* Compact: forms push fullscreen as today.

Files expected in this commit: every `lib/views/*.dart` file touched above plus updates to forms that lacked an explicit close leading.

Run `git status`. Commit: `refactor(forms): migrate form call sites to openFormSurface`.

## Verification

1. `flutter analyze` clean.
2. `flutter test` no new failures. `test/widget_test.dart` remains broken; flag as known.
3. `make build` clean. Re-run `git status` after.
4. **Clean tree gate.** `git status` prints `nothing to commit, working tree clean`. `git ls-files --others --exclude-standard` prints nothing. No `git stash` or `git restore`.
5. **Diff sanity.** `git log --stat origin/main..HEAD`; every changed path in its intended commit.
6. **Grep gate (forms).** `grep -rn "MaterialPageRoute" lib/views/` returns matches only inside `lib/views/shell/open_form_surface.dart`.
7. **Grep gate (wide screen).** `grep -rn "_wideScreen" lib/` returns no matches.
8. **Manual QA matrix.**
   * 1280 × 800: rail + master/detail. Pick one item from each list tab and verify detail fills the right column.
   * 720 × 1000: same with narrower master (280 px).
   * 650 × 1000: fallback path — full-bleed master and sheet for detail.
   * 400 × 800: compact unchanged.
   * Map tab on expanded, medium, fallback and compact.
   * Brief from `CoordinatorScreen` on expanded — fullscreen sheet.
   * Every form: edit station, edit exercise, settings, about, role-play edit, actor edit — on expanded (dialog) and compact (route push).
   * Mini-player visible on every size when an exercise is running, anchored to master footer on wide and above nav-bar on compact.
9. No follow-ups bundled. If found, record at the bottom of the final commit body under `## Follow-ups` and create a fresh prompt file under `docs/prompts/` named `adr-0030-followup-NN-<slug>.md`.

## Out of scope

* FAB placement on medium/expanded. Stays at `NavigationRail.trailing`. Do not move it.
* Saved-detail-per-tab. Tab switch clears the pane.
* Three-pane layout at ≥ 1240 px.
* The ADR-0028 lib/views/ refactor. Place **new** files in `lib/views/shell/`; do not move existing files.
* `BriefSheetBody` internals. Brief opens fullscreen on every size via the existing sheet path.

## Deliverables

Seven Conventional Commits as outlined above. Clean tree at the end. Final commit body:

* One-line summary: "Wide-screen master/detail, dialog forms, master-anchored mini-player."
* Manual QA matrix filled out.
* `## Follow-ups` section, even if empty.

ADR-0030 and DESIGN-005 are the authoritative spec. If you find yourself contradicting either, stop and ask.
