# Implementation prompt — ADR-0033 (selective platform-adaptive UI on iOS)

Implement [ADR-0033](../adrs/0033-platform-adaptive-ui-on-ios.md). Keep the
Material-first shell, adapt only the points the ADR names. Use
`Theme.of(context).platform == TargetPlatform.iOS` for any branching, never
`dart:io` `Platform`, so it stays test-overridable and web-safe.

Work step by step. Each step is one commit. Before every commit run
`flutter analyze` and `flutter test`, then verify `git status` is clean (no
stray files, no uncommitted changes) before moving on. Localize any new
user-visible string in both `lib/l10n/app_en.arb` and `lib/l10n/app_nb.arb`.
No `@freezed`, enum or `json_serializable` changes are expected, so `make
build` should not be needed. If you touch any of those, run `make build`.

Commit messages use conventional-commits format with an `ios-adaptive` thread,
for example `feat(ios-adaptive): ...`.

## Step 0 — Cupertino localizations prerequisite

`AlertDialog.adaptive` and `CupertinoDatePicker` require
`GlobalCupertinoLocalizations` in the delegate list. Confirm it resolves
through `AppLocalizations.localizationsDelegates` in `lib/main.dart`. If it is
missing, add `GlobalCupertinoLocalizations.delegate` and verify a Cupertino
dialog renders on an iOS-platform test.

Files: `lib/main.dart` (and `lib/l10n/*` only if the delegate set changes).
Commit only if a change was needed. Otherwise fold the verification note into
Step 1.

## Step 1 — Adaptive dialogs

Replace `AlertDialog(...)` with `AlertDialog.adaptive(...)` and `showDialog(...)`
with `showAdaptiveDialog(...)` at every site below. Keep titles, content and
actions identical. Where actions are Material `TextButton`/`ElevatedButton`,
leave them as-is unless the adaptive dialog visibly needs
`CupertinoDialogAction` for correct iOS layout, in which case adapt the action
widgets too.

Files:
- `lib/views/main_screen.dart` (consent dialog, ~line 1580)
- `lib/views/settings_page.dart` (~line 167)
- `lib/web/settings_page.dart` (~line 70)
- `lib/views/dialog_widgets.dart` (~line 13)
- `lib/views/add_exercises_dialog.dart` (~line 276)
- `lib/views/publish_plan_dialog.dart` (~line 105)
- `lib/views/active_plan_actions.dart` (~lines 35, 492)
- `lib/views/patch_alert_widget.dart` (~line 43)
- `lib/views/catalog_conflict_dialog.dart` (~line 17)

Commit: `feat(ios-adaptive): render alerts with AlertDialog.adaptive`

## Step 2 — Adaptive switches

Replace `Switch(...)` with `Switch.adaptive(...)` and `SwitchListTile(...)` with
`SwitchListTile.adaptive(...)`. Behaviour stays identical.

Files:
- `lib/views/settings_page.dart` (~lines 241, 369, 405, 417, 429)
- `lib/views/stations_view.dart` (~lines 421, 429, 437, 492)
- `lib/views/program_view.dart` (~line 1265)

Commit: `feat(ios-adaptive): render toggles with Switch.adaptive`

## Step 3 — Cupertino time picker on iOS

Add a helper `pickAdaptiveTime(BuildContext, {required TimeOfDay initialTime})`
that on iOS presents a `CupertinoDatePicker` in `time` mode inside the standard
sheet chrome (reuse the existing `showRingdrillSheet`/sheet helpers) and on
every other platform calls today's `showTimePicker`. It returns `TimeOfDay?`
with the same contract as `showTimePicker`. Reuse existing
`localizations.cancel`/`done`-style strings. Add new ARB keys only if no
suitable string exists.

Route `_pickStartTime()` in `exercise_form_screen.dart` through the helper.

Files:
- new `lib/views/widgets/adaptive_time_picker.dart`
- `lib/views/exercise_form_screen.dart` (~line 386)
- `lib/l10n/app_en.arb`, `lib/l10n/app_nb.arb` (only if a new string is added)

Commit: `feat(ios-adaptive): use a Cupertino time picker on iOS`

## Step 4 — Free the iOS back-swipe

In `lib/views/main_screen.dart` (~line 835) set `drawerEnableOpenDragGesture`
to `false` on iOS and keep `true` elsewhere. The hamburger button must still
open the drawer on all platforms.

Files: `lib/views/main_screen.dart`

Commit: `fix(ios-adaptive): disable left-edge drawer drag on iOS`

## Step 5 — Targeted haptics

Add `HapticFeedback` calls that are a no-op where the platform has none:
- on each settings toggle handler in `lib/views/settings_page.dart`
- on drill start and stop where the UI triggers `ExerciseService().start`/stop
  (`lib/views/main_screen.dart` mini-player play, and the start/stop controls
  in `lib/views/coordinator_screen.dart`, which already uses
  `HapticFeedback.selectionClick()` as the reference pattern)

Use `selectionClick` for toggles and `mediumImpact` for drill start/stop.

Files:
- `lib/views/settings_page.dart`
- `lib/views/main_screen.dart`
- `lib/views/coordinator_screen.dart`

Commit: `feat(ios-adaptive): add haptics on toggles and drill start/stop`

## Out of scope (do not touch)

Navigation (`NavigationBar`, `NavigationRail`, drawer, master/detail),
sheet-based context navigation, `centerTitle: false`, Material icons and the
`RefreshIndicator`. These are cosmetic-only or load-bearing structure per the
ADR.

## Final verification

Run `flutter analyze` and `flutter test` once more on the final state. Confirm
`git status` is clean and that each of the steps above is its own commit.
