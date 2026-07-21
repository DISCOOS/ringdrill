import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/utils/projection.dart';
import 'package:ringdrill/views/widgets/brief_theme.dart';
import 'package:ringdrill/views/widgets/code_chip.dart';

enum PositionFormat { utm, dd }

class PositionWidget extends StatelessWidget {
  const PositionWidget({
    super.key,
    this.style,
    required this.position,
    this.useETRS89 = false,
    this.format = PositionFormat.utm,
  });

  final LatLng? position;
  final TextStyle? style;

  final bool useETRS89;
  final PositionFormat format;

  @override
  Widget build(BuildContext context) {
    if (position == null) {
      return Text(AppLocalizations.of(context)!.noLocation, style: style);
    }

    return switch (format) {
      PositionFormat.utm => _build(context, _toUtm()),
      PositionFormat.dd => _build(context, _toDD()),
    };
  }

  // [useETRS89] only picks which datum the coordinate is projected against
  // (ETRS89 vs WGS84 — they differ by centimeters to a couple of meters in
  // Europe); the display never surfaces which one was used, so both render
  // identically shaped text.
  String _toUtm() {
    final utm = position!.utm(useETRS89: useETRS89);
    return "${utm.zone}${utm.band} "
        "${utm.easting.toStringAsFixed(0).padLeft(7, '0')}E "
        "${utm.northing.toStringAsFixed(0).padLeft(7, '0')}N";
  }

  String _toDD() {
    return [
      "${position!.latitude.toStringAsFixed(4)}N "
          "${position!.longitude.toStringAsFixed(4)}E",
    ].join(' ');
  }

  Widget _build(BuildContext context, String text) {
    final theme = BriefTheme.of(context);
    // Same merge order as _CodeChipNode (brief_markdown.dart): the caller's
    // own style (e.g. the Position bar's bodyMedium) as the base, the
    // brief's code typography on top so size/family match every other chip
    // regardless of where this widget sits — and `theme.code.background`/
    // `foreground`, not `theme.typography.code.backgroundColor`, which is
    // never set on that TextStyle and was silently falling back to a
    // hardcoded light color even in dark mode.
    final merged = (style ?? const TextStyle()).merge(
      theme.typography.code.copyWith(
        color: theme.code.foreground,
        backgroundColor: Colors.transparent,
      ),
    );

    return CodeChip(
      text: text,
      textStyle: merged,
      backgroundColor: theme.code.background,
      // Parentheses folded into a code span (e.g. a location's
      // `(<utm>)`) render just outside the pill in the surrounding body
      // style, not on the chip background.
      adornmentStyle: style,
    );
  }
}
