You are working in the RingDrill repository. This is follow-up 02 on the DESIGN-001 V1 implementation. **Follow-up 01 (`DESIGN-001-V1-followup-01-mini-bar-polish.md`) MUST be landed before this one starts.** This follow-up replaces parts of what 01 just shipped, and it relies on 01's auto-close behaviour and `LiveAccent` background being already in place.

Read first:

- `docs/design/exercise-player.md` §"V1 scope" — the design contract V1 implements.
- `docs/prompts/DESIGN-001-V1-implementation-prompt.md` — what V1 shipped initially.
- `docs/prompts/DESIGN-001-V1-followup-01-mini-bar-polish.md` — what 01 changed (per-second ticker, progress below row, LiveAccent background, auto-close ContextSheet, test relocation).

Smoke-testing V1 + followup-01 surfaced a usability problem: the mini-bar spends most of its width on the exercise name and a phase chip, neither of which the coordinator needs at every glance. The information density is wrong. This follow-up replaces the mini-bar's visual layout with one that mirrors the round table from `CoordinatorScreen` and surfaces the next phase transition times directly. It also drops the phase-changing icon in favour of a universal play symbol with phase-coloured background, and rounds + floats the mini-bar above the navbar Spotify-style.

## Design summary

```
        ┌────────────────────────────────────────────────────────────────┐
margin →│ [#3]  R1/4 │ 20:15 │ 20:55 │ 21:10        04:42      [▶ green] │← margin
        └────────────────────────────────────────────────────────────────┘
        ▒▒▒▒▒▒▒▒▒▒▒▒▒▒ phase-colored progress strip along bottom ▒▒▒▒▒▒▒▒
        ┌────────────────────────────────────────────────────────────────┐
        │  NavigationBar (Øvelser · Kart · Poster · Markører · Lag)     │
        └────────────────────────────────────────────────────────────────┘
```

From left to right, inside the rounded container:

1. **Exercise-number badge** — `[#3]` style, derived from the exercise's position in the active program (`program.exercises.indexWhere((e) => e.uuid == ex.uuid) + 1`, same convention as `BriefRenderer.exerciseNumber`).
2. **Mini round-row** — `R1/4 │ HH:MM │ HH:MM │ HH:MM`. The three timestamps are the start times of the three phases in the current round (`exercise.schedule[event.currentRound][0..2]`). The cell whose phase matches `event.phase` is highlighted with the same blue active-cell treatment used by `PhaseTile` in `CoordinatorScreen` so the user reads the same language across both surfaces.
3. **Countdown** `mm:ss` (from followup-01's per-second ticker).
4. **Play square** — 36×36 rounded square with `Icons.play_arrow` (universal play symbol, never changes between phases) on a `colorForPhase(event.phase)` background. The phase signal lives here, plus on the progress strip, plus on the active mini-row cell.

Whole strip is one tap target. The mini-row is NOT independently tappable in V1 — leave that for a future iteration if it ever needs to be interactive.

Removed from the mini-bar in this loop:

- The phase chip "ØVE / EVAL / RULL" (its information now lives in the active mini-row cell).
- The "Runde 1/4" plain-text indicator (folded into the mini-row's leading `R1/4` cell).
- The exercise name (replaced by the `[#3]` badge).
- The flame/clipboard/swap-horiz phase-changing icon (replaced by a static play arrow on a phase-coloured square).

Rounded + floating behaviour:

- Horizontal margin 8 px on each side.
- Vertical margin 4 px between mini-bar and the navbar above, so the scaffold background shows through and the rounded edge reads.
- Container `BorderRadius.circular(12)`, clipping the progress strip's bottom edge so it sits inside the rounded rectangle.
- Background continues to be `LiveAccent.of(context, isLive: true).background` (= `colorScheme.primaryContainer`) from followup-01 Step 4.

## Ground rules

Same as followup-01. The non-negotiable ones for this change:

- **Widget-only.** No model changes, no codegen.
- **CLI stays Flutter-free.** All work is under `lib/views/`.
- **Mobile-safe imports.** No `dart:html`, no `package:web`.
- **Localize new strings.** No new user-visible English strings should be needed. `R1/4` is numeric and locale-neutral. If a translation surfaces, add the key to both ARB files together.
- **Verify before claiming green.** Run `flutter analyze` and `flutter test` per commit.
- **Wide-screen is parked.** The mini-bar still renders only when `_wideScreen == false`.
- **No stop button on the mini-bar.** The play square is **visual only** — its tap is identical to tapping anywhere else on the strip and opens the DrillPlayer sheet. Do not wire it to a separate handler. The stop affordance still lives inside the sheet via `ExerciseControlButton`.
- **Do not change `ExerciseService`.** Same cadence as followup-01.
- **Do not refactor `PhaseTile`.** The mini-row is its own widget; it can borrow the *visual treatment* (blue active cell, tabular-nums, vertical dividers) but should not depend on `PhaseTile`'s constructor, which is sized for the full table.

## Commit policy

Per [[feedback-prompts-commit-everything]]:

- One commit per step. Conventional Commits. Allowed types `feat`, `fix`, `refactor`, `chore`, `docs`, `test`.
- Every step ends with `git status` clean. Stage all files listed under "Files touched" for that step.
- Run `flutter analyze` and `flutter test` per commit. Fix forward on the same step rather than amending.
- Do not squash.

Scopes that apply here: `player`, `widget`, `navigation`, `test`.

## Handoff between steps

- Read `docs/prompts/DESIGN-001-V1-handoff.md` at step start.
- Append an entry per step using the format:
  ```
  ## Followup-02 Step <N>: <short title> (<commit sha>)
  - State established: <one line>
  - Next step inputs: <one line>
  - Deferred: <one line if anything was noticed and parked; omit otherwise>
  ```
- Keep append-only.

## Scope and step order

Five steps. Do them in order.

### Step 1. **widget**: add `ExerciseNumberBadge`

A small badge that renders `#N` where N is the exercise's 1-based index in the active program. Reuses the visual language of `StationCodeBadge` (same 40×40 pill style, `surfaceContainerHighest` background, bold caption text) so the three badge families — station codes, role codes, exercise numbers — look consistent.

**Files touched:**

- **New** `lib/views/widgets/exercise_number_badge.dart`. Public widget `ExerciseNumberBadge` with:
  - `final int number;`
  - Optional `final bool highlight;` (defaults `false`). When `true`, paint the pill with `colorScheme.primary` / `onPrimary` to match `StationCodeBadge.highlight`. The mini-bar always passes `highlight: false` because the surrounding LiveAccent background already carries the "live" signal — the badge does not need to also flag it.
  - Renders a 40×40 pill (same dimensions as `StationCodeBadge`) with `'#$number'` centered, `FontWeight.w700`, `fontSize: 14`, FittedBox-scaled so multi-digit numbers stay one line.
  - Doc comment explaining: "Sibling of `StationCodeBadge` and `RoleCodeBadge`. The three badges form a visual family — same dimensions, same typography, same corner radius — so users can quickly distinguish exercise / station / role tokens at a glance."

No test file for this badge in this step — coverage comes in the mini-bar test (Step 5).

Commit: `feat(widget): add ExerciseNumberBadge sibling to StationCodeBadge`.

### Step 2. **widget**: add `MiniRoundRow`

A compact horizontal row that mirrors the active row of `CoordinatorScreen`'s round table. Same active-cell treatment as `PhaseTile` (blue background, white bold text, tabular-nums for the times) but sized for the mini-bar's strip height (32 px tall, not 32-px-with-padding tall like `PhaseTile`).

**Files touched:**

- **New** `lib/views/drill_player/mini_round_row.dart`. Public widget `MiniRoundRow` with:
  - `final Exercise exercise;`
  - `final ExerciseEvent event;`
  - Renders a single `Row` with:
    - Title cell `R{currentRound+1}/{exercise.numberOfRounds}` (e.g. `R1/4`). 11-px caption, bold. Use plain text rather than a localized key — `R` + slash format is locale-neutral. Add a `// V2: localize if a target locale needs a different round abbreviation` comment.
    - A `VerticalDividerWidget` between the title cell and the first phase cell (reuse `package:ringdrill/views/vertical_divider_widget.dart` which `PhaseTile` already uses — set `isCurrent: true` so it adopts the active treatment).
    - Three phase cells, one per index 0/1/2. Each cell renders the HH:MM start time from `exercise.schedule[event.currentRound][phaseIndex]` via the existing `SimpleTimeOfDay → formal()` formatter in `lib/utils/time_utils.dart`. Tabular-nums.
    - The cell whose phase index matches `event.phase.index - 1` (since `ExercisePhase` enum is `pending=0, execution=1, evaluation=2, rotation=3, done=4` while `schedule` indices are 0/1/2) is painted with a `Colors.blueAccent` background, white text, bold. The other two cells use `accent.foreground` (`colorScheme.onPrimaryContainer`) on a transparent background.
    - Use `VerticalDividerWidget(isCurrent: phaseIsActive, isComplete: phaseIsComplete)` between phase cells, matching `PhaseTile`'s pattern.
  - When `event.isPending` or `event.isDone`, render all three phase cells in the "inactive" state (no blue highlight on any cell). The title cell still shows `R{currentRound+1}/{N}`.
  - When `event.currentRound` falls outside `exercise.schedule.length` (defensive guard), render an empty strip rather than throwing.
- Reuse `lib/utils/time_utils.dart` for formatting. Do not introduce a new formatter.

No test file in this step — coverage in Step 5.

Commit: `feat(widget): add MiniRoundRow for the DrillPlayer mini-bar`.

### Step 3. **player**: rebuild `DrillMiniPlayer` layout

Replace the existing internals of `DrillMiniPlayer` with the new layout: `[ExerciseNumberBadge][MiniRoundRow][countdown][play-square]`. The container, the per-second ticker from followup-01, and the LiveAccent background tint from followup-01 are all preserved.

**Files touched:**

- `lib/views/drill_player/drill_mini_player.dart`. Inside `build`:
  - Remove the existing 36×36 phase icon square (the flame/clipboard/swap-horiz one).
  - Remove the phase chip widget that renders `event.getState(localizations)`.
  - Remove the plain-text "Runde 1/4" `Text` widget.
  - Remove the `Expanded` exercise name `Text` widget.
  - In the inner `Row`, build the new children in order:
    1. `const SizedBox(width: 8)` for left padding.
    2. `ExerciseNumberBadge(number: exerciseNumber)`. Compute `exerciseNumber` once at the top of `build`: `final program = ProgramService().activeProgram; final exerciseNumber = program == null ? 1 : program.exercises.indexWhere((e) => e.uuid == event.exercise.uuid).clamp(0, 1 << 30) + 1;`. Import `package:ringdrill/services/program_service.dart`.
    3. `const SizedBox(width: 8)`.
    4. `Expanded(child: MiniRoundRow(exercise: event.exercise, event: event))`. The mini-row gets all the slack between badge and countdown.
    5. `const SizedBox(width: 8)`.
    6. `Text(countdown, style: ...tabularFigures with accent.foreground)` — the countdown built by followup-01's ticker stays put.
    7. `const SizedBox(width: 8)`.
    8. A 36×36 `Container` with `BoxDecoration(color: colorForPhase(event.phase), borderRadius: BorderRadius.circular(6))` containing a centered `Icon(Icons.play_arrow, color: Colors.white, size: 22)`. This is the **play square**, replacing the old phase icon. The icon never changes — only the background colour does. Add a `// V2: stop button — see DESIGN-001 "V1 scope" parked list` comment immediately above it, replacing the comment from the V1 prompt that pointed to the same parked feature.
    9. `const SizedBox(width: 8)` for right padding.
  - Pending state: when `event.isPending`, the countdown is replaced with `localizations.drillPlayerStartingIn` (already wired in V1). The play square keeps its neutral grey from `colorForPhase` (which returns grey for pending), no further change needed.
  - Strip height: the inner row should target 48 px (was 53 in V1) so the rounded container has enough headroom for badge + row + progress strip without crowding. Adjust the `SizedBox(height: ...)` accordingly.
  - The phase-coloured progress strip from followup-01 Step 3 stays at the bottom of the column.
  - Update or remove the `drillPlayerRoundOf` ARB key usage. Since the round indicator is now folded into `MiniRoundRow`, the key is unreferenced from this widget — leave the key in the ARB files for now (deleting unused ARB keys belongs in its own chore commit), but remove the import-time reference if it dangles.
  - The `_DrillMiniPlayerState.build` should grow by at most ~20 net lines after this refactor. If you find yourself adding 50+ lines, you are probably duplicating something `MiniRoundRow` should own — push it down.

Commit: `refactor(player): rebuild mini-bar layout around ExerciseNumberBadge and MiniRoundRow`.

### Step 4. **navigation**: float the mini-bar with rounded corners and side margins

Make the mini-bar a floating rounded surface above the navbar, Spotify-style. The change lives in the bottom-chrome wrapper, not inside `DrillMiniPlayer`, because the floating shape is part of the chrome composition.

**Files touched:**

- `lib/views/main_screen.dart`. In `_buildBottomChrome`:
  - Wrap the `DrillMiniPlayer` in a `Padding(padding: EdgeInsets.fromLTRB(8, 0, 8, 4), child: ClipRRect(borderRadius: BorderRadius.circular(12), child: DrillMiniPlayer(...)))`. The `ClipRRect` is what gives the progress strip (which extends to the row's bottom edge) a rounded bottom edge; the badge/row/countdown/play sit on the rounded top edge similarly.
  - Inside `DrillMiniPlayer`, the existing `Material(color: accent.background, child: ...)` from followup-01 Step 4 must NOT also set its own `borderRadius` — the outer `ClipRRect` owns the shape, the `Material` just fills it. Add a one-line comment inside `DrillMiniPlayer` noting that the rounded shape is owned by the parent (`MainScreen._buildBottomChrome`).
  - When `ExerciseService().isStarted` is false and `DrillMiniPlayer` returns `SizedBox.shrink()`, the wrapping `Padding` would still take up 4 px of bottom margin and contribute to layout. To avoid that, in `_buildBottomChrome` check `ExerciseService().isStarted` at the chrome level too and skip the `Padding(ClipRRect(...))` wrapper entirely when false. Subscribe to `ExerciseService().events` in `_MainScreenState.initState` (cancel in `dispose`) so the bottom chrome rebuilds when an exercise starts or stops. There is already a similar subscription pattern in `_MainScreenState` for `ProgramService().events` — extend it.

- `lib/views/drill_player/drill_mini_player.dart`:
  - Drop any `Material` `borderRadius` styling and the outer `Card`/`shape` if anything got added in Step 3. Internal background stays `accent.background`.
  - Add the one-line comment described above pointing to `_buildBottomChrome` as the shape owner.

No test changes required.

Commit: `feat(navigation): float DrillMiniPlayer with rounded corners above the navbar`.

### Step 5. **test**: cover the new mini-bar layout

Update the existing mini-bar tests to assert the new behaviour and add coverage for the two new sub-widgets.

**Files touched:**

- `test/views/drill_player/drill_mini_player_test.dart`:
  - Replace the "shows exercise name and phase chip when running" test with "shows ExerciseNumberBadge, MiniRoundRow, countdown and play square when running". Assert:
    - `find.byType(ExerciseNumberBadge)` finds one widget.
    - `find.byType(MiniRoundRow)` finds one widget.
    - The countdown matches `RegExp(r'^\d{2}:\d{2}$')` (already required by followup-01 Step 2).
    - `find.byIcon(Icons.play_arrow)` finds exactly one widget — the play square.
    - `find.text(exercise.name)` finds **nothing** (the name was intentionally removed).
  - Keep the "hidden when isStarted is false" test as is.
  - Keep the "onOpen fires when tapped" test, but tap a child of `DrillMiniPlayer` other than the play square to confirm the whole strip is one tap target — for example tap the centre of `MiniRoundRow`. Then add a second assertion in the same test: tapping the play square also fires `onOpen` once (it is not an independent button).
  - Keep the "no stop button in V1" test. Update its assertions: still no `Icons.stop` and no `Icons.stop_circle`. Add: `find.byType(IconButton)` returns nothing in `DrillMiniPlayer` (the play square is a `Container`, not a button).
- **New** `test/views/widgets/exercise_number_badge_test.dart`:
  - Test 1: renders `#1` for `number: 1`.
  - Test 2: renders `#12` for `number: 12`, and the FittedBox scales it without overflow (assert no `RenderFlex overflowed` exception by completing a `pumpAndSettle`).
  - Test 3: `highlight: true` paints with primary background. Use `tester.widget<Container>(find.descendant(of: find.byType(ExerciseNumberBadge), matching: find.byType(Container)).first).decoration as BoxDecoration` and assert `color == Theme.of(...).colorScheme.primary` via a Theme-aware `pump` helper.
- **New** `test/views/drill_player/mini_round_row_test.dart`:
  - Test 1: renders `R1/4` for `event.currentRound: 0` and `exercise.numberOfRounds: 4`.
  - Test 2: renders three HH:MM cells from `exercise.schedule[0]` and the cell at index matching `event.phase` is highlighted with `Colors.blueAccent`.
  - Test 3: pending state (`event.isPending`) renders the row without any cell highlight.

`flutter test test/views/drill_player/` and `flutter test test/views/widgets/exercise_number_badge_test.dart` must all be green.

Commit: `test(player): cover new mini-bar layout and helper widgets`.

## When the loop is done

After Step 5 lands clean:

1. Re-check the redesign manually on a running app:
   - The mini-bar shows the exercise number badge on the left, the mini round-row in the middle, the countdown, and the play square on the right.
   - The play square's background tints with the active phase (green during Drill, blue during Eval, amber during Roll, grey when pending) — but the icon stays a static play arrow.
   - The mini round-row's active cell highlights blue, matching `CoordinatorScreen`'s round table.
   - The mini-bar floats with rounded corners and side margin above the navbar.
   - Tapping anywhere (badge, mini-row, countdown, play square, even the corner inside the rounded shape) opens the DrillPlayer sheet.
2. Append a final entry to `docs/prompts/DESIGN-001-V1-handoff.md`:
   ```
   ## Followup-02 complete (<final commit sha>)
   - Mini-bar redesigned: exercise-number badge + mini round-row + countdown + phase-tinted play square. Rounded floating shape above navbar.
   - Removed from mini-bar: phase chip, "Runde X/Y" text, exercise name, phase-changing icon.
   - V2 backlog unchanged. See DESIGN-001 §"V1 scope" parked list.
   ```
3. Stop. Do not start V2 work.

## Out of scope, for the avoidance of doubt

Still parked from DESIGN-001 §"V1 scope":

- Three-tab segmented control or Overview tab.
- Observer player variants.
- Wide-screen mini-bar layout.
- Functional stop button on the mini-bar (the play square in this loop is **visual only**).
- Drag-to-dismiss on the player sheet.
- `PhaseTile` color-semantics rework — `MiniRoundRow` borrows the visual language but does NOT modify `PhaseTile` itself.
- `ExerciseService` event cadence (still per minute, interpolation still local to the mini-bar via followup-01's ticker).
- Interactive cells on `MiniRoundRow` — the row is informational only in this loop. The whole strip is one tap target.

If a new gap surfaces, follow [[feedback-new-findings-own-prompt]]: split it into `DESIGN-001-V1-followup-03-...` rather than stacking it on this one.
