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
  source: json['source'] == null
      ? const ProgramSource.local()
      : ProgramSource.fromJson(json['source'] as Map<String, dynamic>),
  contentHash: json['contentHash'] as String?,
  teams: (json['teams'] as List<dynamic>)
      .map((e) => Team.fromJson(e as Map<String, dynamic>))
      .toList(),
  sessions: (json['sessions'] as List<dynamic>)
      .map((e) => Session.fromJson(e as Map<String, dynamic>))
      .toList(),
  exercises: (json['exercises'] as List<dynamic>)
      .map((e) => Exercise.fromJson(e as Map<String, dynamic>))
      .toList(),
  rolePlays: (json['rolePlays'] as List<dynamic>)
      .map((e) => RolePlay.fromJson(e as Map<String, dynamic>))
      .toList(),
  actors: (json['actors'] as List<dynamic>)
      .map((e) => Actor.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$ProgramToJson(_Program instance) => <String, dynamic>{
  'uuid': instance.uuid,
  'name': instance.name,
  'description': instance.description,
  'metadata': instance.metadata,
  'source': instance.source,
  'contentHash': instance.contentHash,
  'teams': instance.teams,
  'sessions': instance.sessions,
  'exercises': instance.exercises,
  'rolePlays': instance.rolePlays,
  'actors': instance.actors,
};

_Local _$LocalFromJson(Map<String, dynamic> json) =>
    _Local($type: json['runtimeType'] as String?);

Map<String, dynamic> _$LocalToJson(_Local instance) => <String, dynamic>{
  'runtimeType': instance.$type,
};

_Imported _$ImportedFromJson(Map<String, dynamic> json) => _Imported(
  fileName: json['fileName'] as String,
  $type: json['runtimeType'] as String?,
);

Map<String, dynamic> _$ImportedToJson(_Imported instance) => <String, dynamic>{
  'fileName': instance.fileName,
  'runtimeType': instance.$type,
};

_Catalog _$CatalogFromJson(Map<String, dynamic> json) => _Catalog(
  slug: json['slug'] as String,
  latestEtag: json['latestEtag'] as String,
  installedAt: json['installedAt'] == null
      ? null
      : DateTime.parse(json['installedAt'] as String),
  $type: json['runtimeType'] as String?,
);

Map<String, dynamic> _$CatalogToJson(_Catalog instance) => <String, dynamic>{
  'slug': instance.slug,
  'latestEtag': instance.latestEtag,
  'installedAt': instance.installedAt?.toIso8601String(),
  'runtimeType': instance.$type,
};

_ProgramDiff _$ProgramDiffFromJson(Map<String, dynamic> json) => _ProgramDiff(
  nameLocal: json['nameLocal'] as String?,
  nameRemote: json['nameRemote'] as String?,
  descriptionLocal: json['descriptionLocal'] as String?,
  descriptionRemote: json['descriptionRemote'] as String?,
  addedExercises:
      (json['addedExercises'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  removedExercises:
      (json['removedExercises'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  modifiedExercises:
      (json['modifiedExercises'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  addedTeams:
      (json['addedTeams'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  removedTeams:
      (json['removedTeams'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  modifiedTeams:
      (json['modifiedTeams'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  addedSessions:
      (json['addedSessions'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  removedSessions:
      (json['removedSessions'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  modifiedSessions:
      (json['modifiedSessions'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  addedRolePlays:
      (json['addedRolePlays'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  removedRolePlays:
      (json['removedRolePlays'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  modifiedRolePlays:
      (json['modifiedRolePlays'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
);

Map<String, dynamic> _$ProgramDiffToJson(_ProgramDiff instance) =>
    <String, dynamic>{
      'nameLocal': instance.nameLocal,
      'nameRemote': instance.nameRemote,
      'descriptionLocal': instance.descriptionLocal,
      'descriptionRemote': instance.descriptionRemote,
      'addedExercises': instance.addedExercises,
      'removedExercises': instance.removedExercises,
      'modifiedExercises': instance.modifiedExercises,
      'addedTeams': instance.addedTeams,
      'removedTeams': instance.removedTeams,
      'modifiedTeams': instance.modifiedTeams,
      'addedSessions': instance.addedSessions,
      'removedSessions': instance.removedSessions,
      'modifiedSessions': instance.modifiedSessions,
      'addedRolePlays': instance.addedRolePlays,
      'removedRolePlays': instance.removedRolePlays,
      'modifiedRolePlays': instance.modifiedRolePlays,
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
      schema: json['schema'] as String?,
    );

Map<String, dynamic> _$ProgramMetadataToJson(_ProgramMetadata instance) =>
    <String, dynamic>{
      'created': instance.created.toIso8601String(),
      'updated': instance.updated.toIso8601String(),
      'version': instance.version,
      'schema': instance.schema,
    };
