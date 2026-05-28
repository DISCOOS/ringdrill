# DESIGN-001 V1 Handoff Log

## Step 1 — `player-sheet` — 2026-05-27

**Commit:** `feat(player): add immersive DrillPlayer sheet shell` (4d5b98b)

**Files changed:**
- `lib/views/widgets/drill_player_sheet.dart` — NEW. Exports `showDrillPlayerSheet<T>`.
- `lib/l10n/app_en.arb` — added `drillPlayerClose`, `drillPlayerStartingIn`, `drillPlayerRoundOf`.
- `lib/l10n/app_nb.arb` — same keys in Norwegian.
- `lib/l10n/app_localizations*.dart` — regenerated.

**Verification:** `flutter analyze` clean, `flutter gen-l10n` confirmed all three new keys present.

**Notes:** `sheetContext` passed into `_DrillPlayerSheetBody` constructor to avoid Navigator context shadowing (same issue fixed in `context_sheet.dart`). Android immersive guard: `!kIsWeb && defaultTargetPlatform == TargetPlatform.android`.

---

## Step 2 — `mini-player` — 2026-05-27

**Commit:** `feat(player): add tap-only DrillMiniPlayer widget` (45da5bf)

**Files changed:**
- `lib/views/drill_player/phase_colors.dart` — NEW. Phase→color/icon constants.
- `lib/views/drill_player/drill_mini_player.dart` — NEW. 56px strip widget.

**Notes:** `ExerciseEvent.remainingTime` is whole minutes (int); formatted as `mm:00`. `currentRound` is 0-based; displayed as `+1`. `ExerciseService().stop()` must be called inside the FakeAsync zone in tests (not in tearDown/addTearDown) to avoid pending-timer assertion failures.

---

## Step 3 — `navigation` — 2026-05-27

**Commit:** `feat(navigation): mount DrillMiniPlayer above bottom nav` (37846ac)

**Files changed:**
- `lib/views/main_screen.dart` — replaced `bottomNavigationBar: _buildNavBar` with `_buildBottomChrome`; added `_openDrillPlayer`.

**Notes:** `_buildBottomChrome` returns null for wide screen (V2 parked). `Column(mainAxisSize: MainAxisSize.min)` collapses to just `NavigationBar` when `DrillMiniPlayer` returns `SizedBox.shrink()`.

---

## Step 4 — `program` — 2026-05-27

**Commit:** `feat(program): open DrillPlayer for live exercise card` (4a4fc10)

**Files changed:**
- `lib/views/program_view.dart` — live card tap now opens `showDrillPlayerSheet`; non-live cards keep `ContextSheet` flow.

**Notes:** Double guard `_liveEvent?.exercise.uuid == exercise.uuid && ExerciseService().isStarted` needed because `_liveEvent` retains the last event even after the `done` phase.

---

## Step 5 — `test` — 2026-05-27

**Commit:** `test(player): cover DrillMiniPlayer and DrillPlayer sheet behaviour` (2370037)

**Files changed:**
- `test/views/drill_player/drill_mini_player_test.dart` — NEW. 4 tests.
- `test/views/widgets/drill_player_sheet_test.dart` — NEW. 3 tests.

**Notes:** Pre-existing analyze error in `test/views/widgets/context_sheet_test.dart` (non-exhaustive switch on `ContextSheetTarget`) — not introduced by V1.

---

## V1 COMPLETE — 2026-05-27

All 5 steps committed on `main`. `flutter analyze` clean (project-wide, pre-existing test error excepted). `flutter test` on new tests: 7/7 green.

V1 scope per `docs/design/exercise-player.md`:
- ✅ Immersive DrillPlayer sheet shell
- ✅ Tap-only DrillMiniPlayer strip (narrow screens only)
- ✅ Mounted above NavigationBar in MainScreen
- ✅ Live exercise card in ProgramView routes to DrillPlayer
- ✅ Widget tests covering all V1 surface
