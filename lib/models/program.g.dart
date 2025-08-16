// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'program.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Program _$ProgramFromJson(Map<String, dynamic> json) => _Program(
  uuid: json['uuid'] as String,
  name: json['name'] as String,
  description: json['description'] as String,
  metadata: ProgramMetadata.fromJson(json['metadata'] as Map<String, dynamic>),
  teams: (json['teams'] as List<dynamic>)
      .map((e) => Team.fromJson(e as Map<String, dynamic>))
      .toList(),
  sessions: (json['sessions'] as List<dynamic>)
      .map((e) => Session.fromJson(e as Map<String, dynamic>))
      .toList(),
  exercises: (json['exercises'] as List<dynamic>)
      .map((e) => Exercise.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$ProgramToJson(_Program instance) => <String, dynamic>{
  'uuid': instance.uuid,
  'name': instance.name,
  'description': instance.description,
  'metadata': instance.metadata,
  'teams': instance.teams,
  'sessions': instance.sessions,
  'exercises': instance.exercises,
};

_Session _$SessionFromJson(Map<String, dynamic> json) => _Session(
  uuid: json['uuid'] as String,
  startedAt: json['startedAt'] == null
      ? null
      : DateTime.parse(json['startedAt'] as String),
  endedAt: json['endedAt'] == null
      ? null
      : DateTime.parse(json['endedAt'] as String),
  exerciseUuid: json['exerciseUuid'] as String,
  startTime: SimpleTimeOfDay.fromJson(
    json['startTime'] as Map<String, dynamic>,
  ),
);

Map<String, dynamic> _$SessionToJson(_Session instance) => <String, dynamic>{
  'uuid': instance.uuid,
  'startedAt': instance.startedAt?.toIso8601String(),
  'endedAt': instance.endedAt?.toIso8601String(),
  'exerciseUuid': instance.exerciseUuid,
  'startTime': instance.startTime,
};

_ProgramMetadata _$ProgramMetadataFromJson(Map<String, dynamic> json) =>
    _ProgramMetadata(
      created: DateTime.parse(json['created'] as String),
      updated: DateTime.parse(json['updated'] as String),
      version: json['version'] as String,
    );

Map<String, dynamic> _$ProgramMetadataToJson(_ProgramMetadata instance) =>
    <String, dynamic>{
      'created': instance.created.toIso8601String(),
      'updated': instance.updated.toIso8601String(),
      'version': instance.version,
    };
