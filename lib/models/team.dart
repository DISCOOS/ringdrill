import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:latlong2/latlong.dart';

part 'team.freezed.dart';
part 'team.g.dart';

@freezed
sealed class Team with _$Team {
  const factory Team({
    required String uuid,
    required int index,
    required String name,
    int? numberOfMembers,
    LatLng? position,
  }) = _Team;

  factory Team.fromJson(Map<String, dynamic> json) => _$TeamFromJson(json);
}
