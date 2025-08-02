// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'exercise.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Exercise _$ExerciseFromJson(Map<String, dynamic> json) => _Exercise(
  uuid: json['uuid'] as String,
  name: json['name'] as String,
  startTime: const TimeOfDayConverter().fromJson(
    json['startTime'] as Map<String, dynamic>,
  ),
  numberOfTeams: (json['numberOfTeams'] as num).toInt(),
  numberOfRounds: (json['numberOfRounds'] as num).toInt(),
  executionTime: (json['executionTime'] as num).toInt(),
  evaluationTime: (json['evaluationTime'] as num).toInt(),
  rotationTime: (json['rotationTime'] as num).toInt(),
  teams:
      (json['teams'] as List<dynamic>)
          .map((e) => Team.fromJson(e as Map<String, dynamic>))
          .toList(),
  stations:
      (json['stations'] as List<dynamic>)
          .map((e) => Station.fromJson(e as Map<String, dynamic>))
          .toList(),
  schedule:
      (json['schedule'] as List<dynamic>)
          .map(
            (e) =>
                (e as List<dynamic>)
                    .map(
                      (e) => const TimeOfDayConverter().fromJson(
                        e as Map<String, dynamic>,
                      ),
                    )
                    .toList(),
          )
          .toList(),
  endTime: const TimeOfDayConverter().fromJson(
    json['endTime'] as Map<String, dynamic>,
  ),
);

Map<String, dynamic> _$ExerciseToJson(_Exercise instance) => <String, dynamic>{
  'uuid': instance.uuid,
  'name': instance.name,
  'startTime': const TimeOfDayConverter().toJson(instance.startTime),
  'numberOfTeams': instance.numberOfTeams,
  'numberOfRounds': instance.numberOfRounds,
  'executionTime': instance.executionTime,
  'evaluationTime': instance.evaluationTime,
  'rotationTime': instance.rotationTime,
  'teams': instance.teams,
  'stations': instance.stations,
  'schedule':
      instance.schedule
          .map((e) => e.map(const TimeOfDayConverter().toJson).toList())
          .toList(),
  'endTime': const TimeOfDayConverter().toJson(instance.endTime),
};

_Station _$StationFromJson(Map<String, dynamic> json) => _Station(
  index: (json['index'] as num).toInt(),
  name: json['name'] as String,
  position:
      json['position'] == null
          ? null
          : LatLng.fromJson(json['position'] as Map<String, dynamic>),
  description: json['description'] as String?,
);

Map<String, dynamic> _$StationToJson(_Station instance) => <String, dynamic>{
  'index': instance.index,
  'name': instance.name,
  'position': instance.position,
  'description': instance.description,
};

_Team _$TeamFromJson(Map<String, dynamic> json) => _Team(
  index: (json['index'] as num).toInt(),
  name: json['name'] as String,
  position:
      json['position'] == null
          ? null
          : LatLng.fromJson(json['position'] as Map<String, dynamic>),
);

Map<String, dynamic> _$TeamToJson(_Team instance) => <String, dynamic>{
  'index': instance.index,
  'name': instance.name,
  'position': instance.position,
};
