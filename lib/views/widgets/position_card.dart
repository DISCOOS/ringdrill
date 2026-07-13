import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/views/map_view.dart';
import 'package:ringdrill/views/position_widget.dart';
import 'package:ringdrill/views/widgets/collapse_chevron.dart';
import 'package:ringdrill/views/widgets/collapsible_section_store.dart';

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
        ? Text(emptyLabel ?? '', overflow: TextOverflow.ellipsis, maxLines: 1)
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
class PositionCardShell extends StatefulWidget {
  const PositionCardShell({
    super.key,
    required this.onTap,
    this.thumbnail,
    this.thumbnailHeight = 120.0,
    this.overlayActions = const [],
    this.legend,
    this.barLabel,
    required this.barChild,
    this.barTrailing,
    this.asCard = true,
    this.fillHeight = false,
    this.sectionId,
  });

  final VoidCallback onTap;

  /// The mini-map (or placeholder) content. Null omits the whole
  /// thumbnail section — and with it, [overlayActions] and [legend], which
  /// have nowhere to sit without a thumbnail above them.
  final Widget? thumbnail;
  final double thumbnailHeight;

  /// When true, [thumbnail] flexes (`Expanded`) to fill all remaining
  /// height instead of the fixed [thumbnailHeight] — [legend] and the
  /// coordinate bar keep their intrinsic height and end up pinned at the
  /// very bottom of whatever height an ancestor gives this shell, with no
  /// gap below the map. Used by the Post/Spill detail viewers' expanded
  /// right pane (`WideDetailMapSplit`), which already gives this shell the
  /// pane's full height via a stretched `Row` — the default (`false`)
  /// keeps every other call site's wrap-content sizing unchanged. Ignored
  /// (falls back to [thumbnailHeight]) when there is no [thumbnail] to
  /// fill, so a future collapsed (bar-only) variant of this shell still
  /// shrinks to its content instead of being forced to the ancestor's full
  /// height.
  final bool fillHeight;

  /// Rendered top-right over [thumbnail] in a [Stack]. Ignored when
  /// [thumbnail] is null.
  final List<Widget> overlayActions;

  /// A full-width strip between [thumbnail] and the coordinate bar — the
  /// domain-agnostic slot for a map legend (DESIGN-010's Post/Spill
  /// viewers: a wrapping row of colored dots + labels for the scenario
  /// markers, ADR-0020), the same "extra content the caller owns, the
  /// shell just reserves the spot" pattern as [overlayActions]. Ignored
  /// when [thumbnail] is null (nothing to sit a legend under).
  final Widget? legend;

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

  /// Stable identifier for a persisted collapsed preference (DESIGN-010
  /// follow-up: collapsible-section-cards, mockup
  /// `docs/design/mockups/collapsible-position-card.html`). Null (every
  /// call site but the Post/Spill detail panels) keeps this shell exactly
  /// as it always was: no chevron, always expanded. Non-null shows a
  /// leading [CollapseChevron] on the coordinate bar that hides
  /// [thumbnail]/[overlayActions]/[legend] — the coordinate bar itself
  /// (and [onTap]) is unaffected, since it is the always-visible part.
  final String? sectionId;

  @override
  State<PositionCardShell> createState() => _PositionCardShellState();
}

class _PositionCardShellState extends State<PositionCardShell> {
  bool _collapsed = false;

  @override
  void initState() {
    super.initState();
    final sectionId = widget.sectionId;
    if (sectionId != null) unawaited(_loadCollapsed(sectionId));
  }

  Future<void> _loadCollapsed(String sectionId) async {
    final stored = await CollapsibleSectionStore.isCollapsed(sectionId);
    if (!mounted || stored == _collapsed) return;
    setState(() => _collapsed = stored);
  }

  void _toggle() {
    final sectionId = widget.sectionId;
    if (sectionId == null) return;
    final next = !_collapsed;
    setState(() => _collapsed = next);
    unawaited(CollapsibleSectionStore.setCollapsed(sectionId, next));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final collapsible = widget.sectionId != null;
    // Collapsed: treat the shell as if it had no thumbnail at all — the
    // existing `fill`/`mainAxisSize` logic below then shrinks the whole
    // shell to just the coordinate bar on its own, including inside the
    // Post/Spill expanded right pane's `fillHeight` mode (no separate
    // "collapsed height" case to keep in sync with that one).
    final thumbnail = collapsible && _collapsed ? null : widget.thumbnail;
    final fill = widget.fillHeight && thumbnail != null;
    final thumbnailStack = thumbnail == null
        ? null
        : Stack(
            fit: StackFit.expand,
            children: [
              thumbnail,
              if (widget.overlayActions.isNotEmpty)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: widget.overlayActions,
                  ),
                ),
            ],
          );
    final content = Column(
      // `max` in fill mode: the ancestor (the expanded right pane's
      // stretched Row) already gives this shell a tight height, and the
      // Column must claim all of it for the Expanded thumbnail below to
      // have anything to flex into. `min` otherwise — every other call
      // site (and a collapsed shell) wraps this shell content-height, not
      // pane-height.
      mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (thumbnailStack != null)
          fill
              ? Expanded(child: thumbnailStack)
              : SizedBox(height: widget.thumbnailHeight, child: thumbnailStack),
        if (thumbnail != null && widget.legend != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
            ),
            child: widget.legend!,
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
              if (collapsible) ...[
                CollapseChevron(collapsed: _collapsed, onTap: _toggle),
                const SizedBox(width: 8),
              ],
              if (widget.barLabel != null) ...[
                widget.barLabel!,
                const SizedBox(width: 8),
              ],
              Expanded(child: widget.barChild),
              const SizedBox(width: 8),
              widget.barTrailing ??
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
    return widget.asCard
        ? Card(
            margin: EdgeInsets.zero,
            child: InkWell(onTap: widget.onTap, child: content),
          )
        : ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: InkWell(onTap: widget.onTap, child: content),
          );
  }
}
