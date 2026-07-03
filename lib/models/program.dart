import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/models/actor.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/numbering.dart';
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
    @Default(ExerciseNumberFormat.hash) ExerciseNumberFormat exerciseNumberFormat,
    @Default(StationNumberFormat.dotted) StationNumberFormat stationNumberFormat,
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
    // @Default([]) so 1.0/1.1/1.2 archives without the key deserialize to
    // an empty list rather than failing (ADR-0043; same pattern as ADR-0018).
    @Default(<String>[]) List<String> tags,
    // Markdown brief fields — stored as program/<field>.md, not in JSON.
    @JsonKey(includeFromJson: false, includeToJson: false) String? briefIntroMd,
    @JsonKey(includeFromJson: false, includeToJson: false) String? commsMd,
    @JsonKey(includeFromJson: false, includeToJson: false)
    String? beforeRoundMd,
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

    /// Local tags joined as a comma-separated string when they differ from
    /// remote. Null when tag lists match.
    String? tagsLocal,

    /// Remote tags joined as a comma-separated string when they differ from
    /// local. Null when tag lists match.
    String? tagsRemote,
    @Default([]) List<String> addedExercises,
    @Default([]) List<String> removedExercises,
    @Default([]) List<ItemDiff> modifiedExercises,
    @Default([]) List<String> addedTeams,
    @Default([]) List<String> removedTeams,
    @Default([]) List<ItemDiff> modifiedTeams,
    @Default([]) List<String> addedSessions,
    @Default([]) List<String> removedSessions,
    @Default([]) List<ItemDiff> modifiedSessions,
    // rolePlays are included in the content hash; actors are not.
    @Default([]) List<String> addedRolePlays,
    @Default([]) List<String> removedRolePlays,
    @Default([]) List<ItemDiff> modifiedRolePlays,
  }) = _ProgramDiff;

  factory ProgramDiff.fromJson(Map<String, dynamic> json) =>
      _$ProgramDiffFromJson(json);
}

/// A single field that differs between the local and remote copy of a
/// modified [ProgramDiff] item. [field] is a stable, non-localized key (e.g.
/// `"name"`, `"methodMd"`) — the view layer maps it to a display label.
/// [local]/[remote] are pre-formatted for display; both null means the
/// field's presence/absence toggled (e.g. a nested list changed) rather than
/// a scalar value, so the view shows the label alone.
@freezed
sealed class FieldChange with _$FieldChange {
  const factory FieldChange({
    required String field,
    String? local,
    String? remote,
  }) = _FieldChange;

  factory FieldChange.fromJson(Map<String, dynamic> json) =>
      _$FieldChangeFromJson(json);
}

/// A modified item (exercise/team/session/rolePlay) in a [ProgramDiff],
/// naming which of its fields changed. [changes] is best-effort: it covers
/// the fields users actually edit, not every JSON key, so it can be empty
/// even though the item as a whole compares unequal (see the "other changes"
/// fallback in `_diffItems`).
@freezed
sealed class ItemDiff with _$ItemDiff {
  const factory ItemDiff({
    required String name,
    @Default([]) List<FieldChange> changes,
  }) = _ItemDiff;

  factory ItemDiff.fromJson(Map<String, dynamic> json) =>
      _$ItemDiffFromJson(json);
}

extension ProgramX on Program {
  /// Stable fingerprint of the user-visible content. Used to detect whether
  /// the local copy has unpublished edits when refreshing from the catalog.
  ///
  /// This is a DENYLIST, not an allowlist: [programMap] below starts from
  /// this program's own [Program.toJson] — which already carries every
  /// current field, and every field added to [Program] in the future,
  /// automatically — and then only *removes* the handful of keys that must
  /// be excluded. The previous version hand-listed the fields to include
  /// (just `name`/`description`/`tags`/the brief markdown fields) and
  /// silently missed `exerciseNumberFormat` and `stationNumberFormat` as a
  /// result; a denylist can't have that failure mode for a *new* top-level
  /// field — at worst a genuinely inert bookkeeping field gets included by
  /// mistake (a spurious "unpublished" flag that self-corrects on the next
  /// publish), which is far cheaper than silently failing to detect a real
  /// edit. The exercise/station/team/session/rolePlay levels already follow
  /// this same "start from toJson, patch in what's excluded" shape below —
  /// only the program level was still hand-listed.
  ///
  /// Removed on purpose:
  /// - `uuid`, `contentHash`, `source` — identity/bookkeeping, not content.
  /// - `actors` — local PII, excluded entirely per ADR-0018.
  /// - `metadata` — carries `languageCode` (user-chosen content, ADR-0007
  ///   addendum) alongside `created`/`updated`/`version`/`schema`, which
  ///   drift without the plan's content changing. Only `languageCode` is
  ///   re-added below.
  /// - `exercises`/`teams`/`sessions`/`rolePlays` — `toJson()` gives raw,
  ///   unsorted versions with markdown fields missing; the sorted,
  ///   markdown-complete versions built below replace them.
  ///
  /// If you add a new bookkeeping-only field to [Program] or [ProgramMetadata]
  /// (something that changes without the plan's content changing), add it
  /// to the removal list above. If you're unsure whether a new field
  /// belongs here, leave it included — that is the safe default.
  ///
  /// All *Md fields are excluded from toJson (ADR-0022) so they are injected
  /// back into the canonical maps before hashing. Stations inside exercises
  /// are sorted by index for determinism. Exercises and RolePlays are
  /// sorted by uuid.
  String computeContentHash() {
    // Build canonical exercise/rolePlay maps with markdown fields injected.
    // Shared with diffPrograms() below so both stay exhaustive over the same
    // set of fields.
    final sortedExercises = exercises.toList()
      ..sort((a, b) => a.uuid.compareTo(b.uuid));
    final exerciseMaps = sortedExercises.map(_canonicalExerciseMap).toList();

    // rolePlays are publishable; actors are local PII and excluded per ADR-0018.
    final sortedRolePlays = rolePlays.toList()
      ..sort((a, b) => a.uuid.compareTo(b.uuid));
    final rolePlaysMaps = sortedRolePlays.map(_canonicalRolePlayMap).toList();

    // Denylist, not allowlist — see the class-level doc comment above.
    final programMap = Map<String, dynamic>.from(toJson())
      ..remove('uuid')
      ..remove('contentHash')
      ..remove('source')
      ..remove('actors')
      ..remove('metadata')
      ..remove('exercises')
      ..remove('teams')
      ..remove('sessions')
      ..remove('rolePlays')
      ..['languageCode'] = metadata.languageCode
      ..['briefIntroMd'] = briefIntroMd
      ..['commsMd'] = commsMd
      ..['beforeRoundMd'] = beforeRoundMd;

    final canonical = {
      ...programMap,
      'exercises': exerciseMaps,
      'teams': _sortedCanonical(teams, (e) => e.uuid),
      'sessions': _sortedCanonical(sessions, (e) => e.uuid),
      'rolePlays': rolePlaysMaps,
    };
    return sha256
        .convert(utf8.encode(jsonEncode(_canonicalize(canonical))))
        .toString();
  }
}

/// Canonical JSON map for an [Exercise], with its own and its stations'
/// markdown fields (excluded from `toJson()` per ADR-0022) injected back in.
/// Shared by [ProgramX.computeContentHash] and [diffPrograms] so both stay
/// exhaustive over the same fields — see the denylist doc comment above for
/// why a separate, hand-rolled comparison used to silently miss
/// markdown-only edits.
Map<String, dynamic> _canonicalExerciseMap(Exercise ex) {
  final map = Map<String, dynamic>.from(ex.toJson());
  map['methodMd'] = ex.methodMd;
  map['learningGoalsMd'] = ex.learningGoalsMd;
  map['trainingFocusMd'] = ex.trainingFocusMd;
  map['orderFormatMd'] = ex.orderFormatMd;
  map['executionTipsMd'] = ex.executionTipsMd;
  map['commsMd'] = ex.commsMd;
  // Patch station maps in place with their markdown fields.
  // Stations are sorted by index for determinism.
  final sortedStations = ex.stations.toList()
    ..sort((a, b) => a.index.compareTo(b.index));
  map['stations'] = sortedStations.map((s) {
    final sMap = Map<String, dynamic>.from(s.toJson());
    sMap['equipmentMd'] = s.equipmentMd;
    sMap['situationMd'] = s.situationMd;
    sMap['missionMd'] = s.missionMd;
    sMap['logisticsMd'] = s.logisticsMd;
    sMap['criticalQuestionsMd'] = s.criticalQuestionsMd;
    sMap['leaderAnswersMd'] = s.leaderAnswersMd;
    sMap['directorNotesMd'] = s.directorNotesMd;
    return _canonicalize(sMap);
  }).toList();
  return _canonicalize(map) as Map<String, dynamic>;
}

/// Canonical JSON map for a [RolePlay], with `behavior`/`background`/
/// `propsMd` (excluded from `toJson()` per ADR-0022) injected back in.
Map<String, dynamic> _canonicalRolePlayMap(RolePlay rp) {
  final map = Map<String, dynamic>.from(rp.toJson());
  map['behavior'] = rp.behavior;
  map['background'] = rp.background;
  map['propsMd'] = rp.propsMd;
  return _canonicalize(map) as Map<String, dynamic>;
}

ProgramDiff diffPrograms(Program local, Program remote) {
  final exerciseDiff = _diffItems<Exercise>(
    local.exercises,
    remote.exercises,
    uuid: (e) => e.uuid,
    name: (e) => e.name,
    canonicalize: _canonicalExerciseMap,
    fieldChanges: _exerciseFieldChanges,
  );
  final teamDiff = _diffItems<Team>(
    local.teams,
    remote.teams,
    uuid: (e) => e.uuid,
    name: (e) => e.name,
    canonicalize: (t) => _canonicalize(t.toJson()) as Map<String, dynamic>,
    fieldChanges: _teamFieldChanges,
  );
  final sessionDiff = _diffItems<Session>(
    local.sessions,
    remote.sessions,
    uuid: (e) => e.uuid,
    name: (e) => e.uuid,
    canonicalize: (s) => _canonicalize(s.toJson()) as Map<String, dynamic>,
    fieldChanges: _sessionFieldChanges,
  );
  final rolePlayDiff = _diffItems<RolePlay>(
    local.rolePlays,
    remote.rolePlays,
    uuid: (r) => r.uuid,
    name: (r) => r.name,
    canonicalize: _canonicalRolePlayMap,
    fieldChanges: _rolePlayFieldChanges,
  );

  final nameChanged = local.name != remote.name;
  final descriptionChanged = local.description != remote.description;
  final localTagsSorted = [...local.tags]..sort();
  final remoteTagsSorted = [...remote.tags]..sort();
  final tagsChanged =
      localTagsSorted.join(',') != remoteTagsSorted.join(',');

  return ProgramDiff(
    nameLocal: nameChanged ? local.name : null,
    nameRemote: nameChanged ? remote.name : null,
    descriptionLocal: descriptionChanged ? local.description : null,
    descriptionRemote: descriptionChanged ? remote.description : null,
    tagsLocal: tagsChanged ? local.tags.join(', ') : null,
    tagsRemote: tagsChanged ? remote.tags.join(', ') : null,
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

/// Best-effort field-level changes between two [Exercise]s, for display in
/// the catalog-conflict diff. Not exhaustive — `index`/`schedule`/
/// `metadata`/`templateId` are bookkeeping/derived and skipped, same
/// rationale as [ProgramX.computeContentHash]'s denylist. Nested station
/// edits are reported as a single `"stations"` entry rather than broken
/// down per station/field — `_diffItems`'s exhaustive canonical-map
/// comparison is what actually decides whether the exercise is "modified"
/// at all; this only explains it.
List<FieldChange> _exerciseFieldChanges(Exercise local, Exercise remote) {
  final changes = <FieldChange>[];
  void add(String field, String? l, String? r) {
    if (l != r) changes.add(FieldChange(field: field, local: l, remote: r));
  }

  add('name', local.name, remote.name);
  add('startTime', local.startTime.toString(), remote.startTime.toString());
  add('endTime', local.endTime.toString(), remote.endTime.toString());
  add('numberOfTeams', '${local.numberOfTeams}', '${remote.numberOfTeams}');
  add('numberOfRounds', '${local.numberOfRounds}', '${remote.numberOfRounds}');
  add('executionTime', '${local.executionTime}', '${remote.executionTime}');
  add('evaluationTime', '${local.evaluationTime}', '${remote.evaluationTime}');
  add('rotationTime', '${local.rotationTime}', '${remote.rotationTime}');
  add('methodMd', local.methodMd, remote.methodMd);
  add('learningGoalsMd', local.learningGoalsMd, remote.learningGoalsMd);
  add('trainingFocusMd', local.trainingFocusMd, remote.trainingFocusMd);
  add('orderFormatMd', local.orderFormatMd, remote.orderFormatMd);
  add('executionTipsMd', local.executionTipsMd, remote.executionTipsMd);
  add('commsMd', local.commsMd, remote.commsMd);

  final localStations = _canonicalExerciseMap(local)['stations'];
  final remoteStations = _canonicalExerciseMap(remote)['stations'];
  if (jsonEncode(localStations) != jsonEncode(remoteStations)) {
    changes.add(const FieldChange(field: 'stations'));
  }
  return changes;
}

List<FieldChange> _teamFieldChanges(Team local, Team remote) {
  final changes = <FieldChange>[];
  void add(String field, String? l, String? r) {
    if (l != r) changes.add(FieldChange(field: field, local: l, remote: r));
  }

  add('name', local.name, remote.name);
  add(
    'numberOfMembers',
    local.numberOfMembers?.toString(),
    remote.numberOfMembers?.toString(),
  );
  add(
    'position',
    _latLngLabel(local.position),
    _latLngLabel(remote.position),
  );
  return changes;
}

List<FieldChange> _sessionFieldChanges(Session local, Session remote) {
  final changes = <FieldChange>[];
  void add(String field, String? l, String? r) {
    if (l != r) changes.add(FieldChange(field: field, local: l, remote: r));
  }

  add(
    'startedAt',
    local.startedAt?.toIso8601String(),
    remote.startedAt?.toIso8601String(),
  );
  add(
    'endedAt',
    local.endedAt?.toIso8601String(),
    remote.endedAt?.toIso8601String(),
  );
  add('startTime', local.startTime.toString(), remote.startTime.toString());
  return changes;
}

List<FieldChange> _rolePlayFieldChanges(RolePlay local, RolePlay remote) {
  final changes = <FieldChange>[];
  void add(String field, String? l, String? r) {
    if (l != r) changes.add(FieldChange(field: field, local: l, remote: r));
  }

  add('name', local.name, remote.name);
  add('age', local.age?.toString(), remote.age?.toString());
  add('signalement', local.signalement, remote.signalement);
  add('background', local.background, remote.background);
  add('behavior', local.behavior, remote.behavior);
  add('propsMd', local.propsMd, remote.propsMd);
  add(
    'position',
    _latLngLabel(local.position),
    _latLngLabel(remote.position),
  );
  return changes;
}

String? _latLngLabel(LatLng? position) =>
    position == null ? null : '${position.latitude}, ${position.longitude}';

({List<String> added, List<String> removed, List<ItemDiff> modified})
_diffItems<T>(
  List<T> local,
  List<T> remote, {
  required String Function(T item) uuid,
  required String Function(T item) name,
  required Map<String, dynamic> Function(T item) canonicalize,
  required List<FieldChange> Function(T local, T remote) fieldChanges,
}) {
  final localById = {for (final item in local) uuid(item): item};
  final remoteById = {for (final item in remote) uuid(item): item};
  final added = <String>[];
  final removed = <String>[];
  final modified = <ItemDiff>[];

  for (final entry in remoteById.entries) {
    final localItem = localById[entry.key];
    if (localItem == null) {
      added.add(name(entry.value));
    } else if (jsonEncode(canonicalize(localItem)) !=
        jsonEncode(canonicalize(entry.value))) {
      var changes = fieldChanges(localItem, entry.value);
      // The curated field list above doesn't cover every JSON key — fall
      // back to a generic marker rather than silently showing "modified"
      // with no explanation when the actual diff lives in an uncurated
      // field.
      if (changes.isEmpty) {
        changes = const [FieldChange(field: 'other')];
      }
      modified.add(ItemDiff(name: name(entry.value), changes: changes));
    }
  }
  for (final entry in localById.entries) {
    if (!remoteById.containsKey(entry.key)) {
      removed.add(name(entry.value));
    }
  }

  added.sort();
  removed.sort();
  modified.sort((a, b) => a.name.compareTo(b.name));
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
    // ISO 639-1 code for the plan's *content* language (name, briefs,
    // exercise/station/team names) — unrelated to the app's own UI locale.
    // null until the author picks one via ProgramFormScreen (ADR-0007
    // addendum). Never defaulted or guessed by readers.
    String? languageCode,
  }) = _ProgramMetadata;

  factory ProgramMetadata.fromJson(Map<String, dynamic> json) =>
      _$ProgramMetadataFromJson(json);
}
