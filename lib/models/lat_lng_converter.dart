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
  LatLng? fromJson(Map<String, dynamic>? json) =>
      json == null ? null : LatLng.fromJson(json);

  @override
  Map<String, dynamic>? toJson(LatLng? object) => object?.toJson();
}
