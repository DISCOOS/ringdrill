import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/models/actor.dart';
import 'package:ringdrill/models/drill_variable.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/numbering.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/station.dart';
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
    // @Default([]) so 1.0/1.1/1.2 archives without the key deserialize to
    // an empty registry (ADR-0046, additive field, no schema bump).
    @Default(<DrillVariable>[]) List<DrillVariable> variables,
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

    /// The catalog's publish version as of the last install/refresh/publish
    /// (e.g. "5"). Null for programs installed before this field existed;
    /// repopulated on the next successful refresh or publish.
    String? latestVersion,
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
/// fallback in `_diffItems`). A pure reorder (no content change at all) still
/// produces an [ItemDiff] whose only entry is a `field: 'order'`
/// [FieldChange] — see `_diffItems`.
///
/// [number] is the item's formatted display position (e.g. `"#2"` from
/// [Numbering.exercise]), used by the view to tell apart same-named items —
/// a drill program routinely has several exercises sharing a name (e.g. the
/// same round repeated per team). Null for entity types without a numbering
/// scheme (teams, sessions, role plays).
///
/// [nestedChanges] holds sub-entity diffs — currently only an exercise's
/// modified stations, one [ItemDiff] per station (see `_diffStations`).
/// Reuses this same shape (name + number + changes) rather than a bespoke
/// station-diff type since a station's own [number] is a
/// [Numbering.station] label ("1.2") and its changes are ordinary
/// [FieldChange]s — there is nothing station-specific about the shape
/// itself. [addedNested]/[removedNested] are the sub-entity equivalent of
/// [ProgramDiff]'s own `added*`/`removed*` lists, one level down — plain
/// names, no per-item detail, same as how the top-level added/removed
/// lists render. All three are empty for every entity type except
/// exercises today.
@freezed
sealed class ItemDiff with _$ItemDiff {
  const factory ItemDiff({
    required String name,
    String? number,
    @Default([]) List<FieldChange> changes,
    @Default([]) List<ItemDiff> nestedChanges,
    @Default([]) List<String> addedNested,
    @Default([]) List<String> removedNested,
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
  /// - `variables` — `toJson()` gives a raw, unsorted list; the version
  ///   sorted by name (ADR-0046) built below replaces it.
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
      ..remove('variables')
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
      // Sorted by name (not uuid — DrillVariable has no uuid) so archive
      // order never affects the hash (ADR-0046).
      'variables': _sortedCanonical(variables, (v) => v.name),
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
  final localExerciseOrdinals = _exerciseOrdinalsByUuid(local);
  final exerciseDiff = _diffItems<Exercise>(
    local.exercises,
    remote.exercises,
    uuid: (e) => e.uuid,
    name: (e) => e.name,
    // Same canonical map computeContentHash uses — deliberately order-
    // sensitive for stations, so a pure station reorder trips this "is the
    // exercise modified" check and _diffStations below gets the chance to
    // explain *what* moved via its own `field: 'order'` change, the same
    // way an exercise reorder is explained.
    canonicalize: _canonicalExerciseMap,
    fieldChanges: _exerciseFieldChanges,
    // Only exercises have a numbering scheme (Numbering.exercise) — passing
    // these also turns on per-item reorder detection in _diffItems, so a
    // moved exercise can be labelled "moved from #x to #y" using each
    // side's own formatted position.
    localNumbersByUuid: _exerciseNumbersByUuid(local),
    remoteNumbersByUuid: _exerciseNumbersByUuid(remote),
    // Station numbering always uses the LOCAL exercise's own ordinal and
    // format, matching how the exercise's own displayed number is always
    // the local one — a station label nested under it should use the same
    // exercise-number context, not the remote's.
    nestedChanges: (localEx, remoteEx) => _diffStations(
      localEx,
      remoteEx,
      local.stationNumberFormat,
      localExerciseOrdinals[localEx.uuid] ?? 1,
    ),
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

/// 1-based position of every exercise in [program], keyed by uuid, sorted
/// by [Exercise.index]. Shared by [_exerciseNumbersByUuid] (which formats
/// it via [Numbering.exercise]) and `diffPrograms` (which needs the raw int
/// to label that exercise's stations via [Numbering.station]).
Map<String, int> _exerciseOrdinalsByUuid(Program program) {
  final sorted = [...program.exercises]
    ..sort((a, b) => a.index.compareTo(b.index));
  return {for (var i = 0; i < sorted.length; i++) sorted[i].uuid: i + 1};
}

/// Formatted display position (e.g. `"#2"`) for every exercise in
/// [program], keyed by uuid — the number the app already shows elsewhere
/// (see [ExerciseNumberBadge]). Passed into `_diffItems` so a modified or
/// reordered exercise can be labelled the same way the rest of the app
/// labels it, disambiguating same-named exercises (a drill program routinely
/// repeats the same exercise name across rounds/teams).
Map<String, String> _exerciseNumbersByUuid(Program program) {
  final ordinals = _exerciseOrdinalsByUuid(program);
  return {
    for (final entry in ordinals.entries)
      entry.key: Numbering.exercise(program.exerciseNumberFormat, entry.value),
  };
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
/// rationale as [ProgramX.computeContentHash]'s denylist. Station edits are
/// NOT covered here — they are reported separately, per station, via
/// `_diffStations` and attached to the exercise's [ItemDiff.nestedChanges]
/// (see `diffPrograms`) — `_diffItems`'s exhaustive canonical-map comparison
/// is what actually decides whether the exercise is "modified" at all; this
/// only explains its own top-level fields.
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
  return changes;
}

/// Station-level diff for a modified exercise: which stations were added,
/// removed, or edited, matched between local and remote — deliberately NOT
/// by [Station.index] alone, since [Station] has no uuid and matching
/// purely by position makes a plain *reorder* look like every field of
/// every affected station changed (each index now points at a different
/// physical station).
///
/// Matching is name-first: a station whose name appears exactly once on
/// each side is paired by name, which resolves a pure reorder cleanly
/// (the name didn't move, only the index did, and [_stationFieldChanges]
/// already excludes index from content comparison — a name-matched pair
/// with nothing else different simply isn't reported as changed at all).
/// Whatever's left over (duplicate/ambiguous names, or a name that only
/// exists on one side) falls back to matching by index, the same
/// best-effort behavior stations have always had. This is diff-only —
/// no persisted identity, no migration, computed fresh from whichever
/// local/remote pair is being compared (which is always the catalog's
/// current published state for `remote`), so there is nothing to keep in
/// sync across sessions or devices.
///
/// A station that's genuinely renamed *and* reordered in the same edit is
/// unrecoverable from content alone (ambiguous even to a human comparing
/// the two lists) and may show as removed+added instead of modified —
/// accepted as a rare edge case, and never worse than the old behavior of
/// showing every field of every station as changed on every reorder.
///
/// Once paired, a station's relative rank among the *other paired stations*
/// (not its raw index, which an insertion/removal elsewhere would shift even
/// with nothing about relative order changed) is compared local-vs-remote,
/// the same rank-based approach `_diffItems` uses for exercises — a genuine
/// swap surfaces as its own `field: 'order'` change, combined on one card
/// with any real field edit the same station also picked up.
///
/// [exerciseNumber] is the parent exercise's own 1-based local position;
/// combined with [format] via [Numbering.station] it labels each station
/// the same way the rest of the app does (e.g. "1.2").
({List<String> added, List<String> removed, List<ItemDiff> modified})
_diffStations(
  Exercise local,
  Exercise remote,
  StationNumberFormat format,
  int exerciseNumber,
) {
  final consumedLocal = <int>{};
  final consumedRemote = <int>{};
  final pairs = <(Station, Station)>[];

  final localByName = <String, List<Station>>{};
  for (final s in local.stations) {
    localByName.putIfAbsent(s.name, () => []).add(s);
  }
  final remoteByName = <String, List<Station>>{};
  for (final s in remote.stations) {
    remoteByName.putIfAbsent(s.name, () => []).add(s);
  }
  for (final entry in localByName.entries) {
    final localGroup = entry.value;
    final remoteGroup = remoteByName[entry.key];
    if (localGroup.length == 1 && remoteGroup?.length == 1) {
      pairs.add((localGroup.single, remoteGroup!.single));
      consumedLocal.add(localGroup.single.index);
      consumedRemote.add(remoteGroup.single.index);
    }
  }

  final leftoverRemoteByIndex = {
    for (final s in remote.stations)
      if (!consumedRemote.contains(s.index)) s.index: s,
  };
  for (final s in local.stations) {
    if (consumedLocal.contains(s.index)) continue;
    final match = leftoverRemoteByIndex[s.index];
    if (match == null) continue;
    pairs.add((s, match));
    consumedLocal.add(s.index);
    consumedRemote.add(match.index);
  }

  final added =
      remote.stations
          .where((s) => !consumedRemote.contains(s.index))
          .map((s) => s.name)
          .toList()
        ..sort();
  final removed =
      local.stations
          .where((s) => !consumedLocal.contains(s.index))
          .map((s) => s.name)
          .toList()
        ..sort();

  // Rank each paired station among the *other paired* stations, local order
  // vs. remote order — mirrors _diffItems's exercise-level reorder check.
  // Keyed by local index (unique within `local.stations`, and every pair
  // has exactly one), since Station has no uuid to key by.
  final localRankByLocalIndex = {
    for (final (rank, pair) in (List.of(pairs)..sort(
      (a, b) => a.$1.index.compareTo(b.$1.index),
    )).indexed)
      pair.$1.index: rank,
  };
  final remoteRankByLocalIndex = {
    for (final (rank, pair) in (List.of(pairs)..sort(
      (a, b) => a.$2.index.compareTo(b.$2.index),
    )).indexed)
      pair.$1.index: rank,
  };

  final modified = <(ItemDiff, int)>[];
  for (final (localStation, remoteStation) in pairs) {
    var changes = _stationFieldChanges(localStation, remoteStation);
    if (localRankByLocalIndex[localStation.index] !=
        remoteRankByLocalIndex[localStation.index]) {
      changes = [
        FieldChange(
          field: 'order',
          local: Numbering.station(
            format,
            exerciseNumber: exerciseNumber,
            stationIndex: localStation.index,
          ),
          remote: Numbering.station(
            format,
            exerciseNumber: exerciseNumber,
            stationIndex: remoteStation.index,
          ),
        ),
        ...changes,
      ];
    }
    if (changes.isEmpty) continue;
    modified.add((
      ItemDiff(
        name: localStation.name,
        number: Numbering.station(
          format,
          exerciseNumber: exerciseNumber,
          stationIndex: localStation.index,
        ),
        changes: changes,
      ),
      localStation.index,
    ));
  }
  modified.sort((a, b) => a.$2.compareTo(b.$2));

  return (added: added, removed: removed, modified: modified.map((m) => m.$1).toList());
}

/// Best-effort field-level changes between two [Station]s, mirroring
/// [_teamFieldChanges]'s shape. `index` is identity, not content, and is
/// skipped. `variantSuffix` has no editable UI anywhere in the app — only
/// `brief_renderer.dart` reads it for display — so it is excluded too, same
/// rationale as the bookkeeping fields [_exerciseFieldChanges] skips.
List<FieldChange> _stationFieldChanges(Station local, Station remote) {
  final changes = <FieldChange>[];
  void add(String field, String? l, String? r) {
    if (l != r) changes.add(FieldChange(field: field, local: l, remote: r));
  }

  add('name', local.name, remote.name);
  add('description', local.description, remote.description);
  add(
    'position',
    _latLngLabel(local.position),
    _latLngLabel(remote.position),
  );
  add('equipmentMd', local.equipmentMd, remote.equipmentMd);
  add('situationMd', local.situationMd, remote.situationMd);
  add('missionMd', local.missionMd, remote.missionMd);
  add('logisticsMd', local.logisticsMd, remote.logisticsMd);
  add(
    'criticalQuestionsMd',
    local.criticalQuestionsMd,
    remote.criticalQuestionsMd,
  );
  add('leaderAnswersMd', local.leaderAnswersMd, remote.leaderAnswersMd);
  add('directorNotesMd', local.directorNotesMd, remote.directorNotesMd);
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
  // Formatted position (e.g. "#2") on each side, keyed by uuid. Only
  // exercises have a numbering scheme (see [Numbering.exercise]) — passing
  // these also turns on per-item reorder detection below, since without a
  // way to *label* the old and new position there is nothing useful to
  // tell the user beyond the vague "something moved".
  Map<String, String>? localNumbersByUuid,
  Map<String, String>? remoteNumbersByUuid,
  // Sub-entity diffs (currently only an exercise's stations) — same shape
  // as this function's own return record, one level down. See
  // [ItemDiff.nestedChanges]/[ItemDiff.addedNested]/[ItemDiff.removedNested].
  // Only called when the top-level canonical comparison finds the pair
  // unequal, same gating as [fieldChanges].
  ({List<String> added, List<String> removed, List<ItemDiff> modified})
  Function(T local, T remote)?
  nestedChanges,
}) {
  final localById = {for (final item in local) uuid(item): item};
  final remoteById = {for (final item in remote) uuid(item): item};
  final added = <String>[];
  final removed = <String>[];

  // 'index' records position, not content — stripped before deciding
  // whether an item is "modified" so a pure reorder doesn't also read as a
  // content edit. Reordering is reported separately below as its own
  // `field: 'order'` change, attributed to the specific item that moved,
  // instead of a generic "Other changes" or an aggregate note that lists
  // every item regardless of whether it actually moved.
  Map<String, dynamic> withoutIndex(T item) =>
      Map<String, dynamic>.from(canonicalize(item))..remove('index');
  int? rawIndex(T item) {
    final value = canonicalize(item)['index'];
    return value is int ? value : null;
  }

  T at(Map<String, T> map, String key) => map[key] as T;

  // Reordering is compared by each side's *relative rank* among items
  // common to both sides, not raw index — an insertion or removal shifts
  // every later item's absolute index even though nothing about their
  // relative order changed; only a genuine swap changes an item's rank
  // relative to its peers.
  var reorderedUuids = const <String>{};
  if (localNumbersByUuid != null) {
    final commonUuids = localById.keys.where(remoteById.containsKey).toList();
    final localRanked = [...commonUuids]..sort(
      (a, b) =>
          (rawIndex(at(localById, a)) ?? 0).compareTo(
            rawIndex(at(localById, b)) ?? 0,
          ),
    );
    final remoteRanked = [...commonUuids]..sort(
      (a, b) =>
          (rawIndex(at(remoteById, a)) ?? 0).compareTo(
            rawIndex(at(remoteById, b)) ?? 0,
          ),
    );
    final localRank = {
      for (var i = 0; i < localRanked.length; i++) localRanked[i]: i,
    };
    final remoteRank = {
      for (var i = 0; i < remoteRanked.length; i++) remoteRanked[i]: i,
    };
    reorderedUuids = {
      for (final u in commonUuids)
        if (localRank[u] != remoteRank[u]) u,
    };
  }

  // (ItemDiff, sortKey) — sortKey is the local raw index when numbered
  // (keeps same-named exercises in plan order rather than an alphabetical
  // clump) and is unused otherwise, where entries sort by name instead.
  final modified = <(ItemDiff, int)>[];
  for (final entry in remoteById.entries) {
    final localItem = localById[entry.key];
    if (localItem == null) {
      added.add(name(entry.value));
      continue;
    }
    final contentDiffers =
        jsonEncode(withoutIndex(localItem)) !=
        jsonEncode(withoutIndex(entry.value));
    var changes = contentDiffers
        ? fieldChanges(localItem, entry.value)
        : <FieldChange>[];
    // Only computed when the pair actually differs, same gating as
    // `changes` — in the common unchanged case there is nothing to nest.
    final nestedResult = contentDiffers
        ? nestedChanges?.call(localItem, entry.value)
        : null;
    final nested = nestedResult?.modified ?? const <ItemDiff>[];
    final addedNested = nestedResult?.added ?? const <String>[];
    final removedNested = nestedResult?.removed ?? const <String>[];
    // The curated field list above doesn't cover every JSON key — fall back
    // to a generic marker rather than silently showing "modified" with no
    // explanation when the actual diff lives in an uncurated field. Skipped
    // when the nested result already explains the difference (e.g. a
    // station-only edit), so that case doesn't also show a spurious "Other
    // changes".
    if (contentDiffers &&
        changes.isEmpty &&
        nested.isEmpty &&
        addedNested.isEmpty &&
        removedNested.isEmpty) {
      changes = const [FieldChange(field: 'other')];
    }
    final newPosition = localNumbersByUuid?[entry.key];
    final oldPosition = remoteNumbersByUuid?[entry.key];
    if (reorderedUuids.contains(entry.key) &&
        newPosition != null &&
        oldPosition != null) {
      changes = [
        FieldChange(field: 'order', local: newPosition, remote: oldPosition),
        ...changes,
      ];
    }
    if (changes.isNotEmpty ||
        nested.isNotEmpty ||
        addedNested.isNotEmpty ||
        removedNested.isNotEmpty) {
      modified.add((
        ItemDiff(
          name: name(entry.value),
          number: newPosition,
          changes: changes,
          nestedChanges: nested,
          addedNested: addedNested,
          removedNested: removedNested,
        ),
        rawIndex(localItem) ?? 0,
      ));
    }
  }
  for (final entry in localById.entries) {
    if (!remoteById.containsKey(entry.key)) {
      removed.add(name(entry.value));
    }
  }

  added.sort();
  removed.sort();
  modified.sort(
    localNumbersByUuid != null
        ? (a, b) => a.$2.compareTo(b.$2)
        : (a, b) => a.$1.name.compareTo(b.$1.name),
  );

  return (
    added: added,
    removed: removed,
    modified: modified.map((m) => m.$1).toList(),
  );
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
