You are working in the RingDrill repository. Implement the V1 surface of DESIGN-001 ("Exercise Player / DrillPlayer") end-to-end. The authoritative spec lives at:

- `docs/design/exercise-player.md` (DESIGN-001, Accepted) — read the **"V1 scope"** section first. The rest of the doc describes the V2+ target state and is reference material, not V1 work. The V1 scope section is the contract.

Also skim:

- `lib/services/exercise_service.dart` — the singleton that drives the player. `ExerciseService().events` is a broadcast stream of `ExerciseEvent`. `ExerciseService().isStarted` (`isPending || isRunning`) is what gates the mini-bar.
- `lib/views/main_screen.dart` — where the mini-bar mounts. `_buildNavBar` returns the `NavigationBar`. The mini-bar belongs between `body` and `bottomNavigationBar` inside the `Scaffold` (lines around 575–615 today).
- `lib/views/program_view.dart` — `_ProgramViewState._liveEvent` is the source of truth for "which card is live". `ExerciseCard.onOpen` is the tap callback that today routes through `ContextSheet.of(context).show(...)` with an `ExerciseSheetTarget`. V1 reroutes the live card only.
- `lib/views/widgets/ringdrill_sheet.dart` — the existing `showRingdrillViewerSheet` / `showRingdrillActionSheet` helpers. The new `showDrillPlayerSheet` is a third sibling, **not** a parameter on the existing two. Keep `_DragHandle` private to the existing file.
- `lib/views/widgets/context_sheet.dart` — `_DefaultContextSheetBody` maps `ExerciseSheetTarget` to `CoordinatorScreen(uuid: ...)`. V1 reuses that same widget body, just in a different sheet shell.
- `lib/views/coordinator_screen.dart` — the body that goes inside the V1 sheet. It is reused **as-is** in V1. No edits to this file in this loop unless analyzer forces it.
- `docs/adrs/0026-sheet-based-context-navigation.md` — context for why `ContextSheet` exists. V1 does not change ContextSheet, it adds a parallel sheet path for the live exercise.

Read these before you start. If anything in this prompt appears to contradict DESIGN-001's V1 scope, the design doc wins. Stop and ask rather than silently diverging.

## Ground rules

Read `AGENTS.md` and `CLAUDE.md` and follow every numbered rule. The non-negotiable ones for this change:

- **Localize every user-visible string.** Add the key to `lib/l10n/app_en.arb` and `lib/l10n/app_nb.arb` together. Norwegian: "Lukk", phase chips already exist via `ExerciseEvent.getState(localizations)`. Do not introduce new English strings into widgets.
- **CLI must stay Flutter-free.** `bin/ringdrill.dart` and anything it transitively imports must not gain a `package:flutter/*` import. All work here is widget-only and stays under `lib/views/`.
- **Mobile-safe imports.** Nothing in this change reaches `dart:html` or `package:web`.
- **Analytics consent gate.** Do not introduce new Sentry, analytics or telemetry calls.
- **Match existing Dart style.** No new lint suppressions without an inline comment explaining why.
- **Run codegen if any model changes.** This V1 should not touch `@freezed` classes or `*.g.dart`. If you find yourself reaching for one, stop — V1 is widget-only.
- **Verify before claiming green.** Run `flutter analyze` and `flutter test` before reporting a step done. `test/widget_test.dart` is the known-broken default-template smoke test; acknowledge that rather than asserting all tests pass.
- **Wide-screen is parked.** V1 shows the mini-bar only in narrow mode (`_wideScreen == false` in `MainScreen`). In wide-screen mode the mini-bar is not rendered. Do **not** invent a wide-screen layout in this loop. Add a `// V2: wide-screen mini-bar — see DESIGN-001 "Wide-screen behavior"` comment at the relevant branch.
- **No stop button on the mini-bar.** V1 mini-bar is tap-only. Stop lives inside the sheet via the existing `ExerciseControlButton` that `CoordinatorScreen` already renders.
- **`CoordinatorScreen` is reused as-is.** Do not refactor it in this loop. If you spot something off-scope worth fixing inside it, write a one-line note to `docs/prompts/DESIGN-001-V1-followups.md` (create on first use) and move on.

## Commit policy

Per the project rule [[feedback-prompts-commit-everything]]:

- **One commit per step.** Use Conventional Commits with a scope.
- **Every step ends with `git status` clean.** Stage all files listed under "Files touched" for that step. If the step touches a file not in its list, either expand the list (and explain in the commit body) or move that change to its own step.
- **Run the gates per commit.** `flutter analyze` and `flutter test` after each commit, not just at the end. If a gate fails, fix forward on the same step (`fix(<scope>): ...`) rather than amending unless it is a trivial typo.
- **Do not squash.** Each step lands its own commit so the loop driver can resume on a partial run.

Allowed types: `feat`, `fix`, `refactor`, `chore`, `docs`, `test`. Scopes that apply here: `player`, `widget`, `navigation`, `program`, `l10n`. Pick the most specific one.

## Token discipline

- Use `Grep`/`Glob` to locate, `Read` with `offset`/`limit` for sections. Avoid full reads of large files for a one-line change.
- Skip generated files. `*.freezed.dart`, `*.g.dart` and `app_localizations*.dart` regenerate.
- Do not re-read within a step. Hold what you already read in working memory.
- Resist speculative refactors. The only refactor invitation is the small extraction in Step 2 (extract a `phase_colors.dart` constant) and it is bounded.
- Tests target new behaviour only. Do not add regression coverage for code surrounding your change.

## Handoff between steps

Each step may execute in a fresh context. Treat the boundary between steps as a place to drop detail and carry forward only what the next step needs.

- **Read the handoff first.** At step start, before any `Read`/`Glob`/`Grep`, read `docs/prompts/DESIGN-001-V1-handoff.md` (create on first use).
- **Write the handoff at step end.** After committing, append a single entry:

  ```
  ## Step <N>: <short title> (<commit sha>)
  - State established: <one line>
  - Next step inputs: <one line>
  - Deferred: <one line if anything was noticed and parked; omit otherwise>
  ```

- Keep the handoff append-only. Never rewrite earlier entries.

## Loop control

The loop driver picks up the next unfinished step by inspecting `git log` against the step headings. Each step's commit subject contains the keyword in **bold** in its heading. If a step is partially landed (commit exists but verification failed), fix forward.

If a step cannot be completed because the spec is ambiguous, stop and write a paragraph to `docs/prompts/DESIGN-001-V1-blockers.md` (create if needed) explaining what was blocking and what choice the loop would have had to make. Then exit non-zero so the operator notices.

## Scope and step order

V1 implementation is 5 steps. Do them in order. Each step's heading contains the commit keyword in bold.

### Step 1. **player-sheet**: add `showDrillPlayerSheet` immersive sheet shell

A new sibling of `showRingdrillViewerSheet` that opens a fullscreen, no-handle, no-drag, no-dismissible bottom sheet and toggles immersive system chrome on Android while open.

**Files touched:**

- **New** `lib/views/widgets/drill_player_sheet.dart`. Exports `Future<T?> showDrillPlayerSheet<T>({required BuildContext context, required WidgetBuilder builder})`. Behaviour:
  - `showModalBottomSheet<T>` with `useSafeArea: false`, `isScrollControlled: true`, `enableDrag: false`, `isDismissible: false`, `backgroundColor: Theme.of(context).colorScheme.surface`, full-height constraints (`maxWidth: double.infinity`, `minHeight` = screen height).
  - Wraps the builder output in a `Column` with:
    - A top row containing a `Material` `IconButton` with `Icons.keyboard_arrow_down` (chevron-down) aligned to the start. Tooltip uses a new ARB key `drillPlayerClose` ("Close" / "Lukk"). Tapping calls `Navigator.of(sheetContext).pop()`. **No drag handle.**
    - `Expanded(child: SafeArea(top: false, child: builder(sheetContext)))` so the body fills the rest.
  - On `showModalBottomSheet` open (use the returned `Future` plus a `WidgetsBinding.instance.addPostFrameCallback` inside the builder), call `SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky)`. On `.whenComplete`, restore with `SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge)`. Guard the calls behind `defaultTargetPlatform == TargetPlatform.android` — iOS keeps standard fullscreen sheet behavior and macOS/web no-op. Use `kIsWeb` to short-circuit on web.
  - File starts with a doc comment explaining: "V1 of DESIGN-001. Used by `MainScreen` to surface the running exercise. Body is provided by the caller (today: `CoordinatorScreen`)."
- **New ARB key** in `lib/l10n/app_en.arb`: `"drillPlayerClose": "Close"` with a `@drillPlayerClose` description "Tooltip on the chevron-down close button in the DrillPlayer sheet."
- **New ARB key** in `lib/l10n/app_nb.arb`: `"drillPlayerClose": "Lukk"`.

Do not wire any caller yet. This step delivers the shell only.

`git status` clean after `make build` regenerates `app_localizations*.dart`. Verify the regenerated `lib/l10n/app_localizations.dart` includes a `drillPlayerClose` getter on both locales before committing.

Commit: `feat(player): add immersive DrillPlayer sheet shell`.

### Step 2. **mini-player**: add `DrillMiniPlayer` widget

The persistent 56 px strip that signals "an exercise is running" and opens the player sheet on tap. Tap-only in V1 (no stop button).

**Files touched:**

- **New** `lib/views/drill_player/drill_mini_player.dart`. (Use a new `drill_player/` subdirectory under `lib/views/` so the feature-first refactor in [[project-file-grouping-pending]] / ADR-0028 has a single landing spot when it lands.) The widget:
  - Subscribes to `ExerciseService().events` in `initState`, holds the latest `ExerciseEvent?` in state, cancels in `dispose`.
  - Seeds initial state from `ExerciseService().last` so it renders immediately if an exercise is already running.
  - Returns `const SizedBox.shrink()` when `ExerciseService().isStarted` is false.
  - When visible, renders (mirroring DESIGN-001 §Mini-player):
    - A 3 px tall progress strip along the top edge bound to `event.phaseProgress`. Use a `LinearProgressIndicator` or a `FractionallySizedBox` over a 3 px container.
    - A 56 px tall `InkWell` row with:
      - 36×36 colored square on the left with a phase icon (use the icon mapping in DESIGN-001 §"Color tokens for phases" — `Icons.local_fire_department`, `Icons.fact_check`, `Icons.swap_horiz`, with a neutral grey when `event.isPending`).
      - A `Chip`-style phase label using `event.getState(localizations)`.
      - "Round X / Y" using `event.currentRound` and `exercise.numberOfRounds`. When `event.isPending`, replace the phase chip with localized "STARTING IN" and show countdown to start.
      - `Expanded` with the exercise name (use `exercise.name`, ellipsize on overflow).
      - Countdown formatted as `mm:ss` from `event.remainingTime` (which is in **minutes** per `exercise_service.dart` line 16, so split to mm and ss inside the widget; reuse any existing formatter under `lib/utils/time_utils.dart` if one exists, otherwise inline it with a one-line comment).
    - The whole row taps to call a `onOpen` callback passed in by the parent. **No stop button.** Leave a `// V2: stop button — see DESIGN-001 "V1 scope" parked list` comment where it would have lived.
- **New** `lib/views/drill_player/phase_colors.dart`. Constants `kPhaseExecution = Color(0xFF1D9E75)`, `kPhaseEvaluation = Color(0xFF378ADD)`, `kPhaseRotation = Color(0xFFBA7517)`, plus a `Color colorForPhase(ExercisePhase phase)` helper that returns grey for `pending` / `done`. The Overview/observer work in V2 reuses this file, so it lives outside `drill_mini_player.dart` from day one.
- **New ARB keys** in both `lib/l10n/app_en.arb` and `lib/l10n/app_nb.arb`:
  - `drillPlayerStartingIn` ("Starting in" / "Starter om")
  - `drillPlayerRoundOf` with placeholders `{current}` and `{total}` ("Round {current} / {total}" / "Runde {current} / {total}")

Run `make build` so `app_localizations.dart` regenerates.

Commit: `feat(player): add tap-only DrillMiniPlayer widget`.

### Step 3. **navigation**: mount DrillMiniPlayer in `MainScreen`

Wire the mini-bar into the Scaffold so it appears above `bottomNavigationBar` on every tab and survives tab switches.

**Files touched:**

- `lib/views/main_screen.dart`:
  - Import `package:ringdrill/views/drill_player/drill_mini_player.dart` and `package:ringdrill/views/widgets/drill_player_sheet.dart`.
  - In the `Scaffold.bottomNavigationBar` branch, replace `bottomNavigationBar: _buildNavBar(localizations)` with a `bottomNavigationBar: _buildBottomChrome(context, localizations)` call.
  - Add a new private method `Widget? _buildBottomChrome(BuildContext context, AppLocalizations localizations)` that:
    - Returns `null` when `_wideScreen` is true (mini-bar is V2 work on wide screens; the `NavigationBar` is also null in that branch already).
    - Otherwise returns a `Column(mainAxisSize: MainAxisSize.min, children: [DrillMiniPlayer(onOpen: () => _openDrillPlayer(context)), _buildNavBar(localizations)!])`. Wrap the `DrillMiniPlayer` in `Material(elevation: 1)` so the strip casts a faint shadow against the page content above it.
  - Add a new private method `Future<void> _openDrillPlayer(BuildContext context)` that calls `showDrillPlayerSheet<void>(context: context, builder: (sheetContext) { final last = ExerciseService().last; if (last == null) return const SizedBox.shrink(); return CoordinatorScreen(uuid: last.exercise.uuid); })`. Import `CoordinatorScreen` at the top of the file.
  - Add a `// V2: render mini-bar in wide-screen layout — see DESIGN-001 "Wide-screen behavior"` comment where `_wideScreen == true` short-circuits.

Do not edit `ContextSheet`, `_DefaultContextSheetBody`, `ProgramView` or `CoordinatorScreen` in this step. That is Step 4.

Commit: `feat(navigation): mount DrillMiniPlayer above bottom nav`.

### Step 4. **program**: route live ExerciseCard tap to DrillPlayer

Reroute only the running exercise's card from the existing `ContextSheet` flow to the new `showDrillPlayerSheet`. Non-live cards keep the current behaviour.

**Files touched:**

- `lib/views/program_view.dart`:
  - Import `package:ringdrill/views/widgets/drill_player_sheet.dart` and `package:ringdrill/views/coordinator_screen.dart`.
  - In `_ProgramViewState.build`, change the `onOpen` passed to `ExerciseCard`:
    ```dart
    onOpen: () {
      final isLive = _liveEvent?.exercise.uuid == exercise.uuid;
      if (isLive) {
        showDrillPlayerSheet<void>(
          context: context,
          builder: (_) => CoordinatorScreen(uuid: exercise.uuid),
        );
      } else {
        ContextSheet.of(context).show(
          context,
          ExerciseSheetTarget(exerciseUuid: exercise.uuid),
        );
      }
    },
    ```
  - Add a comment above the branch: `// V1: live card opens the DrillPlayer sheet (DESIGN-001). All other cards keep the ContextSheet flow.`

Do **not** change `_DefaultContextSheetBody` in `lib/views/widgets/context_sheet.dart`. Deep-link entry via `routeExercise` still funnels through `ContextSheet` for non-live cards and that path must keep working.

Commit: `feat(program): open DrillPlayer for live exercise card`.

### Step 5. **test**: widget tests for V1 player surface

Add focused widget tests for the new behaviour only. Do not add regression tests for the surrounding code.

**Files touched:**

- **New** `test/views/drill_player/drill_mini_player_test.dart`:
  - Test 1: `DrillMiniPlayer` renders `SizedBox.shrink` when `ExerciseService().isStarted` is false. Use a `pumpWidget` with a `MaterialApp` and the standard localization delegates.
  - Test 2: When `ExerciseService` is started on a fixture `Exercise`, `DrillMiniPlayer` renders a tap-target showing the exercise name, the phase chip and a `mm:ss` countdown. The progress strip at the top is present.
  - Test 3: Tapping the mini-bar triggers the `onOpen` callback exactly once.
  - Test 4: No stop button is present in V1. Assert the absence of any `ExerciseControlButton` descendant inside `DrillMiniPlayer`.
- **New** `test/views/drill_player/drill_player_sheet_test.dart`:
  - Test 1: `showDrillPlayerSheet` opens a route, renders the passed-in builder body, and the close button (chevron-down) closes it.
  - Test 2: The sheet renders no drag handle (assert no descendant with `Key('ringdrill-sheet-drag-handle')`).
  - Test 3: `enableDrag` and `isDismissible` are off — a `fling` down on the body does not dismiss. (Use `tester.fling` on the sheet body and assert the route is still mounted afterward.)

Run `flutter analyze` and `flutter test`. Acknowledge `test/widget_test.dart` (the default-template smoke test) is the known-broken one and the new tests are green.

Commit: `test(player): cover DrillMiniPlayer and DrillPlayer sheet behaviour`.

## When the loop is done

After Step 5 lands clean:

1. Re-read `docs/design/exercise-player.md` "V1 scope" and verify every "In V1" bullet has a corresponding committed change.
2. Append a final entry to `docs/prompts/DESIGN-001-V1-handoff.md`:
   ```
   ## V1 complete (<final commit sha>)
   - Mini-bar mounted, immersive sheet shipping, live card rerouted, tests green.
   - V2 backlog: three-tab segmented control, Overview tab, observer variants, wide-screen layout, mini-bar stop button, drag-to-dismiss, PhaseTile color-semantics rework. See DESIGN-001 §"V1 scope" parked list.
   ```
3. Stop. Do not start V2 work in the same loop. Notify the operator that V1 is ready for manual smoke testing on a real Android device (immersive-mode behaviour) and on iOS (standard fullscreen sheet fallback).

## Out of scope, for the avoidance of doubt

The following are explicitly **not** part of V1 and should land as zero diff in this loop. If you find yourself touching any of them, stop and check the spec.

- Three-tab segmented control inside the player.
- Overview tab and its hero / NEXT / phase strip / round timeline.
- Observer player variants (team / station perspectives) and the perspective pill.
- Wide-screen three-column mini-bar and `NavigationRail` co-layout.
- Stop button on the mini-bar.
- Drag-to-dismiss on the player sheet.
- `PhaseTile` color-semantics rework.
- Any change to `_DefaultContextSheetBody` in `context_sheet.dart`.
- Any change to `CoordinatorScreen`.
- Any wide-screen rendering of the mini-bar.

All of the above are V2+ and tracked in DESIGN-001 §"V1 scope" parked list.
