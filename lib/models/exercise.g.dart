// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'exercise.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Exercise _$ExerciseFromJson(Map<String, dynamic> json) => _Exercise(
  uuid: json['uuid'] as String,
  name: json['name'] as String,
  startTime: SimpleTimeOfDay.fromJson(
    json['startTime'] as Map<String, dynamic>,
  ),
  numberOfTeams: (json['numberOfTeams'] as num).toInt(),
  numberOfRounds: (json['numberOfRounds'] as num).toInt(),
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
);

Map<String, dynamic> _$ExerciseToJson(_Exercise instance) => <String, dynamic>{
  'uuid': instance.uuid,
  'name': instance.name,
  'startTime': instance.startTime,
  'numberOfTeams': instance.numberOfTeams,
  'numberOfRounds': instance.numberOfRounds,
  'executionTime': instance.executionTime,
  'evaluationTime': instance.evaluationTime,
  'rotationTime': instance.rotationTime,
  'stations': instance.stations,
  'schedule': instance.schedule,
  'endTime': instance.endTime,
  'metadata': instance.metadata,
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
