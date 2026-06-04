import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:osm_nominatim/osm_nominatim.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/utils/latlng_utils.dart';
import 'package:ringdrill/utils/projection.dart';
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
    this.clusterGroup,
    this.highlighted = false,
    this.onTap,
  });

  final K id;
  final String label;
  final LatLng point;

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
  /// [labelMinZoom] - 1 and [labelMinZoom] via [AnimatedOpacity].
  static const double labelMinZoom = 14.0;

  /// Padding used when calling [MapController.fitCamera] so the fit
  /// honours the on-map overlays. Because [MapController.fitCamera]
  /// places the bounds *center* into the centre of the padded area,
  /// asymmetric padding directly shifts where the centroid lands on
  /// screen: a larger bottom padding pulls the camera so the centroid
  /// appears higher in the visible area, compensating for the FAB
  /// column at the bottom-right of the map.
  ///
  /// Horizontal padding stays the same regardless of overlays; it is
  /// kept generous (64 px) on purpose so the outermost markers do not
  /// hug the screen edges after a fit. A tighter value zoomed the
  /// camera further than the data's natural extent warranted, which
  /// made re-fits after toggling visibility feel cramped.
  static EdgeInsets fitPadding({
    bool withSearch = false,
    bool withZoom = false,
    bool withCenter = false,
    bool withLocate = false,
  }) {
    // The bottom-right FAB column can host up to four buttons (locate,
    // zoom in, zoom out, centre). 200 px clears the zoom+centre stack;
    // adding the locate FAB on top pushes the column another ~68 px so
    // we bump the bottom inset to keep the centroid above the controls.
    final double bottom = (withZoom || withCenter || withLocate)
        ? (withLocate ? 268 : 200)
        : 48;
    return EdgeInsets.fromLTRB(64, withSearch ? 112 : 48, 64, bottom);
  }

  // Important! TileLayers are widgets! We need to get new layers
  // each time since we can not share them across multiple
  // FlutterMap instances (map may not show correctly)
  static List<TileLayer> get layers => [topoLayer, topoGrayLayer];

  // Important! We need to get new layers each time. See above!
  static TileLayer get topoGrayLayer => TileLayer(
    key: const ValueKey('topo-gray'),
    urlTemplate:
        'https://cache.kartverket.no/v1/wmts/1.0.0/topograatone/default/webmercator/{z}/{y}/{x}.png',
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
    this.initialZoom = 15,
    this.minZoom = 2,
    this.maxZoom = 19,
    this.markers = const [],
    this.clusterStyles = const {},
    this.showLabels = true,
    this.withClustering = true,
    this.searchTargets = const [],
    this.topRightCommands = const [],
    this.initialFit,
    this.interactionFlags = MapConfig.static,
    this.initialCenter = MapConfig.initialCenter,
    this.onTap,
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
  final double initialZoom;
  final double minZoom;
  final double maxZoom;
  final LatLng initialCenter;
  final int interactionFlags;
  final CameraFit? initialFit;
  final TapCallback? onTap;
  final MapController? controller;
  final List<TileLayer> layers;

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

  @override
  State<MapView<K>> createState() => _MapViewState();
}

class _MapViewState<K> extends State<MapView<K>> {
  late MapController _mapController;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _resultsScrollController = ScrollController();
  final Set<SearchResult> _searchResults = {};

  Timer? _throttleTimer;
  bool _isSearching = false;
  int _currentLayerIndex = 0;
  int _currentCenterIndex = 0;

  /// Last known device position resolved by the locate-me FAB. Null until
  /// the user has successfully located themselves at least once during
  /// this session. Survives layer toggles but resets on widget rebuild
  /// from scratch.
  LatLng? _currentLocation;

  /// Set while a one-shot location request is in flight so a second tap
  /// on the FAB does not stack requests. The FAB swaps its icon for a
  /// spinner while this is true.
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _mapController = widget.controller ?? MapController();
    _initCurrentIndex();
  }

  @override
  void didUpdateWidget(covariant MapView<K> oldWidget) {
    if (oldWidget != widget) {
      if (widget.controller != null && _mapController != widget.controller) {
        _mapController = widget.controller!;
      }
      if (widget.initialCenter != oldWidget.initialCenter) {
        _initCurrentIndex();
        _mapController.move(widget.initialCenter, _mapController.camera.zoom);
      }
      if (widget.initialZoom != oldWidget.initialZoom) {
        _initCurrentIndex();
        _mapController.move(_mapController.camera.center, widget.initialZoom);
      }
      if (widget.initialFit != null &&
          widget.initialFit != oldWidget.initialFit) {
        _initCurrentIndex();
        _mapController.fitCamera(widget.initialFit!);
      }
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    final withToggle = widget.withToggle && widget.layers.length > 1;
    final hasTopRightColumn = withToggle || widget.topRightCommands.isNotEmpty;
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialZoom: widget.initialZoom,
                initialCenter: widget.initialCenter,
                initialCameraFit: widget.initialFit,
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
                ..._buildMarkerLayers(),
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
                Scalebar(alignment: Alignment.bottomLeft),
              ],
            ),
            if (widget.withCross)
              IgnorePointer(
                child: Center(
                  child: Transform.rotate(
                    angle: 45 * math.pi / 180,
                    child: Icon(
                      Icons.close,
                      size: 40,
                      color: Colors.red.withValues(alpha: 0.65),
                    ),
                  ),
                ),
              ),
            if (widget.withSearch)
              // Search Results (Dropdown-like List)
              Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: constraints.maxWidth - (hasTopRightColumn ? 66 : 0),
                  child: _buildSearchTool(context, constraints),
                ),
              ),
            if (hasTopRightColumn)
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(
                    10.0,
                  ).copyWith(top: 16.0), // Add some spacing
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (withToggle)
                        FloatingActionButton(
                          heroTag: 'layers',
                          onPressed: _toggleLayer,
                          child: const Icon(
                            Icons.layers,
                          ), // Layer icon for better context
                        ),
                      for (
                        var i = 0;
                        i < widget.topRightCommands.length;
                        i++
                      ) ...[
                        if (i > 0 || withToggle) const SizedBox(height: 8),
                        widget.topRightCommands[i],
                      ],
                    ],
                  ),
                ),
              ),
            if (widget.withCenter || widget.withZoom || widget.withLocate)
              Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (widget.withLocate) ...[
                        FloatingActionButton(
                          heroTag: 'locate',
                          tooltip: AppLocalizations.of(context)!.locateMe,
                          onPressed: _locating ? null : _locateMe,
                          child: _locating
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                  ),
                                )
                              : const Icon(Icons.my_location),
                        ),
                        if (widget.withZoom || widget.withCenter)
                          const SizedBox(height: 12),
                      ],
                      if (widget.withZoom) ...[
                        FloatingActionButton(
                          heroTag: 'zoomIn',
                          tooltip: AppLocalizations.of(context)!.zoomIn,
                          onPressed: _zoomIn,
                          child: const Icon(Icons.add),
                        ),
                        const SizedBox(height: 8),
                        FloatingActionButton(
                          heroTag: 'zoomOut',
                          tooltip: AppLocalizations.of(context)!.zoomOut,
                          onPressed: _zoomOut,
                          child: const Icon(Icons.remove),
                        ),
                        if (widget.withCenter) const SizedBox(height: 12),
                      ],
                      if (widget.withCenter)
                        FloatingActionButton(
                          heroTag: 'center',
                          onPressed: _toggleCenter,
                          child: const Icon(Icons.center_focus_strong_rounded),
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

  void _toggleCenter() {
    if (widget.markers.isEmpty) {
      _mapController.move(widget.initialCenter, _mapController.camera.zoom);
      return;
    }

    // Do not toggle to same initial center if exists in markers
    final unique = !widget.markers.any((e) => e.point == widget.initialCenter);

    _currentCenterIndex =
        (_currentCenterIndex + 1) % (widget.markers.length + (unique ? 1 : 0));

    final point = _currentCenterIndex == 0
        ? widget.initialCenter
        : widget.markers[_currentCenterIndex - (unique ? 1 : 0)].point;

    debugPrint((_currentCenterIndex, point).toString());

    _mapController.move(point, _mapController.camera.zoom);
  }

  Widget _buildSearchTool(BuildContext context, BoxConstraints constraints) {
    // Leave room for the search field itself (88) and a small gap below the
    // dropdown so the results never push past the bottom of the map.
    const double searchFieldHeight = 88;
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
            child: Padding(
              padding: const EdgeInsets.all(8.0).copyWith(left: 8, top: 12),
              child: Center(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(
                      context,
                    )!.searchForPlaceOrLocation,
                    hintMaxLines: 1,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 10,
                    ),
                    suffixIcon: _isSearching
                        ? Transform.scale(
                            scale: 0.6,
                            child: SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(),
                            ),
                          )
                        : IconButton(
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
          ),
        ),
        if (_searchResults.isNotEmpty)
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxResultsHeight),
            child: Card(
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
                        : Text(chipLabel, style: const TextStyle(fontSize: 12));
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

  void _initCurrentIndex() {
    int i = 0;
    _currentCenterIndex = 0;
    for (final it in widget.markers) {
      if (it.point == widget.initialCenter) {
        _currentCenterIndex = i;
        return;
      }
      i++;
    }
  }

  // ---------------------------------------------------------------------------
  // Marker layer builders
  // ---------------------------------------------------------------------------

  /// Builds the list of [MarkerLayer] / [MarkerClusterLayerWidget] children
  /// for [FlutterMap]. When [withClustering] is false, all specs go into a
  /// single flat layer. Otherwise, null-group specs get a flat layer and each
  /// non-null group gets its own [MarkerClusterLayerWidget].
  List<Widget> _buildMarkerLayers() {
    if (widget.markers.isEmpty) return const [];

    if (!widget.withClustering) {
      return [
        MarkerLayer(
          markers: widget.markers.map(_buildMarker).toList(),
        ),
      ];
    }

    final nullGroup = <MapMarkerSpec<K>>[];
    final groups = <Object, List<MapMarkerSpec<K>>>{};
    for (final spec in widget.markers) {
      if (spec.clusterGroup == null) {
        nullGroup.add(spec);
      } else {
        groups.putIfAbsent(spec.clusterGroup!, () => []).add(spec);
      }
    }

    return [
      if (nullGroup.isNotEmpty)
        MarkerLayer(markers: nullGroup.map(_buildMarker).toList()),
      for (final entry in groups.entries)
        _buildClusterLayer(entry.key, entry.value),
    ];
  }

  Marker _buildMarker(MapMarkerSpec<K> spec) {
    final painter = TextPainter(
      text: TextSpan(text: spec.label),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    return Marker(
      height: 64,
      width: math.max(80.0, painter.width),
      point: spec.point,
      alignment: Alignment.topCenter,
      child: GestureDetector(
        behavior: HitTestBehavior.deferToChild,
        onTap: spec.onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _ZoomGatedLabel(label: spec.label, showLabels: widget.showLabels),
            spec.child,
          ],
        ),
      ),
    );
  }

  Widget _buildClusterLayer(Object group, List<MapMarkerSpec<K>> specs) {
    final style = widget.clusterStyles[group];
    final color = style?.color;
    final onColor = style?.onColor;
    final size = style?.size ?? const Size(40, 40);

    // Build the markers once and remember which of the resulting Marker
    // instances came from a highlighted spec. The cluster builder is handed
    // back the exact same Marker instances, so an identity lookup tells us
    // whether the cluster contains any highlighted marker.
    final markers = <Marker>[];
    final highlightedMarkers = <Marker>{};
    for (final spec in specs) {
      final marker = _buildMarker(spec);
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
          return Container(
            width: size.width,
            height: size.height,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: bgColor,
            ),
            child: Center(
              child: Text(
                '${clusterMarkers.length}',
                style: TextStyle(
                  color: fgColor,
                  fontWeight: FontWeight.bold,
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
      // Try parsing LatLng
      if (input.contains(",")) {
        final parts = input.split(",");
        final lat = double.tryParse(parts[0]);
        final lon = double.tryParse(parts[1]);
        if (lat != null && lon != null && lat.isFinite && lon.isFinite) {
          final result = LatLng(lat, lon);
          _mapController.move(result, _mapController.camera.zoom);
          setState(() {
            _isSearching = false;
          });
          return;
        }
      }

      // Try parsing UTM using coordinate_converter. proj4dart can hand
      // back NaN on near-singular inputs, which would crash flutter_map
      // the moment it tries to project the result. Drop those silently
      // and let the geocoder branch have a shot at the same query.
      final result = input.toLatLngFromUtm();
      if (result != null &&
          result.latitude.isFinite &&
          result.longitude.isFinite) {
        _mapController.move(result, _mapController.camera.zoom);
        setState(() {
          _isSearching = false;
        });
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

      // Try geocoding via osm_nominatim
      final nominatim = Nominatim(userAgent: 'discoos.org/ringdrill');
      final results = await nominatim.searchByName(
        limit: 5,
        query: '${input.trim()},',
        nameDetails: true,
        addressDetails: true,
        viewBox: _createViewBoxFromLatLng(_mapController.camera.center, 1000),
      );

      setState(() {
        _isSearching = false;
        if (results.isNotEmpty) {
          _searchResults.addAll(
            results.map(
              (r) => SearchResult(
                _formatPlace(r),
                LatLng(r.lat, r.lon),
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

  ViewBox _createViewBoxFromLatLng(LatLng center, double radiusInKm) {
    const double earthRadiusKm = 6371.0; // Radius of the Earth in kilometers

    // Convert latitude and longitude to radians
    final double lat = center.latitude * pi / 180;
    final double lng = center.longitude * pi / 180;

    // Calculate degree offsets for the given radius
    final double latOffset = radiusInKm / earthRadiusKm;
    final double lngOffset = radiusInKm / (earthRadiusKm * math.cos(lat));

    // Calculate raw ViewBox boundaries in degrees
    double northLatitude = (lat + latOffset) * 180 / pi;
    double southLatitude = (lat - latOffset) * 180 / pi;
    double eastLongitude = (lng + lngOffset) * 180 / pi;
    double westLongitude = (lng - lngOffset) * 180 / pi;

    // Clamp latitudes and longitudes to valid range
    northLatitude = northLatitude.clamp(-90.0, 90.0);
    southLatitude = southLatitude.clamp(-90.0, 90.0);
    eastLongitude = eastLongitude.clamp(-180.0, 180.0);
    westLongitude = westLongitude.clamp(-180.0, 180.0);

    // Return the bounding box (north, south, east, west)
    return ViewBox(northLatitude, southLatitude, eastLongitude, westLongitude);
  }

  String _formatPlace(Place result) {
    if (result.address == null) return _formatNameDetails(result);

    // Check if this is a place (not an address)
    if (result.address?['road'] == null &&
        result.address?['house_number'] == null) {
      return _formatNameDetails(result);
    }

    // Otherwise, it's an address – extract specific fields
    final addressParts = <String>[
      [
        result.address?['road'] ?? '', // Street
        result.address?['house_number'] ?? '',
      ].join(' '), // Street number
      [
        result.address?['postcode'] ?? '', // Postal code
        result.address?['city'] ??
            result.address?['town'] ??
            result.address?['village'] ??
            '',
      ].join(' '),
    ];

    return addressParts.where((part) => part.isNotEmpty).join(', ');
  }

  String _formatNameDetails(Place result) {
    // Combine place details into a single formatted string
    return result.displayName;
  }

  void _onResultTap(SearchResult result) {
    // Parent-provided behaviour wins; fall back to the default move/fit.
    final onSelect = result.onSelect;
    if (onSelect != null) {
      onSelect(result);
    } else if (result.points.length >= 2) {
      // Centre on the geometric mean (centroid) of all the points, while
      // still zooming out enough to include every point. Falls back to
      // the bounding-box fit if the points happen to coincide. Padding
      // is overlay-aware so the centroid does not land underneath the
      // bottom FAB column.
      final padding = MapConfig.fitPadding(
        withSearch: widget.withSearch,
        withZoom: widget.withZoom,
        withCenter: widget.withCenter,
        withLocate: widget.withLocate,
      );
      final fit =
          result.points.centroidFit(padding) ??
          CameraFit.coordinates(padding: padding, coordinates: result.points);
      _mapController.fitCamera(fit);
    } else if (result.location != null) {
      _mapController.move(result.location!, _mapController.camera.zoom);
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
    _throttleTimer?.cancel();
    _resultsScrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}

// Slightly translucent so the label does
// not dominate when multiple markers sit
// close together. Affects background and
// text together; the pin underneath stays
// fully opaque.
class FeatureLabel extends StatelessWidget {
  const FeatureLabel({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.55,
      child: Material(
        elevation: 2,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(1.0),
          child: Text(text, style: const TextStyle(fontSize: 12)),
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
/// Returns [SizedBox.shrink] when [showLabels] is false or when the camera
/// zoom is below [MapConfig.labelMinZoom] - 1. Between that threshold and
/// [MapConfig.labelMinZoom] the label fades in via [AnimatedOpacity].
///
/// Reads the current zoom via [MapCamera.of] so it rebuilds automatically
/// when the camera moves. Must be used inside a [FlutterMap] subtree.
class _ZoomGatedLabel extends StatelessWidget {
  const _ZoomGatedLabel({required this.label, required this.showLabels});

  final String label;
  final bool showLabels;

  @override
  Widget build(BuildContext context) {
    if (!showLabels) return const SizedBox.shrink();
    final zoom = MapCamera.of(context).zoom;
    const minZoom = MapConfig.labelMinZoom;
    if (zoom < minZoom - 1) return const SizedBox.shrink();
    final opacity = zoom >= minZoom
        ? 1.0
        : (zoom - (minZoom - 1)).clamp(0.0, 1.0);
    return AnimatedOpacity(
      opacity: opacity,
      duration: const Duration(milliseconds: 200),
      child: FeatureLabel(text: label),
    );
  }
}
