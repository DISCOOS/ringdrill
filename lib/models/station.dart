import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:latlong2/latlong.dart';

part 'station.freezed.dart';
part 'station.g.dart';

@freezed
sealed class Station with _$Station {
  const factory Station({
    required int index,
    required String name,
    LatLng? position,
    String? description,
  }) = _Station;

  factory Station.fromJson(Map<String, dynamic> json) =>
      _$StationFromJson(json);
}
