import 'dart:math' as math;

import 'package:latlong2/latlong.dart';
import 'package:osm_nominatim/osm_nominatim.dart';

/// A single geocoder hit: a human-readable [label] and its [position].
class GeocodingHit {
  const GeocodingHit(this.label, this.position);

  final String label;
  final LatLng position;
}

/// Forward/reverse place lookup, backed by `osm_nominatim` (Nominatim) — the
/// same public geocoder `MapView`'s search field already queries (ADR-0047
/// follow-up 3c extracts it out of `map_view.dart` so the Location form can
/// reuse the exact same lookups instead of a second implementation).
///
/// Neither method swallows errors: an offline device or a Nominatim failure
/// surfaces as a thrown exception, same as the underlying `osm_nominatim`
/// package call. Callers decide how to handle it — `MapView` reports it to
/// Sentry (existing behaviour, preserved by this extraction); the Location
/// form is a best-effort field tool and treats it as a silent no-op
/// (DESIGN-009 follow-up 3c). Injectable so tests can substitute a fake and
/// never touch the network.
abstract class GeocodingService {
  /// Free-text place search. [near], when given, biases results toward a
  /// small box around that point (mirrors the old inline map-search
  /// behaviour). Returns up to 5 hits, best first; an empty list means "no
  /// matches", not an error.
  Future<List<GeocodingHit>> search(String query, {LatLng? near});

  /// Reverse lookup: the canonical place name for [point].
  Future<String> reverse(LatLng point);
}

class NominatimGeocodingService implements GeocodingService {
  NominatimGeocodingService({Nominatim? client})
    : _client = client ?? Nominatim(userAgent: 'discoos.org/ringdrill');

  final Nominatim _client;

  @override
  Future<List<GeocodingHit>> search(String query, {LatLng? near}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    final results = await _client.searchByName(
      limit: 5,
      query: '$trimmed,',
      nameDetails: true,
      addressDetails: true,
      viewBox: near == null ? null : _viewBoxAround(near, 1000),
    );
    return [
      for (final r in results)
        GeocodingHit(_formatPlace(r), LatLng(r.lat, r.lon)),
    ];
  }

  @override
  Future<String> reverse(LatLng point) async {
    final place = await _client.reverseSearch(
      lat: point.latitude,
      lon: point.longitude,
      addressDetails: true,
    );
    return _formatPlace(place);
  }

  /// Bounding box of [radiusInKm] around [center] — the same "prefer nearby
  /// results" bias the old inline map search applied, moved here verbatim.
  ViewBox _viewBoxAround(LatLng center, double radiusInKm) {
    const double earthRadiusKm = 6371.0;

    final double lat = center.latitude * math.pi / 180;
    final double lng = center.longitude * math.pi / 180;

    final double latOffset = radiusInKm / earthRadiusKm;
    final double lngOffset = radiusInKm / (earthRadiusKm * math.cos(lat));

    double northLatitude = (lat + latOffset) * 180 / math.pi;
    double southLatitude = (lat - latOffset) * 180 / math.pi;
    double eastLongitude = (lng + lngOffset) * 180 / math.pi;
    double westLongitude = (lng - lngOffset) * 180 / math.pi;

    northLatitude = northLatitude.clamp(-90.0, 90.0);
    southLatitude = southLatitude.clamp(-90.0, 90.0);
    eastLongitude = eastLongitude.clamp(-180.0, 180.0);
    westLongitude = westLongitude.clamp(-180.0, 180.0);

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

  String _formatNameDetails(Place result) => result.displayName;
}
