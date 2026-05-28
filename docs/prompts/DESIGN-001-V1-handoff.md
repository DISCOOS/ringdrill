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

---

## Followup-01 Step 1: auto-close exercise ContextSheet (5c17d6d)
- State established: `_ExerciseSheetBody` wraps CoordinatorScreen and closes the sheet when exercise goes live.
- Next step inputs: `drill_mini_player.dart` needs per-second ticker.

## Followup-01 Step 2: per-second countdown (f68cf16)
- State established: `_DrillMiniPlayerState` has `_ticker` (Timer.periodic 1s) and `_now`; countdown is interpolated mm:ss.
- Next step inputs: progress strip position swap.

## Followup-01 Step 3: progress strip below row (4a0d569)
- State established: Column children reordered — InkWell row first, progress strip second (Spotify-style).
- Next step inputs: LiveAccent background tint.

## Followup-01 Step 4: LiveAccent background (6c3c075)
- State established: mini-bar wrapped in `Material(color: accent.background)`; text colours use `accent.foreground`.
- Next step inputs: sheet test relocation.

## Followup-01 Step 5: test grouping (86f2bf1)
- State established: `drill_player_sheet_test.dart` moved to `test/views/drill_player/`.
- Next step inputs: followup-02.

## Followup-01 complete (86f2bf1)
- Sheet auto-closes on live transition; mini-bar tickers per second; progress moved below row; mini-bar tinted with LiveAccent; tests grouped.
- V2 backlog unchanged. See DESIGN-001 §"V1 scope" parked list.

---

## Followup-02 Step 1: ExerciseNumberBadge (9f78397)
- State established: `ExerciseNumberBadge` widget added as sibling to `StationCodeBadge`.
- Next step inputs: `MiniRoundRow` widget.

## Followup-02 Step 2: MiniRoundRow (82cfcb0)
- State established: `MiniRoundRow` renders `R{n}/{total} | start0 | start1 | start2` with active-cell blue highlight.
- Next step inputs: rebuilt DrillMiniPlayer using new widgets.

## Followup-02 Step 3: DrillMiniPlayer rebuilt (958d373)
- State established: mini-bar shows badge + mini-round-row + countdown + play square; exercise name, phase chip, and round text removed.
- Next step inputs: floating shape in MainScreen.

## Followup-02 Step 4: floating shape (28960ed)
- State established: mini-bar wrapped in `Padding(fromLTRB(8,0,8,4), ClipRRect(r=12, ...))`; ExerciseService subscription in MainScreen rebuilds chrome on start/stop.
- Next step inputs: test coverage.

## Followup-02 Step 5: tests (3377d77)
- State established: `mini_round_row_test.dart` and `exercise_number_badge_test.dart` added; `drill_mini_player_test.dart` updated for new layout.

## Followup-02 complete (3377d77)
- Mini-bar redesigned: exercise-number badge + mini round-row + countdown + phase-tinted play square. Rounded floating shape above navbar.
- Removed from mini-bar: phase chip, "Runde X/Y" text, exercise name, phase-changing icon.
- V2 backlog unchanged. See DESIGN-001 §"V1 scope" parked list.
