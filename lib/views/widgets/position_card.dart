import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/views/map_view.dart';
import 'package:ringdrill/views/position_widget.dart';

/// Layout for [PositionCard]'s surface (docs/prompts/position-card-reflow.md):
/// [row] is a horizontal strip (station form), [card] stacks the thumbnail
/// above the coordinate bar (location form).
enum PositionFieldVariant { row, card }

/// Pure layout for a position pick surface: a live mini-map thumbnail plus a
/// single-line UTM coordinate and a trailing chevron, in either [variant].
/// The whole surface is one [InkWell] driving [onTap] — there is no separate
/// map icon button, and no [Icons.edit] in the row (ADR-0031); the chevron
/// alone signals "taps open a surface".
class PositionCard<K> extends StatelessWidget {
  const PositionCard({
    super.key,
    required this.variant,
    required this.position,
    required this.onTap,
    this.showThumbnail = true,
    this.markers = const [],
    this.overlayActions = const [],
    this.emptyLabel,
  });

  final PositionFieldVariant variant;
  final LatLng? position;
  final VoidCallback onTap;

  /// Renders a live [MapView] thumbnail centred on [position]. Only
  /// meaningful when [position] is non-null; the empty state is a plain
  /// placeholder icon regardless.
  final bool showThumbnail;

  final List<MapMarkerSpec<K>> markers;

  /// Rendered top-right over the thumbnail in a [Stack]. Empty by default;
  /// the location form uses this slot for its reverse-geocode action.
  final List<Widget> overlayActions;

  /// Shown instead of the coordinate when [position] is null.
  final String? emptyLabel;

  static const _rowHeight = 64.0;
  static const _thumbnailWidth = 76.0;
  static const _cardThumbnailHeight = 120.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: InkWell(
          onTap: onTap,
          child: variant == PositionFieldVariant.row
              ? _buildRow(theme)
              : _buildCard(theme),
        ),
      ),
    );
  }

  Widget _buildRow(ThemeData theme) {
    return SizedBox(
      height: _rowHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showThumbnail)
            SizedBox(
              width: _thumbnailWidth,
              child: _buildThumbnail(theme, pinSize: 20),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: _buildCoordinate(theme),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
            ),
            child: Icon(
              Icons.chevron_right,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showThumbnail)
          SizedBox(
            height: _cardThumbnailHeight,
            child: _buildThumbnail(theme, pinSize: 28),
          ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
          ),
          child: Row(
            children: [
              Expanded(child: _buildCoordinate(theme)),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildThumbnail(ThemeData theme, {required double pinSize}) {
    final here = position;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (here == null)
          Container(
            color: theme.colorScheme.surfaceContainerHighest,
            child: Center(
              child: Icon(
                Icons.place_outlined,
                size: pinSize,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else ...[
          IgnorePointer(
            child: MapView<K>(
              layers: MapConfig.layers,
              withToggle: false,
              withClustering: false,
              initialZoom: 15,
              initialCenter: here,
              markers: markers,
            ),
          ),
          // The thumbnail is always centred on `here`, so the pin is drawn
          // as a plain overlay rather than a geo-anchored MapMarkerSpec —
          // that would force a K value for a marker with no natural id.
          Center(
            child: Transform.translate(
              offset: Offset(0, -pinSize / 2),
              child: Icon(
                Icons.place,
                size: pinSize,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ],
        if (overlayActions.isNotEmpty)
          Positioned(
            top: 6,
            right: 6,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: overlayActions,
            ),
          ),
      ],
    );
  }

  Widget _buildCoordinate(ThemeData theme) {
    return position == null
        ? Text(
            emptyLabel ?? '',
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          )
        : PositionWidget(
            position: position,
            format: PositionFormat.utm,
            wrapped: false,
          );
  }
}
