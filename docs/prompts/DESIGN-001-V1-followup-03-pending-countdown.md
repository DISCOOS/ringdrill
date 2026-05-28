You are working in the RingDrill repository. This is follow-up 03 on the DESIGN-001 V1 implementation. **Follow-ups 01 and 02 MUST be landed before this one starts.**

Read first:

- `docs/design/exercise-player.md` §"V1 scope" — V1 contract.
- `docs/prompts/DESIGN-001-V1-followup-01-mini-bar-polish.md` — per-second ticker, LiveAccent background, etc.
- `docs/prompts/DESIGN-001-V1-followup-02-mini-bar-redesign.md` — current mini-bar layout (ExerciseNumberBadge + MiniRoundRow + countdown + play square).

Smoke-testing followup-02 surfaced ten small UI gaps. Six are polish on the mini-bar widget; the seventh is a correctness bug in `MiniRoundRow` that has to be closed by reusing `PhasesWidget` instead of reimplementing its state machine; the eighth is a player-sheet cleanup in a different file (`drill_player_sheet.dart`); the ninth fixes which progress the bottom strip represents; the tenth adds an animated ring around the play icon as a liveness affordance. They share one loop because they have the same root cause class — V1 over-assumed what the surrounding chrome would look like:

1. **Pending state has no countdown.** "Starter om" / "Starting in" reads without an actual `mm:ss` after it. The data is already on the event (`ExerciseEvent.remainingTime` in minutes during pending, plus the per-second ticker from followup-01); it is simply not being rendered.
2. **Badge / play-square size mismatch.** `ExerciseNumberBadge` renders at 40×40 (matching the `StationCodeBadge` / `RoleCodeBadge` family) while the play square on the right is 36×36. The badge needs to opt into a 36×36 variant in the mini-bar context while keeping the 40×40 default elsewhere.
3. **Non-badge text is too small.** The countdown (`bodySmall`), the `R1/N` cell in `MiniRoundRow`, the three HH:MM phase-time cells and the dividers all read smaller than they need to inside a 48 px strip. Everything outside a badge should bump up a step. Badge typography stays as is.
4. **Phase label is missing before the countdown.** The "ØVE / EVAL / RULL" label that originally lived on the V1 mini-bar (and was dropped in followup-02 along with the phase chip background) is what the user is missing. It should sit immediately to the left of the countdown so the countdown reads with its phase context. In pending state the label is omitted because the countdown already starts with "Starter om".
5. **Progress strip is too pale.** Using `LinearProgressIndicator` with `valueColor` = phase color and `backgroundColor` = the same phase color at 25 % alpha on a `primaryContainer` surface makes the bar wash out — the fill barely reads against the desaturated track. The fill needs more weight.
6. **Round indicator buries the total round count.** The current `R1/4` packs current and total into one cell; the rest of the app prefers the pattern from the expanded-tile header `EVAL | 20:00 - 21:35 | 1 time | 1 runde | 4 lag` where the total count lives on its own at the right of the row. `MiniRoundRow` should follow that pattern: lead with `R1` (current round only) and append a `4 runder` cell after the three phase times.
7. **Completed phases lose their fill in `MiniRoundRow`.** The widget reimplements `PhasesWidget`'s state machine and only handles the active-phase case (`blueAccent` background on the cell whose `scheduleIndex == event.phase.index - 1`). It misses `PhasesWidget`'s `isComplete` branch (`widthFactor: 1.0` keeps the cell fully filled after the phase advances) and the per-cell divider `isComplete` flags. Result: when the exercise rotates from EVAL to RULL, the EVAL cell goes back to transparent and the divider between EVAL and RULL doesn't carry the "completed" state. The fix is to drop the local `phaseCell` helper and reuse `PhasesWidget` directly, mirroring `PhaseTile`'s composition.
8. **DrillPlayer sheet has double close + rounded corners + not-fullscreen on web.** `showDrillPlayerSheet` wraps the body in a `Column` whose first child is a `Material(IconButton(Icons.keyboard_arrow_down))` chevron. `CoordinatorScreen` (the body) renders its own `Scaffold.AppBar(leading: IconButton(Icons.close, onPressed: Navigator.pop))`. Both close the same route, so two close buttons stack. On web, `showModalBottomSheet`'s default rounded top corners + a viewport margin leak through because we never overrode `shape` and the `BoxConstraints` only pinned `minHeight`. Fix: drop the chevron/Column wrapper from `showDrillPlayerSheet` (the body's AppBar X is the canonical close), pass `shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero)`, and pin `minHeight` *and* `maxHeight` to the viewport height.
9. **Bottom progress strip tracks the wrong thing.** Steps 1/2/5 left the mini-bar's bottom strip bound to `event.phaseProgress` (with the per-second interpolation). But the per-phase progress signal already lives *inside* the strip via the `PhasesWidget` active-cell fill that Step 7 reuses. The bottom strip's job is to show **total exercise progress** — how far through the whole exercise you are end-to-end. Switch the strip to interpolate `event.totalProgress` against the total exercise duration. Colour stays phase-tinted so the user still sees which phase is currently driving the fill.
10. **Play icon has no liveness signal.** The 36×36 play-icon square is static. Wrap it in a ring with a state-dependent animation: pulsing in pending (the exercise is "warming up"), spinning in running (Spotify-style "now playing"). Decorative — no progress information conveyed (the bottom strip already carries total progress; `MiniRoundRow` carries per-phase). The ring just communicates "alive".

Ten steps, one commit each.

## Ground rules

Same as followup-01 and followup-02. The relevant ones:

- **Widget-only.** No model changes, no service changes, no codegen.
- **Localize.** New ARB key with a placeholder, added to both `lib/l10n/app_en.arb` and `lib/l10n/app_nb.arb` together.
- **Verify before claiming green.** `flutter analyze` and `flutter test` after each commit.
- **Do not touch `ExerciseService`.** The interpolation from followup-01's local ticker is what produces the seconds.
- **Pending state in `MiniRoundRow` stays unchanged.** The three HH:MM phase start times are still shown with no active highlight. Only the countdown text changes.
- **Family consistency for the badge.** The default `size` on `ExerciseNumberBadge` stays 40 so existing or future use outside the mini-bar continues to match `StationCodeBadge` / `RoleCodeBadge`. Only the mini-bar opts into the smaller variant. Do **not** resize `StationCodeBadge` or `RoleCodeBadge` in this loop.

## Commit policy

Per [[feedback-prompts-commit-everything]]: one commit per step, `git status` clean per commit, gates after each.

## Scope and step order

Ten steps. Do them in order.

### Step 1. **player**: show mm:ss countdown next to "Starter om" in pending state

Render the pending-state countdown as `"Starter om 04:32"` / `"Starts in 04:32"` instead of bare `"Starter om"` / `"Starts in"`. Use the same per-second interpolation that the running state already uses (followup-01 Step 2), so the seconds tick smoothly between minute-granular service events.

**Files touched:**

- `lib/views/drill_player/drill_mini_player.dart`:
  - Look up the existing block that builds the `countdown` string. It currently looks like:
    ```dart
    final countdown = event.isPending
        ? localizations.drillPlayerStartingIn
        : '$mm:$ss';
    ```
    Replace the pending branch with `localizations.drillPlayerStartingInWithCountdown('$mm:$ss')` so the same `$mm:$ss` value the running branch builds is now used in both branches. The interpolation math from followup-01 (`secondsSinceEvent`, `remainingSeconds`, `mm`, `ss`) does not change.
  - During pending, `event.remainingTime` is the *minutes until start* (see `ExerciseService._progress` → `_raise(exercise, startTimeDelta.abs())`). The existing followup-01 interpolation formula already handles this correctly because it only depends on `event.remainingTime`, `event.when` and the wall-clock delta. No phase-specific branching needed.
  - When `remainingSeconds` clamps to zero (exercise transitions to execution between ticks), the next event from the service flips `event.isPending` to `false` and the running branch takes over naturally. No special handling required.
- `lib/l10n/app_en.arb`:
  - Add a new ARB key:
    ```json
    "drillPlayerStartingInWithCountdown": "Starts in {time}",
    "@drillPlayerStartingInWithCountdown": {
      "description": "Countdown shown on the DrillPlayer mini-bar while an exercise is started but has not yet reached its scheduled start time. The {time} placeholder is mm:ss.",
      "placeholders": {
        "time": { "type": "String" }
      }
    }
    ```
  - Leave the existing `drillPlayerStartingIn` key in place. It is no longer referenced from production code after this change, but removing unused ARB keys belongs in its own chore commit so the diff here stays focused.
- `lib/l10n/app_nb.arb`:
  - Add the same key with the Norwegian translation:
    ```json
    "drillPlayerStartingInWithCountdown": "Starter om {time}"
    ```

Run `make build` so `app_localizations.dart` regenerates with the new key. Verify both the English and Norwegian generated getters exist before committing.

Test updates in `test/views/drill_player/drill_mini_player_test.dart`:

- Add a new test "pending state shows 'Starts in mm:ss' countdown" that:
  - Sets up the exercise with a `startTime` a few minutes in the future relative to `SimpleTimeOfDay`'s `toMaterial`/`toDateTime` conversion (the fixture builder already exists in this file — copy and adjust the times).
  - Calls `ExerciseService().start(exercise)`. The service should emit a pending event.
  - Pumps the widget and asserts both:
    - `find.textContaining('Starts in')` finds the prefix (English-locale test).
    - The same text matches a `RegExp(r'^Starts in \d{2}:\d{2}$')` (or use a more relaxed match if the fixture clock makes the seconds non-deterministic).
  - Pumps one second and asserts the displayed seconds changed (i.e. the ticker is also driving the pending countdown, not just the running one).
- Make sure the test ends with `ExerciseService().stop()` and a final `await tester.pump()` so the periodic timers tear down cleanly.

Commit: `feat(player): show mm:ss countdown in mini-bar pending state`.

### Step 2. **widget**: let `ExerciseNumberBadge` opt into a 36 px variant for the mini-bar

Add a `size` parameter to `ExerciseNumberBadge` so the mini-bar can render it at 36×36 to match the play square on the right, while the default 40 keeps the badge family consistent in list contexts.

**Files touched:**

- `lib/views/widgets/exercise_number_badge.dart`:
  - Add `final double size;` field with `this.size = 40` in the constructor so existing call sites compile unchanged.
  - Replace the hard-coded `width: 40, height: 40` with `width: size, height: size`.
  - Keep the `fontSize: 14` as is — the existing `FittedBox(fit: BoxFit.scaleDown)` already handles overflow on smaller sizes. Add a one-line comment noting that `FittedBox` covers the scale-down so the font does not need to be threaded through `size`.
  - Keep the `borderRadius: 6` and the 4 px horizontal padding unchanged. The badge looks like a smaller pill of the same family, not a different shape.
  - Update the doc comment to mention the `size` parameter and note that the default 40 matches the badge family while smaller values exist for embedded contexts (specifically: the DrillPlayer mini-bar).
- `lib/views/drill_player/drill_mini_player.dart`:
  - Change `ExerciseNumberBadge(number: exerciseNumber)` to `ExerciseNumberBadge(number: exerciseNumber, size: 36)` so the badge matches the 36×36 play square on the right.
  - No other change inside this widget.

Test updates in `test/views/widgets/exercise_number_badge_test.dart`:

- Add a test "renders at custom size" that constructs `ExerciseNumberBadge(number: 1, size: 36)` and asserts `tester.getSize(find.byType(ExerciseNumberBadge))` reports 36×36.
- The existing tests at `size: 40` (the default) continue to pass without changes.

No test changes required for `drill_mini_player_test.dart`. The existing "renders ExerciseNumberBadge ..." assertion does not pin the size and remains valid.

Commit: `feat(widget): make ExerciseNumberBadge size configurable for the mini-bar`.

### Step 3. **player**: enlarge non-badge text in the mini-bar

Everything outside a badge should bump up to a more readable size inside the 48 px strip. Badge typography (the `#N` glyph in `ExerciseNumberBadge`, station/role codes in their respective badges) stays as is.

**Files touched:**

- `lib/views/drill_player/drill_mini_player.dart`:
  - Countdown `Text` style: change `Theme.of(context).textTheme.bodySmall` → `Theme.of(context).textTheme.titleMedium` (so the `mm:ss` reads at ~16 sp instead of ~12 sp). Keep `accent.foreground` colour and `fontFeatures: [FontFeature.tabularFigures()]`. Keep `fontWeight: FontWeight.w600` if not already set.
- `lib/views/drill_player/mini_round_row.dart`:
  - The `R{N}/{M}` title cell: bump font size from the 11 px caption set in followup-02 to 14 sp. Keep bold.
  - The three HH:MM phase cells: bump from caption to 14 sp. Keep tabular figures. Active-cell highlight (blue background + white bold text) stays.
  - `VerticalDividerWidget` between cells: if its appearance derives from a fixed pixel height, adjust so it still spans the new taller text without clipping. Verify visually that dividers don't shrink relative to the text.
- The mini-bar's inner `SizedBox(height: 48)` may need to grow to 52 px to accommodate the larger text without crowding the rounded edges. Bump only if `flutter analyze` clean is not enough — run the app and check that text is not vertically clipped, then commit either the 48 or the 52 value. If you change it, also adjust the comment in `_buildBottomChrome` if any.

No new ARB keys. No test changes required — existing assertions on `find.text(...)` / `find.byType(MiniRoundRow)` continue to hold; they don't pin font sizes.

Commit: `refactor(player): enlarge non-badge text in DrillMiniPlayer and MiniRoundRow`.

### Step 4. **player**: restore the phase label before the countdown

Render the phase label ("ØVE" / "EVAL" / "RULL") immediately to the left of the countdown in running state. In pending state the label is omitted because the countdown already starts with "Starter om", which would otherwise read redundantly ("STARTER Starter om mm:ss"). In done state the label is also omitted.

**Files touched:**

- `lib/views/drill_player/drill_mini_player.dart`:
  - Inside the inner `Row`, between `Expanded(child: MiniRoundRow(...))` and the countdown `Text`, insert a conditional `Text` rendering `event.getState(localizations)` (the existing helper that returns the upper-cased phase label already used in V1). Wrap it in a small `Padding(padding: EdgeInsets.only(right: 8))` so it sits with the same spacing as the surrounding gap widgets.
  - Style: same size as the countdown (`titleMedium` from Step 3) but with `color: colorForPhase(event.phase)` so the label visually ties to the play square on the right and the active mini-row cell. Bold (`FontWeight.w700`). No background fill — this is a label, not a chip; the colour is enough.
  - Conditionally render: only show the label when `!event.isPending && !event.isDone`. In those two states emit `const SizedBox.shrink()` so the countdown sits flush against the mini-row.
  - Add an inline comment: "Phase label restored after followup-02 dropped it; it lives next to the countdown so the time reads with its phase context."

Test updates in `test/views/drill_player/drill_mini_player_test.dart`:

- Add a test "running state shows phase label before countdown" that calls `ExerciseService().start(exercise)`, pumps until the service flips out of pending (in the existing fixture the exercise's `startTime` is in the past so it should be running immediately), then asserts `find.text('ØVE')` or `find.text('DRILL')` (whichever locale the test harness defaults to — the existing tests already pick a locale) is present, and that it appears earlier in the widget tree than the countdown text. Use `tester.getTopLeft` to compare horizontal positions if needed.
- Add a test "pending state hides phase label" that asserts neither `find.text('ØVE')` nor any of the phase labels appear when `event.isPending` is true. Reuse the fixture from Step 1's pending test.

Commit: `feat(player): restore phase label before mini-bar countdown`.

### Step 5. **player**: brighten the progress strip fill

Make the progress fill read more vividly on the `primaryContainer` surface. The current `LinearProgressIndicator` setup (phase-coloured fill on a 25 %-alpha phase-coloured backdrop) washes out — the fill and the backdrop share the same hue so contrast is shallow.

**Files touched:**

- `lib/views/drill_player/drill_mini_player.dart`:
  - Replace the bottom `SizedBox(height: 3, child: LinearProgressIndicator(...))` with a custom container-based strip:
    ```dart
    SizedBox(
      height: 4,
      child: Stack(
        children: [
          // Track: a low-contrast dark wash so the bright phase-coloured
          // fill on top pops on any background.
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.18),
            ),
          ),
          // Fill: solid phase colour, scaled by smoothedProgress.
          FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: smoothedProgress,
            child: Container(color: color),
          ),
        ],
      ),
    )
    ```
  - Bump height from 3 to 4 px so the strip has visual weight without dominating the row.
  - The `smoothedProgress` and `color` variables in scope already come from the followup-01 interpolation block. No new computation needed.
  - Add an inline comment: "Custom strip instead of LinearProgressIndicator because the indicator's `backgroundColor` washed the phase colour out on the primaryContainer surface. A dark wash track maximises contrast with the saturated fill."

No test changes required. The existing tests don't pin progress-strip rendering details.

Commit: `feat(player): brighten the mini-bar progress strip`.

### Step 6. **widget**: simplify round indicator to `R1` and append total-rounds cell

Reshape `MiniRoundRow` so it follows the expanded-tile-header pattern: lead with `R{currentRound+1}` (no `/N`) and append a `{N} runder` cell after the three phase times, with the same divider treatment between cells.

**Files touched:**

- `lib/views/drill_player/mini_round_row.dart`:
  - Title cell: change the text from `R{currentRound+1}/{numberOfRounds}` to `R{currentRound+1}` (e.g. `R1`).
  - After the three phase cells (index 0/1/2 in the existing `Row`), insert a `VerticalDividerWidget(isCurrent: false, isComplete: false)` followed by a new "total rounds" cell. The cell renders `'${exercise.numberOfRounds} ${localizations.round(exercise.numberOfRounds).toLowerCase()}'` — reuse the existing `localizations.round(N)` helper (plural-aware; already used elsewhere in the app, see `lib/views/program_view.dart` `subtitleParts`). Wrap the text in `Padding(padding: EdgeInsets.symmetric(horizontal: 8))` to match the inter-cell spacing.
  - Style the new cell the same as a non-active phase cell: 14 sp (matching the Step 3 bump), `accent.foreground` colour, no background fill, no bold.
  - Add a `final AppLocalizations localizations;` parameter or read it via `AppLocalizations.of(context)!` at the top of `build` — pick whichever pattern matches what the existing `MiniRoundRow` already does.
  - When `exercise.numberOfRounds == 1`, the cell still renders (`1 runde`) — do not hide it.
  - When `event.currentRound` falls outside `exercise.schedule.length` (defensive guard from followup-02 step 2), the new cell renders an empty `SizedBox` so the row degrades gracefully.
- The mini-bar in `lib/views/drill_player/drill_mini_player.dart` does not change — `MiniRoundRow` continues to fill the `Expanded` slot between the badge and the phase label.

Test updates in `test/views/drill_player/mini_round_row_test.dart`:

- Replace the "renders `R1/4` for `event.currentRound: 0` and `exercise.numberOfRounds: 4`" test with "renders `R1` (no `/N`) for `event.currentRound: 0`". Assert `find.text('R1')` exists and `find.text('R1/4')` does not.
- Add a test "appends `{N} runder` cell after the three phase times" that constructs the widget with `numberOfRounds: 4` and asserts `find.text('4 runder')` (Norwegian locale) or the equivalent English string is present. Verify position: `tester.getTopLeft(find.text('4 runder')).dx > tester.getTopLeft(find.text(<third phase time>)).dx` so the cell really sits to the right of the phase cells.
- Add a test "singular case: `1 runder` reads as `1 runde`" (plural-aware via `localizations.round(1)`). Assert `find.text('1 runde')` is present.
- The "renders three HH:MM cells" test continues to hold without changes.

No new ARB keys — `localizations.round(N)` already exists.

Commit: `refactor(widget): split R1/N into R1 + appended {N} runder cell in MiniRoundRow`.

### Step 7. **widget**: reuse `PhasesWidget` for phase-time cells in `MiniRoundRow`

Drop the local `phaseCell(int index)` helper and reuse `PhasesWidget` directly so the active-phase fill, completed-phase persistence, secondary-track backdrop and divider `isComplete` flags all derive from the canonical state machine. This is what `PhaseTile` already does inside `CoordinatorScreen`; the mini-bar should not have its own dialect.

**Files touched:**

- `lib/views/phase_widget.dart`:
  - Promote the local `const cellSize = 56.0;` to a constructor field `final double cellSize;` with `this.cellSize = 56.0` so existing `PhaseTile` call sites continue to render at 56 without changes. Update the `width = cellSize - ...` line and the three internal `SizedBox(width: width)` usages to consume the new field. Nothing else about `PhasesWidget`'s logic moves.
  - Add a one-line doc comment on `cellSize`: "Width per phase cell. Default 56 matches the round-table cell width in `PhaseTile`. Smaller values are used by embedded contexts like the DrillPlayer mini-bar."
  - **Do not** also parametrize `fontSize` in this step. If the 18 sp text is too tall for the mini-bar's smaller cell, fold a `fontSize` parameter in via a follow-up; the current step is scoped to width.

- `lib/views/drill_player/mini_round_row.dart`:
  - Delete the local `phaseCell(int index)` function and the `scheduleIndex` / `hasActiveCell` derived booleans that only existed to drive it.
  - Compute `final isCurrentRound = event.isRunning && event.currentRound < exercise.schedule.length;` once at the top.
  - Build the three phase cells via `PhasesWidget(event: event, exercise: exercise, roundIndex: event.currentRound, phaseIndex: 0|1|2, cellSize: 48)`. Pick 48 as the mini-bar cellSize (3 cells × 48 = 144 px, plus the R-cell ~36 px, the total-rounds cell ~80 px, and four dividers × ~8 px ≈ 290 px — fits comfortably alongside the badge, phase label and countdown on a 380-px-wide phone).
  - Compose the row using the same divider pattern as `PhaseTile` (cross-reference `lib/views/coordinator_screen.dart` / `lib/views/phase_tile.dart` for the canonical shape):
    - Leading divider after the R-cell: `VerticalDividerWidget(isCurrent: isCurrentRound, isComplete: isCurrentRound)`.
    - Between phase 0 and phase 1: `VerticalDividerWidget(isCurrent: isCurrentRound, isComplete: isCurrentRound && 0 < event.phase.index - 1)`.
    - Between phase 1 and phase 2: `VerticalDividerWidget(isCurrent: isCurrentRound, isComplete: isCurrentRound && 1 < event.phase.index - 1)`.
    - Trailing divider after phase 2 (before the new total-rounds cell from Step 6): `VerticalDividerWidget(isCurrent: isCurrentRound, isComplete: isCurrentRound && 2 < event.phase.index - 1)`.
  - The R-cell and total-rounds cell continue to read with `accent.foreground` on a transparent background. They are not part of `PhasesWidget`'s state machine.
  - If `event.currentRound` is out of range (`>= exercise.schedule.length`), short-circuit to a `SizedBox.shrink()` row so `PhasesWidget` does not panic on an invalid `roundIndex`. The defensive guard from followup-02 step 2 already exists; just make sure it short-circuits before any `PhasesWidget` construction.

Tests in `test/views/drill_player/mini_round_row_test.dart`:

- Update the "renders three HH:MM cells" test to assert `find.byType(PhasesWidget)` returns exactly three widgets (instead of three text matches). Phase times rendered inside `PhasesWidget` are still discoverable via the same `find.text(...)` calls because `PhasesWidget` paints the time text in its own `Text`.
- Replace the "cell at index matching `event.phase` is highlighted with `Colors.blueAccent`" assertion with one that finds the third `PhasesWidget` (or whichever matches `event.phase.index - 1`) and verifies its widget tree contains a `FractionallySizedBox` with `widthFactor: 1.0` for completed phases or `widthFactor: event.phaseProgress` for the active phase. If that gets noisy, a coarser assertion is acceptable: assert the underlying widget is `PhasesWidget` and trust its existing tests for the visual state.
- Add a new test "completed phase stays filled when the exercise advances": construct an event with `event.phase == ExercisePhase.rotation` and assert the `PhasesWidget` at `phaseIndex: 0` has its `isComplete` branch active. The simplest check: descend into the widget tree and find a `Container` with `color == Colors.blueAccent` whose ancestor `FractionallySizedBox.widthFactor == 1.0`. If the assertion ergonomics are too painful, fall back to: assert the widget tree contains at least two `Colors.blueAccent` containers (one for the completed phase, one for the current phase's track or partial fill).
- The "singular case: 1 runde" test from Step 6 still holds and does not need changes.

Commit: `refactor(widget): reuse PhasesWidget in MiniRoundRow so completed phases stay filled`.

### Step 8. **player-sheet**: drop chevron wrapper, square corners, fill viewport

The DrillPlayer sheet was built as a chrome-on-top-of-body wrapper, but the body it wraps (`CoordinatorScreen`) already provides its own AppBar with an X close. Result: double close affordance, `showModalBottomSheet`'s default rounded top corners, and a viewport margin on web because `BoxConstraints` only pinned `minHeight`. Rework the sheet shell so it renders the body directly, with no chrome of its own, square corners, and full viewport height.

**Files touched:**

- `lib/views/widgets/drill_player_sheet.dart`. Refactor the file so:

  - `showDrillPlayerSheet` calls `showModalBottomSheet` with:
    - `useSafeArea: false`
    - `isScrollControlled: true`
    - `enableDrag: false`
    - `isDismissible: false`
    - `backgroundColor: Theme.of(context).colorScheme.surface`
    - **New** `shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero)` so the sheet has square edges.
    - `constraints: BoxConstraints(minHeight: screenHeight, maxHeight: screenHeight, maxWidth: double.infinity)` so the sheet pins to the full viewport height instead of capping itself somewhere below. Use `MediaQuery.sizeOf(context).height` as `screenHeight`.
  - The `builder` returns the body **directly**, with no `Column` / `Material` / `IconButton` chevron in front of it. Concretely, the existing `_DrillPlayerSheetBody` stateful wrapper becomes a thin lifecycle host whose `build` returns just `widget.builder(context)` — no row, no chevron, no `SafeArea`. The wrapper still exists because the immersive-mode lifecycle has to happen somewhere; it just stops painting its own chrome.
  - Inside `_DrillPlayerSheetBody`, the `initState` / `dispose` immersive-mode logic from V1 stays unchanged: `SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky)` on enter and `SystemUiMode.edgeToEdge` on exit, guarded by `!kIsWeb && defaultTargetPlatform == TargetPlatform.android`. Web stays edge-to-edge throughout.
  - Update the file-level doc comment to reflect the new model: "The sheet is a true fullscreen route. It does not render its own close chrome — the wrapped body (today: `CoordinatorScreen`) provides its own AppBar with a close affordance. This file owns only the modal-route configuration and the Android immersive-mode lifecycle."
  - Remove the now-unused `import 'package:ringdrill/l10n/app_localizations.dart';` if no other reference remains.
  - The `WidgetBuilder` signature for the `builder` parameter does not change.

- No edits to `lib/views/coordinator_screen.dart`, `lib/views/main_screen.dart`, `lib/views/program_view.dart`, or any other call site. The caller contract is unchanged: pass a `WidgetBuilder` that returns the body widget; the sheet handles the rest.

- ARB files: leave `drillPlayerClose` in place for now — it becomes unreferenced after this step but deleting unused ARB keys belongs in its own chore commit.

Test updates in `test/views/drill_player/drill_player_sheet_test.dart`:

- Update the "renders the close button (chevron-down) closes it" test: rename to "wraps the builder body without adding chrome". Assert:
  - `find.byIcon(Icons.keyboard_arrow_down)` finds **nothing** (the chevron is gone).
  - The builder's output (use a simple `Container(key: const ValueKey('test-body'))` in the test) is rendered.
- Keep the "no drag handle" test as is.
- Keep the "fling does not dismiss" test as is.
- Add a new test "sheet has square corners and fills the viewport":
  - Pump `showDrillPlayerSheet` with a simple body.
  - Find the underlying `Material` widget rendering the modal surface and assert its `shape` is `RoundedRectangleBorder` with `borderRadius == BorderRadius.zero`. If the finder is too brittle, fall back to asserting the rendered `RenderClipRRect`'s `borderRadius` is zero.
  - Use `tester.getSize` on the sheet's outer Material and assert `size.height == tester.view.physicalSize.height / tester.view.devicePixelRatio` (i.e. the sheet fills the viewport).

Commit: `fix(player-sheet): drop chevron, square corners, fill viewport height`.

### Step 9. **player**: bottom strip shows total exercise progress, not phase progress

Switch the mini-bar's bottom progress strip from interpolated `phaseProgress` to interpolated `totalProgress`. Per-phase progress is already represented by the `PhasesWidget` active-cell fill inside `MiniRoundRow` after Step 7, so the bottom strip is free to carry the end-to-end "where am I in the whole exercise" signal instead.

**Files touched:**

- `lib/views/drill_player/drill_mini_player.dart`:
  - In the build method, after the existing `secondsSinceEvent` is computed (from followup-01 Step 2), compute a new `smoothedTotalProgress`:
    ```dart
    final totalDurationMinutes = event.exercise.numberOfRounds *
        (event.exercise.executionTime +
            event.exercise.evaluationTime +
            event.exercise.rotationTime);
    final totalDurationSeconds = (totalDurationMinutes * 60).clamp(1, 1 << 30);
    final smoothedTotalProgress =
        (event.totalProgress + secondsSinceEvent / totalDurationSeconds)
            .clamp(0.0, 1.0);
    ```
  - Replace `widthFactor: smoothedProgress` in the bottom strip's `FractionallySizedBox` (Step 5) with `widthFactor: smoothedTotalProgress`.
  - The phase-coloured fill stays — the active phase still tints the bar so the user sees which phase is currently driving the progress. Only the value source changes.
  - If `smoothedProgress` is no longer referenced anywhere after this edit, leave it in place if it's still computed for a different purpose (none expected); otherwise drop the dead line.
  - Add a brief inline comment: "Bottom strip = total exercise progress. Per-phase progress lives inside MiniRoundRow via PhasesWidget cell fills (Step 7)."
  - During `event.isPending`, `event.totalProgress` is 0 — the strip renders empty until the exercise actually starts. No special handling.
  - During `event.isDone`, `event.totalProgress` is 1 — the strip is fully filled. No special handling.

Tests in `test/views/drill_player/drill_mini_player_test.dart`:

- The existing tests don't pin the bottom strip's value, so no updates required. If any test asserts on `smoothedProgress` (unlikely), drop the assertion.

Commit: `fix(player): bottom mini-bar strip tracks total exercise progress`.

### Step 10. **player**: animated ring around the mini-bar play icon (spinning when running, pulsing when pending)

Wrap the play-icon square in a state-dependent ring: indeterminate `CircularProgressIndicator` while running (Spotify-style "now playing"), a pulsing circle while pending ("warming up"). Decorative, no progress data attached. The bottom strip and `MiniRoundRow` already carry the progress signals.

**Files touched:**

- `lib/views/drill_player/drill_mini_player.dart`:
  - Replace the existing 36×36 play-square `Container` (the one with `BorderRadius.circular(6)` set in followup-02 Step 3) with a `SizedBox(width: 36, height: 36, child: Stack(...))`. Inside the stack, paint two layers in order:
    1. **Inner colored disc + icon.** A `Center` containing a `Container` of width 30, height 30, `decoration: BoxDecoration(color: colorForPhase(event.phase), shape: BoxShape.circle)` with a child `Icon(Icons.play_arrow, color: Colors.white, size: 18)`. The container is now a circle (not a rounded square), 6 px smaller all around so the ring fits around it.
    2. **Animated ring.** A `SizedBox.expand(child: _PlayRing(phase: event.phase))` where `_PlayRing` is a small private widget defined further down in the file. The widget renders one of two visual variants depending on phase:
       - `ExercisePhase.pending` → pulsing ring (see `_PulsingRing` below).
       - any other phase → an indeterminate `CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation<Color>(colorForPhase(phase).withValues(alpha: 0.85)), backgroundColor: Colors.transparent)`.
  - The whole composition stays at the 36×36 footprint matching the `ExerciseNumberBadge` after followup-03 Step 2.
  - Add an inline comment above the play composition: "Ring is decorative — pulses in pending ('warming up'), spins in running ('now playing'). Progress data is on the bottom strip (totalProgress) and inside MiniRoundRow (per-phase via PhasesWidget)."
  - Keep the `// V2: stop button — see DESIGN-001 "V1 scope" parked list` comment immediately above the new composition.

  Add the two private widgets at the bottom of the file:

  ```dart
  /// Switches between a pulsing ring (pending) and an indeterminate spinning
  /// ring (running/eval/rotation/done). Decorative only.
  class _PlayRing extends StatelessWidget {
    const _PlayRing({required this.phase});
    final ExercisePhase phase;

    @override
    Widget build(BuildContext context) {
      final ringColor = colorForPhase(phase).withValues(alpha: 0.85);
      if (phase == ExercisePhase.pending) {
        return _PulsingRing(color: ringColor);
      }
      return CircularProgressIndicator(
        strokeWidth: 2.5,
        valueColor: AlwaysStoppedAnimation<Color>(ringColor),
        backgroundColor: Colors.transparent,
      );
    }
  }

  /// Pulsing ring used in the pending state. Cycles opacity and stroke width
  /// on a ~1.2 s loop so the play icon reads as "warming up".
  class _PulsingRing extends StatefulWidget {
    const _PulsingRing({required this.color});
    final Color color;

    @override
    State<_PulsingRing> createState() => _PulsingRingState();
  }

  class _PulsingRingState extends State<_PulsingRing>
      with SingleTickerProviderStateMixin {
    late final AnimationController _controller;

    @override
    void initState() {
      super.initState();
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1200),
      )..repeat(reverse: true);
    }

    @override
    void dispose() {
      _controller.dispose();
      super.dispose();
    }

    @override
    Widget build(BuildContext context) {
      return AnimatedBuilder(
        animation: _controller,
        builder: (_, __) {
          final t = Curves.easeInOut.transform(_controller.value);
          return Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: widget.color.withValues(alpha: 0.3 + 0.55 * t),
                width: 2 + 1.5 * t,
              ),
            ),
          );
        },
      );
    }
  }
  ```

  Notes on the implementation:
  - The `AnimationController` lives in `_PulsingRingState` and disposes cleanly. No extra timer plumbing in `_DrillMiniPlayerState`.
  - Border-based pulse (not `CircularProgressIndicator`-based) because we want the ring to *breathe* (opacity + stroke width), not to rotate. `CircularProgressIndicator` does not expose those knobs.
  - During `done` (rare in the mini-bar — it disappears almost immediately), the ring still spins. Acceptable since the mini-bar is about to vanish.

Tests in `test/views/drill_player/drill_mini_player_test.dart`:

- Update the existing "renders ExerciseNumberBadge, MiniRoundRow, countdown and play square" test:
  - `find.byIcon(Icons.play_arrow)` still finds one widget (the inner disc's icon).
  - Add an assertion that `find.byType(CircularProgressIndicator)` finds exactly one widget when running. Use a fixture that starts in the running phase (the existing one does).
- Add a new test "pending state shows a pulsing ring, not a spinning indicator":
  - Use the pending fixture from Step 1.
  - Assert `find.byType(CircularProgressIndicator)` finds **nothing**.
  - Assert `find.byType(AnimatedBuilder)` finds at least one widget (the pulsing ring). If the finder picks up unrelated AnimatedBuilders elsewhere in the tree, narrow it with a `Key('drill-mini-player-pulsing-ring')` on the inner `Container` and find by key. Add the key to `_PulsingRingState`'s built `Container` so the test can target it.
- Keep the "no stop button in V1" test as is.
- Make sure each `testWidgets` that constructs the mini-bar ends with `ExerciseService().stop()` and a final `await tester.pump()` — both `CircularProgressIndicator` and the pulse controller add pending timers; without explicit teardown the framework complains.

Commit: `feat(player): animate mini-bar play icon (pulse pending, spin running)`.

## When the loop is done

After Step 10 lands clean:

1. Re-check on a running app:
   - Pending state reads "Starter om mm:ss" with seconds ticking each second; the running state reads "ØVE 04:32" (or EVAL/RULL) with the label coloured by phase and the time at the larger font size.
   - The exercise-number badge on the left and the play square on the right share a 36×36 footprint.
   - All non-badge text in the strip (countdown, R-cell, phase times, dividers, phase label, total-rounds cell) sits comfortably at the new larger size.
   - The progress strip at the very bottom of the mini-bar fills end-to-end across the entire exercise (total progress), not per phase. The active phase's tint still drives the fill colour.
   - `MiniRoundRow` reads `R1 │ 08:00 │ 09:15 │ 09:30 │ 4 runder` (or `1 runde` when there is only one), mirroring the expanded-tile header pattern.
   - Walk the exercise from ØVE → EVAL → RULL and verify completed phases stay fully filled (blueAccent) behind their timestamp text, the active phase animates its progress fill, and the divider between the previous and current phase carries the "completed" state. This is the canonical `PhasesWidget` behaviour now reused via Step 7.
   - Play icon now sits inside a circular phase-coloured disc with an animated ring around it: a slow pulse in pending state, a spinning indeterminate indicator in running state. Composition stays at a 36×36 footprint matching the exercise-number badge on the left.
   - Open the DrillPlayer sheet on web, Android and iOS. The sheet fills the viewport edge-to-edge, has square corners, and shows only a single close affordance (CoordinatorScreen's AppBar X). No chevron-down, no top margin on web.
2. Append a final entry to `docs/prompts/DESIGN-001-V1-handoff.md`:
   ```
   ## Followup-03 complete (<final commit sha>)
   - Mini-bar pending state shows "Starter om mm:ss" with per-second tick.
   - ExerciseNumberBadge gained a `size` param (default 40); mini-bar passes 36 to match the play square.
   - Non-badge text bumped to titleMedium / 14 sp.
   - Phase label (ØVE/EVAL/RULL) restored to the left of the countdown when running.
   - Progress strip rebuilt as a phase-coloured fill on a dark wash track for vivid contrast.
   - MiniRoundRow now reads R{N} … {M} runder, matching the expanded-tile header pattern.
   - PhasesWidget gained a `cellSize` parameter; MiniRoundRow reuses it so completed phases stay filled.
   - DrillPlayer sheet renders body directly: no chevron, square corners, full viewport height. Body's AppBar X is the sole close affordance.
   - Bottom mini-bar strip tracks total exercise progress, not phase progress (per-phase signal lives inside MiniRoundRow via PhasesWidget cell fills).
   - Play icon wrapped in an animated ring: pulse in pending, spin in running. Decorative liveness signal.
   - V2 backlog unchanged. See DESIGN-001 §"V1 scope" parked list.
   ```
3. Stop.

## Out of scope

- Removing or dimming the three HH:MM start times in `MiniRoundRow` during pending. The mini-row already renders without an active cell highlight in pending; the times themselves remain visible so the user can see when each phase will begin once the exercise starts.
- Localizing or changing the format of the round indicator `R1/4`. Still locale-neutral by design.
- Any change to `ExerciseService`'s pending semantics.
- Cleaning up the now-unused `drillPlayerStartingIn` ARB key — defer to a separate chore commit.
- Resizing `StationCodeBadge` or `RoleCodeBadge`. The 36 px override is scoped to `ExerciseNumberBadge` in its mini-bar context. The other badges are not next to a 36 px sibling and don't need the change.
- Changing the badge's corner radius, padding or typography family — only `size` becomes parameterized.
- Threading `size` into the play-square's design — it stays 36 because the `Container` literal there is already correct.
- Reintroducing the phase chip with a coloured background — Step 4 restores the phase **label** (coloured text), not the V1 chip (pill with background fill). The play square already carries the phase background signal.
- Changing the `colorForPhase` palette. Step 5 brightens the strip by reshaping the track and the rendering primitive, not by editing the phase-colour constants in `phase_colors.dart`.
- Parametrizing `PhasesWidget.fontSize` in Step 7 — width-only for now. If the 18 sp text overflows the 48-px mini-bar cell, fold a fontSize parameter into a follow-up rather than expanding Step 7's scope.
- Touching `PhaseTile`'s own composition. Step 7 only edits `PhasesWidget` (adds `cellSize` parameter) and `MiniRoundRow` (reuses the widget). `PhaseTile` continues to render with the existing defaults.
- Touching `CoordinatorScreen`'s AppBar in Step 8. The X close stays put; it is shared with the `ContextSheet` flow and must keep working there.
- Touching `ContextSheet` in Step 8. Its rounded-corner sheet presentation for non-live exercises is still the right look there.
- Removing the `drillPlayerClose` ARB key in Step 8. It becomes unreferenced after the chevron is dropped; the next ARB chore commit handles cleanup en masse.
- Adding "tap outside to close" or "drag down to close" to the DrillPlayer sheet — V1 stays explicit-close-only via the AppBar X.
- Changing `ExerciseService`'s emission cadence in Step 9. The interpolation against `totalProgress` happens locally in the mini-bar widget, the same way Step 5's track-and-fill strip and followup-01's countdown interpolation already do.
- Dropping the Spotify-style 8 px horizontal margin + 12 px rounded clip on the mini-bar. The Spotify reference itself keeps that floating look, so we keep ours too.
- Attaching progress data to the Step 10 ring. It is indeterminate / pulsing by design — decorative only. Wiring `event.totalProgress` or `event.phaseProgress` to its `value` would duplicate signals that already exist elsewhere on the mini-bar.
- Making the play icon a tap target separate from the rest of the strip. The ring composition is still inside the same `InkWell` that wraps the row; tapping anywhere (including the ring) opens the player sheet. No independent button.

If a new gap surfaces, follow [[feedback-new-findings-own-prompt]]: split it into `DESIGN-001-V1-followup-04-...` rather than stacking it on this one.
