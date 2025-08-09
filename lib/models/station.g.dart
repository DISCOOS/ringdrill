// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'station.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Station _$StationFromJson(Map<String, dynamic> json) => _Station(
  index: (json['index'] as num).toInt(),
  name: json['name'] as String,
  position: json['position'] == null
      ? null
      : LatLng.fromJson(json['position'] as Map<String, dynamic>),
  description: json['description'] as String?,
);

Map<String, dynamic> _$StationToJson(_Station instance) => <String, dynamic>{
  'index': instance.index,
  'name': instance.name,
  'position': instance.position,
  'description': instance.description,
};
