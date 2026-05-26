// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'actor.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Actor _$ActorFromJson(Map<String, dynamic> json) => _Actor(
  uuid: json['uuid'] as String,
  realName: json['realName'] as String,
  phone: json['phone'] as String?,
);

Map<String, dynamic> _$ActorToJson(_Actor instance) => <String, dynamic>{
  'uuid': instance.uuid,
  'realName': instance.realName,
  'phone': instance.phone,
};
