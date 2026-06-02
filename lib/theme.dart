import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Unified header height for the main shell AppBar when the master/detail
/// layout is active. Matches the `toolbarHeight: 72` used by the detail
/// screens (`StationScreen`, `TeamExerciseScreen`, `RolePlayScreen`,
/// `CoordinatorScreen`) so the first content row of master and detail
/// align vertically. Compact (no-rail) layout keeps the default
/// `kToolbarHeight = 56` to preserve vertical space on phones.
const double kRingdrillHeaderHeight = 72.0;

// ---------------------------------------------------------------------------
// RingDrill brand palette
// ---------------------------------------------------------------------------
//
// The palette is derived from the v2 app icon
// (`assets/images/ringdrill-v2-1254x1254.png`):
//
//   * `#002C3F` — deep teal background (the canvas behind the ring)
//   * `#00536E` — one shade above the background, used as the primary brand
//                  fill in light mode where the icon background is too heavy
//   * `#1F7B8A` — the inactive station markers on the ring
//   * `#5FB1C0` — the dashed station-path between markers (also used as the
//                  primary in dark mode where we need a lighter token)
//   * `#F0982C` — the active station marker (tertiary / CTA / live-state)
//   * `#C8D0D4` / `#8E9AA1` — the silver ring itself (cards / dividers)
//
// `error` is intentionally a real red rather than the previous amber, so it
// stops colliding visually with the orange active-station accent.
//
// The brief view has its own palette per ADR-0023; nothing here flows into
// `BriefTheme`.
// ---------------------------------------------------------------------------

class RingDrillColors {
  RingDrillColors._();

  static const Color brandDeep = Color(0xFF002C3F);
  static const Color brandPrimary = Color(0xFF00536E);
  static const Color brandSecondary = Color(0xFF1F7B8A);
  static const Color brandAccent = Color(0xFFF0982C);
  static const Color brandPath = Color(0xFF5FB1C0);

  // Light palette stays in the brand's cool blue-teal family — lifted to
  // high luminance values so the page reads as airy without drifting
  // into warm cream or pure white. Same hue family as `brandDeep` /
  // `brandPrimary` / `brandPath`, just up the lightness scale.
  static const Color lightScaffold = Color(0xFFE9EFF1);
  static const Color lightSurface = Color(0xFFD5DEE2);
  static const Color lightOnSurface = Color(0xFF0B1F2A);
  static const Color lightOnSurfaceVariant = Color(0xFF3E5560);

  static const Color darkSurface = Color(0xFF073F54);
  static const Color darkOnSurface = Color(0xFFE6EEF2);
  static const Color darkOnSurfaceVariant = Color(0xFF9FB4BD);

  /// Sidebar tone for the NavigationRail body in the wide master/detail
  /// layout. Sits one step away from `*Scaffold` so the rail reads as a
  /// distinct sidebar surface while staying compatible with the active
  /// `masterAccent*` indicator pill that extends from the selected tab
  /// into the master pane.
  ///
  /// Light: cool blue-gray, between `lightSurface` and `lightScaffold`.
  /// Dark: between `brandDeep` (scaffold #002C3F) and `darkSurface` (#073F54).
  static const Color panelLight = Color(0xFFDDE5E8);
  static const Color panelDark = Color(0xFF053547);

  /// Active-surface tone shared by the NavigationRail selection indicator,
  /// the master pane background and the master AppBar in the wide
  /// master/detail layout. The selected tab's indicator pill visually
  /// "extends" into the master so the active section reads as one block.
  ///
  /// Light: cool blue-gray, one tonal step darker than [panelLight] but
  /// in the same brand-teal hue family. Requires dark foreground on the
  /// AppBar — the shell flips `appBarTheme.foregroundColor` in light
  /// hasRail mode.
  /// Dark: subtle lift from [panelDark] toward [brandPrimary]. White
  /// foreground still works, no flip needed.
  static const Color masterAccentLight = Color(0xFFC5D1D6);
  static const Color masterAccentDark = Color(0xFF093E55);

  /// Background for a selected row in the master list, sitting against
  /// the `masterAccent*` pane. Tuned to pop clearly from the regular card
  /// (`*Surface`) so the user can see which row is active in the detail
  /// pane. Paired with a thick `primary`-coloured border for visibility.
  ///
  /// Light: pure white — brighter than the warm eggshell `lightSurface`
  /// so the selection visibly lifts off the page.
  /// Dark: bolder lifted teal — clearly brighter than `darkSurface`
  /// (#073F54).
  static const Color selectedRowLight = Color(0xFFFFFFFF);
  static const Color selectedRowDark = Color(0xFF1A6885);

  /// Background tones for the live/running exercise card. Paired with a
  /// thick `brandAccent` (orange) border so the running state reads as a
  /// distinct "warm" accent against the cool teal surrounding cards.
  ///
  /// Light: warm peach — clearly orange-tinted on the eggshell page.
  /// Dark: deep warm brown — orange-tinted against the dark teal page.
  static const Color liveBackgroundLight = Color(0xFFFFE0B5);
  static const Color liveBackgroundDark = Color(0xFF4A3010);

  static const Color errorLight = Color(0xFFB3261E);
  static const Color errorDark = Color(0xFFFF7A45);

  // Disabled states.
  //
  // The default Material 3 disabled treatment is `onSurface.withOpacity(0.38)`.
  // In our light theme `onSurface` is a near-black teal, which becomes
  // invisible when the disabled control sits on top of the dark AppBar
  // (`brandDeep`). The tokens below are pre-blended mid-tones that stay
  // readable on both light surfaces and the dark brand surfaces.

  /// Foreground for disabled icons / labels that may sit on the dark
  /// `brandDeep` AppBar in either theme. Tuned to read clearly as "muted"
  /// next to white enabled icons. Contrast against `#002C3F` is ~4.2:1
  /// (icon-readable per WCAG AA non-text), while contrast against white
  /// enabled icons is ~3.3:1 so the disabled state is visibly different
  /// rather than just dimmer.
  static const Color disabledOnDark = Color(0xFF5E7C8B);

  /// Foreground for disabled text / icons on light surfaces in light mode.
  static const Color disabledOnLight = Color(0xFF6E8390);

  /// Background fill for disabled filled buttons in light mode.
  static const Color disabledFillLight = Color(0xFFCBD5DA);

  /// Background fill for disabled filled buttons in dark mode.
  static const Color disabledFillDark = Color(0xFF1F4E63);
}

/// Wrap each [AppBar.actions] item in a local [IconButtonTheme] so the
/// disabled-foreground override actually reaches the icons.
///
/// Why this exists: Material 3 [AppBar] internally wraps its `actions` in
/// its own [IconButtonTheme] that copies `appBarTheme.foregroundColor` (and
/// `actionsIconTheme.color`) into an [IconButton.styleFrom] with only the
/// enabled `foregroundColor` set. Because [InheritedTheme.of] returns only
/// the closest match, that local wrap fully shadows any global
/// `theme.iconButtonTheme`. The disabled state therefore always falls back
/// to the M3 default `colorScheme.onSurface.withOpacity(0.38)` — invisible
/// on the dark `brandDeep` AppBar (dark mode) and now invisible on the
/// light `lightScaffold` AppBar (light mode) as well.
///
/// The fix recommended by the Flutter team (issue #117918, PR #118216) is
/// to wrap each action in a *closer* `IconButtonTheme`. This helper does
/// exactly that, picking the enabled and disabled tones from the active
/// theme brightness so the same call works in both modes.
///
/// Usage:
/// ```dart
/// appBar: AppBar(
///   title: Text(...),
///   actions: rdAppBarActions(context, [
///     IconButton(icon: ..., onPressed: ...),
///     IconButton(icon: ..., onPressed: null), // disabled stays visible
///   ]),
/// ),
/// ```
List<Widget>? rdAppBarActions(BuildContext context, List<Widget>? actions) {
  if (actions == null) return null;
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final enabledForeground = isDark
      ? Colors.white
      : RingDrillColors.lightOnSurface;
  final disabledForeground = isDark
      ? RingDrillColors.disabledOnDark
      : RingDrillColors.disabledOnLight;
  return actions
      .map<Widget>(
        (action) => IconButtonTheme(
          data: IconButtonThemeData(
            style: IconButton.styleFrom(
              foregroundColor: enabledForeground,
              disabledForegroundColor: disabledForeground,
            ),
          ),
          child: action,
        ),
      )
      .toList(growable: false);
}

final ThemeData ringDrillTheme = ThemeData(
  brightness: Brightness.light,
  scaffoldBackgroundColor: RingDrillColors.lightScaffold,
  primaryColor: RingDrillColors.brandPrimary,
  colorScheme: ColorScheme.fromSeed(
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
  textTheme: GoogleFonts.robotoFlexTextTheme(),
  // ThemeData.disabledColor is used by older non-M3 widgets and as a
  // baseline; M3 IconButton has its own resolution (see [rdAppBarActions]).
  disabledColor: RingDrillColors.disabledOnLight,
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: RingDrillColors.brandPrimary,
      foregroundColor: Colors.white,
      disabledBackgroundColor: RingDrillColors.disabledFillLight,
      disabledForegroundColor: RingDrillColors.disabledOnLight,
      textStyle: const TextStyle(fontWeight: FontWeight.w600),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  ),
  appBarTheme: const AppBarTheme(
    // Light mode mirrors dark's "AppBar merges with detail body" pattern:
    // detail AppBar background equals `lightScaffold` (same as the
    // detail Scaffold body) so there is no visible seam between header
    // and content. The master AppBar overrides this back to its accent
    // tone in the wide layout via `MainScreen._buildAppBar`. The
    // disabled state for action buttons is handled per call via
    // [rdAppBarActions].
    backgroundColor: RingDrillColors.lightScaffold,
    foregroundColor: RingDrillColors.lightOnSurface,
    elevation: 0,
    // Left-align titles app-wide. Without this, iOS centers AppBar titles
    // while Android left-aligns them, so the layout differs per platform.
    centerTitle: false,
  ),
  cardTheme: const CardThemeData(
    color: RingDrillColors.lightSurface,
    surfaceTintColor: Colors.transparent,
    elevation: 2,
    shadowColor: Colors.black54,
    margin: EdgeInsets.all(12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(8)),
    ),
    clipBehavior: Clip.antiAlias,
  ),
);

final ThemeData ringDrillDarkTheme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: RingDrillColors.brandDeep,
  primaryColor: RingDrillColors.brandPath,
  colorScheme: ColorScheme.fromSeed(
    seedColor: RingDrillColors.brandPath,
    primary: RingDrillColors.brandPath,
    primaryFixed: RingDrillColors.brandPrimary,
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
  ),
  textTheme: GoogleFonts.robotoFlexTextTheme(ThemeData.dark().textTheme),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: RingDrillColors.brandPath,
      foregroundColor: const Color(0xFF00202C),
      textStyle: const TextStyle(fontWeight: FontWeight.w600),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: RingDrillColors.brandDeep,
    foregroundColor: Colors.white,
    elevation: 0,
    // Left-align titles app-wide (iOS centers by default).
    centerTitle: false,
  ),
  cardTheme: const CardThemeData(
    color: RingDrillColors.darkSurface,
    surfaceTintColor: Colors.transparent,
    elevation: 2,
    shadowColor: Colors.black54,
    margin: EdgeInsets.all(12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(8)),
    ),
    clipBehavior: Clip.antiAlias,
  ),
);
