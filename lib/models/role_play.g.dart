// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'role_play.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RolePlay _$RolePlayFromJson(Map<String, dynamic> json) => _RolePlay(
  uuid: json['uuid'] as String,
  index: (json['index'] as num).toInt(),
  exerciseUuid: json['exerciseUuid'] as String,
  name: json['name'] as String,
  age: (json['age'] as num?)?.toInt(),
  signalement: json['signalement'] as String?,
  background: json['background'] as String?,
  behavior: json['behavior'] as String?,
  stationIndex: (json['stationIndex'] as num?)?.toInt(),
  position: const NullableLatLngJsonConverter().fromJson(
    json['position'] as Map<String, dynamic>?,
  ),
  actorUuid: json['actorUuid'] as String?,
);

Map<String, dynamic> _$RolePlayToJson(_RolePlay instance) => <String, dynamic>{
  'uuid': instance.uuid,
  'index': instance.index,
  'exerciseUuid': instance.exerciseUuid,
  'name': instance.name,
  'age': instance.age,
  'signalement': instance.signalement,
  'background': instance.background,
  'behavior': instance.behavior,
  'stationIndex': instance.stationIndex,
  'position': const NullableLatLngJsonConverter().toJson(instance.position),
  'actorUuid': instance.actorUuid,
};
