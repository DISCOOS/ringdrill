# Pay down the coordinator-screen consolidation debts

Authoritative specs (read each before its step):

- [`docs/debts/0005-repeated-context-lookups-no-extension.md`](../debts/0005-repeated-context-lookups-no-extension.md)
- [`docs/debts/0004-duplicated-destructive-confirm-dialog.md`](../debts/0004-duplicated-destructive-confirm-dialog.md)
- [`docs/debts/0006-manual-stream-subscription-lifecycle.md`](../debts/0006-manual-stream-subscription-lifecycle.md)
- [`docs/debts/0002-coordinator-screen-not-on-expandable-tile.md`](../debts/0002-coordinator-screen-not-on-expandable-tile.md)

This prompt is work-order and gotchas only. The debt entries hold the rationale. Steps are ordered so the shared helpers (1–3) land before the large coordinator rewrite (4) consumes them. Each step is independently committable; do them in order.

## Commit discipline

- Start from a clean tree. Run `git status` first and stop if there is anything uncommitted that is not yours to touch.
- One step = one commit. Do not stack a later step's work into an earlier commit, and do not bundle unrelated changes.
- Before every commit: run `flutter analyze` (must be clean) and `flutter test` (report the result). `make build` is not needed — no `@freezed`, `json_serializable`, or `.arb` inputs change in this batch.
- Commit everything you touched for that step, including any new files. After each commit, run `git status` and confirm the tree is clean before moving on.
- Use the conventional-commits message given at the end of each step verbatim unless the diff forced a deviation, in which case adjust it to match what you actually did.

## Order of work

### Step 1 — Context extension (DEBT-0005)

Create `lib/utils/context_extensions.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';

extension RingdrillContextX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get texts => Theme.of(this).textTheme;
}
```

Additive only in this step. Do not sweep all 154/99 call sites now — that is a separate low-priority cleanup. The files in steps 2–4 adopt the extension as they are touched.

Acceptance: file exists, `flutter analyze` clean, `flutter test` reported.

Commit: `refactor: add BuildContext extension for l10n/colors/texts (DEBT-0005)`

### Step 2 — Shared destructive-confirm dialog (DEBT-0004)

Add a helper to `lib/views/dialog_widgets.dart`:

```dart
Future<bool> confirmDestructive(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async { ... }
```

It must reproduce the current look: an `AlertDialog` with a `TextButton` cancel and an `ElevatedButton` (red background, white bold label) confirm, returning `false` on cancel/dismiss and `true` on confirm. Reuse existing l10n keys (`confirm`, `cancel`, and the per-site `confirmDelete*` / label keys) — do not add new strings.

Migrate these five call sites to use it, keeping their existing localized strings:

- `lib/views/coordinator_screen.dart` `_deleteExercise` (around line 181)
- `lib/views/active_plan_actions.dart` (around line 87)
- `lib/views/actor_form_screen.dart` `_confirmDelete` (around line 182)
- `lib/views/library_view.dart` `_confirmDelete` (around line 431)
- `lib/views/exercise_form_screen.dart` (around line 361)

Use `context.l10n` from Step 1 in the touched code. Watch the `if (context.mounted)` guards after the `await` — preserve them.

Acceptance: all five dialogs route through `confirmDestructive`, behaviour unchanged, analyze clean, tests reported.

Commit: `refactor: extract shared destructive-confirm dialog (DEBT-0004)`

### Step 3 — Subscription-bag mixin (DEBT-0006)

Add `lib/utils/subscription_bag.dart` with a mixin usable on `State`:

- `void listen<T>(Stream<T> stream, void Function(T) onData)` registers a `StreamSubscription` in an internal list.
- It cancels all registered subscriptions in `dispose` and calls `super.dispose()`.
- Implement it as `mixin SubscriptionBag<T extends StatefulWidget> on State<T>` so it can override `dispose`.

Adopt it in these two files only (the coordinator picks it up in Step 4, so do not touch coordinator here):

- `lib/views/main_screen.dart` — replace the manual `_subscriptions` list (field ~463, cancel loop ~569) with the mixin.
- `lib/views/stations_view.dart` — `_programSubscription` (~60) plus the `tick` listeners; keep the `ValueNotifier` listeners managed manually if they do not fit the stream API, but move the `StreamSubscription` onto the bag.

Do not change behaviour. Keep every `if (mounted) setState(...)` guard as-is.

Acceptance: no `StreamSubscription` field or manual cancel loop remains in the two files, analyze clean, tests reported (`drill_mini_player`, shell and `roleplays_view` tests still pass).

Commit: `refactor: add SubscriptionBag mixin and adopt in main/stations (DEBT-0006)`

### Step 4 — Migrate coordinator to `ExpandableTile` + `LiveAccent` (DEBT-0002)

Rewrite the two list builders in `lib/views/coordinator_screen.dart`:

- `_buildStationList` (line 906) and `_buildTeamList` (line 1116): replace the hand-rolled `Card` + `ExpansionTile` + manual `isLive ? colorScheme.primaryContainer` styling with `ExpandableTile`, exactly as `team_screen._ExerciseSection` (`lib/views/team_screen.dart`, line 114) does it.
- Derive the accent with `LiveAccent.of(context, isLive: ...)`. Pass `accent.indicator` to `leading`, `accent.foreground`/`accent.textStyle` to the title/subtitle, and the accent to `ExpandableTile.accent`. Remove every raw `primaryContainer`/`onPrimaryContainer`/`primary`-border literal in these builders.
- Move the per-round rotation columns (team count for stations, station cell for teams) into the `title:`/`trailing:` slots. Keep `VerticalDividerWidget`, `TeamStationWidget`, `PhaseTile`, `StationPositionPanel`, `StationRoleSummary` and the `ContextSheet` tap targets unchanged.
- Replace the `ExpansibleController` pool and `_handleExpansionChange` (lines 78–115) with parent-owned `int? _expandedStationIndex` / `_expandedTeamIndex` mutex state, toggled through `ExpandableTile.expanded`/`onToggle`. Delete the controller pool, `_controllerFor`, and the controller `dispose` loops (lines 1334–1339).
- Adopt the `SubscriptionBag` mixin (Step 3) here, replacing the `_subscriptions` list (field line 66, cancel loop line 1326).
- Use `context.l10n` / `context.colors` (Step 1) in the rewritten code.

Do not change the round table, the hero card, the bottom status bar, the FAB animator, or the two-column layout logic. Keep the `ValueKey` (not `PageStorageKey`) discipline noted in the existing comments — the `SelectableText` scroll-state collision is real.

Acceptance: both lists render through `ExpandableTile`; mutex (one row open at a time) still works; live styling matches the other tabs; `ExpansibleController` is gone from the file; analyze clean; `flutter test` reported with `test/views/widgets/expandable_tile_test.dart` and any coordinator-related tests passing. Manually smoke-test: start an exercise, confirm the live row highlights and auto-context still open the right sheets in both single- and two-column layouts.

Commit: `refactor: migrate coordinator lists to ExpandableTile + LiveAccent (DEBT-0002)`

## After the batch

Update each debt entry's frontmatter to `status: resolved` with today's `resolved:` date, and flip its row in [`docs/debts/README.md`](../debts/README.md) to `Resolved`. Do this as a final small commit: `docs(debts): mark DEBT-0002/0004/0005/0006 resolved`.

DEBT-0005 stays `open` — only the extension was added, the full call-site sweep is still outstanding. Note in its entry that the helper now exists and the remaining work is mechanical adoption.

## Constraints

- View/util layer only. No changes to `lib/models/`, `lib/data/`, `lib/services/`, `bin/`, or `netlify/`.
- Keep `bin/ringdrill.dart` Flutter-free. None of the new code is reachable from it, but confirm the new `lib/utils/` files are not imported by anything the CLI pulls in.
- Web-safe imports only. No `dart:html` / `package:web` in the new util files.
- No new user-visible strings. Reuse existing l10n keys.
- Match `dart format`. No new lint suppressions without an inline comment explaining why.
- Per AGENTS.md rule 9, a clean `flutter test` run is the expected baseline now that the stale `widget_test.dart` is gone. If a test fails, fix or flag it — do not assert green.

## Expected diff scope

New: `lib/utils/context_extensions.dart`, `lib/utils/subscription_bag.dart`. Modified: `lib/views/dialog_widgets.dart`, `lib/views/coordinator_screen.dart`, `lib/views/active_plan_actions.dart`, `lib/views/actor_form_screen.dart`, `lib/views/library_view.dart`, `lib/views/exercise_form_screen.dart`, `lib/views/main_screen.dart`, `lib/views/stations_view.dart`, plus the four debt entries and `docs/debts/README.md` in the final commit. No other files should change.
