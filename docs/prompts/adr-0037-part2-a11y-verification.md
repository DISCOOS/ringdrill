# Prompt — close ADR-0037 part 2: verify text scaling at 1.3

Closes part 2 of [ADR-0037](../adrs/0037-text-sizing-and-legibility.md). The
clamp (`MediaQuery.withClampedTextScaling(maxScaleFactor: 1.3)` in
`lib/main.dart`) and the tightened baseline `textTheme` are already in. This
prompt adds the missing regression tests and confirms the tightest chrome
survives the maximum reachable scale, now that the baseline is smaller.

Because the clamp caps runtime scaling at 1.3, 1.3 is the largest a user can
ever reach. Test at 1.0 and 1.3 only. Do not test above 1.3.

No new dependency. If you reach for one, stop and flag it. Run `flutter
analyze` and `flutter test` before each commit and confirm `git status` is
clean. Use `Theme.of(context).platform` for any branching, never `dart:io`.

## Step 1 — a11y regression tests at 1.3 (report, do not fix)

Add widget tests under `test/a11y/` that pump the tightest surfaces at
`TextScaler.linear(1.0)` and `TextScaler.linear(1.3)` inside a realistic phone
viewport, and assert no `RenderFlex`/overflow error (no exception, no
yellow-black overflow stripe). Cover the surfaces ADR-0037 named as klynge B
and C:

- live-drill timeline: `lib/views/phase_tile.dart`, `lib/views/phase_widget.dart`,
  `lib/views/phase_headers.dart`
- round row: `lib/views/drill_player/mini_round_row.dart`
- drill mini-player: `lib/views/drill_player/drill_mini_player.dart`

Also cover one header surface from klynge A as a spot check: a screen using the
72px `SheetTitle`/toolbar (e.g. `station_screen` or `coordinator_screen`).

Outcome rule:
- If a surface renders clean at 1.3, keep its test. These passing tests are the
  regression guard ADR-0037 calls for.
- If a surface overflows or throws at 1.3, **do not commit a failing test and
  do not change the widget in this step.** Record the surface, the scale, and
  the overflow amount for step 2.

Commit (only passing tests): `test(a11y): cover live-drill chrome at 1.3 text scale`

## Step 2 — fix confirmed overflow, least-invasive (only if step 1 found any)

For each surface that overflowed at 1.3, apply the smallest fix that resolves
it, in this order of preference: remove a fixed `height:` around text, then
`Flexible`/`Expanded`, then `maxLines` + `TextOverflow.ellipsis`. Do not
introduce per-widget text-scale overrides. After fixing, the step 1 test for
that surface must pass and be committed alongside the fix.

If step 1 found no overflow, skip this step and say so.

Commit (per logical group): `fix(a11y): keep <surface> within bounds at 1.3 text scale`

## Step 3 — reassess the cap (report only)

With the tightened baseline, measure the headroom at 1.3 on the klynge B/C
surfaces (how much vertical slack remains). Report whether 1.3 still looks
right, whether it could be relaxed (e.g. to 1.5) for better accessibility, or
should stay. **Do not change the cap.** Raising it is a decision for the
maintainer and an ADR-0037 amendment, not part of this prompt. Just report the
finding.

## Final verification

Run `flutter analyze` and `flutter test`. Confirm `git status` is clean, each
step is its own commit, and no failing test was committed.
