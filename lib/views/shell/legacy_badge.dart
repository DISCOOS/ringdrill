import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/views/shell/migration_banner.dart';
import 'package:ringdrill/web/legacy_host_web.dart'
    if (dart.library.io) 'package:ringdrill/web/legacy_host_stub.dart';

/// Fixed ribbon colours, independent of the active [ColorScheme], so the
/// marker looks identical in light and dark mode.
const Color _kRibbonColor = Color(0xFFB3261E);
const Color _kRibbonTextColor = Color(0xFFFFFFFF);

/// Persistent, non-dismissable marker shown whenever the PWA runs on the
/// legacy apex origin (`ringdrill.app`). Styled like Flutter's own debug
/// banner — a diagonal ribbon pinned to the top-right corner — so it reads
/// instantly as "this build is not the real thing". Unlike [MigrationBanner]
/// (a dismissable call-to-action) this marker is ambient.
///
/// The ribbon is painted by Flutter's [Banner] with locked colours (red
/// band, white text) so it matches the debug-banner look in both themes.
///
/// Tapping the ribbon does not navigate away: it bumps
/// [migrationBannerForceShowTick] so the [MigrationBanner] re-surfaces even
/// if the user dismissed it. The banner's "Read more" button then opens the
/// full explainer. See ADR-0042 "Persistent legacy marker".
///
/// Gated on [isLegacyHost], so it inherits the same controls as the rest of
/// the migration UI: hidden in production before Phase 2, suppressed by
/// `MIGRATION_DISABLED`, forced on in local dev by
/// `RINGDRILL_FORCE_LEGACY_HOST`. On native builds the stub returns false,
/// so the marker is web-only for free. Mutually exclusive with the
/// [MigrationBanner] — hidden while the banner is on screen.
class LegacyBadge extends StatelessWidget {
  const LegacyBadge({
    super.key,
    @visibleForTesting this.isLegacyHostOverride,
    @visibleForTesting this.onTapOverride,
  });

  final bool Function()? isLegacyHostOverride;

  /// If set, replaces the force-show tick bump in tests.
  final VoidCallback? onTapOverride;

  /// Side of the square corner box the ribbon is painted into.
  static const double _size = 96;

  @override
  Widget build(BuildContext context) {
    final isLegacy = isLegacyHostOverride?.call() ?? isLegacyHost();
    if (!isLegacy) return const SizedBox.shrink();

    // Mutually exclusive with the MigrationBanner: while the banner is on
    // screen it already signals legacy loudly, so the ambient ribbon steps
    // aside. Tapping the ribbon re-surfaces the banner, which then hides
    // the ribbon again.
    return ValueListenableBuilder<bool>(
      valueListenable: migrationBannerVisible,
      builder: (context, bannerVisible, _) {
        if (bannerVisible) return const SizedBox.shrink();
        return _buildRibbon(context);
      },
    );
  }

  Widget _buildRibbon(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return SizedBox(
      key: const Key('legacyRibbon'),
      width: _size,
      height: _size,
      child: Stack(
        children: [
          // The ribbon itself is painted by Flutter's own [Banner] so it
          // matches the debug-banner look exactly. It does not receive taps.
          Positioned.fill(
            child: IgnorePointer(
              child: Banner(
                message: l10n.legacyBadgeLabel,
                location: BannerLocation.topEnd,
                color: _kRibbonColor,
                textStyle: const TextStyle(
                  color: _kRibbonTextColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                  height: 1.0,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
          // Tap target confined to the ribbon triangle. [ClipPath] also
          // clips hit-testing (RenderClipPath.hitTest checks the clip), so
          // taps below the diagonal — e.g. the map's layer/filter buttons
          // that sit just under this corner — pass straight through instead
          // of being swallowed by a full-box gesture detector.
          Positioned.fill(
            child: ClipPath(
              clipper: _RibbonCornerClipper(),
              child: Tooltip(
                message: l10n.legacyBadgeTooltip,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (onTapOverride != null) {
                      onTapOverride!();
                      return;
                    }
                    migrationBannerForceShowTick.value++;
                  },
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Clips the tap target to the top-right corner triangle covering the
/// ribbon, so taps outside it pass through to whatever is underneath.
class _RibbonCornerClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => Path()
    ..moveTo(size.width * 0.15, 0)
    ..lineTo(size.width, 0)
    ..lineTo(size.width, size.height * 0.5)
    ..close();

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
