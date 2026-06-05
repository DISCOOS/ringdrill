# Prompt — Dynamic Type step 5 + measurement (ADR-0037)

Implements the clamp from [ADR-0037](docs/adrs/0037-text-sizing-and-legibility.md) and
then measures, so we can decide on per-widget fixes afterwards. Do not fix any
fixed-height widget in this prompt. The point of the measurement part is to
learn what still breaks at 1.3, not to fix it.

No new dependency. If you reach for one, stop and flag it. Run `flutter
analyze` and `flutter test` before each commit and confirm `git status` is
clean. No new user-visible strings are expected.

## Part 1 — Clamp the text scale (one commit)

In `lib/main.dart`, wrap the app content of the main `MaterialApp.router` (the
one in `RingDrillApp`, not the `_BootFailureApp` fallback) so the text scale is
capped at 1.3 while the lower bound stays at the system value. Use the
`builder` callback:

```dart
builder: (context, child) => MediaQuery.withClampedTextScaling(
  maxScaleFactor: 1.3,
  child: child!,
),
```

If a `builder` already exists, compose with it rather than replacing it. Only
the maximum is capped. Do not set a minimum.

Commit: `feat(a11y): clamp text scaling to 1.3 app-wide (ADR-0037)`

## Part 2 — Measure the live-drill chrome at 1.3 (report, do not fix)

Add widget tests under `test/a11y/` that pump the tightest surfaces from the
Dynamic Type review at `TextScaler.linear(1.3)` inside a sized viewport, and
assert there is no `RenderFlex`/overflow error (no exception, no yellow-black
overflow). Cover at least:

- the live-drill timeline widgets: `lib/views/phase_tile.dart`,
  `lib/views/phase_widget.dart`, `lib/views/phase_headers.dart`
- the round row: `lib/views/drill_player/mini_round_row.dart`
- the drill mini-player: `lib/views/drill_player/drill_mini_player.dart`

Pump each at scales 1.0 and 1.3.

Outcome rule:
- If a surface renders clean at 1.3, keep its test. These passing tests are the
  regression guard for the later fix step.
- If a surface overflows or throws at 1.3, **do not commit a failing test and
  do not change the widget.** Instead, write down exactly which surface, at
  which scale, with the overflow amount, in the commit body or PR notes.

Commit (only the passing tests): `test(a11y): cover live-drill chrome at 1.3 text scale`

## Report back

List which of the five surfaces survive 1.3 and which overflow, with numbers.
That list scopes the follow-up fix step. Do not start the fixes here.

## Final verification

Run `flutter analyze` and `flutter test`. Confirm `git status` is clean and
that Part 1 and the passing Part 2 tests are separate commits.
