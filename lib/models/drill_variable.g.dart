// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'drill_variable.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_DrillVariable _$DrillVariableFromJson(Map<String, dynamic> json) =>
    _DrillVariable(
      name: json['name'] as String,
      value: json['value'] as String? ?? '',
      hint: json['hint'] as String?,
    );

Map<String, dynamic> _$DrillVariableToJson(_DrillVariable instance) =>
    <String, dynamic>{
      'name': instance.name,
      'value': instance.value,
      'hint': instance.hint,
    };
