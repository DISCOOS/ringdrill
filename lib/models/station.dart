import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/models/lat_lng_converter.dart';

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
