import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart';
import 'package:http/retry.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/services/geocoding_service.dart';
import 'package:ringdrill/services/map_settings.dart';
import 'package:ringdrill/utils/latlng_utils.dart';
import 'package:ringdrill/utils/variable_values.dart';
import 'package:ringdrill/views/shell/master_detail_leading.dart';
import 'package:ringdrill/views/shell/window_size_class.dart';
import 'package:ringdrill/views/widgets/map_command.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Unified spec for a single map marker. The [child] widget is the icon
/// (e.g. [Icons.place], [RoleMarker]). [MapView] owns label rendering.
///
/// Set [clusterGroup] to a non-null key to opt this marker into clustering
/// with others that share the same key. Markers with a null [clusterGroup]
/// are rendered in a flat [MarkerLayer] without clustering.
class MapMarkerSpec<K> {
  const MapMarkerSpec({
    required this.id,
    required this.label,
    required this.point,
    required this.child,
    this.shortLabel,
    this.clusterGroup,
    this.highlighted = false,
    this.onTap,
  });

  final K id;
  final String label;
  final LatLng point;

  /// Optional compact chip text for overview zooms — e.g. a station's plan
  /// number ("1.1" / "1a"). When set, the on-map label shows this from
  /// [MapConfig.labelMinZoomFor] up, switching to the full [label] once the
  /// camera passes [MapConfig.labelDetailZoomFor] — up close there is room
  /// for the full text; the overlap problem only exists at overview zooms.
  /// Null shows [label] whenever labels are visible at all, as before
  /// (roleplay-placement and scenario-location markers).
  final String? shortLabel;

  /// The icon widget rendered below the label. Must not render its own label.
  final Widget child;

  /// Cluster discriminator. Markers with the same non-null key are clustered
  /// together; null means flat rendering.
  final Object? clusterGroup;

  /// Generic "this marker is in its emphasized state" flag. [MapView] does
  /// not change the marker's own [child] for it — the caller already supplies
  /// whatever icon it wants — but a cluster that contains at least one
  /// highlighted marker is painted with [MapClusterStyle.activeColor] instead
  /// of [MapClusterStyle.color]. Stays domain-agnostic: callers decide what
  /// "highlighted" means (e.g. a station a team is currently at).
  final bool highlighted;

  final VoidCallback? onTap;
}

/// Visual style for a cluster badge produced by [MapView] when
/// [MapMarkerSpec.clusterGroup] is set. Omitted fields fall back to
/// theme-derived defaults inside [MapView].
class MapClusterStyle {
  const MapClusterStyle({
    this.color,
    this.onColor,
    this.activeColor,
    this.activeOnColor,
    this.size = const Size(40, 40),
  });

  final Color? color;
  final Color? onColor;

  /// Badge fill used when the cluster contains at least one
  /// [MapMarkerSpec.highlighted] marker. Falls back to [color] when null.
  final Color? activeColor;

  /// Number colour paired with [activeColor]. Falls back to [onColor] when
  /// null.
  final Color? activeOnColor;

  final Size size;
}

class MapConfig {
  static const int static = InteractiveFlag.none;
  static const int interactive =
      InteractiveFlag.drag |
      InteractiveFlag.flingAnimation |
      InteractiveFlag.pinchMove |
      InteractiveFlag.pinchZoom |
      InteractiveFlag.doubleTapZoom |
      InteractiveFlag.doubleTapDragZoom |
      InteractiveFlag.scrollWheelZoom;

  static const LatLng initialCenter = LatLng(59.91, 10.75);

  /// Below this zoom level, marker labels are hidden. Labels fade in between
  /// [labelMinZoom] - 1 and [labelMinZoom] via [AnimatedOpacity]. This is the
  /// compact-layout baseline; [labelMinZoomFor] relaxes it on wider windows.
  ///
  /// Calibrated against flutter_map's own [Scalebar] bucketing
  /// (`_metricScale`/`index = round(zoom - length.value)`, `length` default
  /// `m` = -1): the "500 m" reading spans zoom ≈ 13.5-14.5. At the previous
  /// value (14.0) labels sat at only ~50% opacity for the lower half of
  /// that range — visible as "faded/gone" while the scale bar still read
  /// "500 m" (reported: labels disappearing before the user expected). 13.0
  /// reaches full opacity at zoom 13, safely before that bucket starts.
  static const double labelMinZoom = 13.0;

  /// Zoom at which labels become fully visible, by window-size class. Wider
  /// layouts (tablets, desktop, split view) have far more room, so labels can
  /// appear at a more zoomed-out overview without crowding the map; compact
  /// phones keep the tighter [labelMinZoom] baseline. Mirrors the marker-scale
  /// bump in [MapView] so labels and icons grow into the extra space together.
  static double labelMinZoomFor(WindowSizeClass sizeClass) =>
      switch (sizeClass) {
        WindowSizeClass.compact => labelMinZoom,
        WindowSizeClass.medium => 11.5,
        WindowSizeClass.expanded => 10.5,
      };

  /// Zoom at which a marker with a [MapMarkerSpec.shortLabel] switches its
  /// chip from the compact form (the station number) to the full [label].
  /// Five levels above [labelMinZoomFor] (by the same [Scalebar] bucketing
  /// as [labelMinZoom]'s doc comment, landing the switch around the
  /// "25 m" reading) — but never above [defaultAutoFitMaxZoom].
  ///
  /// That cap matters: [defaultAutoFitMaxZoom] limits how tight *every*
  /// auto-fit is allowed to zoom, regardless of size class. Before this
  /// cap was added here, `labelMinZoomFor(compact) + 5 = 18` sat *above*
  /// `defaultAutoFitMaxZoom` (16.5) — meaning no auto-fit, and no tap of
  /// "centre", could ever reach zoom 18 on a compact window; only a
  /// manual pinch past what any built-in view would ever show could. On
  /// medium (11.5 + 5 = 16.5, exactly the cap) and expanded (10.5 + 5 =
  /// 15.5, comfortably under it) this coincidentally never bound, which is
  /// exactly why those two "worked" and compact silently didn't (reported:
  /// full labels only appearing well past where the scale bar read "25 m",
  /// needing "10 m" instead — compact's 18 was simply unreachable by any
  /// normal interaction). Capping at `min(labelMinZoomFor + 5,
  /// defaultAutoFitMaxZoom)` keeps every size class's threshold reachable
  /// by the same auto-fit a caller's own "centre" button would produce.
  static double labelDetailZoomFor(WindowSizeClass sizeClass) => math.min(
    labelMinZoomFor(sizeClass) + 5,
    defaultAutoFitMaxZoom,
  );

  /// Visual scale applied to marker icons and labels for [sizeClass] —
  /// mirrors [MapView]'s own per-instance marker scaling
  /// (`_MapViewState._markerScale`) so [fitPadding]'s label-footprint
  /// reserve below matches what will actually render.
  static double markerScaleFor(WindowSizeClass sizeClass) =>
      switch (sizeClass) {
        WindowSizeClass.compact => 1.0,
        WindowSizeClass.medium => 1.2,
        WindowSizeClass.expanded => 1.35,
      };

  /// The rendered width of a single marker's label at scale 1.0 — mirrors
  /// `_MapViewState._buildMarker`'s own `TextPainter` measurement and its
  /// `math.max(80.0, ...)` floor exactly, so [fitPadding]'s footprint
  /// reserve matches the real marker box, not a guess.
  static double _labelWidth(String label) {
    final painter = TextPainter(
      text: TextSpan(text: label),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    return math.max(80.0, painter.width);
  }

  /// Shrinks a flat "breathing room" padding constant proportionally to a
  /// small [viewportExtent] instead of letting it consume a fixed pixel
  /// amount regardless of how little room is actually available (a fixed
  /// 64px margin is negligible on a full-height phone screen but can eat a
  /// third of a short modal sheet's own height, forcing far more zoom-out
  /// than the data warrants). Never grows past [flat], and never shrinks
  /// past half of it — some minimum breathing room always survives, even
  /// on a very small viewport.
  ///
  /// Only ever applied to *aesthetic* margin (nothing physically obstructs
  /// there) — never to always-visible overlay chrome (the FAB command
  /// stack, the search field), since those occlude markers for real if
  /// under-reserved regardless of viewport size. The marker label
  /// footprint sits between the two: real rendered space, but zoom-gated
  /// invisible at overview zooms, so it gets its own viewport-fraction cap
  /// in [fitPadding] instead of this one (whose `flat * 0.5` floor would
  /// defeat a cap exactly when the label is widest).
  static double _capAesthetic(
    double flat,
    double viewportExtent, {
    double fraction = 0.12,
  }) {
    final cap = math.max(viewportExtent * fraction, flat * 0.5);
    return math.min(flat, cap);
  }

  /// Padding used when calling [MapController.fitCamera] so the fit
  /// honours both the on-map overlays and the markers' own rendered
  /// footprint. Because [MapController.fitCamera] places the bounds
  /// *center* into the centre of the padded area, asymmetric padding
  /// directly shifts where the centroid lands on screen: a larger bottom
  /// padding pulls the camera so the centroid appears higher in the
  /// visible area.
  ///
  /// [viewport] must be the *real* local size the [MapView] being fit will
  /// actually render at — its own `LayoutBuilder` constraints, not
  /// necessarily the full window (a map embedded in a narrower/shorter
  /// dialog, sheet, or side pane renders at that pane's size, not the
  /// window's). Every size-derived component below (marker scale, FAB
  /// diameter, and the capped aesthetic margins) is derived from it, so a
  /// map's fit always matches what will actually render in its own space —
  /// callers without a real pre-layout size (e.g. computing a fit before
  /// the `MapView` exists) should pass their best estimate, typically
  /// `MediaQuery.sizeOf(context)`.
  ///
  /// A marker's own box (label above its icon) is anchored by its
  /// *bottom* edge to the geographic point (`_MapViewState._buildMarker`),
  /// so it only ever extends upward and sideways from that point, never
  /// downward. Reserving only flat overlay clearance can still land a
  /// marker's point close enough to an edge that its own label clips
  /// outside the viewport, or slides under the FAB overlays — passing
  /// [labels] (every marker's label in the set being fit) adds the actual
  /// rendered footprint on top of the overlay margins below, scaled the
  /// same way [MapView] itself would render it — capped to a fraction of
  /// [viewport], since labels are zoom-gated invisible at the overview
  /// zooms a small surface's fit lands on (see the inline comment in the
  /// body). An empty [labels] (every label hidden via `MapView
  /// .showLabels: false`) still reserves the icon's own footprint — it
  /// renders regardless of whether its label does, and is anchored the
  /// same bottom-up way, so it needs the same edge clearance, just not
  /// the label box on top of it.
  ///
  /// Half of that footprint reserve is added to *both* top and bottom,
  /// even though only the top physically needs it (labels never render
  /// below their marker) — reserving it top-only would bias the fitted
  /// centroid downward by exactly that amount (per the centroid-shift rule
  /// above), which is visible as "every marker sits in the lower half" on
  /// any fit with labels but no search field or FAB stack to counterbalance
  /// it (e.g. a static mini-map preview). Splitting it rather than mirroring
  /// a full second copy keeps top+bottom's combined total — and so the
  /// resulting zoom level — unchanged from omitting the split entirely.
  ///
  /// Top and bottom insets are kept close to one another so a fit lands
  /// the markers near the visible centre rather than skewed upward. The
  /// top inset clears the search field (hard, unscaled — a real overlay
  /// that's always fully opaque and always in the same place). The bottom
  /// inset mirrors the bottom-right command column's *actual* composition
  /// — locate, then zoom in/out, then centre, each `MapCommandSize
  /// .diameter` tall with the same gaps [MapView] itself lays out with —
  /// but unlike the search field, that reserve is capped against
  /// [viewport] via [_capAesthetic] too: three stacked commands can total
  /// 150+ px, and reserving all of it unconditionally forced far more
  /// zoom-out than the floating, semi-transparent circular buttons
  /// actually need to stay legible (reported: an all-stations map with
  /// zoom + centre showing a "500 m" scale for the same markers a
  /// command-free preview fit at "250 m"). `_capAesthetic`'s `flat * 0.5`
  /// floor still guarantees at least half the natural stack height is
  /// kept clear, so the buttons never fully swallow a marker, just no
  /// longer demand the *entire* column stay untouched on a small viewport.
  ///
  /// Horizontal padding is a capped 64 px floor when no [labels] are
  /// given, so the outermost markers do not hug the screen edges after a
  /// fit without eating a large fraction of a narrow viewport; a wide
  /// label pushes it out further (uncapped — a real footprint requirement)
  /// so its own text does not clip.
  static EdgeInsets fitPadding({
    bool withSearch = false,
    bool withZoom = false,
    bool withCenter = false,
    bool withLocate = false,
    required Size viewport,
    Iterable<String> labels = const [],
  }) => _fitPaddingAndFootprint(
    withSearch: withSearch,
    withZoom: withZoom,
    withCenter: withCenter,
    withLocate: withLocate,
    viewport: viewport,
    labels: labels,
  ).padding;

  /// [fitPadding]'s own computation, additionally returning the raw
  /// per-marker vertical footprint (`markerHeight`, *before* the top/bottom
  /// split) — [fitFor] needs that same figure again for [centroidFit]'s
  /// [_UnbiasedBoundsFit.markerAnchorHeight] correction, and recomputing it
  /// independently would drift the two apart the next time this is tuned.
  static ({EdgeInsets padding, double markerHeight}) _fitPaddingAndFootprint({
    bool withSearch = false,
    bool withZoom = false,
    bool withCenter = false,
    bool withLocate = false,
    required Size viewport,
    Iterable<String> labels = const [],
    // False only when a caller (fitFor, for zero points) knows there is no
    // marker at all to protect — distinct from "markers exist but their
    // labels aren't shown," which still needs the icon-only footprint
    // below. Defaults true: every other caller either has markers or
    // doesn't distinguish the two, matching this function's original
    // (markers-always-present) contract.
    bool hasMarkers = true,
  }) {
    final sizeClass = WindowSizeClass.fromWidth(viewport.width);
    final scale = markerScaleFor(sizeClass);
    final commandSize = MapCommandSize.fromWidth(viewport.width);

    // The label footprint is real rendered space, but unlike the search
    // field and FAB stack (chrome that is always visible) it is zoom-gated:
    // below MapConfig.labelMinZoomFor every label is fully transparent
    // (_ZoomGatedLabel), and a small viewport's overview fit always lands
    // below that zoom. So the footprint is capped to a fraction of the
    // viewport — a plain min, NOT _capAesthetic, whose `flat * 0.5` floor
    // would defeat the cap exactly when the label is widest. Uncapped, a
    // single long label (~150 px half-width) reserved on BOTH sides of a
    // 360 px mini-map starved the fit into a ~70 px strip and forced a
    // massive zoom-out to protect labels that rendered at opacity 0. On
    // any full-size surface the cap sits above every real label footprint
    // and changes nothing.
    // Even with no labels at all (an empty [labels] iterable, or every
    // label suppressed via `showLabels: false`), the marker's own *icon*
    // still renders and is anchored the same bottom-up way a label would
    // be — it still needs top/bottom clearance to avoid clipping at the
    // viewport edge, just not the extra label-box height on top of it.
    // 32px matches the largest icon actually used across every
    // MapMarkerSpec producer (Icons.place at size 32); a smaller icon just
    // gets a touch more breathing room than strictly required.
    const double iconOnlyHeight = 32;
    const double iconOnlyHalfWidth = 16;

    final labelList = labels.toList(growable: false);
    final double markerHeight = !hasMarkers
        ? 0
        : labelList.isEmpty
        ? iconOnlyHeight * scale
        : math.min(64 * scale, viewport.height * 0.15);
    final double markerHalfWidth = !hasMarkers
        ? 0
        : labelList.isEmpty
        ? iconOnlyHalfWidth * scale
        : math.min(
            labelList.map(_labelWidth).reduce(math.max) * scale / 2,
            viewport.width * 0.15,
          );

    // Mirrors MapView's own bottom-right Column: locate, then the zoom
    // pair, then centre — 12 px between groups, 8 px between the two zoom
    // buttons, 16 px outer padding.
    double stack = 0;
    var hasCommands = false;
    void addGroup(double height) {
      if (hasCommands) stack += 12;
      stack += height;
      hasCommands = true;
    }

    if (withLocate) addGroup(commandSize.diameter);
    if (withZoom) addGroup(commandSize.diameter * 2 + 8);
    if (withCenter) addGroup(commandSize.diameter);

    final double sideFloor = _capAesthetic(64, viewport.width);
    final double topNoSearch = _capAesthetic(48, viewport.height);
    final double bottomNoCommands = _capAesthetic(48, viewport.height);

    // markerHeight only clears a label that renders above its marker, so it
    // is a top-only requirement in isolation — but reserving it solely on
    // top biases the fitted centroid downward (see the class doc above),
    // exactly the "markers sit below centre" symptom this splits away.
    // Splitting it across both sides (rather than adding a second full
    // copy) keeps top+bottom's *total* unchanged — no extra zoom-out — while
    // still landing top == bottom whenever withSearch/commands don't
    // themselves demand an imbalance.
    final double bottomBase = hasCommands
        ? _capAesthetic(stack + 16, viewport.height)
        : bottomNoCommands;
    final double topBase = withSearch ? 112 : topNoSearch;
    final double bottom = bottomBase + markerHeight / 2;
    final double top = topBase + markerHeight / 2;
    final double side = math.max(sideFloor, markerHalfWidth);
    return (
      padding: EdgeInsets.fromLTRB(side, top, side, bottom),
      markerHeight: markerHeight,
    );
  }

  /// Single source of truth for "camera fit that frames [points]", used by
  /// every mini-map, sheet and full map screen so the initial framing a
  /// caller shows always matches what pressing that same surface's "centre"
  /// control would produce. Before this, callers each hand-rolled their own
  /// mix of bbox-fit vs. centroid-fit and flat vs. overlay-aware padding,
  /// which is why a sheet's initial view could show a different zoom than
  /// its own centre button.
  ///
  /// The `withX` flags must mirror the flags passed to the [MapView] this
  /// fit is framing, so [fitPadding] reserves the same overlay clearance
  /// [MapView._toggleCenter] would. [viewport] must be the real local
  /// render size that `MapView` will use (see [fitPadding]). Pass [labels]
  /// (every fitted marker's label) so the fit also clears each marker's
  /// own rendered footprint — omit it only when [points] don't correspond
  /// to rendered markers at all (e.g. a raw search-result fit).
  ///
  /// Always returns a usable fit, for any number of [points] — zero, one
  /// or many are the same call into [LatlngListX.centroidFit], which
  /// itself needs no marker-count branch (see its own doc). Pass
  /// [fallbackCenter] for the zero-points case (typically a caller's own
  /// `initialCenter`); omit it to fall back to [MapConfig.initialCenter].
  ///
  /// [maxZoom] caps how tight a fit for closely-clustered points can zoom —
  /// defaults to [defaultAutoFitMaxZoom] so a handful of markers a few
  /// hundred metres apart still frame with some surrounding geographic
  /// context (roads, terrain, the next-nearest landmark) instead of
  /// zooming in only as far as the bare marker spread requires. Pass
  /// `null` for a caller that genuinely wants an unbounded tight fit.
  ///
  /// The returned fit also corrects for a marker's own rendering: every
  /// marker is anchored bottom-up (`_MapViewState._buildMarker`), so its
  /// icon/label box only ever extends *above* its point — centring
  /// strictly on the raw point centroid still leaves the rendered
  /// graphics looking shifted up. `_fitPaddingAndFootprint`'s per-marker
  /// footprint height feeds `centroidFit`'s `markerAnchorHeight`, which
  /// nudges the camera centre north by half that height (see
  /// `_UnbiasedBoundsFit`'s doc in `latlng_utils.dart` for the full
  /// derivation) so the *visual* group ends up centred, not just the bare
  /// anchor points.
  static CameraFit fitFor(
    Iterable<LatLng> points, {
    bool withSearch = false,
    bool withZoom = false,
    bool withCenter = false,
    bool withLocate = false,
    required Size viewport,
    Iterable<String> labels = const [],
    double? maxZoom = defaultAutoFitMaxZoom,
    LatLng? fallbackCenter,
  }) {
    final pts = points.toList(growable: false);
    final result = _fitPaddingAndFootprint(
      withSearch: withSearch,
      withZoom: withZoom,
      withCenter: withCenter,
      withLocate: withLocate,
      viewport: viewport,
      labels: labels,
      // No markers at all (as opposed to markers with hidden labels) means
      // no icon is rendered either — nothing to reserve footprint for, and
      // no visual anchor to correct centroidFit's markerAnchorHeight for.
      hasMarkers: pts.isNotEmpty,
    );
    return pts.centroidFit(
      result.padding,
      maxZoom,
      result.markerHeight,
      fallbackCenter,
    );
  }

  /// Default cap for [fitFor]'s zoom when points are closely clustered —
  /// calibrated against flutter_map's [Scalebar] bucketing (see
  /// [labelMinZoom]'s doc comment for the same math): 16.5 sits at the top
  /// of the "100 m" reading, one bucket coarser than "50 m". Reported: an
  /// auto-fit for 6 stations ~700 m apart landed at "50 m", zoomed in
  /// tighter than wanted for seeing the surrounding area — nudge if this
  /// doesn't land right on a real device.
  static const double defaultAutoFitMaxZoom = 16.5;

  /// Guidance, not an enforced check: the local viewport height a caller
  /// should have available before passing `interactive: true` to
  /// `StationMiniMap`/`RoleMiniMap`/`ExerciseMiniMap` (the
  /// medium/expanded mini-map consolidation), so the resulting directly
  /// interactive [MapView] (zoom + centre + layer-toggle commands) doesn't
  /// overflow its own command stack — a list-tile thumbnail (140px tall)
  /// is far too short to fit the bottom-right zoom+centre column
  /// (56 + 8 + 56 + 12 + 56 = 188px of buttons, plus 32px of padding =
  /// 220) without clipping, reported as a `RenderFlex overflowed` in a
  /// station/roleplay list tile.
  ///
  /// This used to be enforced automatically, inside each mini-map's own
  /// `LayoutBuilder`, gated on both this height *and* a local-width
  /// `WindowSizeClass` check. Both were dropped in favour of a plain
  /// caller-supplied `interactive` flag: the width check in particular
  /// reproduced this same session's recurring "local pane vs. its own
  /// sub-region" bug — `WideDetailMapSplit` caps its own left column at a
  /// flat 440px, so an otherwise-expanded 900px detail pane leaves the map
  /// itself only ~410px wide, reading as compact by a local-width measure
  /// even though the screen had already committed to its expanded,
  /// `fillHeight: true` layout. A caller (`StationPositionPanel`/
  /// `RolePositionPanel` forwarding their own `fillHeight`) already knows
  /// whether it has room; re-deriving the same answer from constraints
  /// that don't tell the whole story was strictly worse than just asking
  /// the caller directly.
  static const double minInteractiveHeight = 220;

  /// Single long-living HTTP client shared by every [NetworkTileProvider]
  /// the app builds.
  ///
  /// Without this, flutter_map gives each [TileLayer] its own provider with
  /// an internally-created client, and [NetworkTileProvider.dispose] closes
  /// that client when the layer leaves the tree. Toggling between the two
  /// Kartverket base layers therefore tore down the client mid-flight and
  /// spun up a fresh one every time, so connections to cache.kartverket.no
  /// were never reused and abandoned ones piled up until the host pool
  /// stalled. This is worst on web, where the browser caps concurrent
  /// connections per host and the stuck requests blocked all new tiles.
  ///
  /// A shared client survives layer toggles: [NetworkTileProvider.dispose]
  /// only closes a client it created itself, never one passed in. [http]
  /// >= 1.5.0 also lets the provider abort requests for pruned tiles
  /// natively, so no extra dependency is needed.
  static final Client _tileClient = RetryClient(Client());

  // Important! TileLayers are widgets! We need to get new layers
  // each time since we can not share them across multiple
  // FlutterMap instances (map may not show correctly). The HTTP client
  // they use is shared via [_tileClient]; only the widgets are rebuilt.
  static List<TileLayer> get layers => [topoLayer, topoGrayLayer];

  // Important! We need to get new layers each time. See above!
  static TileLayer get topoGrayLayer => TileLayer(
    key: const ValueKey('topo-gray'),
    urlTemplate:
        'https://cache.kartverket.no/v1/wmts/1.0.0/topograatone/default/webmercator/{z}/{y}/{x}.png',
    // Reuse the shared client so toggling base layers does not churn
    // connections to cache.kartverket.no. See [_tileClient].
    tileProvider: NetworkTileProvider(httpClient: _tileClient),
    subdomains: const [],
    userAgentPackageName: 'discoos.org/ringdrill',
    minZoom: 0,
    maxZoom: 19,
    minNativeZoom: 0,
    maxNativeZoom: 18,
  );

  // Important! We need to get new layers each time. See above!
  static TileLayer get topoLayer => TileLayer(
    key: const ValueKey('topo'),
    urlTemplate:
        'https://cache.kartverket.no/v1/wmts/1.0.0/topo/default/webmercator/{z}/{y}/{x}.png',
    // See topoGrayLayer / [_tileClient]: reuse the shared HTTP client.
    tileProvider: NetworkTileProvider(httpClient: _tileClient),
    subdomains: const [],
    userAgentPackageName: 'discoos.org/ringdrill',
    minZoom: 0,
    maxZoom: 19,
    minNativeZoom: 0,
    maxNativeZoom: 18,
  );
}

class MapView<K> extends StatefulWidget {
  const MapView({
    super.key,
    required this.layers,
    this.controller,
    this.withCross = false,
    this.withSearch = false,
    this.withCenter = false,
    this.withToggle = true,
    this.withZoom = false,
    this.withLocate = false,
    this.locateZoom = 16,
    this.resultZoom = 17,
    this.initialZoom,
    this.minZoom = 2,
    this.maxZoom = 19,
    this.markers = const [],
    this.clusterStyles = const {},
    this.showLabels = true,
    this.withClustering = true,
    this.searchTargets = const [],
    this.topRightCommands = const [],
    this.bottomOverlayInset = 0,
    this.initialFit,
    this.interactionFlags = MapConfig.static,
    this.initialCenter = MapConfig.initialCenter,
    this.onTap,
    this.geocodingService,
    this.withFullscreen = false,
    this.fullscreenHeader,
    this.commandSizeOverride,
  });

  final bool withCross;
  final bool withSearch;
  final bool withCenter;
  final bool withToggle;
  final bool withZoom;

  /// When true, render a "locate me" FAB at the top of the bottom-right
  /// command column. Tapping it requests one-shot foreground location
  /// from `geolocator`, recentres the camera, and draws a non-interactive
  /// blue dot at the resolved position. Permission state is handled in
  /// place via SnackBars; this widget does not surface a settings UI of
  /// its own beyond the deny-forever action that deep-links into the OS
  /// app settings.
  final bool withLocate;

  /// Zoom level the camera animates to after a successful locate. Picked
  /// to roughly match Google Maps's "blue-dot recenter" feel without
  /// being so tight that it overshoots short-distance moves on a
  /// stationary device.
  final double locateZoom;

  /// Minimum zoom the camera snaps to when a single-point search result is
  /// selected. Picked above the marker-cluster threshold so the chosen
  /// station declusters and shows on its own instead of staying hidden
  /// inside a group badge. The camera never zooms *out* to reach it: if the
  /// user is already closer the current zoom is kept.
  final double resultZoom;

  /// Ceiling on how tight the internal default fit is allowed to zoom —
  /// see `_MapViewState._effectiveMaxZoom`. Null (the default) lets
  /// `MapView` use [MapConfig.defaultAutoFitMaxZoom] uniformly, for any
  /// number of markers. Pass an explicit value only when a caller
  /// genuinely needs something else (e.g. `MapPickerScreen`'s pick-mode
  /// framing).
  final double? initialZoom;
  final double minZoom;
  final double maxZoom;
  final LatLng initialCenter;
  final int interactionFlags;
  final CameraFit? initialFit;
  final TapCallback? onTap;
  final MapController? controller;
  final List<TileLayer> layers;

  /// Geocoder used by the search field's place lookups (ADR-0047 follow-up
  /// 3c). Defaults to the real `osm_nominatim`-backed service; tests
  /// substitute a fake so no test hits the network.
  final GeocodingService? geocodingService;

  /// Unified marker list. Replaces the old `markers` + `roleMarkers` split.
  /// Each spec carries its own icon widget and optional tap callback.
  /// Markers with a non-null [MapMarkerSpec.clusterGroup] are clustered
  /// together when [withClustering] is true.
  final List<MapMarkerSpec<K>> markers;

  /// Per-group visual style for cluster badges. Keys must match the
  /// [MapMarkerSpec.clusterGroup] values used in [markers].
  final Map<Object, MapClusterStyle> clusterStyles;

  /// When false, the label slot returns [SizedBox.shrink] regardless of zoom.
  final bool showLabels;

  /// When false, all markers are emitted into a single flat [MarkerLayer]
  /// regardless of their [MapMarkerSpec.clusterGroup]. Useful for mini-maps
  /// and pickers that never have enough markers to benefit from clustering.
  final bool withClustering;

  /// Extra named locations available to the search field. Each target may
  /// have zero, one, or many points (e.g. an exercise that aggregates the
  /// positions of its stations) and may override the tap behaviour with
  /// [SearchResult.onSelect].
  final List<SearchResult> searchTargets;

  /// Caller-provided commands stacked under the built-in layer-toggle FAB
  /// at the top-right corner of the map. Use this to hang feature-specific
  /// FABs (e.g. an exercise-visibility filter) without coupling [MapView]
  /// to a particular domain. Each widget should be sized like a
  /// [FloatingActionButton] and carry a unique `heroTag`.
  final List<Widget> topRightCommands;

  /// Extra bottom clearance for [MapView]'s own bottom-anchored chrome —
  /// the bottom-right command column (zoom, locate, centre) and the
  /// [Scalebar] — so a caller can overlay its own bottom chrome (e.g. a
  /// confirm bar) without either sitting underneath it. [MapView] stays
  /// domain-agnostic: the caller just reports how much space it needs.
  final double bottomOverlayInset;

  /// Shows an "expand to fullscreen" command alongside the layer-toggle
  /// FAB. Tapping it pushes a genuine full-screen route (on the root
  /// navigator — not a dialog, not a bottom sheet, regardless of
  /// [WindowSizeClass]) containing a fresh, fully-interactive clone of
  /// this same map — see `_MapViewState._openFullscreen`. Building this as
  /// an internal command (sized from the same local `commandSize` every
  /// other built-in command uses) also avoids a real bug a caller-supplied
  /// `topRightCommands` entry has: with no explicit `size:`, such a widget
  /// resolves via [MapCommandSize.of] (full-window `MediaQuery`), which can
  /// visibly mismatch the internal commands' local-viewport-derived size
  /// whenever this `MapView` is embedded narrower than the full window.
  final bool withFullscreen;

  /// `AppBar` shown only in the route [withFullscreen] pushes — the inline
  /// embed itself never shows an app bar. Null renders a minimal `AppBar`
  /// with just a close affordance ([MasterDetailLeading]).
  final PreferredSizeWidget? fullscreenHeader;

  /// Forces every command (layer toggle, zoom, centre, locate, fullscreen)
  /// to this size instead of deriving it from the local `LayoutBuilder`
  /// constraints. Set internally by `_MapViewState._openFullscreen` on the
  /// clone it pushes, so "expand to fullscreen" reads as "the same map,
  /// more room" rather than growing every button just because the pushed
  /// route's own window happens to be wider than the embed the user
  /// tapped from. Not meant for external callers — omit it.
  final MapCommandSize? commandSizeOverride;

  @override
  State<MapView<K>> createState() => _MapViewState();
}

class _MapViewState<K> extends State<MapView<K>> {
  late final GeocodingService _geocoder =
      widget.geocodingService ?? NominatimGeocodingService();
  late MapController _mapController;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _resultsScrollController = ScrollController();
  final Set<SearchResult> _searchResults = {};

  Timer? _throttleTimer;
  bool _isSearching = false;
  int _currentLayerIndex = 0;

  /// Per-instance scope for this map's [MapCommand] hero tags — several
  /// `MapView`s (a list's mini-map previews alongside a detail pane's own
  /// map, in the master/detail split layouts) can be in the same subtree at
  /// once, so a command name alone ("layers", "locate", ...) is not unique
  /// enough on its own; combined with this per-`State` key it is.
  final Object _heroScope = UniqueKey();

  /// Last known device position resolved by the locate-me FAB. Null until
  /// the user has successfully located themselves at least once during
  /// this session. Survives layer toggles but resets on widget rebuild
  /// from scratch.
  LatLng? _currentLocation;

  /// Set while a one-shot location request is in flight so a second tap
  /// on the FAB does not stack requests. The FAB swaps its icon for a
  /// spinner while this is true.
  bool _locating = false;

  /// This build's [LayoutBuilder] constraints — the real local size this
  /// `MapView` is actually rendering at, which may be much narrower/shorter
  /// than the full window (a dialog, a bottom sheet, a mini-map thumbnail,
  /// a master/detail side pane). Populated as the first line of `build`'s
  /// `LayoutBuilder.builder`, so it is always set before anything below
  /// (the default fit, `_toggleCenter`, `_onResultTap`) needs it — none of
  /// those run before the first `build`.
  BoxConstraints? _lastConstraints;

  /// The `commandSize` most recently computed in `build()` (or
  /// `widget.commandSizeOverride`, if set) — captured so `_openFullscreen`
  /// can freeze it onto the clone it pushes instead of letting that clone
  /// re-derive its own, likely different, size from the pushed route's own
  /// (usually wider) constraints.
  MapCommandSize? _lastCommandSize;

  /// [_lastConstraints]'s size, when known and finite in both axes. Null
  /// only if this `MapView` hasn't laid out yet, or an ancestor handed it
  /// unbounded constraints (not observed in any current embedding — every
  /// caller gives `MapView` a bounded box, directly or via `Expanded`/a
  /// fixed-height `SizedBox` — but guarded defensively regardless).
  Size? get _knownViewport {
    final c = _lastConstraints;
    if (c == null || !c.hasBoundedWidth || !c.hasBoundedHeight) return null;
    return c.biggest;
  }

  /// The real local viewport when known, else the full window as a
  /// fallback — matches what every caller's own [WindowSizeClass.of] guess
  /// was already implicitly reading before this existed, so it's never
  /// worse than the old behaviour, just more accurate once layout has run.
  Size _effectiveViewport(BuildContext context) =>
      _knownViewport ?? MediaQuery.sizeOf(context);

  /// The default "fit every visible marker" camera fit, computed from this
  /// `MapView`'s own real render size — used as [MapOptions.initialCameraFit]
  /// whenever the caller doesn't pass an explicit [MapView.initialFit] (the
  /// common case: every mini-map/sheet/full-map screen that just wants to
  /// frame what it's showing). Callers that need something else entirely —
  /// e.g. `MapPickerScreen`'s "centre on the pick point, frame the sibling
  /// context markers" — keep passing an explicit [MapView.initialFit].
  ///
  /// Always returns a fit — for any number of [specs], zero included. Zero
  /// or one marker used to be a separate `null` case with its own
  /// `initialCenter`/`initialZoom` fallback at every call site; now the
  /// same [MapConfig.fitFor] call handles it directly, landing on
  /// [widget.initialCenter] at [_effectiveMaxZoom] instead of needing a
  /// distinct code path (see [LatlngListX.centroidFit]'s doc for why that's
  /// safe). A single marker was previously zoomed to
  /// [MapConfig.labelDetailZoomFor] on the reasoning that nothing else is
  /// nearby to crowd — but that threshold answers a different question
  /// (when a multi-marker fit's label can expand from a number chip to
  /// full text) and had nothing to do with a good default framing for a
  /// lone point; reported: a single station previewed at a "25 m" scale
  /// reading, tighter than wanted.
  CameraFit _defaultFitFor(
    BuildContext context,
    Iterable<MapMarkerSpec<K>> specs,
  ) {
    final points = specs.map((e) => e.point).toList(growable: false);
    // Debug-only trace for diagnosing wrong default fits on a real device:
    // shows whether this instance used its real laid-out size or fell back
    // to the full window, which no widget test has reproduced going wrong.
    assert(() {
      debugPrint(
        'MapView(${widget.key ?? 'no-key'}) default fit: '
        'viewport=${_effectiveViewport(context)} '
        'bounded=${_knownViewport != null} markers=${points.length}',
      );
      return true;
    }());
    return MapConfig.fitFor(
      points,
      withSearch: widget.withSearch,
      withZoom: widget.withZoom && MapSettings.instance.showZoomControls.value,
      withCenter: widget.withCenter,
      withLocate: widget.withLocate,
      viewport: _effectiveViewport(context),
      maxZoom: _effectiveMaxZoom,
      fallbackCenter: widget.initialCenter,
      // The fit reserves label footprint only when labels actually render —
      // a showLabels: false surface (the static mini-map previews) must not
      // zoom out to protect text it never draws. The default fit always
      // lands on an overview zoom (framing every marker), which is always
      // below labelDetailZoomFor — so a marker with a shortLabel reserves
      // that shorter chip's width, not the full label it won't show yet.
      labels: widget.showLabels
          ? specs.map((e) => e.shortLabel ?? e.label)
          : const Iterable<String>.empty(),
    );
  }

  /// Ceiling on the internal default fit's zoom, for any marker count —
  /// an explicit [MapView.initialZoom] always wins; otherwise
  /// [MapConfig.defaultAutoFitMaxZoom], the same "give some surrounding
  /// geographic context" zoom that already capped the multi-marker fit,
  /// so there's no jarring jump in zoom level as a filter/data change
  /// moves a surface between marker counts.
  double get _effectiveMaxZoom =>
      widget.initialZoom ?? MapConfig.defaultAutoFitMaxZoom;

  @override
  void initState() {
    super.initState();
    _mapController = widget.controller ?? MapController();
    // Rebuild when the "show zoom buttons" preference changes so an open map
    // reflects the setting immediately.
    MapSettings.instance.showZoomControls.addListener(_onMapSettingsChanged);
  }

  void _onMapSettingsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant MapView<K> oldWidget) {
    if (oldWidget != widget) {
      if (widget.controller != null && _mapController != widget.controller) {
        _mapController = widget.controller!;
      }
      if (widget.initialCenter != oldWidget.initialCenter) {
        _mapController.move(widget.initialCenter, _mapController.camera.zoom);
      }
      // Only an *explicit* zoom change moves the camera here — a caller
      // clearing its override (explicit -> null) falls through to the
      // internal-default-fit branch below instead, same as `initialFit`.
      if (widget.initialZoom != null &&
          widget.initialZoom != oldWidget.initialZoom) {
        _mapController.move(_mapController.camera.center, widget.initialZoom!);
      }
      if (widget.initialFit != null &&
          widget.initialFit != oldWidget.initialFit) {
        // Caller-supplied override: unchanged re-fit-on-identity-change,
        // same as before this widget could compute its own default fit.
        _mapController.fitCamera(widget.initialFit!);
      } else if (widget.initialFit == null && oldWidget.initialFit == null) {
        // Internal-default-fit path: only re-fit when the actual marker
        // point set changed, not on every unrelated parent rebuild — a
        // caller typically rebuilds `markers` as a fresh List instance on
        // every build even when the underlying data hasn't changed, and
        // re-fitting then would fight the user's own pan/zoom.
        final oldPoints = oldWidget.markers
            .map((e) => e.point)
            .toList(growable: false);
        final newPoints = widget.markers
            .map((e) => e.point)
            .toList(growable: false);
        if (!_pointsEqual(oldPoints, newPoints)) {
          _mapController.fitCamera(_defaultFitFor(context, widget.markers));
        }
      }
    }
    super.didUpdateWidget(oldWidget);
  }

  /// Mirrors `SearchResult._listEquals` — element-wise `LatLng` equality,
  /// used by [didUpdateWidget] to tell "the marker set actually changed"
  /// apart from "the caller rebuilt `markers` as a new `List` instance with
  /// the same data," which happens on essentially every unrelated parent
  /// rebuild and must not retrigger a fit.
  static bool _pointsEqual(List<LatLng> a, List<LatLng> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Pushes a genuine full-screen route on the root navigator — not a
  /// dialog, not a bottom sheet, regardless of [WindowSizeClass] — with a
  /// fresh, fully-interactive clone of this map. `widget.markers` (already
  /// resolved `MapMarkerSpec`s, labels baked in as plain strings) is reused
  /// as-is: unlike `openFormSurface` (which exists for *forms* that
  /// resolve plan-variable scope live), there is nothing here that needs
  /// re-provisioning from the calling context's `InheritedWidget` ancestry.
  /// A marker's own `onTap` closure keeps referencing whatever
  /// `BuildContext` built it originally, which stays mounted (just
  /// visually covered by the new route), so it behaves exactly as it does
  /// from the non-fullscreen embed.
  void _openFullscreen() {
    // Freeze the embed's current command size onto the pushed clone — see
    // MapView.commandSizeOverride's doc for why: otherwise the clone would
    // recompute its own, usually larger, size purely because the pushed
    // route's own window is wider than the embed the user tapped from.
    final frozenCommandSize = _lastCommandSize;
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (routeContext) => Scaffold(
          appBar:
              widget.fullscreenHeader ??
              AppBar(
                leading: MasterDetailLeading(
                  onClose: () => Navigator.of(routeContext).pop(),
                ),
              ),
          body: MapView<K>(
            layers: widget.layers,
            withCross: widget.withCross,
            withSearch: widget.withSearch,
            // Fullscreen always means fully interactive, regardless of
            // what the smaller embed itself opted into.
            withCenter: true,
            withToggle: true,
            withZoom: true,
            withLocate: widget.withLocate,
            locateZoom: widget.locateZoom,
            resultZoom: widget.resultZoom,
            minZoom: widget.minZoom,
            maxZoom: widget.maxZoom,
            markers: widget.markers,
            clusterStyles: widget.clusterStyles,
            showLabels: widget.showLabels,
            withClustering: widget.withClustering,
            searchTargets: widget.searchTargets,
            topRightCommands: widget.topRightCommands,
            interactionFlags: MapConfig.interactive,
            initialCenter: widget.initialCenter,
            onTap: widget.onTap,
            geocodingService: widget.geocodingService,
            commandSizeOverride: frozenCommandSize,
            // No controller: forwarded — this pushed clone gets its own
            // fresh MapController; sharing one across two simultaneously
            // mounted MapViews would fight over camera state.
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final withToggle = widget.withToggle && widget.layers.length > 1;
    final hasTopRightColumn =
        widget.topRightCommands.isNotEmpty || withToggle || widget.withFullscreen;
    // Zoom buttons follow the user's setting (Map → show zoom buttons),
    // which itself defaults off on touch where pinch-to-zoom suffices.
    final showZoom =
        widget.withZoom && MapSettings.instance.showZoomControls.value;
    return LayoutBuilder(
      builder: (context, constraints) {
        _lastConstraints = constraints;
        // Derived from these *local* constraints, not MapCommandSize.of/
        // WindowSizeClass.of(context)'s full-window read — a map embedded in
        // a narrower/shorter dialog, sheet, or side pane must render (and
        // reserve fit padding for) the size it actually has, not the whole
        // window's. See MapConfig.fitPadding's own viewport parameter.
        //
        // widget.commandSizeOverride wins when set: the fullscreen route
        // _openFullscreen pushes is a brand-new, usually much wider Scaffold
        // than the embed the user tapped "expand" from, so measuring its own
        // constraints from scratch would grow the buttons (compact →
        // regular) purely because the window is bigger — a jarring size
        // change for what's meant to read as "the same map, more room,"
        // not "different controls." _openFullscreen freezes the size the
        // embed was actually using at the moment it was tapped and forwards
        // it here instead of letting it re-derive.
        final commandSize =
            widget.commandSizeOverride ??
            MapCommandSize.fromWidth(constraints.maxWidth);
        _lastCommandSize = commandSize;
        // Distance from the right edge to the *visible* command circle, plus
        // a 10 px gap so the search field never butts up against it. The
        // command column is inset 16 px from the right (matching the
        // bottom-right column, so the two stacks align) and its small-FAB
        // visual sits `tapInset` in from its hit box.
        final topRightInset =
            16 + commandSize.tapInset + commandSize.diameter + 10;
        // The visible command circle starts `tapInset` below the column's
        // 16 px top padding, so the search field drops by the same amount to
        // keep the tops aligned.
        final searchTopInset = 16 + commandSize.tapInset;
        final effectiveInitialFit =
            widget.initialFit ?? _defaultFitFor(context, widget.markers);
        // The search field follows the same "size that fits the layout" rule
        // as the commands: it fills the available width on compact (the
        // screen is narrow anyway) but is capped on wider layouts so it does
        // not stretch the full width of a large map.
        // Subtract the 10 px left inset (below) and, on the right, either the
        // command-column footprint or a matching 10 px margin so the field
        // never slides under the FABs.
        final rightReserve = hasTopRightColumn ? topRightInset : 10.0;
        final searchAvailable = constraints.maxWidth - 10 - rightReserve;
        // Compact fills the (narrow) screen; medium/expanded cap the field
        // so it does not stretch across a wide map.
        const double maxSearchWidth = 400;
        final searchWidth = commandSize == MapCommandSize.compact
            ? searchAvailable
            : math.min(searchAvailable, maxSearchWidth);
        return Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialZoom: _effectiveMaxZoom,
                initialCenter: widget.initialCenter,
                initialCameraFit: effectiveInitialFit,
                // TileLayer.minZoom/maxZoom only gate which tiles are
                // fetched; they do not constrain the camera. Without these
                // the user could pinch/scroll past the tile layer's range
                // and end up over empty zoom levels showing FlutterMap's
                // blank default background. Mirror the same bounds used to
                // clamp the zoom FABs so every interaction agrees.
                minZoom: widget.minZoom,
                maxZoom: widget.maxZoom,
                interactionOptions: InteractionOptions(
                  flags: widget.interactionFlags,
                ),
                onTap: (tapPosition, point) {
                  if (widget.interactionFlags != InteractiveFlag.none) {
                    _mapController.move(point, _mapController.camera.zoom);
                  }
                  if (widget.onTap != null) {
                    widget.onTap!(tapPosition, point);
                  }
                },
              ),
              children: [
                widget.layers[_currentLayerIndex],
                ..._buildMarkerLayers(_effectiveViewport(context)),
                if (_currentLocation != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _currentLocation!,
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        child: const _CurrentLocationDot(),
                      ),
                    ],
                  ),
                Scalebar(
                  alignment: Alignment.bottomLeft,
                  padding: EdgeInsets.fromLTRB(
                    10,
                    10,
                    10,
                    10 + widget.bottomOverlayInset,
                  ),
                ),
              ],
            ),
            if (widget.withCross)
              // One clear centre pin = the point the camera centre sets
              // (e.g. the map picker's selection), with a small ground dot
              // marking the exact coordinate under the pin's tip.
              IgnorePointer(
                child: Stack(
                  children: [
                    Center(
                      child: Transform.translate(
                        offset: const Offset(0, -21),
                        child: Icon(
                          Icons.location_on,
                          size: 42,
                          color: Colors.green,
                        ),
                      ),
                    ),
                    Center(
                      child: Container(
                        width: 10,
                        height: 3,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (widget.withSearch)
              // Search Results (Dropdown-like List)
              Align(
                alignment: Alignment.topLeft,
                // Inset to match the top-right command column (left 10) and
                // drop by the command's tap-target offset so the visible tops
                // line up instead of hugging the screen edge.
                child: Padding(
                  padding: EdgeInsets.only(left: 10, top: searchTopInset),
                  child: SizedBox(
                    width: searchWidth,
                    child: _buildSearchTool(context, constraints, commandSize),
                  ),
                ),
              ),
            if (hasTopRightColumn)
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  // Right inset matches the bottom-right command column
                  // (16) so the two FAB stacks line up on the same vertical
                  // edge; a larger top inset just drops the first command
                  // clear of the map's top edge / any search field.
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (withToggle)
                        MapCommand(
                          heroTag: (_heroScope, 'layers'),
                          tooltip: AppLocalizations.of(context)!.layers,
                          onPressed: _toggleLayer,
                          icon: Icons.layers,
                          size: commandSize,
                        ),
                      if (widget.withFullscreen) ...[
                        if (withToggle) const SizedBox(height: 8),
                        MapCommand(
                          heroTag: (_heroScope, 'fullscreen'),
                          tooltip: AppLocalizations.of(context)!.expandMap,
                          onPressed: _openFullscreen,
                          icon: Icons.open_in_full,
                          size: commandSize,
                        ),
                      ],
                      for (
                        var i = 0;
                        i < widget.topRightCommands.length;
                        i++
                      ) ...[
                        if (i > 0 || withToggle || widget.withFullscreen)
                          const SizedBox(height: 8),
                        widget.topRightCommands[i],
                      ],
                    ],
                  ),
                ),
              ),
            if (widget.withCenter || showZoom || widget.withLocate)
              Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    16 + widget.bottomOverlayInset,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (widget.withLocate) ...[
                        MapCommand(
                          heroTag: (_heroScope, 'locate'),
                          tooltip: AppLocalizations.of(context)!.locateMe,
                          size: commandSize,
                          onPressed: _locating ? null : _locateMe,
                          child: _locating
                              ? SizedBox(
                                  width: commandSize.spinnerSize,
                                  height: commandSize.spinnerSize,
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                  ),
                                )
                              : Icon(
                                  Icons.my_location,
                                  size: commandSize.iconSize,
                                ),
                        ),
                        if (showZoom || widget.withCenter)
                          const SizedBox(height: 12),
                      ],
                      if (showZoom) ...[
                        MapCommand(
                          heroTag: (_heroScope, 'zoomIn'),
                          tooltip: AppLocalizations.of(context)!.zoomIn,
                          size: commandSize,
                          onPressed: _zoomIn,
                          icon: Icons.add,
                        ),
                        const SizedBox(height: 8),
                        MapCommand(
                          heroTag: (_heroScope, 'zoomOut'),
                          tooltip: AppLocalizations.of(context)!.zoomOut,
                          size: commandSize,
                          onPressed: _zoomOut,
                          icon: Icons.remove,
                        ),
                        if (widget.withCenter) const SizedBox(height: 12),
                      ],
                      if (widget.withCenter)
                        MapCommand(
                          heroTag: (_heroScope, 'center'),
                          tooltip: AppLocalizations.of(context)!.recenter,
                          size: commandSize,
                          onPressed: _toggleCenter,
                          icon: Icons.center_focus_strong_rounded,
                        ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _zoomIn() {
    final next = (_mapController.camera.zoom + 1).clamp(
      widget.minZoom,
      widget.maxZoom,
    );
    _mapController.move(_mapController.camera.center, next);
  }

  void _zoomOut() {
    final next = (_mapController.camera.zoom - 1).clamp(
      widget.minZoom,
      widget.maxZoom,
    );
    _mapController.move(_mapController.camera.center, next);
  }

  /// One-shot "locate me" flow. Verifies that location services are on,
  /// requests permission if needed, fetches a single high-accuracy fix,
  /// and recentres the camera with the resulting point. All user-visible
  /// outcomes are surfaced via SnackBar; nothing is logged to the
  /// console. Unexpected errors are forwarded to Sentry (which is a
  /// no-op when the user has opted out of analytics).
  Future<void> _locateMe() async {
    if (_locating) return;
    // Capture localized strings and the messenger up front: the
    // geolocator calls await, and BuildContext is not safe to use
    // across async gaps.
    final l = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _locating = true);

    void show(String message, {SnackBarAction? action}) {
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          showCloseIcon: true,
          dismissDirection: DismissDirection.endToStart,
          content: Text(message),
          action: action,
        ),
      );
    }

    try {
      final servicesOn = await Geolocator.isLocationServiceEnabled();
      if (!servicesOn) {
        show(l.locationServicesDisabled);
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        // openAppSettings is not implemented on web (the browser does
        // not expose a deep-link to its per-site permission page), so
        // showing a Settings button there crashes with UnsupportedError.
        // Offer it only where it actually works; on web the message
        // alone has to be enough — the user has to clear the permission
        // from the browser's URL-bar lock icon manually.
        show(
          l.locationPermissionDeniedForever,
          action: kIsWeb
              ? null
              : SnackBarAction(
                  label: l.settings,
                  onPressed: () => unawaited(Geolocator.openAppSettings()),
                ),
        );
        return;
      }
      if (permission == LocationPermission.denied) {
        show(l.locationPermissionDenied);
        return;
      }

      // Optimistic "looking for you" hint. Cleared by the success path
      // implicitly because that path hides the current snackbar before
      // it would normally time out.
      show(l.locating);

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          // Cap the wait so a stalled GPS does not leave the FAB
          // spinning forever. The widget settles into the "error"
          // branch on timeout and the user can simply try again.
          timeLimit: Duration(seconds: 15),
        ),
      );
      // Geolocator on web can in rare cases hand back NaN coordinates
      // (e.g. when the Geolocation API resolves successfully but the
      // underlying platform has no fix yet). A LatLng with NaN poisons
      // every subsequent projection pass, so treat it as an error.
      if (!position.latitude.isFinite || !position.longitude.isFinite) {
        show(l.locationError);
        return;
      }
      final point = LatLng(position.latitude, position.longitude);
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      setState(() {
        _currentLocation = point;
      });
      _mapController.move(point, widget.locateZoom);
    } on TimeoutException {
      // A stalled GPS fix is an expected outcome (weak signal, slow
      // first fix), not a bug. The user sees the error and can retry,
      // so consume it here instead of forwarding noise to Sentry.
      show(l.locationError);
    } catch (e, stackTrace) {
      show(l.locationError);
      unawaited(Sentry.captureException(e, stackTrace: stackTrace));
    } finally {
      if (mounted) {
        setState(() => _locating = false);
      } else {
        _locating = false;
      }
    }
  }

  /// Recentre the camera so every currently-visible marker fits in view.
  ///
  /// Replaces the old round-robin behaviour (which stepped through markers
  /// one at a time): fitting all visible markers at once is what users
  /// expect from a "centre" control and matches the initial fit.
  void _toggleCenter() {
    final points = widget.markers.map((e) => e.point).toList(growable: false);
    if (points.length < 2) {
      // No extent to fit — recentre on the single marker (or
      // widget.initialCenter, if there are none) and keep the user's
      // current zoom, unlike the initial-fit case, which has no "current
      // zoom" yet to preserve.
      _mapController.move(
        points.average(widget.initialCenter),
        _mapController.camera.zoom,
      );
      return;
    }
    // Same computation _defaultFitFor uses for the initial view (real local
    // viewport, overlay + marker-footprint aware padding), so "centre" and
    // "the view you land on" are provably identical.
    _mapController.fitCamera(_defaultFitFor(context, widget.markers));
  }

  Widget _buildSearchTool(
    BuildContext context,
    BoxConstraints constraints,
    MapCommandSize size,
  ) {
    // Match the field height to the command diameter (40 compact / 56
    // regular) so the search bar and the FABs share one baseline.
    final double searchFieldHeight = size.diameter;
    // Match the tonal command background so the search field reads as part
    // of the same overlay family rather than a differently-coloured card.
    final scheme = Theme.of(context).colorScheme;
    final overlayBackground = MapCommandEmphasis.tonal.background(scheme);
    final overlayForeground = MapCommandEmphasis.tonal.foreground(scheme);
    // Leave room for the search field itself and a small gap below the
    // dropdown so the results never push past the bottom of the map.
    const double bottomGutter = 24;
    final double maxResultsHeight =
        (constraints.maxHeight - searchFieldHeight - bottomGutter).clamp(
          120.0,
          double.infinity,
        );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: searchFieldHeight,
          child: Card(
            margin: EdgeInsets.zero,
            color: overlayBackground,
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: overlayForeground),
              // Centre the text within the fixed-height field instead of
              // letting the baseline float to the top.
              textAlignVertical: TextAlignVertical.center,
              decoration: InputDecoration(
                isCollapsed: true,
                hintText: AppLocalizations.of(
                  context,
                )!.searchForPlaceOrLocation,
                hintMaxLines: 1,
                hintStyle: TextStyle(
                  color: overlayForeground.withValues(alpha: 0.7),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                // Keep the suffix from imposing the default 48 dp height,
                // which would make the field taller than the commands.
                suffixIconConstraints: BoxConstraints(
                  minWidth: searchFieldHeight,
                  minHeight: searchFieldHeight,
                ),
                suffixIcon: _isSearching
                    ? Center(
                        widthFactor: 1,
                        child: SizedBox(
                          height: size.spinnerSize,
                          width: size.spinnerSize,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2.4,
                          ),
                        ),
                      )
                    : IconButton(
                        color: overlayForeground,
                        iconSize: size.iconSize,
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(
                          minWidth: searchFieldHeight,
                          minHeight: searchFieldHeight,
                        ),
                        icon: Icon(
                          _searchController.text.isEmpty
                              ? Icons.search
                              : Icons.clear,
                        ),
                        onPressed: _isSearching
                            ? null
                            : () {
                                if (_searchController.text.isNotEmpty) {
                                  setState(() {
                                    _searchResults.clear();
                                    _searchController.clear();
                                  });
                                }
                              },
                      ),
              ),
              onChanged: (input) {
                if (_isSearching) return;
                _isSearching = true;
                _searchLocationWithThrottle(input);
              },
              onSubmitted: _searchLocation,
            ),
          ),
        ),
        if (_searchResults.isNotEmpty)
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxResultsHeight),
            child: Card(
              // Only a top margin so the results sheet keeps the exact width
              // of the search field (which has zero margin) while still
              // leaving a small gap below it.
              margin: const EdgeInsets.only(top: 6),
              color: overlayBackground,
              clipBehavior: Clip.antiAlias,
              child: Scrollbar(
                controller: _resultsScrollController,
                child: ListView.builder(
                  controller: _resultsScrollController,
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final result = _searchResults.toList()[index];
                    final kind = result.kind;
                    final chipLabel = kind?.label(
                      AppLocalizations.of(context)!,
                    );
                    final hasPosition = result.points.isNotEmpty;
                    final chipText = chipLabel == null
                        ? null
                        // ADR-0037: themed bodySmall so the search-result chip
                        // scales with Dynamic Type instead of a hardcoded 12.
                        : Text(
                            chipLabel,
                            style: Theme.of(context).textTheme.bodySmall,
                          );
                    return ListTile(
                      onTap: () => _onResultTap(result),
                      title: Text(
                        result.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (chipText != null) ...[
                            if (result.onTagTap != null)
                              ActionChip(
                                label: chipText,
                                onPressed: () => result.onTagTap!(result),
                                padding: EdgeInsets.zero,
                                labelPadding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              )
                            else
                              Chip(
                                label: chipText,
                                padding: EdgeInsets.zero,
                                labelPadding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                            const SizedBox(width: 8),
                          ],
                          Icon(
                            hasPosition
                                ? Icons.location_on
                                : Icons.location_off,
                            color: hasPosition
                                ? null
                                : Theme.of(context).colorScheme.outline,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _toggleLayer() {
    setState(() {
      _currentLayerIndex = (_currentLayerIndex + 1) % widget.layers.length;
    });
  }

  // ---------------------------------------------------------------------------
  // Marker layer builders
  // ---------------------------------------------------------------------------

  /// Builds the list of [MarkerLayer] / [MarkerClusterLayerWidget] children
  /// for [FlutterMap]. When [withClustering] is false, all specs go into a
  /// single flat layer. Otherwise, null-group specs get a flat layer and each
  /// non-null group gets its own [MarkerClusterLayerWidget].
  /// Visual scale applied to marker icons and labels per window-size class.
  /// On compact phones the base size is right; on the larger maps shown at
  /// medium/expanded widths the 32 dp icon and small label read as too tiny,
  /// so they are bumped to keep pace with the bigger canvas (and the larger
  /// FAB controls, which already scale via [MapCommandSize]). Takes the
  /// real local [viewport] (not `WindowSizeClass.of(context)`'s full-window
  /// read) and delegates to [MapConfig.markerScaleFor] so
  /// [MapConfig.fitPadding]'s footprint reserve can never drift from what
  /// actually renders here, in this MapView's own space.
  double _markerScaleFor(Size viewport) =>
      MapConfig.markerScaleFor(WindowSizeClass.fromWidth(viewport.width));

  /// True once per app session, after the first non-finite marker has been
  /// reported to Sentry. Subsequent drops are silent so a single bad row
  /// cannot flood the issue tracker on every rebuild.
  static bool _nonFiniteMarkerReported = false;

  void _reportNonFiniteMarker(MapMarkerSpec<K> spec) {
    if (_nonFiniteMarkerReported) return;
    _nonFiniteMarkerReported = true;
    unawaited(
      Sentry.captureMessage(
        'MapView dropped non-finite marker',
        level: SentryLevel.warning,
        withScope: (scope) {
          scope.setTag('marker.id', '${spec.id}');
          scope.setTag('marker.label', spec.label);
          scope.setTag('marker.point', '${spec.point}');
          scope.setTag('marker.clusterGroup', '${spec.clusterGroup}');
        },
      ),
    );
  }

  List<Widget> _buildMarkerLayers(Size viewport) {
    if (widget.markers.isEmpty) return const [];

    // Last-line defence against non-finite points reaching flutter_map. A
    // single NaN [LatLng] makes [MarkerLayer.build] throw, which takes the
    // whole map subtree down and cascades into gesture/rebuild handlers
    // (see the 5x-Sentry-issue bundle around commit 5e7cff0). Producers
    // already filter with [LatLngFiniteX], but a future call-site that
    // forgets must not be able to crash the map. The first drop per
    // session is reported to Sentry so we can track where the bad point
    // came from.
    final specs = <MapMarkerSpec<K>>[];
    for (final s in widget.markers) {
      if (s.point.latitude.isFinite && s.point.longitude.isFinite) {
        specs.add(s);
      } else {
        _reportNonFiniteMarker(s);
      }
    }
    if (specs.isEmpty) return const [];

    final scale = _markerScaleFor(viewport);

    if (!widget.withClustering) {
      return [
        MarkerLayer(markers: specs.map((s) => _buildMarker(s, scale)).toList()),
      ];
    }

    final nullGroup = <MapMarkerSpec<K>>[];
    final groups = <Object, List<MapMarkerSpec<K>>>{};
    for (final spec in specs) {
      if (spec.clusterGroup == null) {
        nullGroup.add(spec);
      } else {
        groups.putIfAbsent(spec.clusterGroup!, () => []).add(spec);
      }
    }

    return [
      if (nullGroup.isNotEmpty)
        MarkerLayer(
          markers: nullGroup.map((s) => _buildMarker(s, scale)).toList(),
        ),
      for (final entry in groups.entries)
        _buildClusterLayer(entry.key, entry.value, scale),
    ];
  }

  Marker _buildMarker(MapMarkerSpec<K> spec, double scale) {
    final painter = TextPainter(
      text: TextSpan(text: spec.label),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    return Marker(
      height: 64 * scale,
      width: math.max(80.0, painter.width) * scale,
      point: spec.point,
      // `Alignment.topCenter` here means flutter_map pins the *bottom* edge
      // of this box to the geographic point and lets the box hang upward
      // from there (verified against flutter_map's MarkerLayer offset
      // maths) — i.e. the box's bottom edge is the true anchor, not its
      // top. `spec.child` is conventionally a pin-style icon (e.g.
      // Icons.place) whose visual tip sits at the bottom of its own
      // bounds, and it is the LAST child of the Column below, so it must
      // be flush with that bottom edge — not left dangling above it by
      // whatever the label slot's height happens to be.
      alignment: Alignment.topCenter,
      child: GestureDetector(
        behavior: HitTestBehavior.deferToChild,
        onTap: spec.onTap,
        // Scale around the bottom — where the anchor and the icon both
        // live — not the top, so scaling never shifts the icon relative
        // to the geographic point; only the label above it grows/shrinks.
        child: Transform.scale(
          scale: scale,
          alignment: Alignment.bottomCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            // Pack children against the bottom of the box (the anchor),
            // not the top, so the icon (last child) sits flush with the
            // geographic point regardless of the label slot's height.
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _ZoomGatedLabel(
                label: spec.label,
                shortLabel: spec.shortLabel,
                showLabels: widget.showLabels,
              ),
              spec.child,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClusterLayer(
    Object group,
    List<MapMarkerSpec<K>> specs,
    double scale,
  ) {
    final style = widget.clusterStyles[group];
    final color = style?.color;
    final onColor = style?.onColor;
    // Grow the cluster badge with the same window-size scale as the markers it
    // stands in for, so it does not look tiny on the larger medium/expanded
    // maps.
    final baseSize = style?.size ?? const Size(40, 40);
    final size = Size(baseSize.width * scale, baseSize.height * scale);

    // Build the markers once and remember which of the resulting Marker
    // instances came from a highlighted spec. The cluster builder is handed
    // back the exact same Marker instances, so an identity lookup tells us
    // whether the cluster contains any highlighted marker.
    final markers = <Marker>[];
    final highlightedMarkers = <Marker>{};
    for (final spec in specs) {
      final marker = _buildMarker(spec, scale);
      markers.add(marker);
      if (spec.highlighted) highlightedMarkers.add(marker);
    }

    return MarkerClusterLayerWidget(
      options: MarkerClusterLayerOptions(
        maxClusterRadius: 45,
        size: size,
        padding: const EdgeInsets.all(50),
        maxZoom: 17,
        markers: markers,
        markerChildBehavior: true,
        builder: (context, clusterMarkers) {
          final scheme = Theme.of(context).colorScheme;
          // A cluster is "active" when at least one of the markers it groups
          // is highlighted, so a zoomed-out group reads as live whenever any
          // single station inside it is live.
          final isActive = clusterMarkers.any(highlightedMarkers.contains);
          final bgColor = isActive
              ? (style?.activeColor ?? color ?? scheme.primary)
              : (color ?? scheme.primary);
          final fgColor = isActive
              ? (style?.activeOnColor ?? style?.onColor ?? scheme.onPrimary)
              : (onColor ?? scheme.onPrimary);
          // Match the map-overlay language used by the FABs: a Material circle
          // at the same low (tonal) elevation. The soft shadow lifts the badge
          // off the busy topo map without the heavy ring a border drew.
          return Material(
            color: bgColor,
            elevation: 1,
            shape: const CircleBorder(),
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: Center(
                child: Text(
                  '${clusterMarkers.length}',
                  style: TextStyle(
                    color: fgColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14 * scale,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _searchLocationWithThrottle(String input) {
    if (_throttleTimer?.isActive ?? false) {
      _throttleTimer!.cancel(); // Cancel any ongoing throttle action
    }

    // Delay the search by 300ms (adjust duration as needed)
    _throttleTimer = Timer(const Duration(milliseconds: 50), () {
      // Perform the search when throttle time ends
      _searchLocation(input);
    });
  }

  Future<void> _searchLocation(String value) async {
    // Capture localized strings up front: the nominatim call awaits, and
    // BuildContext is not safe to use across async gaps.
    final l = AppLocalizations.of(context)!;
    setState(() {
      _searchResults.clear();
    });

    final input = value.trim();
    if (input.isEmpty) {
      _isSearching = false;
      return;
    }

    try {
      // Coordinate input — a decimal lat,lng pair or a UTM string, including
      // the app's own "…E …N" display format — is parsed by the shared
      // parseCoordinateInput (bounds-checked, NaN-guarded). A null result
      // falls through to the search targets and the geocoder below.
      final coordinate = parseCoordinateInput(input);
      if (coordinate != null) {
        _mapController.move(coordinate, _mapController.camera.zoom);
        setState(() {
          _isSearching = false;
        });
        return;
      }

      // Try search targets supplied by the parent (e.g. stations and
      // exercises). Targets may not have a position; they are still
      // surfaced so the user can find them by name. The semantic kind
      // is matched via its localized label in the active locale, so
      // typing the chip text ("Post" / "Øvelse" in nb, "Station" /
      // "Exercise" in en) yields every result of that kind.
      if (widget.searchTargets.isNotEmpty) {
        final needle = input.trim().toLowerCase();
        final found = widget.searchTargets.where((t) {
          if (t.name.toLowerCase().contains(needle)) return true;
          final kind = t.kind;
          return kind != null && kind.label(l).toLowerCase().contains(needle);
        }).toList();
        if (found.isNotEmpty) {
          setState(() {
            _searchResults.addAll(found);
          });
        }
      }

      // Try geocoding via the shared geocoder.
      final hits = await _geocoder.search(
        input.trim(),
        near: _mapController.camera.center,
      );

      setState(() {
        _isSearching = false;
        if (hits.isNotEmpty) {
          _searchResults.addAll(
            hits.map(
              (h) => SearchResult(
                h.label,
                h.position,
                kind: SearchResultKind.place,
              ),
            ),
          );
        }
      });
    } catch (e, stackTrace) {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
        unawaited(Sentry.captureException(e, stackTrace: stackTrace));
      }
    }
  }

  void _onResultTap(SearchResult result) {
    // Parent-provided behaviour wins; fall back to the default move/fit.
    final onSelect = result.onSelect;
    if (onSelect != null) {
      onSelect(result);
    } else if (result.points.length >= 2) {
      // Centre on the geometric mean (centroid) of all the points, while
      // still zooming out enough to include every point. Padding is
      // overlay-aware so the centroid does not land underneath the bottom
      // FAB column.
      final fit = MapConfig.fitFor(
        result.points,
        withSearch: widget.withSearch,
        withZoom: widget.withZoom,
        withCenter: widget.withCenter,
        withLocate: widget.withLocate,
        viewport: _effectiveViewport(context),
        // No per-point labels here — a SearchResult's points are camera
        // targets, not rendered markers of their own, so there is no label
        // footprint to reserve for (unlike widget.markers in _toggleCenter).
      );
      _mapController.fitCamera(fit);
    } else if (result.location != null) {
      // Snap to at least [resultZoom] so the marker leaves its cluster, but
      // keep a closer zoom if the user already had one.
      final targetZoom = math.max(
        _mapController.camera.zoom,
        widget.resultZoom,
      );
      _mapController.move(result.location!, targetZoom);
    } else {
      // No location available – let the user know rather than silently
      // doing nothing.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          showCloseIcon: true,
          dismissDirection: DismissDirection.endToStart,
          content: Text(AppLocalizations.of(context)!.noLocation),
        ),
      );
    }
    setState(() {
      _searchResults.clear();
      _searchController.text = result.name;
    });
  }

  @override
  void dispose() {
    MapSettings.instance.showZoomControls.removeListener(_onMapSettingsChanged);
    _throttleTimer?.cancel();
    _resultsScrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}

// Kept just shy of fully opaque so the label still reads as a soft
// overlay without washing out against the map. Labels can be toggled
// off entirely (the "show labels" filter), so when they are shown we
// can afford near-full opacity for legibility. Affects background and
// text together; the pin underneath stays fully opaque.
class FeatureLabel extends StatelessWidget {
  const FeatureLabel({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.9,
      child: Material(
        elevation: 2,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(1.0),
          // ADR-0037: themed bodySmall so the map overlay label scales with
          // Dynamic Type. Growth is bounded by the app-root 1.3 clamp, so it
          // cannot crowd the map at the largest accessibility sizes. The
          // marker itself is scaled up on wider layouts via Transform.scale
          // in _buildMarker, which grows this label in step.
          child: Text(text, style: Theme.of(context).textTheme.bodySmall),
        ),
      ),
    );
  }
}

// Helper class to represent search results.
//
// A result may have:
//   * one point – classic place/coordinate match (panned to)
//   * many points – e.g. an exercise's stations (the camera fits them)
//   * no points – named entity without coordinates (a snackbar is shown
//     unless the parent provides [onSelect] to handle the tap)
/// Semantic type of a [SearchResult]. The rendered chip label and the
/// text used for matching are both derived from the active locale via
/// [label] – callers never embed localized strings into the search
/// model itself.
enum SearchResultKind {
  exercise,
  station,
  place;

  String label(AppLocalizations l) => switch (this) {
    SearchResultKind.exercise => l.searchHintExercise,
    SearchResultKind.station => l.searchHintStation,
    SearchResultKind.place => l.searchHintPlace,
  };
}

class SearchResult {
  final String name;

  /// Semantic type of the result. When non-null, the chip rendered in
  /// the result row uses the localized label for [kind] and the search
  /// matcher checks the needle against that same localized label in the
  /// active locale.
  final SearchResultKind? kind;

  /// Zero or more points associated with the result. Empty when the
  /// underlying entity has no known location.
  final List<LatLng> points;

  /// Optional override for what should happen when the user taps the
  /// result. When provided, the default move/fit behaviour is skipped.
  final void Function(SearchResult result)? onSelect;

  /// Optional callback invoked when the user taps the chip itself
  /// (rather than the row). Lets the parent attach a separate action
  /// to the type — e.g. always opening the station detail page from
  /// the "Post" chip, regardless of what the row tap does.
  final void Function(SearchResult result)? onTagTap;

  SearchResult(
    String name,
    LatLng location, {
    SearchResultKind? kind,
    void Function(SearchResult)? onSelect,
    void Function(SearchResult)? onTagTap,
  }) : this.points(
         name,
         [location],
         kind: kind,
         onSelect: onSelect,
         onTagTap: onTagTap,
       );

  const SearchResult.points(
    this.name,
    this.points, {
    this.kind,
    this.onSelect,
    this.onTagTap,
  });

  LatLng? get location => points.isEmpty ? null : points.first;

  @override
  String toString() {
    return 'SearchResult{name: $name, points: ${points.length}, kind: $kind}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SearchResult &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          kind == other.kind &&
          _listEquals(points, other.points);

  @override
  int get hashCode => Object.hash(name, kind, Object.hashAll(points));

  static bool _listEquals(List<LatLng> a, List<LatLng> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Non-interactive blue dot used to mark the user's resolved position
/// from the locate-me FAB. Kept visually distinct from the green station
/// pins so an observer can tell at a glance "this is *me*" vs. "this is
/// a station." Sized to read at the same density as a standard Material
/// FAB; the halo gives a small target area for visual scanning without
/// hijacking taps from underlying markers.
class _CurrentLocationDot extends StatelessWidget {
  const _CurrentLocationDot();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.blueAccent.withValues(alpha: 0.25),
        ),
        alignment: Alignment.center,
        child: Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.blueAccent,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Zoom-gated label slot rendered above each marker icon.
///
/// Returns [SizedBox.shrink] only when [showLabels] is false (a persistent
/// filter toggle, not something that changes mid-gesture). Otherwise it
/// always reserves [FeatureLabel]'s full footprint and only fades its
/// *opacity* in/out via [AnimatedOpacity] as the camera zoom crosses the
/// layout-class threshold ([MapConfig.labelMinZoomFor]), so wider windows
/// reveal labels at a more zoomed-out overview than compact phones.
///
/// Deliberately does NOT collapse to zero size below the zoom threshold
/// (an earlier version did, via a second `SizedBox.shrink()` branch). The
/// marker's [Marker.height] is a fixed constant independent of the label —
/// flutter_map anchors the whole box to the geographic point using that
/// fixed height and `Alignment.topCenter` — so if this label's own layout
/// size changed with zoom, [_buildMarker]'s icon would shift within the
/// (unchanged) box exactly at the zoom threshold, i.e. visibly drift
/// relative to the map underneath as the label fades in/out. Reserving a
/// constant size and only animating opacity keeps the icon's on-screen
/// offset from the anchor point fixed at every zoom level.
///
/// Reads the current zoom via [MapCamera.of] so it rebuilds automatically
/// when the camera moves. Must be used inside a [FlutterMap] subtree.
///
/// When [shortLabel] is set, the rendered text itself is also zoom-tiered:
/// [shortLabel] (e.g. a station's plan number) from [MapConfig
/// .labelMinZoomFor] up, switching to the full [label] once the camera
/// reaches [MapConfig.labelDetailZoomFor] — see that constant's doc for why.
/// A null [shortLabel] always renders [label], as before. The switch is a
/// content change, not a size change (the marker's box width already
/// accommodates the longer of the two, measured in [_buildMarker]), so it
/// does not trip the "no layout shift" concern above.
class _ZoomGatedLabel extends StatelessWidget {
  const _ZoomGatedLabel({
    required this.label,
    this.shortLabel,
    required this.showLabels,
  });

  final String label;
  final String? shortLabel;
  final bool showLabels;

  @override
  Widget build(BuildContext context) {
    if (!showLabels) return const SizedBox.shrink();
    final zoom = MapCamera.of(context).zoom;
    // Deliberately WindowSizeClass.of(context) (full window), not
    // MapCamera.of(context).nonRotatedSize.width (local map pane) — tried
    // the latter on the theory that this was the same "local pane vs. full
    // window" mismatch ADR-0053 fixed elsewhere, but confirmed wrong
    // on-device: it made every form factor land on the compact ("10 m")
    // threshold, because nonRotatedSize starts at MapCamera.kImpossibleSize
    // (literally negative infinity — see flutter_map's own camera.dart)
    // before the first real layout pass, and this widget's InheritedWidget
    // dependency kept resolving to that placeholder rather than the real,
    // later-updated size. The actual "labels only appear at 10 m on
    // compact" bug was unrelated to this read and lived in
    // labelDetailZoomFor's cap against defaultAutoFitMaxZoom (see that
    // doc comment) — fixed there, not here.
    final sizeClass = WindowSizeClass.of(context);
    final minZoom = MapConfig.labelMinZoomFor(sizeClass);
    final opacity = zoom >= minZoom
        ? 1.0
        : (zoom - (minZoom - 1)).clamp(0.0, 1.0);
    final short = shortLabel;
    final text =
        (short == null || zoom >= MapConfig.labelDetailZoomFor(sizeClass))
        ? label
        : short;
    return AnimatedOpacity(
      opacity: opacity,
      duration: const Duration(milliseconds: 200),
      child: FeatureLabel(text: text),
    );
  }
}
