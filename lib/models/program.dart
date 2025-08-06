import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:ringdrill/models/exercise.dart';

part 'program.freezed.dart';
part 'program.g.dart';

/// Represents an immutable drill program
@freezed
sealed class Program with _$Program {
  const factory Program({
    required String uuid,
    required String name,
    required String description,
    required ProgramMetadata metadata,
    required List<Exercise> exercises,
    required List<Session> sessions,
  }) = _Program;

  factory Program.fromJson(Map<String, dynamic> json) =>
      _$ProgramFromJson(json);
}

/// Represents an immutable drill session
@freezed
sealed class Session with _$Session {
  const factory Session({
    required String uuid,
    required DateTime? startedAt,
    required DateTime? endedAt,
    required String exerciseUuid,
    @TimeOfDayConverter() required TimeOfDay startTime,
  }) = _Session;

  factory Session.fromJson(Map<String, dynamic> json) =>
      _$SessionFromJson(json);
}

/// Represents an immutable drill program metadata
@freezed
sealed class ProgramMetadata with _$ProgramMetadata {
  const factory ProgramMetadata({
    required DateTime created,
    required DateTime updated,
    required String version,
  }) = _ProgramMetadata;

  factory ProgramMetadata.fromJson(Map<String, dynamic> json) =>
      _$ProgramMetadataFromJson(json);
}
