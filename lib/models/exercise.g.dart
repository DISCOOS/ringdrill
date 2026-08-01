// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'exercise.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_GroupSlot _$GroupSlotFromJson(Map<String, dynamic> json) => _GroupSlot(
  stationIndex: (json['stationIndex'] as num).toInt(),
  teams:
      (json['teams'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList() ??
      const <int>[],
);

Map<String, dynamic> _$GroupSlotToJson(_GroupSlot instance) =>
    <String, dynamic>{
      'stationIndex': instance.stationIndex,
      'teams': instance.teams,
    };

_ExerciseGroup _$ExerciseGroupFromJson(Map<String, dynamic> json) =>
    _ExerciseGroup(
      stations:
          (json['stations'] as List<dynamic>?)
              ?.map((e) => GroupSlot.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <GroupSlot>[],
    );

Map<String, dynamic> _$ExerciseGroupToJson(_ExerciseGroup instance) =>
    <String, dynamic>{'stations': instance.stations};

_Exercise _$ExerciseFromJson(Map<String, dynamic> json) => _Exercise(
  uuid: json['uuid'] as String,
  index: (json['index'] as num?)?.toInt() ?? 0,
  name: json['name'] as String,
  startTime: SimpleTimeOfDay.fromJson(
    json['startTime'] as Map<String, dynamic>,
  ),
  numberOfTeams: (json['numberOfTeams'] as num).toInt(),
  numberOfRounds: (json['numberOfRounds'] as num).toInt(),
  mode:
      $enumDecodeNullable(_$ExerciseModeEnumMap, json['mode']) ??
      ExerciseMode.ring,
  groups:
      (json['groups'] as List<dynamic>?)
          ?.map((e) => ExerciseGroup.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <ExerciseGroup>[],
  executionTime: (json['executionTime'] as num).toInt(),
  evaluationTime: (json['evaluationTime'] as num).toInt(),
  rotationTime: (json['rotationTime'] as num).toInt(),
  stations: (json['stations'] as List<dynamic>)
      .map((e) => Station.fromJson(e as Map<String, dynamic>))
      .toList(),
  schedule: (json['schedule'] as List<dynamic>)
      .map(
        (e) => (e as List<dynamic>)
            .map((e) => SimpleTimeOfDay.fromJson(e as Map<String, dynamic>))
            .toList(),
      )
      .toList(),
  endTime: SimpleTimeOfDay.fromJson(json['endTime'] as Map<String, dynamic>),
  metadata: json['metadata'] == null
      ? null
      : ExerciseMetadata.fromJson(json['metadata'] as Map<String, dynamic>),
  templateId: json['templateId'] as String?,
  variableOverrides:
      (json['variableOverrides'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ) ??
      const <String, String>{},
);

Map<String, dynamic> _$ExerciseToJson(_Exercise instance) => <String, dynamic>{
  'uuid': instance.uuid,
  'index': instance.index,
  'name': instance.name,
  'startTime': instance.startTime,
  'numberOfTeams': instance.numberOfTeams,
  'numberOfRounds': instance.numberOfRounds,
  'mode': _$ExerciseModeEnumMap[instance.mode]!,
  'groups': instance.groups,
  'executionTime': instance.executionTime,
  'evaluationTime': instance.evaluationTime,
  'rotationTime': instance.rotationTime,
  'stations': instance.stations,
  'schedule': instance.schedule,
  'endTime': instance.endTime,
  'metadata': instance.metadata,
  'templateId': instance.templateId,
  'variableOverrides': instance.variableOverrides,
};

const _$ExerciseModeEnumMap = {
  ExerciseMode.ring: 'ring',
  ExerciseMode.together: 'together',
  ExerciseMode.split: 'split',
};

_ExerciseMetadata _$ExerciseMetadataFromJson(Map<String, dynamic> json) =>
    _ExerciseMetadata(copyOfUuid: json['copyOfUuid'] as String?);

Map<String, dynamic> _$ExerciseMetadataToJson(_ExerciseMetadata instance) =>
    <String, dynamic>{'copyOfUuid': instance.copyOfUuid};

_SimpleTimeOfDay _$SimpleTimeOfDayFromJson(Map<String, dynamic> json) =>
    _SimpleTimeOfDay(
      hour: (json['hour'] as num).toInt(),
      minute: (json['minute'] as num).toInt(),
    );

Map<String, dynamic> _$SimpleTimeOfDayToJson(_SimpleTimeOfDay instance) =>
    <String, dynamic>{'hour': instance.hour, 'minute': instance.minute};
