// Headless widget-preview harness.
//
// Renders a single widget to a PNG offscreen so a coding agent (or CI) can
// *see* what a widget looks like without launching Chrome, a device, or
// `flutter widget-preview start`. This is the no-browser companion to
// Flutter's Widget Previewer (https://docs.flutter.dev/tools/widget-previewer):
// point the harness at the same builders you annotate with `@Preview`, or at
// any widget expression, and it captures the rendered surface as an image.
//
// Mechanism: it wraps the widget in a MaterialApp + theme + l10n, pumps it in
// the Flutter test binary, and writes the frame via `matchesGoldenFile`. Run
// the test with `--update-goldens` to (re)generate the PNG, then open the file.
//
// Fonts: the app's `ringDrillTheme` uses `google_fonts` (RobotoFlex), fetched
// over the network. Fetching inside `flutter test` is slow and flaky (and the
// cache write needs plugins that aren't available), so this harness does NOT
// use google_fonts. It builds an equivalent theme from the same
// `RingDrillColors` (identical colours) and renders text with a system font.
// The render is therefore fast and fully offline; the only difference from the
// running app is the text font. For pixel-exact typography use the real
// `flutter widget-preview start`.
//
// This file is a permanent test utility and must keep passing
// `flutter analyze`. The throwaway preview test that calls it is transient
// (see skills/flutter-widget-preview/SKILL.md).

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/theme.dart';

/// Directory (relative to a preview test in `test/preview/`) where PNGs land.
const String kPreviewOutputDir = 'output';

bool _fontsLoaded = false;

/// Loads fonts so text renders as glyphs, not the test binary's empty boxes.
///
/// Uses [WidgetTester.runAsync] because file reads and `FontLoader.load` are
/// real async that the fake-async pump loop cannot drive. No network is used.
Future<void> loadPreviewFonts(WidgetTester tester) async {
  if (_fontsLoaded) return;
  _fontsLoaded = true;

  TestWidgetsFlutterBinding.ensureInitialized();
  // Never let google_fonts hit the network from a test (slow/flaky). We don't
  // use ringDrillTheme, so this is just belt-and-suspenders for any previewed
  // widget that calls google_fonts directly.
  GoogleFonts.config.allowRuntimeFetching = false;

  await tester.runAsync(() async {
    // Bundled fonts (Material icons, any declared .ttf) so icons render.
    try {
      final manifest = await rootBundle.loadString('FontManifest.json');
      final fonts = json.decode(manifest) as List<dynamic>;
      for (final font in fonts.cast<Map<String, dynamic>>()) {
        final loader = FontLoader(font['family'] as String);
        for (final asset in (font['fonts'] as List<dynamic>)) {
          final path = (asset as Map<String, dynamic>)['asset'] as String;
          loader.addFont(rootBundle.load(path));
        }
        await loader.load();
      }
    } catch (_) {
      // No FontManifest.json; icons may be missing but layout is unaffected.
    }

    // A real text font registered under the families that unspecified text
    // resolves to (Flutter's default is "Roboto"), so labels render as glyphs
    // rather than empty boxes. Best-effort across common OS font locations.
    await _loadSystemTextFont();
  });
}

/// Family names that text with no explicit `fontFamily` may resolve to. We
/// register the same real font under all of them so default/system text paints.
const List<String> _defaultFontFamilies = <String>[
  'Roboto',
  'Arial',
  'Helvetica',
  'Helvetica Neue',
  'SF Pro Text',
  '.SF Pro Text',
  '.SF UI Text',
  '.AppleSystemUIFont',
  'sans-serif',
];

Future<void> _loadSystemTextFont() async {
  const candidates = <String>[
    '/System/Library/Fonts/Supplemental/Arial.ttf', // macOS
    '/System/Library/Fonts/Supplemental/Verdana.ttf',
    '/System/Library/Fonts/SFNS.ttf', // macOS system font
    '/Library/Fonts/Arial.ttf',
    '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', // Debian/Ubuntu
    '/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf',
    'C:/Windows/Fonts/arial.ttf', // Windows
  ];
  for (final path in candidates) {
    final file = File(path);
    if (await file.exists()) {
      final bytes = await file.readAsBytes();
      for (final family in _defaultFontFamilies) {
        final loader = FontLoader(family)
          ..addFont(Future.value(bytes.buffer.asByteData()));
        await loader.load();
      }
      stderr.writeln('[widget-preview] Loaded text font from $path');
      return;
    }
  }
  stderr.writeln(
    '[widget-preview] No system text font found; text may render as boxes. '
    'Checked: ${candidates.join(', ')}',
  );
}

/// A google-fonts-free theme matching the app's colours. Colours come from the
/// same [RingDrillColors] source of truth as [ringDrillTheme]; only the font
/// differs (default family "Roboto").
ThemeData _previewTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    fontFamily: 'Roboto',
    scaffoldBackgroundColor: isDark
        ? RingDrillColors.brandDeep
        : RingDrillColors.lightScaffold,
    colorScheme: isDark
        ? ColorScheme.fromSeed(
            seedColor: RingDrillColors.brandPath,
            primary: RingDrillColors.brandPath,
            onPrimary: const Color(0xFF00202C),
            secondary: const Color(0xFF87C7D3),
            onSecondary: const Color(0xFF00202C),
            tertiary: RingDrillColors.brandAccent,
            onTertiary: const Color(0xFF1A0F00),
            surface: RingDrillColors.darkSurface,
            onSurface: RingDrillColors.darkOnSurface,
            onSurfaceVariant: RingDrillColors.darkOnSurfaceVariant,
            error: RingDrillColors.errorDark,
            brightness: Brightness.dark,
          )
        : ColorScheme.fromSeed(
            seedColor: RingDrillColors.brandPrimary,
            primary: RingDrillColors.brandPrimary,
            onPrimary: Colors.white,
            secondary: RingDrillColors.brandSecondary,
            onSecondary: Colors.white,
            tertiary: RingDrillColors.brandAccent,
            onTertiary: const Color(0xFF1A0F00),
            surface: RingDrillColors.lightSurface,
            onSurface: RingDrillColors.lightOnSurface,
            onSurfaceVariant: RingDrillColors.lightOnSurfaceVariant,
            error: RingDrillColors.errorLight,
            brightness: Brightness.light,
          ),
  );
}

/// Renders [child] to `test/preview/$kPreviewOutputDir/$name.png`.
///
/// Call this inside a `testWidgets` body and run the test with
/// `--update-goldens`. The PNG is captured at [size] logical pixels; the whole
/// [MaterialApp] surface is captured, so [size] is effectively the "device"
/// canvas the widget is laid out in.
///
/// * [brightness] picks light vs dark theme.
/// * [textScaleFactor] simulates Dynamic Type / font scaling.
/// * [locale] drives `AppLocalizations` (`nb` or `en`).
/// * [wrapper] injects ancestors the widget needs (providers,
///   `InheritedWidget`s, scopes) — mirrors `@Preview(wrapper: ...)`.
/// * [settle] runs `pumpAndSettle`; set to `false` for widgets with
///   continuous animation (spinners, the ring illustration) to avoid a
///   settle timeout — a fixed [settleFrame] pump is used instead.
Future<void> renderPreview(
  WidgetTester tester, {
  required String name,
  required Widget child,
  Size size = const Size(400, 800),
  Brightness brightness = Brightness.light,
  double textScaleFactor = 1.0,
  Locale locale = const Locale('nb'),
  Widget Function(Widget child)? wrapper,
  bool settle = true,
  Duration settleFrame = const Duration(milliseconds: 300),
  double devicePixelRatio = 1.0,
}) async {
  await loadPreviewFonts(tester);

  tester.view.devicePixelRatio = devicePixelRatio;
  tester.view.physicalSize = size * devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final wrapped = wrapper != null ? wrapper(child) : child;

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: _previewTheme(Brightness.light),
      darkTheme: _previewTheme(Brightness.dark),
      themeMode: brightness == Brightness.dark
          ? ThemeMode.dark
          : ThemeMode.light,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          devicePixelRatio: devicePixelRatio,
          textScaler: TextScaler.linear(textScaleFactor),
          platformBrightness: brightness,
        ),
        child: Scaffold(body: Center(child: wrapped)),
      ),
    ),
  );

  if (settle) {
    try {
      await tester.pumpAndSettle();
    } on FlutterError {
      // Continuous animation never settles; capture a representative frame.
      await tester.pump(settleFrame);
    }
  } else {
    await tester.pump(settleFrame);
  }

  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('$kPreviewOutputDir/$name.png'),
  );
}
