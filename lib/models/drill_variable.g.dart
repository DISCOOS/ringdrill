// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'drill_variable.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_VariableLocation _$VariableLocationFromJson(Map<String, dynamic> json) =>
    _VariableLocation(
      place: json['place'] as String? ?? '',
      position: const NullableLatLngJsonConverter().fromJson(
        json['position'] as Map<String, dynamic>?,
      ),
    );

Map<String, dynamic> _$VariableLocationToJson(_VariableLocation instance) =>
    <String, dynamic>{
      'place': instance.place,
      'position': const NullableLatLngJsonConverter().toJson(instance.position),
    };

_DrillVariable _$DrillVariableFromJson(Map<String, dynamic> json) =>
    _DrillVariable(
      name: json['name'] as String,
      value: json['value'] as String? ?? '',
      hint: json['hint'] as String?,
      type:
          $enumDecodeNullable(
            _$VariableTypeEnumMap,
            json['type'],
            unknownValue: VariableType.string,
          ) ??
          VariableType.string,
      location: json['location'] == null
          ? null
          : VariableLocation.fromJson(json['location'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$DrillVariableToJson(_DrillVariable instance) =>
    <String, dynamic>{
      'name': instance.name,
      'value': instance.value,
      'hint': instance.hint,
      'type': _$VariableTypeEnumMap[instance.type]!,
      'location': instance.location,
    };

const _$VariableTypeEnumMap = {
  VariableType.string: 'string',
  VariableType.number: 'number',
  VariableType.time: 'time',
  VariableType.date: 'date',
  VariableType.duration: 'duration',
  VariableType.location: 'location',
};
