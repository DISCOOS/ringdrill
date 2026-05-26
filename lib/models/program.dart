import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:ringdrill/models/actor.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/team.dart';

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
    @Default(ProgramSource.local()) ProgramSource source,
    String? contentHash,
    required List<Team> teams,
    required List<Session> sessions,
    required List<Exercise> exercises,
    // @Default([]) so 1.0 archives without these keys deserialize to empty
    // lists rather than failing (ADR-0018 backward-compat requirement).
    @Default([]) List<RolePlay> rolePlays,
    @Default([]) List<Actor> actors,
  }) = _Program;

  factory Program.fromJson(Map<String, dynamic> json) =>
      _$ProgramFromJson(json);
}

@freezed
sealed class ProgramSource with _$ProgramSource {
  const factory ProgramSource.local() = _Local;

  const factory ProgramSource.imported({required String fileName}) = _Imported;

  const factory ProgramSource.catalog({
    required String slug,
    required String latestEtag,
    DateTime? installedAt,
  }) = _Catalog;

  factory ProgramSource.fromJson(Map<String, dynamic> json) =>
      _$ProgramSourceFromJson(json);
}

@freezed
sealed class ProgramDiff with _$ProgramDiff {
  const factory ProgramDiff({
    /// Local name when it differs from remote. Null when names match.
    String? nameLocal,

    /// Remote name when it differs from local. Null when names match.
    String? nameRemote,

    /// Local description when it differs from remote. Null when descriptions
    /// match.
    String? descriptionLocal,

    /// Remote description when it differs from local. Null when descriptions
    /// match.
    String? descriptionRemote,
    @Default([]) List<String> addedExercises,
    @Default([]) List<String> removedExercises,
    @Default([]) List<String> modifiedExercises,
    @Default([]) List<String> addedTeams,
    @Default([]) List<String> removedTeams,
    @Default([]) List<String> modifiedTeams,
    @Default([]) List<String> addedSessions,
    @Default([]) List<String> removedSessions,
    @Default([]) List<String> modifiedSessions,
    // rolePlays are included in the content hash; actors are not.
    @Default([]) List<String> addedRolePlays,
    @Default([]) List<String> removedRolePlays,
    @Default([]) List<String> modifiedRolePlays,
  }) = _ProgramDiff;

  factory ProgramDiff.fromJson(Map<String, dynamic> json) =>
      _$ProgramDiffFromJson(json);
}

extension ProgramX on Program {
  /// Stable fingerprint of the user-visible content. Used to detect whether
  /// the local copy has unpublished edits when refreshing from the catalog.
  /// Includes name and description so renames (the most common "small" edit)
  /// are detected as local changes. Excludes uuid, source, contentHash and
  /// metadata timestamps because those drift without being content changes.
  String computeContentHash() {
    // rolePlays are publishable; actors are local PII and excluded per ADR-0018.
    // behavior and background are excluded from toJson (ADR-0022) so we inject
    // them back into the canonical map before hashing.
    final sortedRolePlays = rolePlays.toList()
      ..sort((a, b) => a.uuid.compareTo(b.uuid));
    final rolePlaysMaps = sortedRolePlays.map((rp) {
      final map = Map<String, dynamic>.from(rp.toJson());
      map['behavior'] = rp.behavior;
      map['background'] = rp.background;
      return _canonicalize(map) as Map<String, dynamic>;
    }).toList();

    final canonical = {
      'name': name,
      'description': description,
      'exercises': _sortedCanonical(exercises, (e) => e.uuid),
      'teams': _sortedCanonical(teams, (e) => e.uuid),
      'sessions': _sortedCanonical(sessions, (e) => e.uuid),
      'rolePlays': rolePlaysMaps,
    };
    return sha256
        .convert(utf8.encode(jsonEncode(_canonicalize(canonical))))
        .toString();
  }
}

ProgramDiff diffPrograms(Program local, Program remote) {
  final exerciseDiff = _diffNamed(
    local.exercises,
    remote.exercises,
    (e) => e.uuid,
    (e) => e.name,
  );
  final teamDiff = _diffNamed(
    local.teams,
    remote.teams,
    (e) => e.uuid,
    (e) => e.name,
  );
  final sessionDiff = _diffNamed(
    local.sessions,
    remote.sessions,
    (e) => e.uuid,
    (e) => e.uuid,
  );
  final rolePlayDiff = _diffNamed(
    local.rolePlays,
    remote.rolePlays,
    (r) => r.uuid,
    (r) => r.name,
  );

  final nameChanged = local.name != remote.name;
  final descriptionChanged = local.description != remote.description;

  return ProgramDiff(
    nameLocal: nameChanged ? local.name : null,
    nameRemote: nameChanged ? remote.name : null,
    descriptionLocal: descriptionChanged ? local.description : null,
    descriptionRemote: descriptionChanged ? remote.description : null,
    addedExercises: exerciseDiff.added,
    removedExercises: exerciseDiff.removed,
    modifiedExercises: exerciseDiff.modified,
    addedTeams: teamDiff.added,
    removedTeams: teamDiff.removed,
    modifiedTeams: teamDiff.modified,
    addedSessions: sessionDiff.added,
    removedSessions: sessionDiff.removed,
    modifiedSessions: sessionDiff.modified,
    addedRolePlays: rolePlayDiff.added,
    removedRolePlays: rolePlayDiff.removed,
    modifiedRolePlays: rolePlayDiff.modified,
  );
}

List<Map<String, dynamic>> _sortedCanonical<T>(
  Iterable<T> items,
  String Function(T item) uuid,
) {
  final sorted = items.toList()..sort((a, b) => uuid(a).compareTo(uuid(b)));
  return sorted
      .map(
        (item) =>
            _canonicalize((item as dynamic).toJson()) as Map<String, dynamic>,
      )
      .toList();
}

Object? _canonicalize(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((e) => e.toString()).toList()..sort();
    return {for (final key in keys) key: _canonicalize(value[key])};
  }
  if (value is List) {
    return value.map(_canonicalize).toList();
  }
  return value;
}

({List<String> added, List<String> removed, List<String> modified})
_diffNamed<T>(
  List<T> local,
  List<T> remote,
  String Function(T item) uuid,
  String Function(T item) name,
) {
  final localById = {for (final item in local) uuid(item): item};
  final remoteById = {for (final item in remote) uuid(item): item};
  final added = <String>[];
  final removed = <String>[];
  final modified = <String>[];

  for (final entry in remoteById.entries) {
    final localItem = localById[entry.key];
    if (localItem == null) {
      added.add(name(entry.value));
    } else if (jsonEncode(_canonicalize((localItem as dynamic).toJson())) !=
        jsonEncode(_canonicalize((entry.value as dynamic).toJson()))) {
      modified.add(name(entry.value));
    }
  }
  for (final entry in localById.entries) {
    if (!remoteById.containsKey(entry.key)) {
      removed.add(name(entry.value));
    }
  }

  added.sort();
  removed.sort();
  modified.sort();
  return (added: added, removed: removed, modified: modified);
}

/// Represents an immutable drill session
@freezed
sealed class Session with _$Session {
  const factory Session({
    required String uuid,
    required DateTime? startedAt,
    required DateTime? endedAt,
    required String exerciseUuid,
    required SimpleTimeOfDay startTime,
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
    // Optional schema marker added in schema 1.1 (ADR-0018).
    // Absent in 1.0 archives; readers treat null as '1.0'.
    String? schema,
  }) = _ProgramMetadata;

  factory ProgramMetadata.fromJson(Map<String, dynamic> json) =>
      _$ProgramMetadataFromJson(json);
}
