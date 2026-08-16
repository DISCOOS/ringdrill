// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'staff.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Staff _$StaffFromJson(Map<String, dynamic> json) => _Staff(
  uuid: json['uuid'] as String,
  realName: json['realName'] as String,
  phone: json['phone'] as String?,
  roles:
      (json['roles'] as List<dynamic>?)
          ?.map((e) => $enumDecode(_$StaffRoleEnumMap, e))
          .toSet() ??
      const <StaffRole>{},
  userId: json['userId'] as String?,
);

Map<String, dynamic> _$StaffToJson(_Staff instance) => <String, dynamic>{
  'uuid': instance.uuid,
  'realName': instance.realName,
  'phone': instance.phone,
  'roles': instance.roles.map((e) => _$StaffRoleEnumMap[e]!).toList(),
  'userId': instance.userId,
};

const _$StaffRoleEnumMap = {
  StaffRole.director: 'director',
  StaffRole.instructor: 'instructor',
  StaffRole.actor: 'actor',
  StaffRole.other: 'other',
};
