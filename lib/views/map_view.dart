import 'dart:async';
import 'dart:math' as math;

import 'package:coordinate_converter/coordinate_converter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:osm_nominatim/osm_nominatim.dart';
import 'package:ringdrill/l10n/app_localizations.dart';

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
  static TileLayer get osmLayer => TileLayer(
    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    userAgentPackageName: 'discoos.org/ringdrill',
    subdomains: [],
  );
  static TileLayer get topoLayer => TileLayer(
    urlTemplate:
        'https://cache.kartverket.no/v1/wmts/1.0.0/topo/default/webmercator/{z}/{y}/{x}.png',
    subdomains: [],
    userAgentPackageName: 'discoos.org/ringdrill',
  );
}

class MapView extends StatefulWidget {
  const MapView({
    super.key,
    required this.layer,
    this.controller,
    this.withCross = false,
    this.withSearch = false,
    this.initialZoom = 15,
    this.interactionFlags = MapConfig.static,
    this.initialCenter = MapConfig.initialCenter,
    this.onTap,
  });

  final TileLayer layer;
  final bool withCross;
  final bool withSearch;
  final double initialZoom;
  final int interactionFlags;
  final LatLng initialCenter;
  final MapController? controller;
  final TapCallback? onTap;

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  late MapController _mapController;
  final TextEditingController _searchController = TextEditingController();
  Timer? _throttleTimer;
  bool _isSearching = false;
  List<SearchResult> _searchResults = [];

  @override
  void initState() {
    super.initState();
    _mapController = widget.controller ?? MapController();
  }

  @override
  void didUpdateWidget(covariant MapView oldWidget) {
    if (oldWidget != widget) {
      if (widget.controller != null && _mapController != widget.controller) {
        //_mapController.dispose();
        _mapController = widget.controller!;
      }
      _mapController.move(widget.initialCenter, widget.initialZoom);
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    final searchHint = AppLocalizations.of(context)!.searchForPlaceOrLocation;
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialZoom: widget.initialZoom,
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
          children: [widget.layer],
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
            child: Column(
              children: [
                SizedBox(
                  height: 88,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(
                        8.0,
                      ).copyWith(left: 8, top: 12),
                      child: Center(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: searchHint,
                            hintMaxLines: 1,
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 10,
                            ),
                            suffixIcon:
                                _isSearching
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
                                      onPressed:
                                          _isSearching
                                              ? null
                                              : () {
                                                if (_searchController
                                                    .text
                                                    .isNotEmpty) {
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
                        final result = _searchResults[index];
                        return ListTile(
                          onTap: () => _onResultTap(result),
                          title: Text(result.name),
                          trailing: const Icon(Icons.location_on),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
      ],
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
          _mapController.move(result, widget.initialZoom);
          setState(() {
            _isSearching = false;
          });
          return;
        }
      }

      // Try parsing UTM using coordinate_converter
      final tokens = input.split(RegExp(r'[ ,]+'));
      if (tokens.length == 4) {
        final zone = int.tryParse(tokens[0].replaceAll(RegExp(r'[^0-9]'), ''));
        final band = tokens[0].replaceAll(RegExp(r'[^A-Z]'), '');
        final x = double.tryParse(tokens[2]);
        final y = double.tryParse(tokens[3]);
        if (zone != null && x != null && y != null) {
          final isSouthern = band.codeUnitAt(0) < 'N'.codeUnitAt(0);
          final utm = UTMCoordinates(
            x: x,
            y: y,
            zoneNumber: zone,
            isSouthernHemisphere: isSouthern,
          );
          final dd = utm.toDD();
          final result = LatLng(dd.latitude, dd.longitude);
          _mapController.move(result, widget.initialZoom);
          setState(() {
            _isSearching = false;
          });
          return;
        }
      }

      // Try geocoding via osm_nominatim
      final nominatim = Nominatim(userAgent: 'discoos.org/ringdrill');
      final locale = Intl.getCurrentLocale();
      final results = await nominatim.searchByName(
        limit: 5,
        query: '${input.trim()},',
        nameDetails: true,
        addressDetails: true,
        countryCodes: [locale.split('_')[1]],
      );

      setState(() {
        _isSearching = false;
        if (results.isNotEmpty) {
          _searchResults =
              results
                  .map(
                    (r) => SearchResult(_formatPlace(r), LatLng(r.lat, r.lon)),
                  )
                  .toList();
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.searchFailed(e)),
          ),
        );
      }
    }
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
    _mapController.move(result.location, widget.initialZoom);
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
}
