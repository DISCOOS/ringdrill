import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/models/lat_lng_converter.dart';

part 'role_play.freezed.dart';
part 'role_play.g.dart';

@freezed
sealed class RolePlay with _$RolePlay {
  const factory RolePlay({
    required String uuid,
    required int index,
    required String exerciseUuid,
    required String name,
    int? age,
    String? signalement,
    String? background,
    String? behavior,
    int? stationIndex,
    @NullableLatLngJsonConverter() LatLng? position,
    String? actorUuid,
  }) = _RolePlay;

  factory RolePlay.fromJson(Map<String, dynamic> json) =>
      _$RolePlayFromJson(json);
}
