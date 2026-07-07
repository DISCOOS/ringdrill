import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/models/lat_lng_converter.dart';

part 'location.freezed.dart';
part 'location.g.dart';

/// The kind of a station-owned [Location]. Drives map marker styling and
/// picker grouping (ADR-0047). The JSON value is a stable wire slug; an
/// unknown value (e.g. written by a newer client) decodes to [other] so
/// older clients stay forward-compatible when a kind is added later.
/// `label`/`description` are not hard-coded here — they come from i18n,
/// added with the editor (DESIGN-009).
enum LocationKind {
  lkp, // last known position
  ipp, // initial planning point
  pp, // planning point
  rendezvous, // Oppmøtested
  commandPost, // Kommandoplass (KO)
  home, // Bosted
  trackFound, // Funn av spor
  dogInterest, // Interesse av hund
  obstacle, // Hindring
  notSearchable, // Ikke søkbart
  phoneTrace, // Mobilspor
  observation, // Observasjon
  vantagePoint, // Utkikkspunkt
  containmentPost, // Sperrepost
  personFound, // Funn av person
  other, // Annet
}

/// Scenario geography, owned by a [Station]. Distinct from the
/// administrative `Station.position` (game-technical placement of the
/// station/marker) — this is tactical/scenario geography such as a last
/// known position or a rendezvous point (ADR-0047).
///
/// [slug] is the stable reference used by `{{station.loc.<slug>}}`
/// (DESIGN-009); it must match `^[a-z][a-z0-9_]*$` and be unique within
/// the station. Slug validation and uniqueness are an editor concern, not
/// enforced by this model.
@freezed
sealed class Location with _$Location {
  const factory Location({
    required String slug,
    @Default('') String label,
    @Default(LocationKind.other)
    @JsonKey(unknownEnumValue: LocationKind.other)
    LocationKind kind,
    @Default('') String place,
    @NullableLatLngJsonConverter() LatLng? position,
    String? note,
  }) = _Location;

  factory Location.fromJson(Map<String, dynamic> json) =>
      _$LocationFromJson(json);
}
