# Implement ADR-0027

You are working in the RingDrill repository. Implement ADR-0027 ("Unify all bottom sheets behind two `showRingdrillSheet` variants with shared surface, corners and drag-handle") end-to-end. The ADR lives at `docs/adrs/0027-unified-bottom-sheet-chrome.md` and is **Accepted**. It is the authoritative spec for chrome, the two variants and the migration list.

This prompt covers ADR-0027 only. If you find unrelated defects, record them as follow-ups. Do not bundle.

## Ground rules

Read `AGENTS.md` and follow every numbered rule. Non-negotiable for this change:

* `ringdrill_sheet.dart` is view-layer only. Lives under `lib/views/widgets/`. Not imported from `bin/`, `lib/services/`, `lib/models/`, `lib/data/` or `netlify/`.
* Mobile-safe imports. No `dart:html` or `package:web`.
* No third-party packages.
* Match existing Dart style. Run `dart format` before each commit.
* `test/widget_test.dart` is the known-broken default-template smoke test. Do not try to fix it.

## Commits

Four commits, in order, on the same working branch. Conventional Commits with scope `sheet`. Suggested subjects:

1. `feat(sheet): add showRingdrillSheet helper with viewer and action variants`
2. `refactor(sheet): route ContextSheet host through showRingdrillViewerSheet`
3. `refactor(sheet): migrate all action sheets to showRingdrillActionSheet`
4. `refactor(sheet): drop sidebar tint from brief TOC sheet`

### Commit discipline (non-negotiable)

* After every step, `git status` and `git diff --stat`. No untracked or unstaged paths before claiming the step done.
* Each step lists the **files expected in that commit**. The commit must include every listed path.
* `make build` regenerations belong in the commit that triggered them.
* Never `git stash` or `git restore` to close a step.
* The Verification gate at the end requires `git status` to print a clean tree with no untracked or unstaged files.

## Scope

### Step 1. Add the helper

Create `lib/views/widgets/ringdrill_sheet.dart` with the public shape:

```dart
Future<T?> showRingdrillViewerSheet<T>({
  required BuildContext context,
  required Widget Function(BuildContext, ScrollController) builder,
  String? title,
  List<Widget>? actions,            // trailing icon buttons in the header row
  VoidCallback? onClose,            // tapped close-X; defaults to Navigator.pop
});

Future<T?> showRingdrillActionSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
});
```

Both call `showModalBottomSheet<T>` with `backgroundColor: Colors.transparent`, `useSafeArea: true`, `isScrollControlled: true`, `shape: null`.

Both wrap their inner content in:

```dart
ClipRRect(
  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
  child: Material(
    color: Theme.of(context).colorScheme.surface,
    child: ...,
  ),
);
```

Both render an identical drag-handle pill above the body: centered, 40×4, `Theme.of(context).dividerColor`, 12 px top padding, 8 px bottom padding. Extract this as a private `_DragHandle` widget so the two variants share one source.

Viewer additions:

* Wraps body in `DraggableScrollableSheet(initialChildSize: 0.92, minChildSize: 0.5, maxChildSize: 1.0, expand: false)`. Body builder gets the sheet's `ScrollController`.
* Below the drag-handle, a slim header row: `title` on the left (theme `titleMedium`, `colorScheme.onSurface`), `actions` (if any) on the right, then a close-X `IconButton(Icons.close)` that fires `onClose ?? () => Navigator.pop(context)`. Header row is rendered even when `title` is null (close-X still needed).
* Wide-screen: when `MediaQuery.sizeOf(context).width >= 600`, body is centred and constrained to `maxWidth: 720`.

Action additions:

* No `DraggableScrollableSheet`. Body wraps its own content.
* No close-X. Drag-handle + body only.
* Body is internally wrapped in `SafeArea`.

Add widget tests at `test/views/widgets/ringdrill_sheet_test.dart`:

* `showRingdrillViewerSheet` opens a sheet that contains the drag-handle and a close-X; tapping the close-X pops.
* `showRingdrillActionSheet` opens a sheet with the drag-handle and no close-X.
* Both share the same surface color (`colorScheme.surface`) and corner radius (16 px).
* Viewer constrains body to 720 px on a 1024 px-wide pump and not on a 400 px-wide pump.
* Action sheet wraps its body in `SafeArea` (assert one is in the tree).

Files expected in this commit:

* `lib/views/widgets/ringdrill_sheet.dart`
* `test/views/widgets/ringdrill_sheet_test.dart`

Run `git status`. Commit: `feat(sheet): add showRingdrillSheet helper with viewer and action variants`.

### Step 2. ContextSheet host adopts the viewer variant

Edit `lib/views/widgets/context_sheet.dart`:

* `ContextSheetController.show` calls `showRingdrillViewerSheet` instead of `showModalBottomSheet` directly.
* The existing `_ContextSheetHost` widget loses the parts that the helper now owns: the `DraggableScrollableSheet` wrapper, the `ClipRRect`, the `Material(color: surface)`, the drag-handle pill, the `Align(...IconButton(Icons.close))` row, and the wide-screen `Center + ConstrainedBox(720)` wrapper. Pass `title: null` (the bodies render their own titles today) and the controller's `close` as `onClose`.
* `_ContextSheetHost` now just returns the `ValueListenableBuilder` + `AnimatedSwitcher` + the resolved body widget. The helper supplies the scroll controller via its builder.

Update `test/views/widgets/context_sheet_test.dart` so any assertions that previously found the host's own `ClipRRect` / `DraggableScrollableSheet` now look up the helper's version (same node, different ancestor). Existing behavioural assertions (show/replace/close) should pass unchanged.

Manual QA: open a station from the Stations tab; the sheet looks identical to before. Replace works. Close-X dismisses. Wide-screen still constrains to 720 px.

Files expected in this commit:

* `lib/views/widgets/context_sheet.dart`
* `test/views/widgets/context_sheet_test.dart`

Run `git status`. Commit: `refactor(sheet): route ContextSheet host through showRingdrillViewerSheet`.

### Step 3. Migrate every other sheet to the action variant

Mechanical rewrite of every `showModalBottomSheet` call outside `context_sheet.dart` and `ringdrill_sheet.dart`. For each site:

* Replace `showModalBottomSheet<T>(context: ..., showDragHandle: true, isScrollControlled: true, useSafeArea: ..., shape: ..., builder: ...)` with `showRingdrillActionSheet<T>(context: ..., builder: ...)`.
* Drop `showDragHandle`, `shape`, `useSafeArea`, `isScrollControlled`, `backgroundColor` — all owned by the helper.
* If the body wraps itself in `SafeArea`, remove that wrap (the helper does it).
* If the body uses `FractionallySizedBox(heightFactor: 1.0)` purely to fill the sheet (map sheets, cast roster), keep it for now — it still works inside an action sheet; revisit if QA shows it doesn't.

Sites to migrate (one rewrite each):

* `lib/views/dialog_widgets.dart` — `showBottomSheet` helper, line ~45.
* `lib/views/feedback.dart` — `showFeedbackSheet`, line ~15.
* `lib/views/add_exercises_dialog.dart` — line ~31.
* `lib/views/library_view.dart` — `_LibraryBody` opener at line ~39, `_showPlanActions` at line ~470.
* `lib/views/main_screen.dart` — `_showOpenFileBottomSheet` at line ~308.
* `lib/views/station_screen.dart` — `_openCastPicker` at line ~497.
* `lib/views/roleplays_view.dart` — `_openCastPicker` (line ~480), `_openCastRoster` (line ~581), `openFilterSheet` (line ~597).
* `lib/views/station_list_view.dart` — `openFilterSheet` at line ~427.
* `lib/views/stations_view.dart` — `_openFilterSheet` at line ~265.
* `lib/views/widgets/station_mini_map.dart` — `openStationMapSheet` at line ~81.
* `lib/views/widgets/role_mini_map.dart` — `_openMapSheet` at line ~54.

Audit pass. After the rewrite, run `grep -rn "showModalBottomSheet\|showDragHandle" lib/`. The only matches should be inside `lib/views/widgets/ringdrill_sheet.dart` (the helper itself). Any other match is a missed migration; fix before commit.

Update or add widget tests that previously asserted Material default drag-handle (`showDragHandle: true` results in a `BottomSheetDragHandle` widget). Those tests now look for the `_DragHandle` widget (or its key, if you add one in Step 1 — recommend adding `Key('ringdrill-sheet-drag-handle')` to the pill in Step 1 to make tests cheap).

Files expected in this commit: all 13 view files listed above plus any test files under `test/views/` that referenced the old chrome.

Run `git status`. Commit: `refactor(sheet): migrate all action sheets to showRingdrillActionSheet`.

### Step 4. Brief TOC sheet drops sidebar tint

Edit `lib/views/brief_screen.dart` `_openTocSheet` (post-Step 3 it already uses `showRingdrillActionSheet`, but it still passes the old `theme.surfaces.sidebar` via some mechanism — Step 3 should have left it as a stray local `backgroundColor: ...` argument that no longer exists on the helper):

* Remove the `theme.surfaces.sidebar` background entirely from the call site.
* If a visual link to the brief sidebar is still wanted (optional), add a 1 px top stripe inside the body (`Container(height: 1, color: theme.borders.subtle)`) just below the drag-handle area. Skip if it does not improve the look — the default surface from the helper is usually enough.
* The body's own typography stays (`theme.text.heading`, `theme.text.muted`).

Files expected in this commit:

* `lib/views/brief_screen.dart`

Run `git status`. Commit: `refactor(sheet): drop sidebar tint from brief TOC sheet`.

## Verification

1. `flutter analyze` clean.
2. `flutter test` no new failures. `test/widget_test.dart` remains broken; flag as known.
3. `make build` clean. Re-run `git status` after.
4. **Clean tree gate.** `git status` prints `nothing to commit, working tree clean`. `git ls-files --others --exclude-standard` prints nothing. No `git stash` or `git restore`.
5. **Diff sanity.** `git log --stat origin/main..HEAD`; every changed path in its intended commit.
6. **Grep gate.** `grep -rn "showModalBottomSheet\|showDragHandle" lib/` returns matches only inside `lib/views/widgets/ringdrill_sheet.dart`.
7. Manual QA. Open one sheet of each kind and verify the chrome matches:
   * Station/team/role sheet (viewer): 16 px top corners, surface fill, drag-handle pill, close-X visible.
   * Brief sheet (viewer).
   * Cast picker (action).
   * Cast roster (action).
   * Filter sheet from Stations tab / Stations list / RolePlays (action).
   * File-open sheet (action).
   * Feedback sheet (action).
   * Library sheet (action).
   * Plan-actions sheet (action).
   * Add-exercises sheet (action).
   * Mini-map sheet from a station or role (action; verify the embedded map still fills).
   * Brief TOC sheet (action; verify it no longer has the sidebar tint).
8. No follow-ups bundled. If found, record at the bottom of the final commit body under `## Follow-ups` and create a fresh prompt file under `docs/prompts/` named `adr-0027-followup-NN-<slug>.md`.

## Out of scope

* Touching the Brief sheet's main reading-column chrome ([ADR-0023](../adrs/0023-brief-theme-tokens.md) owns that).
* Re-styling the close-X icon or the drag-handle pill beyond what ADR-0027 spells out.
* Renaming or relocating files under `lib/views/`. [[file grouping is deferred]] per existing convention.

## Deliverables

Four Conventional Commits as outlined above, clean tree at the end. Final commit body:

* One-line summary of what now looks the same across all sheets.
* QA matrix filled out.
* `## Follow-ups` section, even if empty.

ADR-0027 is the authoritative spec. If you find yourself contradicting it, stop and ask.
