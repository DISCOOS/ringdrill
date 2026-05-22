import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:osm_nominatim/osm_nominatim.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/utils/latlng_utils.dart';
import 'package:ringdrill/utils/projection.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

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

  /// Padding used when calling [MapController.fitCamera] so the fit
  /// honours the on-map overlays. Because [MapController.fitCamera]
  /// places the bounds *center* into the centre of the padded area,
  /// asymmetric padding directly shifts where the centroid lands on
  /// screen: a larger bottom padding pulls the camera so the centroid
  /// appears higher in the visible area, compensating for the FAB
  /// column at the bottom-right of the map.
  static EdgeInsets fitPadding({
    bool withSearch = false,
    bool withZoom = false,
    bool withCenter = false,
  }) {
    return EdgeInsets.fromLTRB(
      24,
      withSearch ? 112 : 24,
      24,
      (withZoom || withCenter) ? 200 : 24,
    );
  }

  // Important! TileLayers are widgets! We need to get new layers
  // each time since we can not share them across multiple
  // FlutterMap instances (map may not show correctly)
  static List<TileLayer> get layers => [topoLayer, osmLayer];

  // Important! We need to get new layers each time. See above!
  static TileLayer get osmLayer => TileLayer(
    key: ValueKey('osm'),
    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    userAgentPackageName: 'discoos.org/ringdrill',
    subdomains: [],
  );

  // Important! We need to get new layers each time. See above!
  static TileLayer get topoLayer => TileLayer(
    key: ValueKey('topo'),
    urlTemplate:
        'https://cache.kartverket.no/v1/wmts/1.0.0/topo/default/webmercator/{z}/{y}/{x}.png',
    subdomains: [],
    userAgentPackageName: 'discoos.org/ringdrill',
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
    this.initialZoom = 15,
    this.minZoom = 2,
    this.maxZoom = 19,
    this.markers = const [],
    this.searchTargets = const [],
    this.initialFit,
    this.interactionFlags = MapConfig.static,
    this.initialCenter = MapConfig.initialCenter,
    this.onTap,
    this.onMarkerTap,
  });

  final bool withCross;
  final bool withSearch;
  final bool withCenter;
  final bool withToggle;
  final bool withZoom;
  final double initialZoom;
  final double minZoom;
  final double maxZoom;
  final LatLng initialCenter;
  final int interactionFlags;
  final CameraFit? initialFit;
  final TapCallback? onTap;
  final MapController? controller;
  final List<TileLayer> layers;
  final List<(K, String, LatLng)> markers;

  /// Extra named locations available to the search field. Each target may
  /// have zero, one, or many points (e.g. an exercise that aggregates the
  /// positions of its stations) and may override the tap behaviour with
  /// [SearchResult.onSelect].
  final List<SearchResult> searchTargets;
  final ValueSetter<(K, String, LatLng)>? onMarkerTap;

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
                if (widget.markers.isNotEmpty)
                  MarkerLayer(
                    markers: widget.markers.map((e) {
                      final painter = TextPainter(
                        text: TextSpan(text: e.$2),
                        maxLines: 1,
                        textDirection: TextDirection.ltr,
                      )..layout();
                      return Marker(
                        height: 52,
                        width: painter.width,
                        point: e.$3,
                        alignment: Alignment.topCenter,
                        child: GestureDetector(
                          behavior: HitTestBehavior.deferToChild,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Slightly translucent so the label does
                              // not dominate when multiple markers sit
                              // close together. Affects background and
                              // text together; the pin underneath stays
                              // fully opaque.
                              Opacity(
                                opacity: 0.55,
                                child: Material(
                                  elevation: 2,
                                  borderRadius: BorderRadius.circular(4),
                                  child: Padding(
                                    padding: const EdgeInsets.all(1.0),
                                    child: Text(
                                      e.$2,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.place,
                                color: Colors.green,
                                size: 32,
                              ),
                            ],
                          ),
                          onTap: () => widget.onMarkerTap?.call(e),
                        ),
                      );
                    }).toList(),
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
                  width: constraints.maxWidth - (withToggle ? 66 : 0),
                  child: _buildSearchTool(context, constraints),
                ),
              ),
            if (withToggle)
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(
                    10.0,
                  ).copyWith(top: 16.0), // Add some spacing
                  child: FloatingActionButton(
                    heroTag: 'layers',
                    onPressed: _toggleLayer,
                    child: const Icon(
                      Icons.layers,
                    ), // Layer icon for better context
                  ),
                ),
              ),
            if (widget.withCenter || widget.withZoom)
              Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
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

  void _toggleCenter() {
    if (widget.markers.isEmpty) {
      _mapController.move(widget.initialCenter, _mapController.camera.zoom);
      return;
    }

    // Do not toggle to same initial center if exists in markers
    final unique = !widget.markers.any((e) => e.$3 == widget.initialCenter);

    _currentCenterIndex =
        (_currentCenterIndex + 1) % (widget.markers.length + (unique ? 1 : 0));

    final point = _currentCenterIndex == 0
        ? widget.initialCenter
        : widget.markers[_currentCenterIndex - (unique ? 1 : 0)].$3;

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
      if (it.$3 == widget.initialCenter) {
        _currentCenterIndex = i;
        return;
      }
      i++;
    }
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
        if (lat != null && lon != null) {
          final result = LatLng(lat, lon);
          _mapController.move(result, _mapController.camera.zoom);
          setState(() {
            _isSearching = false;
          });
          return;
        }
      }

      // Try parsing UTM using coordinate_converter
      final result = input.toLatLngFromUtm();
      if (result != null) {
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
