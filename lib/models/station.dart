import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/models/lat_lng_converter.dart';
import 'package:ringdrill/models/location.dart';
import 'package:ringdrill/models/numbering.dart';
import 'package:ringdrill/models/person.dart';

part 'station.freezed.dart';
part 'station.g.dart';

@freezed
sealed class Station with _$Station {
  const factory Station({
    required int index,
    required String name,
    String? variantSuffix,
    @NullableLatLngJsonConverter() LatLng? position,
    String? description,
    /// Per-scope value overrides for plan-global variables, keyed by
    /// DrillVariable.name. A key that does not name a declared variable is
    /// meaningless and is ignored at resolution time (ADR-0046). This scope
    /// never declares new variables.
    @Default(<String, String>{}) Map<String, String> variableOverrides,
    /// Station-owned scenario geography, referenced as
    /// `{{station.loc.<slug>}}` (ADR-0047, DESIGN-009). @Default so
    /// archives without the key deserialize to an empty list (additive
    /// field, no schema bump).
    @Default(<Location>[]) List<Location> locations,
    /// Station-owned fictional scenario persons, referenced as
    /// `{{station.person.<slug>}}` (ADR-0047, DESIGN-009). @Default so
    /// archives without the key deserialize to an empty list (additive
    /// field, no schema bump).
    @Default(<Person>[]) List<Person> persons,
    // Markdown brief fields — stored as exercises/<uuid>/stations/<index>/<field>.md, not in JSON.
    @JsonKey(includeFromJson: false, includeToJson: false) String? equipmentMd,
    @JsonKey(includeFromJson: false, includeToJson: false) String? situationMd,
    @JsonKey(includeFromJson: false, includeToJson: false) String? missionMd,
    @JsonKey(includeFromJson: false, includeToJson: false) String? logisticsMd,
    @JsonKey(includeFromJson: false, includeToJson: false)
    String? criticalQuestionsMd,
    @JsonKey(includeFromJson: false, includeToJson: false) String? leaderAnswersMd,
    @JsonKey(includeFromJson: false, includeToJson: false) String? directorNotesMd,
  }) = _Station;

  factory Station.fromJson(Map<String, dynamic> json) =>
      _$StationFromJson(json);
}

extension StationNumbering on Station {
  /// This station's formatted number alone ([Numbering.station], per
  /// [format] and the 1-based [exerciseNumber]) — e.g. "1.1" / "1a".
  /// Map marker labels use this rather than [numberAndName]: the number
  /// takes far less room above the pin and matches the StationNumberBadge
  /// used everywhere else (see `PlanService.getLocations`).
  String numberLabel(StationNumberFormat format, {required int exerciseNumber}) =>
      Numbering.station(
        format,
        exerciseNumber: exerciseNumber,
        stationIndex: index,
      );

  /// This station's formatted number ([Numbering.station], per [format] and
  /// the 1-based [exerciseNumber]) followed by its [name] — e.g. "1.1 Turgåer".
  /// The raw [name] is used as-is; the caller resolves any plan-variable
  /// tokens in the result.
  String numberAndName(
    StationNumberFormat format, {
    required int exerciseNumber,
  }) => '${numberLabel(format, exerciseNumber: exerciseNumber)} $name';
}
