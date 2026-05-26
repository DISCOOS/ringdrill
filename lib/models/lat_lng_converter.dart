import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:latlong2/latlong.dart';

/// Converts a nullable [LatLng] to and from JSON using latlong2's GeoJSON
/// `{ "coordinates": [lng, lat] }` shape.
///
/// `json_serializable` would otherwise emit `'position': instance.position`
/// for a `LatLng?` field, dumping the `LatLng` object in the toJson map
/// without invoking its `toJson()`. That round-trips fine through
/// `jsonEncode`/`jsonDecode` (because `jsonEncode` invokes `toJson()` via
/// duck-typing), but breaks any in-memory toJson → fromJson cycle — the
/// generated `fromJson` then tries `json['position'] as Map<String, dynamic>`
/// against a real `LatLng` instance and throws a TypeError.
///
/// Attaching this converter forces the generator to call `LatLng.toJson()`
/// on the way out and `LatLng.fromJson()` on the way in, so the field is
/// always a plain map between the two ends of the boundary.
class NullableLatLngJsonConverter
    implements JsonConverter<LatLng?, Map<String, dynamic>?> {
  const NullableLatLngJsonConverter();

  @override
  LatLng? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final parsed = LatLng.fromJson(json);
    // Reject non-finite coordinates at the storage boundary. flutter_map
    // throws `LatLng is not finite` the moment such a value is projected,
    // which manifests as a crash deep inside the marker/cluster build
    // pipeline rather than at the site of the bad data. Treating it as a
    // missing position lets the rest of the map render normally.
    if (!parsed.latitude.isFinite || !parsed.longitude.isFinite) return null;
    return parsed;
  }

  @override
  Map<String, dynamic>? toJson(LatLng? object) => object?.toJson();
}
