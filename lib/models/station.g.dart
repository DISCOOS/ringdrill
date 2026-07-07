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
  variableOverrides:
      (json['variableOverrides'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ) ??
      const <String, String>{},
  locations:
      (json['locations'] as List<dynamic>?)
          ?.map((e) => Location.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <Location>[],
  persons:
      (json['persons'] as List<dynamic>?)
          ?.map((e) => Person.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <Person>[],
);

Map<String, dynamic> _$StationToJson(_Station instance) => <String, dynamic>{
  'index': instance.index,
  'name': instance.name,
  'variantSuffix': instance.variantSuffix,
  'position': const NullableLatLngJsonConverter().toJson(instance.position),
  'description': instance.description,
  'variableOverrides': instance.variableOverrides,
  'locations': instance.locations,
  'persons': instance.persons,
};
