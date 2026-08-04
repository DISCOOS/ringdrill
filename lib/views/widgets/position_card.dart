import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/views/map_view.dart';
import 'package:ringdrill/views/position_widget.dart';
import 'package:ringdrill/views/widgets/collapse_chevron.dart';
import 'package:ringdrill/views/widgets/collapsible_section_mixin.dart';
import 'package:ringdrill/views/widgets/map_camera_link.dart';

/// Layout for [PositionCard]'s surface (docs/prompts/position-card-reflow.md):
/// [row] is a horizontal strip (station form), [card] stacks the thumbnail
/// above the coordinate bar (location form).
enum PositionFieldVariant { row, card }

/// Pure layout for a position pick surface: a live mini-map thumbnail plus a
/// single-line UTM coordinate, in either [variant]. The whole surface is one
/// [InkWell] driving [onTap] — there is no separate map icon button, and no
/// [Icons.edit] in the row (ADR-0031).
class PositionCard<K> extends StatelessWidget {
  const PositionCard({
    super.key,
    required this.variant,
    required this.position,
    this.showThumbnail = true,
    this.markers = const [],
    this.overlayActions = const [],
    this.emptyLabel,
    this.barLabel,
    this.barLeading,
    this.barTrailing,
    this.elevation = 1,
    this.onTap,
  });

  final LatLng? position;
  final double elevation;
  final VoidCallback? onTap;
  final PositionFieldVariant variant;

  /// Optional label widget in the `card` variant's bar. Ignored by `row`.
  final Widget? barLabel;

  /// Optional leading widget in the `card` variant's bar. Ignored by `row`.
  final Widget? barLeading;

  /// Optional trailing widget in the `card` variant's bar. Ignored by `row`.
  final Widget? barTrailing;

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
        barLabel: barLabel,
        barLeading: barLeading,
        barTrailing: barTrailing,
        barChild: _buildCoordinate(theme),
        overlayActions: overlayActions,
        thumbnailHeight: _cardThumbnailHeight,
        thumbnail: showThumbnail ? _buildMapContent(theme, pinSize: 28) : null,
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
        : PositionWidget(position: position, format: PositionFormat.utm);
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
    this.thumbnail,
    this.thumbnailHeight = 120.0,
    this.overlayActions = const [],
    this.legend,
    this.barLabel,
    this.barTrailing,
    this.barLeading,
    this.elevation = 1,
    required this.barChild,
    this.asCard = true,
    this.fillHeight = false,
    this.sectionId,
    this.onTap,
  });

  final double elevation;

  final VoidCallback? onTap;

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

  /// Optional leading widget in the `card` variant's bar. Ignored by `row`.
  final Widget? barLeading;

  /// Optional trailing widget in the `card` variant's bar. Ignored by `row`.
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
  /// follow-up: collapsible-position-card, mockup
  /// `docs/design/mockups/collapsible-position-card.html`). Null keeps this
  /// shell exactly as it always was: a plain [barLabel], no icon/title, no
  /// chevron, always expanded.
  ///
  final String? sectionId;

  @override
  State<PositionCardShell> createState() => _PositionCardShellState();
}

class _PositionCardShellState extends State<PositionCardShell>
    with SingleTickerProviderStateMixin, CollapsibleSectionStateMixin {
  /// Published to this shell's subtree so the [PositionCardShell.legend] strip
  /// can drive the camera of the map in [PositionCardShell.thumbnail]. Held in
  /// the state, not rebuilt in `build`, so the map stays attached across
  /// rebuilds.
  final MapCameraLink _cameraLink = MapCameraLink();

  @override
  void initState() {
    super.initState();
    initCollapse(widget.sectionId);
  }

  void _toggle() {
    final sectionId = widget.sectionId;
    if (sectionId != null) toggleCollapse(sectionId);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Collapse is disabled in `fillHeight` mode (the Post/Spill expanded
    // right pane): the map is the whole point of that pane, and the
    // ancestor's stretched Row forces this shell to the pane height — so a
    // collapsed shell there would just be a big empty card rather than
    // shrinking to the bar. The chevron therefore only appears in the
    // stacked (fixed-thumbnail) layouts, where collapsing to the coordinate
    // bar reads correctly.
    final collapsible = widget.sectionId != null && !widget.fillHeight;
    // The thumbnail stays in the tree while collapsible so the SizeTransition
    // below can slide it (down to expand, up to collapse) rather than it
    // appearing/vanishing at once. A genuinely absent thumbnail (no map) or a
    // non-collapsible caller is unaffected.
    final thumbnail = widget.thumbnail;
    final fill = widget.fillHeight && thumbnail != null;
    final thumbnailStack = thumbnail == null
        ? null
        : Stack(
            fit: StackFit.expand,
            children: [
              thumbnail,
              if (widget.overlayActions.isNotEmpty ||
                  (collapsible && !collapsed))
                Positioned(
                  top: 12,
                  right: 12,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ...widget.overlayActions,
                      // The fold-away control floats over the map itself while
                      // expanded — dropped from the tree once collapsed (the
                      // map slides shut, and the bar's own chevron takes over)
                      // so it never lingers clipped-but-findable behind the
                      // folded map.
                      if (collapsible && !collapsed)
                        CollapseChevron(
                          collapsed: collapsed,
                          onTap: _toggle,
                          inverseColorOnCollapsed: true,
                        ),
                    ],
                  ),
                ),
            ],
          );

    final legendBox = widget.legend == null
        ? null
        : Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
            ),
            child: widget.legend!,
          );

    // The fixed-height map plus any legend, one unit so the collapse animation
    // slides them together (non-fill layouts only; fill mode never collapses
    // and flexes the map instead).
    final mapAndLegend = thumbnailStack == null
        ? null
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: widget.thumbnailHeight, child: thumbnailStack),
              ?legendBox,
            ],
          );

    // Divider between the map section and the bar — dropped once collapsed
    // (nothing visible above the bar), so no stray line remains.
    final showBarDivider =
        thumbnailStack != null && !(collapsible && collapsed);

    final trailing = collapsible && collapsed
        ? CollapseChevron(
            onTap: _toggle,
            collapsed: collapsed,
            inverseColorOnCollapsed: true,
            padding: EdgeInsets.only(left: 0),
          )
        : widget.barTrailing;

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
        if (fill && thumbnailStack != null) ...[
          Expanded(child: thumbnailStack),
          ?legendBox,
        ] else if (mapAndLegend != null)
          collapsible
              ? SizeTransition(
                  alignment: Alignment.topCenter,
                  sizeFactor: collapseFactor,
                  child: mapAndLegend,
                )
              : mapAndLegend,
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: showBarDivider
                ? Border(
                    top: BorderSide(color: theme.colorScheme.outlineVariant),
                  )
                : null,
          ),
          child: InkWell(
            onTap: () {
              if (widget.onTap != null) {
                widget.onTap!();
                return;
              }
              setState(() {
                if (widget.sectionId != null) {
                  toggleCollapse(widget.sectionId!);
                }
              });
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ?widget.barLeading,
                if (widget.barLeading != null) const SizedBox(width: 8),
                if (widget.barLabel != null) ...[
                  widget.barLabel!,
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: widget.barChild,
                  ),
                ),
                // Collapsed: the expand chevron takes the trailing slot instead
                // of the editor `›` — the two are never shown together (the
                // over-map collapse chevron only exists while expanded).
                if (trailing != null) const SizedBox(width: 8),
                ?trailing,
              ],
            ),
          ),
        ),
      ],
    );

    // Couples the legend strip to the map above it (both are caller-supplied
    // widgets, mounted here as siblings, so neither can reach the other): a
    // MapView under this shell attaches its camera to the link, and a MapLegend
    // entry that names a marker uses it to move the map onto that marker. One
    // link per shell instance, so a screen showing several of these — a list of
    // post cards — has each legend driving its own map.
    //
    // asCard: a plain Card picks up the ambient cardTheme's
    // shape/elevation/shadow, so this reads as the same kind of card as
    // everything else in the app instead of a bespoke boxed frame. When
    // the caller already provides that card (asCard: false), skip it —
    // otherwise the map preview nests a card inside a card — and just
    // round the thumbnail's own corners.
    return MapCameraScope(
      link: _cameraLink,
      child: widget.asCard
          ? Card(
              // Match CollapsibleSectionCard exactly (elevation 1 + clip), so
              // the collapsed bar reads as the same surface as the other
              // section cards rather than the cardTheme default (elevation 2),
              // whose dark-mode elevation overlay makes it visibly lighter.
              margin: EdgeInsets.zero,
              elevation: widget.elevation,
              clipBehavior: Clip.antiAlias,
              child: InkWell(onTap: widget.onTap, child: content),
            )
          : ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: InkWell(onTap: widget.onTap, child: content),
            ),
    );
  }
}
