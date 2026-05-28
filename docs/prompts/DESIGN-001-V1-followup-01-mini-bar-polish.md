You are working in the RingDrill repository. This is follow-up 01 on the DESIGN-001 V1 implementation that landed in commits `4d5b98b..468a9c1`. The V1 spec is locked at `docs/design/exercise-player.md` §"V1 scope". The implementation prompt that produced the current state is `docs/prompts/DESIGN-001-V1-implementation-prompt.md`. Read both before you start.

Smoke-testing V1 surfaced four real gaps and one cleanup item. This follow-up closes all five. None of them require revisiting DESIGN-001's V2+ parked list.

## Gaps to close

### Gap 1 — The mini-bar appears to not be wired to the Play FAB

Repro:

1. From the Program tab, tap a non-live exercise card.
2. `ProgramView` routes to `ContextSheet.show(ExerciseSheetTarget(uuid: ...))` because `_liveEvent?.exercise.uuid != exercise.uuid`. The ContextSheet opens with `CoordinatorScreen(uuid: ...)` as the body.
3. Inside CoordinatorScreen, tap the green Play FAB (`ExerciseControlButton`). It calls `ExerciseService().start(exercise)`. The service starts emitting events on its broadcast stream.
4. `DrillMiniPlayer` is mounted in `MainScreen.bottomNavigationBar` via `_buildBottomChrome`. It subscribes to `ExerciseService().events` and rebuilds correctly — but `bottomNavigationBar` is covered by the ContextSheet's modal route, so the user sees nothing change.
5. To see the mini-bar, the user has to close the ContextSheet manually. That looks like a wiring bug even though it is not.

The Step 4 routing rule in the V1 implementation prompt (live → DrillPlayer sheet, non-live → ContextSheet) covers only the *initial* tap. It does not cover the *transition* from non-live to live while the ContextSheet is open. That is the actual hole.

### Gap 2 — Countdown only steps in minutes

`DrillMiniPlayer` formats the countdown as `'${event.remainingTime.toString().padLeft(2, '0')}:00'`. `ExerciseEvent.remainingTime` is an `int` in minutes (`lib/services/exercise_service.dart:16`), so the seconds slot is hard-coded to `00`. Compounding this: `ExerciseService._progress` only emits an event when `TimeOfDay.now()` changes minute, so even if the widget formatted seconds correctly, fresh data only arrives once per minute.

The user wants a true `mm:ss` countdown that ticks every second, Spotify-style. That requires the mini-bar to interpolate locally between events instead of waiting for the next one.

### Gap 3 — Progress bar is in the wrong place

Today the 3 px progress strip sits *above* the mini-bar row (Column child #0). On Spotify the progress bar sits at the *bottom* of the now-playing strip, hugging the navigation. Move it below the row so it lines up with the top edge of `NavigationBar`.

### Gap 4 — Mini-bar background blends into the list above it

The live `ExerciseCard` in `ProgramView` uses `LiveAccent.of(context, isLive: true)` for its `Card.color`, which resolves to `Theme.of(context).colorScheme.primaryContainer`. The mini-bar today uses the default `Material` colour and disappears visually into the scaffold background under the list, with no edge to read against.

The user wants the mini-bar to pick up the same `LiveAccent` background as the live `ExerciseCard`. Two benefits:

- The mini-bar and the live card read as one continuous "live" surface, separated only by the gap below the list (where the scaffold background shows through), which gives the mini-bar a natural edge.
- The LiveAccent token already exists per [[feedback-design-tokens-pattern]]. Don't introduce a parallel colour constant.

### Gap 5 — Sheet test path is inconsistent

`drill_mini_player_test.dart` lives at `test/views/drill_player/drill_mini_player_test.dart` per the V1 prompt, but `drill_player_sheet_test.dart` landed at `test/views/widgets/drill_player_sheet_test.dart`. Both files cover the same feature; group them.

## Ground rules

Read `AGENTS.md` and `CLAUDE.md` and follow every numbered rule. The non-negotiable ones for this change:

- **Widget-only.** No `@freezed` edits, no `*.g.dart`, no model changes. If you find yourself reaching for codegen, stop — this follow-up is widget + service-listener wiring only.
- **CLI stays Flutter-free.** `bin/ringdrill.dart` and its imports must not gain a `package:flutter/*` import.
- **Mobile-safe imports.** No `dart:html` or `package:web`.
- **Localize new strings.** No new user-visible strings are needed for these fixes. If you discover you do need one, add the key to both `lib/l10n/app_en.arb` and `lib/l10n/app_nb.arb` together and explain why in the commit body.
- **Verify before claiming green.** Run `flutter analyze` and `flutter test` per commit. `test/widget_test.dart` is the known-broken default-template smoke test.
- **Wide-screen is still parked.** The mini-bar remains narrow-only in V1.
- **Do not refactor `ContextSheet`.** Gap 1 is closed with a small subscriber inside `_DefaultContextSheetBody`, not by changing the controller's API.
- **Do not change `ExerciseService`.** Gap 2 is closed locally in the mini-bar via a per-second `Timer` that interpolates against `ExerciseEvent.when`. The service still emits per minute. Do not introduce a per-second emission in the service — that ripples through every other subscriber.

## Commit policy

Per [[feedback-prompts-commit-everything]]:

- One commit per step. Conventional Commits, allowed types `feat`, `fix`, `refactor`, `chore`, `docs`, `test`.
- Every step ends with `git status` clean. Stage all files listed under "Files touched" for that step.
- Run `flutter analyze` and `flutter test` after each commit. Fix forward on the same step (`fix(<scope>): ...`) rather than amending unless the failure is a trivial typo.
- Do not squash. Each step lands its own commit so the loop driver can resume on a partial run.

Scopes that apply here: `player`, `widget`, `navigation`, `test`.

## Token discipline

- `Grep`/`Glob` to locate, `Read` with `offset`/`limit` for sections. The V1 files are small — full reads are fine on `drill_mini_player.dart`, `drill_player_sheet.dart`, and `context_sheet.dart`.
- Skip generated files. `app_localizations*.dart` regenerates if you edit ARB files (you should not need to in this follow-up).
- Resist speculative refactors. The four gaps above are the entire scope. If you spot something else, append a one-line note to `docs/prompts/DESIGN-001-V1-followups.md` (create on first use) and keep moving.

## Handoff between steps

- Read `docs/prompts/DESIGN-001-V1-handoff.md` at the start of each step. Append a fresh entry at the end of each step using the format established in the V1 implementation prompt:

  ```
  ## Followup-01 Step <N>: <short title> (<commit sha>)
  - State established: <one line>
  - Next step inputs: <one line>
  - Deferred: <one line if anything was noticed and parked; omit otherwise>
  ```

- Keep the handoff append-only.

## Scope and step order

Four steps. Do them in order. Each step's heading contains the commit keyword in **bold**.

### Step 1. **navigation**: auto-close ContextSheet when its exercise goes live

Close Gap 1 with the smallest possible diff. The fix is a stateful wrapper inside `_DefaultContextSheetBody` that subscribes to `ExerciseService().events` for the duration of an `ExerciseSheetTarget` and calls `ContextSheet.of(context).close()` when `isStartedOn(target.exerciseUuid)` flips to true.

**Files touched:**

- `lib/views/widgets/context_sheet.dart`:
  - Add a new private `StatefulWidget` (e.g. `_ExerciseSheetBody`) that takes the `exerciseUuid` and renders `CoordinatorScreen(uuid: exerciseUuid)`. In `initState` it subscribes to `ExerciseService().events`, in `dispose` it cancels.
  - The listener: if `event.exercise.uuid == widget.exerciseUuid && ExerciseService().isStarted` and the subscriber has not already closed, post a single `WidgetsBinding.instance.addPostFrameCallback((_) { if (!mounted) return; ContextSheet.of(context).close(); })`. Use a `bool _closed` flag so the callback only runs once even if multiple events arrive before the route pops.
  - Guard against the "already live when sheet opens" race: also check the gate in `initState` after subscribing (read `ExerciseService().last` and trigger close in a post-frame callback if it already matches).
  - Update the `_DefaultContextSheetBody.build` switch arm for `ExerciseSheetTarget(:final exerciseUuid)` to return the new `_ExerciseSheetBody(exerciseUuid: exerciseUuid)` instead of the bare `CoordinatorScreen`.
  - No public API changes on `ContextSheet` or `ContextSheetController`. No new ARB strings.

Smoke flow after this step (manual, not automated): open a non-live exercise sheet, press Play inside, observe that the sheet closes itself and the mini-bar appears above the navbar. Tap the mini-bar — DrillPlayer sheet opens with the same CoordinatorScreen body.

Commit: `feat(navigation): auto-close exercise ContextSheet when it goes live`.

### Step 2. **player**: per-second countdown and progress interpolation in `DrillMiniPlayer`

Close Gap 2 by interpolating locally instead of waiting for the next service event.

**Files touched:**

- `lib/views/drill_player/drill_mini_player.dart`:
  - In `_DrillMiniPlayerState`, add a `Timer? _ticker` and a `DateTime _now` field. Start the ticker in `initState` with `Timer.periodic(const Duration(seconds: 1), (_) { if (!mounted) return; setState(() => _now = DateTime.now()); })`. Cancel in `dispose`.
  - Replace the current `event.remainingTime` formatting with a local computation:
    ```dart
    final secondsSinceEvent = _now.difference(event.when).inSeconds.clamp(0, 1 << 30);
    final remainingSeconds = (event.remainingTime * 60 - secondsSinceEvent).clamp(0, 1 << 30);
    final mm = (remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final ss = (remainingSeconds % 60).toString().padLeft(2, '0');
    final countdown = event.isPending
        ? localizations.drillPlayerStartingIn
        : '$mm:$ss';
    ```
  - Replace the current `event.phaseProgress` use in the progress strip with a smoothed value:
    ```dart
    final phaseDurationSeconds = (event.currentDuration * 60).clamp(1, 1 << 30);
    final smoothedProgress = (event.phaseProgress +
            secondsSinceEvent / phaseDurationSeconds)
        .clamp(0.0, 1.0);
    ```
    Pass `smoothedProgress` to the `LinearProgressIndicator`.
  - The ticker is purely a redraw signal. The actual data still comes from `event`. When a new `ExerciseEvent` arrives via the existing stream listener, the displayed values resynchronise to truth automatically.
  - Add a brief inline comment explaining: "Per-second ticker interpolates between minute-granular service events so the countdown reads mm:ss and the progress bar moves smoothly. The service still emits per minute — see V1 followup-01 Gap 2."

Test updates in `test/views/drill_player/drill_mini_player_test.dart`:

- Adjust the "shows exercise name and phase chip when running" test to assert the countdown matches an `mm:ss` regex (`RegExp(r'^\d{2}:\d{2}$')`) instead of a literal string. Do not assert exact seconds — tests run against wall-clock time.
- Pump `tester.pump(const Duration(seconds: 2))` once in the running-state test to exercise the ticker and assert the widget does not throw.
- Make sure each `testWidgets` body that calls `ExerciseService().start(...)` ends with `ExerciseService().stop()` *and* `await tester.pump()` so the periodic timers in both the service and the mini-bar are torn down before the framework's pending-timer invariant check.

Commit: `feat(player): tick mini-bar per second for smooth mm:ss countdown`.

### Step 3. **player**: move the progress strip below the mini-bar row

Close Gap 3.

**Files touched:**

- `lib/views/drill_player/drill_mini_player.dart`:
  - In the returned `Column`, swap the two children so the order becomes `[InkWell(mini-bar row), SizedBox(progress strip)]`. The progress strip is then the last child of `_buildBottomChrome`'s mini-bar column, sitting immediately above `NavigationBar`. This matches Spotify's now-playing strip placement.
  - The progress strip itself does not change — just its position. Color, height (3 px) and value (smoothed per Step 2) stay the same.

No test changes required (the existing tests do not assert ordering).

Commit: `refactor(player): place mini-bar progress strip below the row, Spotify-style`.

### Step 4. **player**: apply `LiveAccent` background to the mini-bar

Close Gap 4 by tinting the mini-bar's surface with the same `colorScheme.primaryContainer` the live `ExerciseCard` already uses, so the two surfaces read together.

**Files touched:**

- `lib/views/drill_player/drill_mini_player.dart`:
  - At the top of `build`, derive the live accent: `final accent = LiveAccent.of(context, isLive: true);`. Import `package:ringdrill/views/widgets/live_accent.dart`. The mini-bar is by construction only visible when an exercise is live, so the `isLive: true` literal is correct here — we are not branching on `ExerciseService` state, we are saying "this widget represents a live exercise".
  - Wrap the returned `Column` in a `Material(color: accent.background, child: ...)`. `Material` rather than `Container` so the existing `InkWell` keeps its ripple. Do not also apply `accent.shape` — the mini-bar is a strip, not a card, and the bordered shape from `LiveAccent` is meant for `Card.shape`.
  - Replace the literal `Colors.white` text colours and `Theme.of(context).textTheme.bodyMedium`-style defaults on the title, round indicator and countdown with `accent.foreground` (i.e. `colorScheme.onPrimaryContainer`). Specifically:
    - Exercise name `Text` style: add `color: accent.foreground`.
    - Round indicator `Text` style: add `color: accent.foreground`.
    - Countdown `Text` style: add `color: accent.foreground`.
  - **Do not** repaint the 36×36 phase-icon square or the phase chip. They keep their phase colours (`colorForPhase`) and white icon/text. The contrast between the phase-coloured glyphs and the `primaryContainer` background is the point.
  - **Do not** repaint the progress strip. It keeps the phase colour so phase signal stays readable, the same way the live card's progress widgets keep their phase fills.

No test changes required. The existing tests don't assert background colour.

Commit: `feat(player): tint mini-bar with LiveAccent background`.

### Step 5. **test**: group DrillPlayer tests under `test/views/drill_player/`

Close Gap 5.

**Files touched:**

- Move `test/views/widgets/drill_player_sheet_test.dart` → `test/views/drill_player/drill_player_sheet_test.dart`. Use `git mv` so the move shows up cleanly in history. No content change.
- Confirm the moved file's imports still resolve (`package:ringdrill/views/widgets/drill_player_sheet.dart` is unchanged) and `flutter test` picks it up at the new path.

Commit: `test(player): move sheet test next to mini-player test for consistency`.

## When the loop is done

After Step 5 lands clean:

1. Re-check the five gaps manually on a running app (Android device or emulator for the immersive-mode aspects, plus iOS simulator for parity):
   - Start a non-live exercise from inside its ContextSheet → sheet auto-closes → mini-bar appears.
   - Mini-bar countdown reads `mm:ss` and ticks every second.
   - Progress strip is below the mini-bar row, touching the navbar's top edge.
   - Mini-bar background is `primaryContainer`, matching the live `ExerciseCard` in the list above so the two surfaces read together with the scaffold gap forming the edge.
   - `flutter test test/views/drill_player/` runs both test files green.
2. Append a final entry to `docs/prompts/DESIGN-001-V1-handoff.md`:
   ```
   ## Followup-01 complete (<final commit sha>)
   - Sheet auto-closes on live transition; mini-bar tickers per second; progress moved below row; mini-bar tinted with LiveAccent; tests grouped.
   - V2 backlog unchanged. See DESIGN-001 §"V1 scope" parked list.
   ```
3. Stop. Do not start V2 work in the same loop.

## Out of scope, for the avoidance of doubt

Everything in DESIGN-001 §"V1 scope" parked list remains parked. In particular this follow-up does **not** touch:

- The three-tab segmented control or the Overview tab.
- Observer player variants.
- Wide-screen mini-bar layout.
- Stop button on the mini-bar (V1 stays tap-only).
- Drag-to-dismiss on the player sheet.
- `PhaseTile` color-semantics rework.
- `ExerciseService` event cadence (still per minute).
- The deep-link path through `_ContextSheetDeepLinkLauncher` — the auto-close from Step 1 still applies there because it lives in the body, not the entry point.

If a sixth gap surfaces while you're working, follow [[feedback-new-findings-own-prompt]]: split it into a new numbered follow-up (`DESIGN-001-V1-followup-02-...`) rather than stacking it on this one.
