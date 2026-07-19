---
name: flutter-widget-preview
description: >-
  Render a single Flutter widget to a PNG headlessly (no browser, no device, no
  `flutter widget-preview start`) so a coding agent can visually verify layout,
  theming, light/dark, text scaling, or i18n. Use when asked to "preview",
  "show", "render", "screenshot", or "see what a widget looks like", or to
  visually check a UI change in the RingDrill app. The no-browser companion to
  Flutter's Widget Previewer.
---

# Flutter widget preview (headless)

## What this is

Flutter's Widget Previewer (https://docs.flutter.dev/tools/widget-previewer)
renders `@Preview`-annotated widgets live in Chrome. A coding agent can't watch
a Chrome tab. This skill renders a widget to a **PNG** through the Flutter test
binary instead — headless, no browser, no device — and the agent opens the PNG
to see the result.

It reuses the app's real chrome: `ringDrillTheme` / `ringDrillDarkTheme` and
`AppLocalizations`, so a capture matches the running app.

## Parts

- `../../test/support/widget_preview_harness.dart` — permanent test utility.
  `renderPreview(...)` wraps a widget in the real `MaterialApp` + theme + l10n,
  pumps it, and writes the frame via `matchesGoldenFile`. Must keep passing
  `flutter analyze`.
- `preview.template.dart` — copy to `test/preview/_preview.dart` and fill in.
- `run_preview.sh` — renders the preview test and lists the PNGs.
- `test/preview/` — where throwaway preview tests and their PNG output live.
  Gitignored, so nothing generated here is committed. The file is named
  `_preview.dart` (not `_preview_test.dart`) on purpose: a bare `flutter test`
  only collects `*_test.dart`, so the preview never runs in the normal suite —
  you invoke it by explicit path.

## When to use it

- The user asks to preview / render / screenshot / "see" a widget.
- You changed a widget and want to confirm it looks right before claiming done.
- You need to compare light vs dark, `nb` vs `en`, or a text-scale bound.

For live, interactive inspection on a real device or in Chrome, use the actual
Widget Previewer (`flutter widget-preview start`) instead — complementary.

## Use it

1. Create the throwaway test:

   ```bash
   mkdir -p test/preview
   cp skills/flutter-widget-preview/preview.template.dart test/preview/_preview.dart
   ```

2. Edit `test/preview/_preview.dart`:
   - `import` the widget under review.
   - Set `child:` to the widget expression (or reuse an existing `@Preview`
     builder so there is a single source of truth).
   - Give each capture a unique `name:`.

3. Render (no browser, exits when done):

   ```bash
   skills/flutter-widget-preview/run_preview.sh
   # or directly:
   flutter test test/preview/_preview.dart --update-goldens
   ```

4. Open `test/preview/output/<name>.png` to inspect it.

5. Delete `test/preview/_preview.dart` when done — it is throwaway.

## Worked example

The onboarding ring illustration, in light/dark and `nb`/`en`. Copy to
`test/preview/_preview.dart` and run the runner:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/views/widgets/ring_rotation_figure.dart';

import '../../test/support/widget_preview_harness.dart';

void main() {
  const canvas = Size(320, 320);
  const figure = RingRotationFigure(size: 260);

  testWidgets('ring figure — light (nb)', (tester) async {
    await renderPreview(tester,
        name: 'ring_figure_light_nb', size: canvas, child: figure);
  });

  testWidgets('ring figure — dark (nb)', (tester) async {
    await renderPreview(tester,
        name: 'ring_figure_dark_nb',
        size: canvas,
        brightness: Brightness.dark,
        child: figure);
  });

  testWidgets('ring figure — light (en)', (tester) async {
    await renderPreview(tester,
        name: 'ring_figure_light_en',
        size: canvas,
        locale: const Locale('en'),
        child: figure);
  });
}
```

## renderPreview options

`renderPreview(tester, name:, child:, ...)`:

- `size` — capture canvas in logical px (default 400x800). Unconstrained
  widgets fill this; set it to the frame you want.
- `brightness` — `Brightness.light` (default) or `.dark`.
- `textScaleFactor` — simulate Dynamic Type (the app clamps to 1.3 in prod).
- `locale` — `Locale('nb')` (default) or `Locale('en')`.
- `wrapper` — inject ancestors the widget needs (providers, `InheritedWidget`s,
  scopes); mirrors `@Preview(wrapper: ...)`.
- `settle` — set `false` for widgets with continuous animation (spinners, the
  ring illustration) to avoid a `pumpAndSettle` timeout.
- `devicePixelRatio` — bump to 2.0 for crisper text (larger file).

## Limitations

- Fonts / theme: rendering is fast and fully offline. The app's `ringDrillTheme`
  uses `google_fonts` (RobotoFlex), whose runtime fetch is slow and flaky inside
  `flutter test`, so the harness does **not** use it. It builds an equivalent
  theme from the same `RingDrillColors` — colours are identical — and renders
  text with a system font (Arial/DejaVu/Liberation). So the text font differs
  from the app, and component theming beyond the colour scheme (custom card /
  app-bar / button styling) isn't replicated. For pixel-exact typography and
  full theming, use the real `flutter widget-preview start`.
- Text painted directly via `CustomPaint`/`TextPainter` with **no explicit
  `fontFamily`** (e.g. `RingRotationFigure`) shows as filled boxes: `flutter
  test` uses a deterministic box-drawing font for unspecified families, and
  such text bypasses the theme so it can't be redirected. Text in normal
  widgets (which inherits the theme's font) and Material icons render fine.
- Native plugins and `dart:ffi` are unavailable — same constraint as the
  official web-based previewer. Guard platform code behind conditional imports.
- Renders a static frame, not an interactive session. For gestures or live
  state, use `flutter widget-preview start` or a widget test.

## Maintenance

After changing the harness, keep it clean:

```bash
flutter analyze test/support/widget_preview_harness.dart
```
