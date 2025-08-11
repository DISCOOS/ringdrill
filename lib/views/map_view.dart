import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:osm_nominatim/osm_nominatim.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
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
    this.initialZoom = 15,
    this.markers = const [],
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
  final double initialZoom;
  final LatLng initialCenter;
  final int interactionFlags;
  final CameraFit? initialFit;
  final TapCallback? onTap;
  final MapController? controller;
  final List<TileLayer> layers;
  final List<(K, String, LatLng)> markers;
  final ValueSetter<(K, String, LatLng)>? onMarkerTap;

  @override
  State<MapView<K>> createState() => _MapViewState();
}

class _MapViewState<K> extends State<MapView<K>> {
  late MapController _mapController;
  final TextEditingController _searchController = TextEditingController();
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
                initialCameraFit: widget.initialFit,
                initialCenter: widget.initialCenter,
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
                              Material(
                                elevation: 2,
                                borderRadius: BorderRadius.circular(4),
                                child: Padding(
                                  padding: const EdgeInsets.all(1.0),
                                  child: Text(
                                    e.$2,
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                              ),
                              Icon(Icons.place, color: Colors.green, size: 32),
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
                  child: _buildSearchTool(context),
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
            if (widget.withCenter)
              Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: FloatingActionButton(
                    heroTag: 'center',
                    onPressed: _toggleCenter,
                    child: Icon(Icons.center_focus_strong_rounded),
                  ),
                ),
              ),
          ],
        );
      },
    );
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

  Widget _buildSearchTool(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 88,
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
          Card(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final result = _searchResults.toList()[index];
                return ListTile(
                  onTap: () => _onResultTap(result),
                  title: Text(result.name),
                  trailing: const Icon(Icons.location_on),
                );
              },
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

      // Try markers
      if (widget.markers.isNotEmpty) {
        final found = widget.markers
            .where((e) => e.$2.contains(input.trim()))
            .map((e) => SearchResult(e.$2, e.$3))
            .toList();
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
              (r) => SearchResult(_formatPlace(r), LatLng(r.lat, r.lon)),
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
    _mapController.move(result.location, _mapController.camera.zoom);
    setState(() {
      _searchResults.clear();
      _searchController.text = result.name;
    });
  }

  @override
  void dispose() {
    _throttleTimer?.cancel();
    super.dispose();
  }
}

// Helper class to represent search results
class SearchResult {
  final String name;
  final LatLng location;

  SearchResult(this.name, this.location);

  @override
  String toString() {
    return 'SearchResult{name: $name}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SearchResult &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          location == other.location;

  @override
  int get hashCode => name.hashCode ^ location.hashCode;
}
