import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:nanoid/nanoid.dart';
import 'package:ringdrill/data/drill_client.dart';
import 'package:ringdrill/data/drill_file.dart';
import 'package:ringdrill/data/drill_library.dart';
import 'package:ringdrill/data/plan_repository.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/staff.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/numbering.dart';
import 'package:ringdrill/models/plan.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/schedule.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/models/team.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/utils/prefs.dart';
import 'package:ringdrill/utils/time_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef OnSelectExercises =
    Future<Iterable<Exercise>?> Function(Iterable<Exercise> items);

/// Thrown by [PlanService.deletePlan] when the user asks to
/// delete their only remaining plan.
///
/// Per ADR-0038 §"Edge case: no active plan", the app guarantees an
/// active plan exists from the moment onboarding completes — so
/// allowing the user to delete the last plan would put them back in
/// the unsupported "no plan" state. UI surfaces catch this and
/// surface a localized snackbar instead of letting the deletion
/// proceed.
class LastPlanDeletionException implements Exception {
  const LastPlanDeletionException();
  @override
  String toString() =>
      'LastPlanDeletionException: refusing to delete the only remaining plan';
}

enum PlanEventType {
  exerciseAdded,
  exerciseDeleted,
  teamSaved,
  rolePlaySaved,
  rolePlayDeleted,
  actorSaved,
  actorDeleted,
  planOpened,
  planImported,
  planExported,
  planCreated,
  planDeleted,
  planActivated,
  planInstalled,
  planRefreshed,
}

enum CatalogConflictChoice {
  cancel,
  overwriteLocal,
  publishMyChanges,
  forkAsLocal,
}

enum CatalogRefreshKind {
  upToDate,
  updatedSilently,
  updatedAfterPrompt,
  cancelled,
  published,
  forked,
  failed,
  // The catalog slug this plan was installed from no longer exists on the
  // server (HEAD returned 404) — distinct from [failed], which is "this
  // isn't a catalog plan at all". Checked explicitly before calling
  // download() so that request doesn't throw an uncaught 404
  // DrillApiException that a generic catch-all would otherwise report as
  // "catalog service unavailable", which is misleading: the service is
  // fine, this specific plan is just gone.
  removedFromCatalog,
}

class CatalogRefreshOutcome {
  const CatalogRefreshOutcome({
    required this.kind,
    required this.planUuid,
    this.diff,
    this.remoteUnchanged = false,
  });

  final CatalogRefreshKind kind;
  final String planUuid;
  final PlanDiff? diff;

  /// True when the catalog server reported no changes (HTTP 304) but the
  /// local copy diverged from the installed snapshot. Distinguishes a real
  /// catalog update from a local-only divergence so call sites can pick the
  /// right user-facing wording (e.g. "Updated from catalog" vs. "Discarded
  /// local changes").
  final bool remoteUnchanged;
}

/// Result of installing a drill-library bundle (ADR-0045).
class BundleInstallResult {
  const BundleInstallResult({required this.imported, required this.skipped});

  /// Number of inner `.drill` entries successfully installed.
  final int imported;

  /// Inner `.drill` entries that failed to parse and were skipped rather
  /// than aborting the rest of the bundle, one per failure, so the UI can
  /// tell the user which files were skipped and why instead of just a count.
  final List<SkippedDrillEntry> skipped;

  bool get hasFailures => skipped.isNotEmpty;
  bool get isEmpty => imported == 0 && skipped.isEmpty;
}

/// One inner `.drill` entry that [PlanService.installBundle] could not
/// install, and why.
class SkippedDrillEntry {
  const SkippedDrillEntry({required this.fileName, required this.reason});

  final String fileName;
  final DrillFormatReason reason;
}

class PlanEvent {
  final DrillFile? file;
  final Plan plan;
  final Exercise? exercise;
  final Team? team;
  final RolePlay? rolePlay;
  final Staff? actor;
  final PlanEventType type;

  PlanEvent(
    this.type,
    this.plan, {
    this.file,
    this.exercise,
    this.team,
    this.rolePlay,
    this.actor,
  });

  factory PlanEvent.added(Plan plan, Exercise exercise) =>
      PlanEvent(PlanEventType.exerciseAdded, plan, exercise: exercise);

  factory PlanEvent.deleted(Plan plan, Exercise exercise) =>
      PlanEvent(PlanEventType.exerciseDeleted, plan, exercise: exercise);

  factory PlanEvent.teamSaved(Plan plan, Team team) =>
      PlanEvent(PlanEventType.teamSaved, plan, team: team);

  factory PlanEvent.rolePlaySaved(Plan plan, RolePlay rolePlay) =>
      PlanEvent(PlanEventType.rolePlaySaved, plan, rolePlay: rolePlay);

  factory PlanEvent.rolePlayDeleted(Plan plan, RolePlay rolePlay) =>
      PlanEvent(PlanEventType.rolePlayDeleted, plan, rolePlay: rolePlay);

  factory PlanEvent.actorSaved(Plan plan, Staff actor) =>
      PlanEvent(PlanEventType.actorSaved, plan, actor: actor);

  factory PlanEvent.actorDeleted(Plan plan, Staff actor) =>
      PlanEvent(PlanEventType.actorDeleted, plan, actor: actor);

  factory PlanEvent.opened(Plan plan, DrillFile file) =>
      PlanEvent(PlanEventType.planOpened, plan, file: file);

  factory PlanEvent.imported(Plan plan, DrillFile file) =>
      PlanEvent(PlanEventType.planImported, plan, file: file);

  factory PlanEvent.importedPlan(Plan plan) =>
      PlanEvent(PlanEventType.planImported, plan);

  factory PlanEvent.exported(Plan plan, DrillFile file) =>
      PlanEvent(PlanEventType.planExported, plan, file: file);
}

class PlanService {
  static final PlanService _instance = PlanService._internal();

  factory PlanService() => _instance;

  PlanService._internal();

  final StreamController<PlanEvent> _controller = StreamController.broadcast();

  bool _isReady = false;
  // Not `final`: [reset] drops the initialised state so the next [init] can
  // rebind to a fresh SharedPreferences instance.
  late PlanRepository _repo;

  Stream<PlanEvent> get events => _controller.stream;

  Future<List<Exercise>> init() async {
    if (!_isReady) {
      // PlanRepository takes the instance itself. Prefer the bound one so a
      // normal launch does not resolve it twice.
      final prefs =
          Prefs.instanceOrNull ?? await SharedPreferences.getInstance();
      _repo = PlanRepository(prefs);
      await _repo.init();
      _isReady = true;
    }
    return activePlan == null ? const [] : _repo.loadExercises();
  }

  List<Plan> listPlans() => _isReady ? _repo.listPlans() : const [];

  Plan? loadPlan(String uuid) => _isReady ? _repo.loadPlan(uuid) : null;

  Plan? get activePlan {
    if (!_isReady) return null;
    final uuid = _repo.activePlanUuid;
    if (uuid == null) return null;
    return _repo.loadPlan(uuid);
  }

  String? get activePlanUuid => _isReady ? _repo.activePlanUuid : null;

  bool get librarySchemaJustMigrated =>
      _isReady && _repo.librarySchemaJustMigrated;

  Future<void> clearLibrarySchemaJustMigrated() =>
      _isReady ? _repo.clearLibrarySchemaJustMigrated() : Future.value();

  Future<Plan> createPlan({
    required String name,
    String description = '',
  }) async {
    final now = DateTime.now();
    final emptyPlan = Plan(
      uuid: nanoid(10),
      name: name,
      description: description,
      metadata: PlanMetadata(created: now, updated: now, version: '1.0'),
      source: const PlanSource.local(),
      teams: const [],
      sessions: const [],
      exercises: const [],
      rolePlays: const [],
      staff: const [],
    );
    final plan = emptyPlan.copyWith(
      contentHash: emptyPlan.computeContentHash(),
    );
    await _repo.savePlanShell(plan);
    _controller.add(PlanEvent(PlanEventType.planCreated, plan));
    return plan;
  }

  Future<void> setActive(String uuid) async {
    if (ExerciseService().isStarted) {
      throw StateError('Cannot switch active plan while an exercise runs.');
    }
    await _repo.setActivePlanUuid(uuid);
    final plan = _repo.loadPlan(uuid);
    if (plan != null) {
      _controller.add(PlanEvent(PlanEventType.planActivated, plan));
    }
  }

  Future<void> deletePlan(String uuid) async {
    if (_repo.activePlanUuid == uuid && ExerciseService().isStarted) {
      throw StateError('Cannot delete active plan while an exercise runs.');
    }
    // The library is required to keep at least one plan around so
    // `activePlan` is never null (ADR-0038). UI-side guards
    // should catch this before the user attempts the deletion, but
    // the service throws as defence-in-depth in case a call site
    // forgets.
    if (_repo.listPlans().length <= 1) {
      throw const LastPlanDeletionException();
    }
    final plan = _repo.loadPlan(uuid);
    await _repo.deletePlan(uuid);
    if (plan != null) {
      _controller.add(PlanEvent(PlanEventType.planDeleted, plan));
    }
  }

  /// Wipes every plan from the repository, bypassing the
  /// [LastPlanDeletionException] guard that protects production callers
  /// (ADR-0038). Test-only — production code paths must keep at least one
  /// plan around. Drives `tearDown` blocks that reset state between tests.
  @visibleForTesting
  Future<void> clearAllForTest() async {
    if (!_isReady) return;
    for (final plan in List<Plan>.from(_repo.listPlans())) {
      await _repo.deletePlan(plan.uuid);
    }
  }

  /// Drops the initialised repository so the next [init] rebinds to whatever
  /// `SharedPreferences` instance is current.
  ///
  /// Test-only. `SharedPreferences.setMockInitialValues` hands each test a
  /// fresh instance, but this service is a singleton that captures the first
  /// one — so without a reset, a re-seed between tests is invisible here (every
  /// test keeps reading the *first* test's data) and anything written through
  /// the service outlives the test that wrote it. Call this before [init] in
  /// `setUp`.
  ///
  /// Deliberately leaves [events] alone. Subscribers are widget-scoped and
  /// cancel on dispose, so there is nothing to clean up, and replacing the
  /// broadcast controller would silently detach any listener that legitimately
  /// outlives a reset.
  @visibleForTesting
  void reset() {
    _isReady = false;
  }

  Future<void> replacePlan(Plan plan) async {
    await _repo.savePlan(plan);
    _controller.add(PlanEvent(PlanEventType.planRefreshed, plan));
  }

  Exercise? getExercise(String uuid) => _repo.getExercise(uuid);

  List<RolePlay> loadRolePlays() {
    if (activePlanUuid == null) return const [];
    return _repo.loadRolePlays();
  }

  RolePlay? getRolePlay(String uuid) => _repo.getRolePlay(uuid);

  /// The roleplays belonging to [exerciseUuid], in their own ordinal order.
  ///
  /// There is no per-exercise store — roleplays live in one flat list keyed by
  /// their parent's uuid — so every surface that shows an exercise's markører was
  /// repeating this filter-and-sort. Shared so the player's picker and its swipe
  /// pager cannot disagree about the order, which would make a swipe land
  /// somewhere the picker did not list next.
  List<RolePlay> rolePlaysOf(String exerciseUuid) =>
      loadRolePlays().where((r) => r.exerciseUuid == exerciseUuid).toList()
        ..sort((a, b) => a.index.compareTo(b.index));

  /// 1-based number of [role] among the roles placed at [stationIndex] in
  /// the same exercise, ordered by their [RolePlay.index]. Drives the
  /// `Numbering.role` badge so markers read as `1.1-1`, `1.1-2`, … per
  /// station. A role that is not yet persisted at this station (a fresh
  /// draft, or one whose station is being changed in the form) appends at
  /// the end, so it gets the next free number.
  int roleNumberAtStation(RolePlay role, int stationIndex) {
    final peers =
        loadRolePlays()
            .where(
              (r) =>
                  r.exerciseUuid == role.exerciseUuid &&
                  r.stationIndex == stationIndex,
            )
            .toList()
          ..sort((a, b) => a.index.compareTo(b.index));
    final pos = peers.indexWhere((r) => r.uuid == role.uuid);
    return (pos < 0 ? peers.length : pos) + 1;
  }

  /// Composite badge label for a markør — the station code plus the role's
  /// 1-based number at that station, e.g. `1.1-1` / `1a-2`. An unassigned role
  /// renders its post/markør parts as `?` (see [RolePlayNumbering.numberLabel]).
  ///
  /// Composing [Numbering.role] needs both the plan's format and
  /// [roleNumberAtStation], so it lived duplicated in every surface that shows
  /// a markør badge. [format] and [exerciseNumber] stay parameters because
  /// callers listing several exercises already have them in hand per row.
  String roleLabel(
    RolePlay role, {
    required StationNumberFormat format,
    required int exerciseNumber,
  }) {
    final stationIndex = role.stationIndex;
    return role.numberLabel(
      format,
      exerciseNumber: exerciseNumber,
      roleNumber: stationIndex == null
          ? 0
          : roleNumberAtStation(role, stationIndex),
    );
  }

  /// Persists [rolePlay] under the currently active plan, creating a
  /// default plan first if none exists yet. Mirrors [saveExercise]: every
  /// mutation that writes nested data must ensure a parent plan exists,
  /// otherwise [_repo.saveRolePlay] (via `_requirePlanUuid`) throws
  /// `Bad state: No active plan.` and the call site has no chance to
  /// recover — see Sentry issue 7503574588.
  Future<void> saveRolePlay(
    AppLocalizations localizations,
    RolePlay rolePlay,
  ) async {
    await _ensureActivePlan(localizations.defaultPlanName);
    await _repo.saveRolePlay(rolePlay);
    // Notify listeners so views that depend on RolePlay state (e.g. the
    // Roster tab's actor→roles subtitle) can refresh on cast / uncast.
    final plan = activePlan;
    if (plan != null) {
      _controller.add(PlanEvent.rolePlaySaved(plan, rolePlay));
    }
  }

  Future<RolePlay?> deleteRolePlay(String uuid) async {
    final deleted = await _repo.deleteRolePlay(uuid);
    final plan = activePlan;
    if (deleted != null && plan != null) {
      _controller.add(PlanEvent.rolePlayDeleted(plan, deleted));
    }
    return deleted;
  }

  List<Staff> loadStaff() {
    if (activePlanUuid == null) return const [];
    return _repo.loadStaff();
  }

  Staff? getStaff(String uuid) => _repo.getStaff(uuid);

  /// See [saveRolePlay] for the rationale behind requiring localizations
  /// and ensuring an active plan before write.
  Future<void> saveStaff(AppLocalizations localizations, Staff actor) async {
    await _ensureActivePlan(localizations.defaultPlanName);
    await _repo.saveStaff(actor);
    final plan = activePlan;
    if (plan != null) {
      _controller.add(PlanEvent.actorSaved(plan, actor));
    }
  }

  Future<Staff?> deleteStaff(String uuid) async {
    final deleted = await _repo.deleteStaff(uuid);
    final plan = activePlan;
    if (deleted != null && plan != null) {
      _controller.add(PlanEvent.actorDeleted(plan, deleted));
    }
    return deleted;
  }

  List<Exercise> loadExercises() {
    if (activePlanUuid == null) return const [];
    return _repo.loadExercises();
  }

  int getExerciseNumber(String uuid) {
    return loadExercises().indexWhere((e) => e.uuid == uuid) + 1;
  }

  List<StationLocation> getLocations() {
    // Map markers are labelled with the station *number* (e.g. "1.2" / "1a"),
    // not the name: the number takes far less room above the pin and matches
    // the StationNumberBadge used everywhere else. Exercise/station context is
    // still available via the search-result chip and the station detail
    // screen.
    final format =
        activePlan?.stationNumberFormat ?? StationNumberFormat.dotted;
    final markers = <StationLocation>[];
    final exercises = loadExercises();
    for (var ei = 0; ei < exercises.length; ei++) {
      markers.addAll(
        exercises[ei].getNumberedLocations(
          exerciseNumber: ei + 1,
          format: format,
        ),
      );
    }
    return markers;
  }

  Future<void> saveExercise(
    AppLocalizations localizations,
    Exercise exercise,
  ) async {
    await _ensureActivePlan(localizations.defaultPlanName);
    await ensureTeams(localizations, exercise.numberOfTeams);
    // Assign a new index when this exercise is not yet in the plan so it
    // appends at the end. Leave an edit of an existing exercise's index alone.
    final persisted = _repo.getExercise(exercise.uuid);
    final toSave = persisted == null
        ? exercise.copyWith(index: _nextExerciseIndex())
        : exercise;
    await _repo.saveExercise(toSave);
    final plan = activePlan;
    if (plan != null) {
      _controller.add(PlanEvent.added(plan, toSave));
    }
  }

  /// Returns the next exercise index to use when appending a new exercise:
  /// max(existing indices) + 1, or 0 when the plan is empty.
  int _nextExerciseIndex() {
    final existing = _repo.loadExercises();
    if (existing.isEmpty) return 0;
    return existing.map((e) => e.index).reduce(max) + 1;
  }

  /// Rewrites [Exercise.index] values so the exercises in the active plan
  /// are ordered according to [orderedUuids] (a full permutation of all
  /// exercise uuids in the plan). Each exercise whose position changed is
  /// persisted through the existing save path.
  ///
  /// Called by drag-to-reorder, move-up/down, and the one-shot sort actions —
  /// all three mechanisms converge here so there is a single write path.
  Future<void> reorderExercises(List<String> orderedUuids) async {
    for (var i = 0; i < orderedUuids.length; i++) {
      final ex = _repo.getExercise(orderedUuids[i]);
      if (ex != null && ex.index != i) {
        await _repo.saveExercise(ex.copyWith(index: i));
      }
    }
    final plan = activePlan;
    if (plan != null) {
      _controller.add(PlanEvent(PlanEventType.planRefreshed, plan));
    }
  }

  /// Reorders the stations of [exerciseUuid] according to [orderedOldIndices],
  /// where `orderedOldIndices[newPosition] = oldIndex`. In one persisted
  /// change:
  ///
  /// 1. Reassigns `Station.index` to reflect new positions and stores the
  ///    reordered list on the exercise. Station objects carry their brief
  ///    markdown fields via `copyWith`, so the brief content follows the
  ///    station — no separate file-rename is needed for in-session reordering.
  /// 2. Remaps `RolePlay.stationIndex` for every marker attached to a
  ///    reordered station using the old→new permutation, so each marker keeps
  ///    pointing at the same physical station ("markers follow their station",
  ///    ADR-0036). Markers with `stationIndex == null` are left untouched.
  /// 3. Emits a single refresh event once all writes are done.
  ///
  /// The rotation schedule matrix is per-round, not per-station, so it does
  /// not need regeneration — the rotation math in [ExerciseX.teamIndex] /
  /// [ExerciseX.stationIndex] reads live from the ordered stations list.
  Future<void> reorderStations(
    String exerciseUuid,
    List<int> orderedOldIndices,
  ) async {
    final ex = _repo.getExercise(exerciseUuid);
    if (ex == null) return;

    // Build old→new index map and the reordered stations list. For each new
    // position, pull the station that had the old index and assign the new one.
    // Station.index must equal list position (rotation math invariant).
    final oldToNew = <int, int>{};
    for (var newPos = 0; newPos < orderedOldIndices.length; newPos++) {
      oldToNew[orderedOldIndices[newPos]] = newPos;
    }
    final stationsByOldIndex = {for (final s in ex.stations) s.index: s};
    final reorderedStations = List<Station>.generate(orderedOldIndices.length, (
      newPos,
    ) {
      final oldIndex = orderedOldIndices[newPos];
      final station = stationsByOldIndex[oldIndex]!;
      // Only rebuild the object when the index actually changes.
      return oldIndex != newPos ? station.copyWith(index: newPos) : station;
    });

    // Persist the exercise with the reordered stations. Use _repo directly
    // to avoid the index-assignment / ensureTeams / "added" event side effects
    // of the service-level saveExercise — same pattern as reorderExercises.
    await _repo.saveExercise(ex.copyWith(stations: reorderedStations));

    // Remap RolePlay.stationIndex so each marker follows its station.
    for (final rolePlay in loadRolePlays()) {
      final si = rolePlay.stationIndex;
      if (rolePlay.exerciseUuid != exerciseUuid || si == null) continue;
      final newIndex = oldToNew[si];
      if (newIndex != null && newIndex != si) {
        await _repo.saveRolePlay(rolePlay.copyWith(stationIndex: newIndex));
      }
    }

    final plan = activePlan;
    if (plan != null) {
      _controller.add(PlanEvent(PlanEventType.planRefreshed, plan));
    }
  }

  Future<void> saveTeam(AppLocalizations localizations, Team team) async {
    await _ensureActivePlan(localizations.defaultPlanName);
    await _repo.saveTeam(team);
    final plan = activePlan;
    if (plan != null) {
      _controller.add(PlanEvent.teamSaved(plan, team));
    }
  }

  Future<void> deleteExercise(String uuid, [bool replace = false]) async {
    final plan = activePlan;
    if (plan == null) return;
    final deleted = await _repo.deleteExercise(uuid);
    if (deleted != null) {
      _controller.add(PlanEvent.deleted(plan, deleted));
    }
  }

  Future<DrillFile> exportPlan(
    String uuid,
    String fileName,
    List<String> selected,
  ) async {
    final plan = _planForExport(uuid: uuid, name: fileName, selected: selected);
    final drillFile = DrillFile.fromPlan(plan, fileName);
    _controller.add(PlanEvent.exported(plan, drillFile));
    return drillFile;
  }

  Future<Plan?> openPlan(
    AppLocalizations localizations,
    DrillFile file, {
    OnSelectExercises? onSelect,
  }) async {
    final plan = await installFromFile(file, activate: true);
    _controller.add(PlanEvent.opened(plan, file));
    return plan;
  }

  Future<Plan?> importPlan(
    AppLocalizations localizations,
    DrillFile file, {
    OnSelectExercises? onSelect,
  }) async {
    await _ensureActivePlan(localizations.defaultPlanName);
    final incoming = file.plan();
    final selected = onSelect == null
        ? incoming.exercises
        : await onSelect.call(incoming.exercises);
    if (selected == null) return null;

    var maxNumberOfTeams = 0;
    var nextIndex = _nextExerciseIndex();
    for (final exercise in selected) {
      await _repo.saveExercise(exercise.copyWith(index: nextIndex++));
      maxNumberOfTeams = max(maxNumberOfTeams, exercise.numberOfTeams);
    }
    for (final team in incoming.teams) {
      await _repo.saveTeam(team);
    }
    await ensureTeams(localizations, maxNumberOfTeams);

    final plan = activePlan;
    if (plan != null) {
      _controller.add(PlanEvent.imported(plan, file));
    }
    return plan?.copyWith(exercises: selected.toList());
  }

  Future<Plan?> mergeFromPlan(
    AppLocalizations localizations,
    Plan source,
    List<String> selectedExerciseUuids,
  ) async {
    await _ensureActivePlan(localizations.defaultPlanName);
    final selected = source.exercises
        .where((exercise) => selectedExerciseUuids.contains(exercise.uuid))
        .toList();
    if (selected.isEmpty) return null;

    var maxNumberOfTeams = 0;
    var nextIndex = _nextExerciseIndex();
    for (final exercise in selected) {
      await _repo.saveExercise(exercise.copyWith(index: nextIndex++));
      maxNumberOfTeams = max(maxNumberOfTeams, exercise.numberOfTeams);
    }
    for (final team in source.teams) {
      await _repo.saveTeam(team);
    }
    await ensureTeams(localizations, maxNumberOfTeams);

    final plan = activePlan;
    if (plan != null) {
      _controller.add(PlanEvent.importedPlan(plan));
    }
    return plan?.copyWith(exercises: selected);
  }

  Future<Plan> installFromFile(DrillFile file, {bool activate = false}) async {
    final incoming = file.plan();
    // Always preserve the incoming uuid. The catalog wiki model relies on
    // Plan.uuid being stable across opens so the backend ownership check
    // (ownerId, programId — the Netlify functions' wire name for this uuid)
    // lines up when the same plan is published again
    // from a different device or after reinstall. Regenerating on collision
    // here would silently break that link. If the user re-opens a plan they
    // already have, the existing local copy is overwritten — which matches
    // the "this is the same plan" semantic.
    final now = DateTime.now();
    final installed = incoming.copyWith(
      source: PlanSource.imported(fileName: file.fileName),
      metadata: incoming.metadata.copyWith(updated: now),
      contentHash: incoming.computeContentHash(),
      // Keep the local cast roster when re-opening a plan we already have.
      // A catalog download has actors/ stripped server-side (ADR-0018), so
      // without this the existing actors would be wiped on every reinstall.
      staff: _mergeLocalStaff(incoming.uuid, incoming.staff),
    );
    await _repo.savePlan(installed);
    if (activate) {
      await _repo.setActivePlanUuid(installed.uuid);
      ExerciseService().stop();
    }
    _controller.add(
      PlanEvent(PlanEventType.planInstalled, installed, file: file),
    );
    return installed;
  }

  /// Install every plan in a drill-library bundle into the local
  /// library. Never activates anything and never touches the active plan
  /// (ADR-0045). Best-effort per entry: a [DrillFormatException] on one
  /// entry increments [BundleInstallResult.skipped] and does not abort the
  /// rest. Container-level failures ([DrillLibraryException]) propagate to
  /// the caller.
  Future<BundleInstallResult> installBundle(
    List<int> content, {
    String? sourceName,
  }) async {
    final files = DrillLibrary.entries(content, sourceName: sourceName);
    var imported = 0;
    final skipped = <SkippedDrillEntry>[];
    for (final file in files) {
      try {
        await installFromFile(file, activate: false);
        imported++;
      } on DrillFormatException catch (e) {
        skipped.add(
          SkippedDrillEntry(fileName: file.fileName, reason: e.reason),
        );
      }
    }
    return BundleInstallResult(imported: imported, skipped: skipped);
  }

  Future<Plan> installFromCatalog(
    MarketFeedItem item,
    DrillClient client, {
    bool activate = false,
  }) async {
    final download = await client.download(item.slug);
    return installFromCatalogFile(item, download, activate: activate);
  }

  /// Same as [installFromCatalog], but for a caller that already downloaded
  /// the blob (e.g. a bottom sheet offering both "Open" and "Import" off a
  /// single fetch of a shared `/i/<slug>` link — see `install_link_handler`).
  Future<Plan> installFromCatalogFile(
    MarketFeedItem item,
    DrillDownloadResponse download, {
    bool activate = false,
  }) async {
    final installed = await installFromFile(download.file, activate: activate);
    final catalogPlan = installed.copyWith(
      source: PlanSource.catalog(
        slug: item.slug,
        latestEtag: download.etag ?? '',
        installedAt: DateTime.now(),
        latestVersion: download.version,
      ),
      contentHash: _repo.loadPlan(installed.uuid)?.computeContentHash(),
    );
    await _repo.savePlanShell(catalogPlan);
    _controller.add(PlanEvent(PlanEventType.planInstalled, catalogPlan));
    return _repo.loadPlan(catalogPlan.uuid) ?? catalogPlan;
  }

  Future<CatalogRefreshOutcome> refreshCatalogItem(
    String planUuid,
    DrillClient client, {
    required Future<CatalogConflictChoice> Function(
      PlanDiff diff, {
      required bool ownedSlug,
      required bool remoteUnchanged,
      required String? localVersion,
      required String? catalogVersion,
    })
    onConflict,
  }) async {
    final local = _repo.loadPlan(planUuid);
    final source = local?.source;
    final catalogSource = source?.whenOrNull(
      catalog: (slug, latestEtag, installedAt, latestVersion) => (
        slug: slug,
        storedEtag: latestEtag,
        installedAt: installedAt,
        storedVersion: latestVersion,
      ),
    );
    if (local == null || catalogSource == null) {
      return CatalogRefreshOutcome(
        kind: CatalogRefreshKind.failed,
        planUuid: planUuid,
      );
    }
    final (:slug, :storedEtag, :installedAt, :storedVersion) = catalogSource;

    // Detect local divergence from the installed snapshot up front so that a
    // 304 from the server does not silently mask local edits (e.g. the user
    // changed an exercise start time and then triggered "update from
    // catalog"). When the server has not changed but the local copy has, we
    // still need to show the conflict dialog so the user can choose between
    // reverting (overwriteLocal), forking, or publishing.
    final localHash = local.computeContentHash();
    final hasLocalChanges =
        local.contentHash != null && localHash != local.contentHash;

    final head = await client.head(slug, ifNoneMatch: storedEtag);
    if (!head.exists) {
      return CatalogRefreshOutcome(
        kind: CatalogRefreshKind.removedFromCatalog,
        planUuid: planUuid,
      );
    }
    if (head.notModified && !hasLocalChanges) {
      return CatalogRefreshOutcome(
        kind: CatalogRefreshKind.upToDate,
        planUuid: planUuid,
      );
    }

    final download = await client.download(slug);
    final remote = download.file.plan();
    final diff = diffPlans(local, remote);
    final latestEtag = download.etag ?? head.etag ?? storedEtag;
    final catalogVersion = download.version ?? head.version ?? storedVersion;
    final remoteUnchanged = head.notModified;
    debugPrint(
      '[refreshCatalogItem] slug=$slug '
      'storedContentHash=${local.contentHash} '
      'localHash=$localHash '
      'hasLocalChanges=$hasLocalChanges '
      'remoteUnchanged=$remoteUnchanged',
    );

    if (!hasLocalChanges) {
      debugPrint('[refreshCatalogItem] no local changes → overwriting local');
      await _overwriteCatalogPlan(
        local,
        remote,
        slug,
        latestEtag,
        catalogVersion,
      );
      return CatalogRefreshOutcome(
        kind: CatalogRefreshKind.updatedSilently,
        planUuid: planUuid,
        diff: diff,
        remoteUnchanged: remoteUnchanged,
      );
    }

    final ownedSlug = _repo.ownsCatalogSlug(slug);
    final choice = await onConflict(
      diff,
      ownedSlug: ownedSlug,
      remoteUnchanged: remoteUnchanged,
      localVersion: storedVersion,
      catalogVersion: catalogVersion,
    );
    switch (choice) {
      case CatalogConflictChoice.cancel:
        return CatalogRefreshOutcome(
          kind: CatalogRefreshKind.cancelled,
          planUuid: planUuid,
          diff: diff,
          remoteUnchanged: remoteUnchanged,
        );
      case CatalogConflictChoice.overwriteLocal:
        await _overwriteCatalogPlan(
          local,
          remote,
          slug,
          latestEtag,
          catalogVersion,
        );
        return CatalogRefreshOutcome(
          kind: CatalogRefreshKind.updatedAfterPrompt,
          planUuid: planUuid,
          diff: diff,
          remoteUnchanged: remoteUnchanged,
        );
      case CatalogConflictChoice.publishMyChanges:
        // Use the *fresh* etag we just downloaded as If-Match. The user has
        // seen the diff and chosen to overwrite the new remote with their
        // local changes — sending the stale storedEtag would 412 against
        // the server we just synced from.
        final upload = await client.upload(
          DrillFile.fromPlan(local, slug),
          ifMatchEtag: latestEtag,
          published: true,
        );
        await _repo.setOwnsCatalogSlug(slug, true);
        final published = local.copyWith(
          source: PlanSource.catalog(
            slug: slug,
            latestEtag: upload.etag,
            installedAt: installedAt,
            latestVersion: upload.version,
          ),
          contentHash: local.computeContentHash(),
        );
        await _repo.savePlanShell(published);
        _controller.add(PlanEvent(PlanEventType.planRefreshed, published));
        return CatalogRefreshOutcome(
          kind: CatalogRefreshKind.published,
          planUuid: planUuid,
          diff: diff,
          remoteUnchanged: remoteUnchanged,
        );
      case CatalogConflictChoice.forkAsLocal:
        final fork = local.copyWith(
          uuid: nanoid(10),
          name: '${local.name} copy',
          source: const PlanSource.local(),
          contentHash: local.computeContentHash(),
        );
        await _repo.savePlan(fork);
        _controller.add(PlanEvent(PlanEventType.planCreated, fork));
        return CatalogRefreshOutcome(
          kind: CatalogRefreshKind.forked,
          planUuid: fork.uuid,
          diff: diff,
          remoteUnchanged: remoteUnchanged,
        );
    }
  }

  /// Publish a plan to the catalog.
  ///
  /// Handles both first-time publish (when [Plan.source] is [_Local] or
  /// [_Imported]) and updates of an already-published plan (when the source is
  /// [_Catalog]).
  ///
  /// For first-time publish the caller supplies the desired [slug]; it is run
  /// through [sanitizeSlug] before use. For updates the existing slug is reused
  /// and [slug] is ignored — the catalog model treats `slug` as identity.
  ///
  /// Throws [DrillApiException] with `status == 409` when the slug is in use by
  /// an unrelated plan, and with `status == 412` when a concurrent update raced
  /// ahead. Other errors are rethrown unchanged.
  Future<({Plan plan, bool notModified})> publishPlan(
    String planUuid, {
    required String slug,
    required DrillClient client,
  }) async {
    final local = _repo.loadPlan(planUuid);
    if (local == null) {
      throw StateError('Plan $planUuid not found');
    }

    final catalogSource = local.source.whenOrNull(
      catalog: (existingSlug, latestEtag, installedAt, latestVersion) =>
          (slug: existingSlug, etag: latestEtag, installedAt: installedAt),
    );
    final String effectiveSlug;
    final String? ifMatch;
    final DateTime? existingInstalledAt;
    if (catalogSource != null) {
      effectiveSlug = catalogSource.slug;
      ifMatch = catalogSource.etag.isNotEmpty ? catalogSource.etag : null;
      existingInstalledAt = catalogSource.installedAt;
    } else {
      effectiveSlug = sanitizeSlug(slug);
      ifMatch = null;
      existingInstalledAt = null;
    }
    if (effectiveSlug.isEmpty) {
      throw ArgumentError('Slug cannot be empty after sanitization');
    }

    debugPrint(
      '[publishPlan] slug=$effectiveSlug name="${local.name}" '
      'ifMatch=$ifMatch contentHash=${local.contentHash}',
    );
    final file = DrillFile.fromPlan(local, effectiveSlug);
    final upload = await client.upload(
      file,
      ifMatchEtag: ifMatch,
      published: true,
    );
    debugPrint(
      '[publishPlan] upload version=${upload.version} '
      'newEtag=${upload.etag} notModified=${upload.notModified}',
    );
    await _repo.setOwnsCatalogSlug(effectiveSlug, true);

    final published = local.copyWith(
      source: PlanSource.catalog(
        slug: effectiveSlug,
        latestEtag: upload.etag,
        installedAt: existingInstalledAt ?? DateTime.now(),
        latestVersion: upload.version,
      ),
      contentHash: local.computeContentHash(),
    );
    await _repo.savePlanShell(published);
    _controller.add(PlanEvent(PlanEventType.planRefreshed, published));
    return (
      plan: _repo.loadPlan(published.uuid) ?? published,
      notModified: upload.notModified,
    );
  }

  /// Publish a plan to the catalog under a specific [slug], forking the
  /// local plan if the slug differs from its current catalog slug.
  ///
  /// Behaviour depends on the plan's current source:
  ///   - Source is local / imported: identical to [publishPlan] (first-time
  ///     publish at the requested slug).
  ///   - Source is catalog and [slug] equals the current slug: delegates to
  ///     [publishPlan] — pure update, no fork.
  ///   - Source is catalog and [slug] differs from the current slug: a local
  ///     fork is created (new [Plan.uuid]) tracking the new slug, and the
  ///     fork is published. The original local plan is left untouched and
  ///     continues to track its existing slug.
  ///
  /// Returns the published [Plan] (the fork, when a fork was created).
  ///
  /// Throws the same exceptions as [publishPlan].
  Future<({Plan plan, bool notModified})> publishPlanAs(
    String planUuid, {
    required String slug,
    required DrillClient client,
  }) async {
    final local = _repo.loadPlan(planUuid);
    if (local == null) {
      throw StateError('Plan $planUuid not found');
    }
    final cleanSlug = sanitizeSlug(slug);
    if (cleanSlug.isEmpty) {
      throw ArgumentError('Slug cannot be empty after sanitization');
    }

    final currentSlug = local.source.whenOrNull(
      catalog: (existingSlug, latestEtag, installedAt, latestVersion) =>
          existingSlug,
    );
    if (currentSlug == null || currentSlug == cleanSlug) {
      // First-time publish, or update in place under the same slug. No fork.
      return publishPlan(planUuid, slug: cleanSlug, client: client);
    }

    // Fork: clone the plan locally with a fresh uuid and a local source,
    // then publish the fork at the new slug. The original keeps its
    // catalog(currentSlug) source.
    final now = DateTime.now();
    final fork = local.copyWith(
      uuid: nanoid(10),
      source: const PlanSource.local(),
      metadata: local.metadata.copyWith(updated: now),
      contentHash: local.computeContentHash(),
    );
    await _repo.savePlan(fork);
    _controller.add(PlanEvent(PlanEventType.planCreated, fork));

    return publishPlan(fork.uuid, slug: cleanSlug, client: client);
  }

  List<Team> loadTeams() {
    if (activePlanUuid == null) return const [];
    return _repo.loadTeams();
  }

  Team? getTeam(int index) {
    final teams = loadTeams();
    return teams.length > index ? teams[index] : null;
  }

  Future<List<Team>> ensureTeams(
    AppLocalizations localizations,
    int numberOfTeams,
  ) async {
    final teams = _ensureTeams(localizations, numberOfTeams, loadTeams());
    for (final it in teams.where((e) => !_repo.containsTeam(e.uuid))) {
      await _repo.addTeam(it);
    }
    return teams;
  }

  Plan _planForExport({
    required String uuid,
    required String name,
    required List<String> selected,
  }) {
    final now = DateTime.now();
    final current = activePlan;
    final exercises = loadExercises()
        .where((exercise) => selected.contains(exercise.uuid))
        .toList();
    return Plan(
      uuid: uuid,
      name: name,
      description: current?.description ?? '',
      metadata:
          current?.metadata.copyWith(updated: now) ??
          PlanMetadata(created: now, updated: now, version: '1.0'),
      source: current?.source ?? const PlanSource.local(),
      teams: loadTeams(),
      sessions: current?.sessions ?? const [],
      exercises: exercises,
      rolePlays: loadRolePlays(),
      staff: loadStaff(),
    );
  }

  /// Public entry point for the gated startup call in [MainScreen].
  ///
  /// Only runs when SharedPreferences already contains the active-plan key
  /// (i.e., the user has previously created a plan). On a fresh install,
  /// [MainScreen] skips this call so no auto-created "Default plan" appears.
  Future<void> ensureActivePlan(AppLocalizations localizations) =>
      _ensureActivePlan(localizations.defaultPlanName);

  Future<void> _ensureActivePlan(String defaultPlanName) async {
    if (activePlanUuid != null) return;
    final plan = await createPlan(name: defaultPlanName);
    await _repo.setActivePlanUuid(plan.uuid);
  }

  Future<void> _overwriteCatalogPlan(
    Plan local,
    Plan remote,
    String slug,
    String latestEtag,
    String? latestVersion,
  ) async {
    final merged = remote.copyWith(
      uuid: local.uuid,
      name: remote.name,
      source: PlanSource.catalog(
        slug: slug,
        latestEtag: latestEtag,
        installedAt: DateTime.now(),
        latestVersion: latestVersion,
      ),
      contentHash: remote.computeContentHash(),
      // The remote copy never carries actors (stripped server-side per
      // ADR-0018). Merge in the locally-stored cast so a refresh does not
      // silently destroy the user's roster and break role↔actor links.
      staff: _mergeLocalStaff(local.uuid, remote.staff),
    );
    await _repo.savePlan(merged);
    _controller.add(PlanEvent(PlanEventType.planRefreshed, merged));
  }

  /// Actors are local-only PII: the catalog strips the `actors/` folder
  /// server-side (ADR-0018), so any plan fetched from the catalog arrives
  /// with an empty actor list. Replacing the local copy wholesale would then
  /// destroy the cast roster built on this device — the data loss behind
  /// "the marker list had a name yesterday, it's empty today".
  ///
  /// This merges [incoming] over the actors already stored for [planUuid]
  /// by uuid: incoming entries win, and local-only actors (those absent from
  /// [incoming]) are retained. A first install has no existing actors, so it
  /// returns [incoming] unchanged. A genuine peer-to-peer `.drill` that
  /// legitimately carries actors still imports them.
  List<Staff> _mergeLocalStaff(String planUuid, List<Staff> incoming) {
    final existing = _repo.loadStaff(planUuid);
    if (existing.isEmpty) return incoming;
    final incomingUuids = {for (final a in incoming) a.uuid};
    return [
      ...incoming,
      ...existing.where((a) => !incomingUuids.contains(a.uuid)),
    ];
  }

  static Exercise generateSchedule({
    String? uuid,
    required String name,
    required TimeOfDay startTime,
    required int numberOfTeams,
    required int numberOfStations,
    required int numberOfRounds,
    required int executionTime,
    required int evaluationTime,
    required int rotationTime,
    required AppLocalizations localizations,
    List<Station> stations = const [],
    Map<String, String> variableOverrides = const {},
  }) {
    assert(
      numberOfTeams <= numberOfStations,
      '<numberOfTeams> must be less or equal to <numberOfStations>',
    );
    // The rotation math itself lives in ExerciseSchedule, which is free of
    // package:flutter so the source-format builder can call it too — this
    // method's TimeOfDay signature is what keeps it out of the CLI's reach
    // (DESIGN-014). A `calcFromTimes: false` variant used to live here with a
    // different phase model; nothing ever passed false, so it went with the
    // move rather than being ported.
    final start = startTime.toSimple();
    return Exercise(
      name: name,
      uuid: uuid ?? nanoid(8),
      startTime: start,
      executionTime: executionTime,
      evaluationTime: evaluationTime,
      rotationTime: rotationTime,
      numberOfTeams: numberOfTeams,
      numberOfRounds: numberOfRounds,
      stations: ensureStations(localizations, numberOfStations, stations),
      schedule: List.unmodifiable(
        ExerciseSchedule.rounds(
          startTime: start,
          numberOfRounds: numberOfRounds,
          executionTime: executionTime,
          evaluationTime: evaluationTime,
          rotationTime: rotationTime,
        ),
      ),
      endTime: ExerciseSchedule.endTime(
        startTime: start,
        numberOfRounds: numberOfRounds,
        executionTime: executionTime,
        evaluationTime: evaluationTime,
        rotationTime: rotationTime,
      ),
      variableOverrides: variableOverrides,
    );
  }

  static List<Station> ensureStations(
    AppLocalizations localizations,
    int numberOfStations,
    List<Station> stations,
  ) {
    return List.unmodifiable(
      List<Station>.generate(numberOfStations, (index) {
        return index < stations.length
            ? stations[index]
            : Station(
                index: index,
                name: '${localizations.station(1)} ${index + 1}',
              );
      }),
    );
  }

  static List<Team> _ensureTeams(
    AppLocalizations localizations,
    int numberOfTeams,
    List<Team> teams,
  ) {
    return List.unmodifiable(
      List<Team>.generate(max(numberOfTeams, teams.length), (index) {
        return index < teams.length
            ? teams[index]
            : Team(
                uuid: nanoid(8),
                index: index,
                name: '${localizations.team(1)} ${index + 1}',
              );
      }),
    );
  }
}
