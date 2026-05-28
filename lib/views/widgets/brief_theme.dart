import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Supporting data classes
// ---------------------------------------------------------------------------

@immutable
class BriefSurfaces {
  const BriefSurfaces({
    required this.canvas,
    required this.sidebar,
    required this.appBar,
  });

  /// Main reading-column background.
  final Color canvas;

  /// TOC sidebar background.
  final Color sidebar;

  /// Slim app-bar surface. No Material primary fill.
  final Color appBar;
}

@immutable
class BriefTextColors {
  const BriefTextColors({
    required this.heading,
    required this.body,
    required this.muted,
  });

  /// All headings (H1–H4) and emphasized body.
  final Color heading;

  /// Default paragraph / body color.
  final Color body;

  /// Captions, sidebar labels, audience hint text.
  final Color muted;
}

@immutable
class BriefBorders {
  const BriefBorders({required this.subtle});

  /// App-bar bottom 1 px border, sidebar right edge, horizontal rules,
  /// table borders, inline-code chip border.
  final Color subtle;
}

@immutable
class BriefCodeStyle {
  const BriefCodeStyle({
    required this.background,
    required this.foreground,
    required this.border,
  });

  final Color background;
  final Color foreground;
  final Color border;
}

@immutable
class BriefLinkStyle {
  const BriefLinkStyle({required this.color, required this.underlineOpacity});

  /// Same as body text. Distinction from body text is the underline only.
  final Color color;

  /// Opacity of the underline decoration (0.0–1.0).
  final double underlineOpacity;
}

@immutable
class BriefAccent {
  const BriefAccent({required this.activeStripe});

  /// 2 px left stripe on the active TOC sidebar item.
  final Color activeStripe;
}

@immutable
class BriefSearchHighlight {
  const BriefSearchHighlight({required this.match, required this.current});

  /// Flat background paint for every search match in the rendered brief
  /// except the one the user is currently focused on. Painted by the
  /// `<mark>` SpanNode.
  final Color match;

  /// Stronger background paint for the search match the user is currently
  /// focused on (advanced to via the next/previous controls or Enter).
  /// Painted by the `<curr-mark>` SpanNode.
  final Color current;
}

@immutable
class BriefTypography {
  const BriefTypography({
    required this.h1,
    required this.h2,
    required this.h3,
    required this.h4,
    required this.body,
    required this.code,
  });

  final TextStyle h1;
  final TextStyle h2;
  final TextStyle h3;
  final TextStyle h4;
  final TextStyle body;
  final TextStyle code;
}

@immutable
class BriefSpacing {
  const BriefSpacing({
    required this.readingColumnMax,
    required this.gutter,
    required this.sidebarWidth,
    required this.appBarHeight,
  });

  /// Maximum width of the reading column in logical pixels.
  final double readingColumnMax;

  /// Horizontal padding on each side of the reading column.
  final double gutter;

  /// Width of the TOC sidebar on wide screens.
  final double sidebarWidth;

  /// Height of the slim app bar.
  final double appBarHeight;
}

// ---------------------------------------------------------------------------
// BriefTheme
// ---------------------------------------------------------------------------

/// Design-token set for the Brief view.
///
/// The Brief is intentionally a design island — its visual language diverges
/// from the app's Material 3 [ColorScheme] to read as a documentation
/// surface rather than a working screen. These tokens are hardcoded (not
/// derived from [ColorScheme]) so the Brief's appearance is unaffected by
/// future Material seed-color changes.
///
/// See ADR-0023 for palette values and rationale.
///
/// Usage:
/// ```dart
/// final theme = BriefTheme.of(context);
/// Container(color: theme.surfaces.canvas);
/// ```
///
/// Pattern mirrors [LiveAccent]: immutable value-class, named factories,
/// cheap to read in `build`.
@immutable
class BriefTheme {
  const BriefTheme._({
    required this.surfaces,
    required this.text,
    required this.borders,
    required this.code,
    required this.link,
    required this.accent,
    required this.searchHighlight,
    required this.typography,
    required this.spacing,
  });

  final BriefSurfaces surfaces;
  final BriefTextColors text;
  final BriefBorders borders;
  final BriefCodeStyle code;
  final BriefLinkStyle link;
  final BriefAccent accent;
  final BriefSearchHighlight searchHighlight;
  final BriefTypography typography;
  final BriefSpacing spacing;

  // ---------------------------------------------------------------------------
  // Factories
  // ---------------------------------------------------------------------------

  /// Light-mode palette. Hardcoded slate-ramp values from ADR-0023.
  factory BriefTheme.light() => const BriefTheme._(
    surfaces: BriefSurfaces(
      canvas: Color(0xFFFFFFFF),
      sidebar: Color(0xFFFAFAFA),
      appBar: Color(0xFFFFFFFF),
    ),
    text: BriefTextColors(
      heading: Color(0xFF0F172A),
      body: Color(0xFF334155),
      muted: Color(0xFF64748B),
    ),
    borders: BriefBorders(subtle: Color(0xFFE5E7EB)),
    code: BriefCodeStyle(
      // Slate-200 chip fill. Bumped up from slate-100 (#F4F4F5) because the
      // chip needs to be unambiguously visible on a white canvas; slate-100
      // blends with the background even with the rounded-Container chip
      // treatment in BriefMarkdown.
      background: Color(0xFFE4E4E7),
      foreground: Color(0xFF0F172A),
      border: Color(0xFFE5E7EB),
    ),
    link: BriefLinkStyle(color: Color(0xFF334155), underlineOpacity: 0.4),
    accent: BriefAccent(activeStripe: Color(0xFF0F172A)),
    // Search-match fills: a soft amber for non-current matches and a
    // stronger amber for the current focused match. Both keep the slate
    // body text readable on top.
    searchHighlight: BriefSearchHighlight(
      match: Color(0xFFFEF08A),
      current: Color(0xFFFACC15),
    ),
    typography: BriefTypography(
      h1: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, height: 1.20),
      h2: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, height: 1.30),
      h3: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, height: 1.40),
      h4: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.40),
      body: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, height: 1.65),
      code: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.50,
        fontFamily: 'monospace',
      ),
    ),
    spacing: BriefSpacing(
      readingColumnMax: 720,
      gutter: 24,
      sidebarWidth: 240,
      appBarHeight: 56,
    ),
  );

  /// Dark-mode palette. Hardcoded slate-ramp values from ADR-0023.
  factory BriefTheme.dark() => const BriefTheme._(
    surfaces: BriefSurfaces(
      canvas: Color(0xFF0B0F17),
      sidebar: Color(0xFF0F1623),
      appBar: Color(0xFF0B0F17),
    ),
    text: BriefTextColors(
      heading: Color(0xFFE5E7EB),
      body: Color(0xFFCBD5E1),
      muted: Color(0xFF94A3B8),
    ),
    borders: BriefBorders(subtle: Color(0xFF1F2937)),
    code: BriefCodeStyle(
      // Slate-700 chip fill. Bumped up from slate-800 (#1F2937) so the chip
      // stands out against the near-black canvas. Slate-800 is too close to
      // the #0B0F17 canvas to read as a distinct chip.
      background: Color(0xFF374151),
      foreground: Color(0xFFE5E7EB),
      border: Color(0xFF374151),
    ),
    link: BriefLinkStyle(color: Color(0xFFCBD5E1), underlineOpacity: 0.6),
    accent: BriefAccent(activeStripe: Color(0xFFE5E7EB)),
    // Darker amber on dark canvas so the search match is unmistakably
    // visible without bleaching the surrounding text into white.
    searchHighlight: BriefSearchHighlight(
      match: Color(0xFFCA8A04),
      current: Color(0xFFEAB308),
    ),
    typography: BriefTypography(
      h1: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, height: 1.20),
      h2: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, height: 1.30),
      h3: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, height: 1.40),
      h4: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.40),
      body: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, height: 1.65),
      code: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.50,
        fontFamily: 'monospace',
      ),
    ),
    spacing: BriefSpacing(
      readingColumnMax: 720,
      gutter: 24,
      sidebarWidth: 240,
      appBarHeight: 56,
    ),
  );

  /// Resolves a [BriefTheme] for the current platform brightness.
  ///
  /// Pass [override] to force a specific brightness (useful in tests and
  /// in the `BriefTheme_test` widget test).
  factory BriefTheme.of(BuildContext context, {Brightness? override}) {
    final brightness = override ?? Theme.of(context).brightness;
    return brightness == Brightness.dark
        ? BriefTheme.dark()
        : BriefTheme.light();
  }
}
