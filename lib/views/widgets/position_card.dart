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
    if (variant == PositionFieldVariant.card) {
      return PositionCardShell(
        onTap: onTap,
        thumbnail: showThumbnail ? _buildMapContent(theme, pinSize: 28) : null,
        thumbnailHeight: _cardThumbnailHeight,
        overlayActions: overlayActions,
        barChild: _buildCoordinate(theme),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: InkWell(onTap: onTap, child: _buildRow(theme)),
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
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildMapContent(theme, pinSize: 20),
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
              ),
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

  /// Just the map/placeholder content — no overlay actions. [_buildRow]
  /// wraps this in its own `Stack` (it isn't built on [PositionCardShell]);
  /// the `card` variant hands it to the shell's `thumbnail` slot, which
  /// applies `overlayActions` itself.
  Widget _buildMapContent(ThemeData theme, {required double pinSize}) {
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

/// Shared `card` shell (docs/prompts/position-panel-read-alignment.md):
/// an optional thumbnail slot (with its own top-right [overlayActions]
/// stack) above a coordinate bar (optional leading [barLabel], a
/// [barChild] slot, a trailing widget), the whole surface wrapped in one
/// [InkWell] driving [onTap].
///
/// Used by [PositionCard]'s `card` variant (the pick surfaces) and by
/// `StationPositionPanel`/`RolePositionPanel` (the read-only detail
/// panels) — call sites sharing one layout instead of near-identical
/// `Column`s.
class PositionCardShell extends StatelessWidget {
  const PositionCardShell({
    super.key,
    required this.onTap,
    this.thumbnail,
    this.thumbnailHeight = 120.0,
    this.overlayActions = const [],
    this.barLabel,
    required this.barChild,
    this.barTrailing,
    this.asCard = true,
  });

  final VoidCallback onTap;

  /// The mini-map (or placeholder) content. Null omits the whole
  /// thumbnail section — and with it, [overlayActions], which have
  /// nowhere to sit without a thumbnail to float over.
  final Widget? thumbnail;
  final double thumbnailHeight;

  /// Rendered top-right over [thumbnail] in a [Stack]. Ignored when
  /// [thumbnail] is null.
  final List<Widget> overlayActions;

  /// Optional leading label in the coordinate bar (e.g. "Position" on the
  /// read-only panels; the pick surfaces omit it — their label sits above
  /// the whole field instead).
  final Widget? barLabel;

  final Widget barChild;

  /// Defaults to a muted `chevron_right` — every call site uses the same
  /// "tap opens a surface" affordance (ADR-0031).
  final Widget? barTrailing;

  /// Whether this shell draws its own [Card] (elevation, background,
  /// rounded shape from the ambient `cardTheme`). Set to `false` when the
  /// caller already sits inside another card-like surface (e.g. an
  /// `ExpandableTile`, itself a `Card`) — otherwise the map preview nests
  /// a card inside a card. `false` still rounds the thumbnail's corners
  /// via [ClipRRect] and keeps the divider between the thumbnail and the
  /// coordinate bar; it just skips the extra background/elevation.
  final bool asCard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (thumbnail != null)
          SizedBox(
            height: thumbnailHeight,
            child: Stack(
              fit: StackFit.expand,
              children: [
                thumbnail!,
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
            ),
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
              if (barLabel != null) ...[barLabel!, const SizedBox(width: 8)],
              Expanded(child: barChild),
              const SizedBox(width: 8),
              barTrailing ??
                  Icon(
                    Icons.chevron_right,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
            ],
          ),
        ),
      ],
    );

    // asCard: a plain Card picks up the ambient cardTheme's
    // shape/elevation/shadow, so this reads as the same kind of card as
    // everything else in the app instead of a bespoke boxed frame. When
    // the caller already provides that card (asCard: false), skip it —
    // otherwise the map preview nests a card inside a card — and just
    // round the thumbnail's own corners.
    return asCard
        ? Card(
            margin: EdgeInsets.zero,
            child: InkWell(onTap: onTap, child: content),
          )
        : ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: InkWell(onTap: onTap, child: content),
          );
  }
}
