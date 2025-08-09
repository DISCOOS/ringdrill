// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'team.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Team _$TeamFromJson(Map<String, dynamic> json) => _Team(
  uuid: json['uuid'] as String,
  index: (json['index'] as num).toInt(),
  name: json['name'] as String,
  numberOfMembers: (json['numberOfMembers'] as num?)?.toInt(),
  position: json['position'] == null
      ? null
      : LatLng.fromJson(json['position'] as Map<String, dynamic>),
);

Map<String, dynamic> _$TeamToJson(_Team instance) => <String, dynamic>{
  'uuid': instance.uuid,
  'index': instance.index,
  'name': instance.name,
  'numberOfMembers': instance.numberOfMembers,
  'position': instance.position,
};
