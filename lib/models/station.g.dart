// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'station.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Station _$StationFromJson(Map<String, dynamic> json) => _Station(
  index: (json['index'] as num).toInt(),
  name: json['name'] as String,
  variantSuffix: json['variantSuffix'] as String?,
  position: const NullableLatLngJsonConverter().fromJson(
    json['position'] as Map<String, dynamic>?,
  ),
  description: json['description'] as String?,
);

Map<String, dynamic> _$StationToJson(_Station instance) => <String, dynamic>{
  'index': instance.index,
  'name': instance.name,
  'variantSuffix': instance.variantSuffix,
  'position': const NullableLatLngJsonConverter().toJson(instance.position),
  'description': instance.description,
};
