import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:nanoid/nanoid.dart';
import 'package:ringdrill/data/drill_client.dart';
import 'package:ringdrill/data/drill_file.dart';
import 'package:ringdrill/data/program_repository.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/actor.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/program.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/models/team.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/utils/time_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef OnSelectExercises =
    Future<Iterable<Exercise>?> Function(Iterable<Exercise> items);

enum ProgramEventType {
  exerciseAdded,
  exerciseDeleted,
  programOpened,
  programImported,
  programExported,
  programCreated,
  programDeleted,
  programActivated,
  programInstalled,
  programRefreshed,
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
}

class CatalogRefreshOutcome {
  const CatalogRefreshOutcome({
    required this.kind,
    required this.programUuid,
    this.diff,
    this.remoteUnchanged = false,
  });

  final CatalogRefreshKind kind;
  final String programUuid;
  final ProgramDiff? diff;

  /// True when the catalog server reported no changes (HTTP 304) but the
  /// local copy diverged from the installed snapshot. Distinguishes a real
  /// catalog update from a local-only divergence so call sites can pick the
  /// right user-facing wording (e.g. "Updated from catalog" vs. "Discarded
  /// local changes").
  final bool remoteUnchanged;
}

class ProgramEvent {
  final DrillFile? file;
  final Program program;
  final Exercise? exercise;
  final ProgramEventType type;

  ProgramEvent(this.type, this.program, {this.file, this.exercise});

  factory ProgramEvent.added(Program program, Exercise exercise) =>
      ProgramEvent(ProgramEventType.exerciseAdded, program, exercise: exercise);

  factory ProgramEvent.deleted(Program program, Exercise exercise) =>
      ProgramEvent(
        ProgramEventType.exerciseDeleted,
        program,
        exercise: exercise,
      );

  factory ProgramEvent.opened(Program program, DrillFile file) =>
      ProgramEvent(ProgramEventType.programOpened, program, file: file);

  factory ProgramEvent.imported(Program program, DrillFile file) =>
      ProgramEvent(ProgramEventType.programImported, program, file: file);

  factory ProgramEvent.importedProgram(Program program) =>
      ProgramEvent(ProgramEventType.programImported, program);

  factory ProgramEvent.exported(Program program, DrillFile file) =>
      ProgramEvent(ProgramEventType.programExported, program, file: file);
}

class ProgramService {
  static final ProgramService _instance = ProgramService._internal();

  factory ProgramService() => _instance;

  ProgramService._internal();

  final StreamController<ProgramEvent> _controller =
      StreamController.broadcast();

  bool _isReady = false;
  late final ProgramRepository _repo;

  Stream<ProgramEvent> get events => _controller.stream;

  Future<List<Exercise>> init() async {
    if (!_isReady) {
      final prefs = await SharedPreferences.getInstance();
      _repo = ProgramRepository(prefs);
      await _repo.init();
      _isReady = true;
    }
    return activeProgram == null ? const [] : _repo.loadExercises();
  }

  List<Program> listPrograms() => _isReady ? _repo.listPrograms() : const [];

  Program? loadProgram(String uuid) =>
      _isReady ? _repo.loadProgram(uuid) : null;

  Program? get activeProgram {
    if (!_isReady) return null;
    final uuid = _repo.activeProgramUuid;
    if (uuid == null) return null;
    return _repo.loadProgram(uuid);
  }

  String? get activeProgramUuid => _isReady ? _repo.activeProgramUuid : null;

  bool get librarySchemaJustMigrated =>
      _isReady && _repo.librarySchemaJustMigrated;

  Future<void> clearLibrarySchemaJustMigrated() =>
      _isReady ? _repo.clearLibrarySchemaJustMigrated() : Future.value();

  Future<Program> createProgram({
    required String name,
    String description = '',
  }) async {
    final now = DateTime.now();
    final emptyProgram = Program(
      uuid: nanoid(10),
      name: name,
      description: description,
      metadata: ProgramMetadata(created: now, updated: now, version: '1.0'),
      source: const ProgramSource.local(),
      teams: const [],
      sessions: const [],
      exercises: const [],
      rolePlays: const [],
      actors: const [],
    );
    final program = emptyProgram.copyWith(
      contentHash: emptyProgram.computeContentHash(),
    );
    await _repo.saveProgramShell(program);
    _controller.add(ProgramEvent(ProgramEventType.programCreated, program));
    return program;
  }

  Future<void> setActive(String uuid) async {
    if (ExerciseService().isStarted) {
      throw StateError('Cannot switch active program while an exercise runs.');
    }
    await _repo.setActiveProgramUuid(uuid);
    final program = _repo.loadProgram(uuid);
    if (program != null) {
      _controller.add(ProgramEvent(ProgramEventType.programActivated, program));
    }
  }

  Future<void> deleteProgram(String uuid) async {
    if (_repo.activeProgramUuid == uuid && ExerciseService().isStarted) {
      throw StateError('Cannot delete active program while an exercise runs.');
    }
    final program = _repo.loadProgram(uuid);
    await _repo.deleteProgram(uuid);
    if (program != null) {
      _controller.add(ProgramEvent(ProgramEventType.programDeleted, program));
    }
  }

  Future<void> replaceProgram(Program program) async {
    await _repo.saveProgram(program);
    _controller.add(ProgramEvent(ProgramEventType.programRefreshed, program));
  }

  Exercise? getExercise(String uuid) => _repo.getExercise(uuid);

  List<RolePlay> loadRolePlays() {
    if (activeProgramUuid == null) return const [];
    return _repo.loadRolePlays();
  }

  RolePlay? getRolePlay(String uuid) => _repo.getRolePlay(uuid);

  /// Persists [rolePlay] under the currently active program, creating a
  /// default plan first if none exists yet. Mirrors [saveExercise]: every
  /// mutation that writes nested data must ensure a parent program exists,
  /// otherwise [_repo.saveRolePlay] (via `_requireProgramUuid`) throws
  /// `Bad state: No active program.` and the call site has no chance to
  /// recover — see Sentry issue 7503574588.
  Future<void> saveRolePlay(
    AppLocalizations localizations,
    RolePlay rolePlay,
  ) async {
    await _ensureActiveProgram(localizations.defaultPlanName);
    await _repo.saveRolePlay(rolePlay);
  }

  Future<RolePlay?> deleteRolePlay(String uuid) => _repo.deleteRolePlay(uuid);

  List<Actor> loadActors() {
    if (activeProgramUuid == null) return const [];
    return _repo.loadActors();
  }

  Actor? getActor(String uuid) => _repo.getActor(uuid);

  /// See [saveRolePlay] for the rationale behind requiring localizations
  /// and ensuring an active program before write.
  Future<void> saveActor(
    AppLocalizations localizations,
    Actor actor,
  ) async {
    await _ensureActiveProgram(localizations.defaultPlanName);
    await _repo.saveActor(actor);
  }

  Future<Actor?> deleteActor(String uuid) => _repo.deleteActor(uuid);

  List<Exercise> loadExercises() {
    if (activeProgramUuid == null) return const [];
    return _repo.loadExercises();
  }

  List<StationLocation> getLocations() {
    final markers = <((String, int), String, LatLng)>[];
    for (final e in loadExercises()) {
      // Map markers show the station name only. Exercise context is
      // available via the search-result chip and the station detail
      // screen, so prefixing the label with the exercise name just
      // crowds the marker.
      markers.addAll(e.getLocations(false));
    }
    return markers;
  }

  Future<void> saveExercise(
    AppLocalizations localizations,
    Exercise exercise,
  ) async {
    await _ensureActiveProgram(localizations.defaultPlanName);
    await ensureTeams(localizations, exercise.numberOfTeams);
    await _repo.saveExercise(exercise);
    final program = activeProgram;
    if (program != null) {
      _controller.add(ProgramEvent.added(program, exercise));
    }
  }

  Future<void> deleteExercise(String uuid, [bool replace = false]) async {
    final program = activeProgram;
    if (program == null) return;
    final deleted = await _repo.deleteExercise(uuid);
    if (deleted != null) {
      _controller.add(ProgramEvent.deleted(program, deleted));
    }
  }

  Future<DrillFile> exportProgram(
    String uuid,
    String fileName,
    List<String> selected,
  ) async {
    final program = _programForExport(
      uuid: uuid,
      name: fileName,
      selected: selected,
    );
    final drillFile = DrillFile.fromProgram(program, fileName);
    _controller.add(ProgramEvent.exported(program, drillFile));
    return drillFile;
  }

  Future<Program?> openProgram(
    AppLocalizations localizations,
    DrillFile file, {
    OnSelectExercises? onSelect,
  }) async {
    final program = await installFromFile(file, activate: true);
    _controller.add(ProgramEvent.opened(program, file));
    return program;
  }

  Future<Program?> importProgram(
    AppLocalizations localizations,
    DrillFile file, {
    OnSelectExercises? onSelect,
  }) async {
    await _ensureActiveProgram(localizations.defaultPlanName);
    final incoming = file.program();
    final selected = onSelect == null
        ? incoming.exercises
        : await onSelect.call(incoming.exercises);
    if (selected == null) return null;

    var maxNumberOfTeams = 0;
    for (final exercise in selected) {
      await _repo.saveExercise(exercise);
      maxNumberOfTeams = max(maxNumberOfTeams, exercise.numberOfTeams);
    }
    for (final team in incoming.teams) {
      await _repo.saveTeam(team);
    }
    await ensureTeams(localizations, maxNumberOfTeams);

    final program = activeProgram;
    if (program != null) {
      _controller.add(ProgramEvent.imported(program, file));
    }
    return program?.copyWith(exercises: selected.toList());
  }

  Future<Program?> mergeFromProgram(
    AppLocalizations localizations,
    Program source,
    List<String> selectedExerciseUuids,
  ) async {
    await _ensureActiveProgram(localizations.defaultPlanName);
    final selected = source.exercises
        .where((exercise) => selectedExerciseUuids.contains(exercise.uuid))
        .toList();
    if (selected.isEmpty) return null;

    var maxNumberOfTeams = 0;
    for (final exercise in selected) {
      await _repo.saveExercise(exercise);
      maxNumberOfTeams = max(maxNumberOfTeams, exercise.numberOfTeams);
    }
    for (final team in source.teams) {
      await _repo.saveTeam(team);
    }
    await ensureTeams(localizations, maxNumberOfTeams);

    final program = activeProgram;
    if (program != null) {
      _controller.add(ProgramEvent.importedProgram(program));
    }
    return program?.copyWith(exercises: selected);
  }

  Future<Program> installFromFile(
    DrillFile file, {
    bool activate = false,
  }) async {
    final incoming = file.program();
    // Always preserve the incoming uuid. The catalog wiki model relies on
    // Program.uuid being stable across opens so the backend ownership check
    // (ownerId, programId) lines up when the same plan is published again
    // from a different device or after reinstall. Regenerating on collision
    // here would silently break that link. If the user re-opens a plan they
    // already have, the existing local copy is overwritten — which matches
    // the "this is the same plan" semantic.
    final now = DateTime.now();
    final installed = incoming.copyWith(
      source: ProgramSource.imported(fileName: file.fileName),
      metadata: incoming.metadata.copyWith(updated: now),
      contentHash: incoming.computeContentHash(),
    );
    await _repo.saveProgram(installed);
    if (activate) {
      await _repo.setActiveProgramUuid(installed.uuid);
      ExerciseService().stop();
    }
    _controller.add(
      ProgramEvent(ProgramEventType.programInstalled, installed, file: file),
    );
    return installed;
  }

  Future<Program> installFromCatalog(
    MarketFeedItem item,
    DrillClient client, {
    bool activate = false,
  }) async {
    final download = await client.download(item.slug);
    final installed = await installFromFile(download.file, activate: activate);
    final catalogProgram = installed.copyWith(
      source: ProgramSource.catalog(
        slug: item.slug,
        latestEtag: download.etag ?? '',
        installedAt: DateTime.now(),
      ),
      contentHash: _repo.loadProgram(installed.uuid)?.computeContentHash(),
    );
    await _repo.saveProgramShell(catalogProgram);
    _controller.add(
      ProgramEvent(ProgramEventType.programInstalled, catalogProgram),
    );
    return _repo.loadProgram(catalogProgram.uuid) ?? catalogProgram;
  }

  Future<CatalogRefreshOutcome> refreshCatalogItem(
    String programUuid,
    DrillClient client, {
    required Future<CatalogConflictChoice> Function(
      ProgramDiff diff, {
      required bool ownedSlug,
      required bool remoteUnchanged,
    })
    onConflict,
  }) async {
    final local = _repo.loadProgram(programUuid);
    final source = local?.source;
    final catalogSource = source?.whenOrNull(
      catalog: (slug, latestEtag, installedAt) =>
          (slug: slug, storedEtag: latestEtag, installedAt: installedAt),
    );
    if (local == null || catalogSource == null) {
      return CatalogRefreshOutcome(
        kind: CatalogRefreshKind.failed,
        programUuid: programUuid,
      );
    }
    final (:slug, :storedEtag, :installedAt) = catalogSource;

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
    if (head.notModified && !hasLocalChanges) {
      return CatalogRefreshOutcome(
        kind: CatalogRefreshKind.upToDate,
        programUuid: programUuid,
      );
    }

    final download = await client.download(slug);
    final remote = download.file.program();
    final diff = diffPrograms(local, remote);
    final latestEtag = download.etag ?? head.etag ?? storedEtag;
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
      await _overwriteCatalogProgram(local, remote, slug, latestEtag);
      return CatalogRefreshOutcome(
        kind: CatalogRefreshKind.updatedSilently,
        programUuid: programUuid,
        diff: diff,
        remoteUnchanged: remoteUnchanged,
      );
    }

    final ownedSlug = _repo.ownsCatalogSlug(slug);
    final choice = await onConflict(
      diff,
      ownedSlug: ownedSlug,
      remoteUnchanged: remoteUnchanged,
    );
    switch (choice) {
      case CatalogConflictChoice.cancel:
        return CatalogRefreshOutcome(
          kind: CatalogRefreshKind.cancelled,
          programUuid: programUuid,
          diff: diff,
          remoteUnchanged: remoteUnchanged,
        );
      case CatalogConflictChoice.overwriteLocal:
        await _overwriteCatalogProgram(local, remote, slug, latestEtag);
        return CatalogRefreshOutcome(
          kind: CatalogRefreshKind.updatedAfterPrompt,
          programUuid: programUuid,
          diff: diff,
          remoteUnchanged: remoteUnchanged,
        );
      case CatalogConflictChoice.publishMyChanges:
        // Use the *fresh* etag we just downloaded as If-Match. The user has
        // seen the diff and chosen to overwrite the new remote with their
        // local changes — sending the stale storedEtag would 412 against
        // the server we just synced from.
        final upload = await client.upload(
          DrillFile.fromProgram(local, slug),
          ifMatchEtag: latestEtag,
          published: true,
        );
        await _repo.setOwnsCatalogSlug(slug, true);
        final published = local.copyWith(
          source: ProgramSource.catalog(
            slug: slug,
            latestEtag: upload.etag,
            installedAt: installedAt,
          ),
          contentHash: local.computeContentHash(),
        );
        await _repo.saveProgramShell(published);
        _controller.add(
          ProgramEvent(ProgramEventType.programRefreshed, published),
        );
        return CatalogRefreshOutcome(
          kind: CatalogRefreshKind.published,
          programUuid: programUuid,
          diff: diff,
          remoteUnchanged: remoteUnchanged,
        );
      case CatalogConflictChoice.forkAsLocal:
        final fork = local.copyWith(
          uuid: nanoid(10),
          name: '${local.name} copy',
          source: const ProgramSource.local(),
          contentHash: local.computeContentHash(),
        );
        await _repo.saveProgram(fork);
        _controller.add(ProgramEvent(ProgramEventType.programCreated, fork));
        return CatalogRefreshOutcome(
          kind: CatalogRefreshKind.forked,
          programUuid: fork.uuid,
          diff: diff,
          remoteUnchanged: remoteUnchanged,
        );
    }
  }

  /// Publish a program to the catalog.
  ///
  /// Handles both first-time publish (when [Program.source] is [_Local] or
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
  Future<({Program program, bool notModified})> publishProgram(
    String programUuid, {
    required String slug,
    required List<String> tags,
    required DrillClient client,
  }) async {
    final local = _repo.loadProgram(programUuid);
    if (local == null) {
      throw StateError('Program $programUuid not found');
    }

    final catalogSource = local.source.whenOrNull(
      catalog: (existingSlug, latestEtag, installedAt) =>
          (slug: existingSlug, etag: latestEtag, installedAt: installedAt),
    );
    final String effectiveSlug;
    final String? ifMatch;
    final DateTime? existingInstalledAt;
    if (catalogSource != null) {
      effectiveSlug = catalogSource.slug;
      ifMatch =
          catalogSource.etag.isNotEmpty ? catalogSource.etag : null;
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
      '[publishProgram] slug=$effectiveSlug name="${local.name}" '
      'ifMatch=$ifMatch contentHash=${local.contentHash}',
    );
    final file = DrillFile.fromProgram(local, effectiveSlug);
    final upload = await client.upload(
      file,
      ifMatchEtag: ifMatch,
      published: true,
      tags: tags,
    );
    debugPrint(
      '[publishProgram] upload version=${upload.version} '
      'newEtag=${upload.etag} notModified=${upload.notModified}',
    );
    await _repo.setOwnsCatalogSlug(effectiveSlug, true);

    final published = local.copyWith(
      source: ProgramSource.catalog(
        slug: effectiveSlug,
        latestEtag: upload.etag,
        installedAt: existingInstalledAt ?? DateTime.now(),
      ),
      contentHash: local.computeContentHash(),
    );
    await _repo.saveProgramShell(published);
    _controller.add(
      ProgramEvent(ProgramEventType.programRefreshed, published),
    );
    return (
      program: _repo.loadProgram(published.uuid) ?? published,
      notModified: upload.notModified,
    );
  }

  /// Publish a program to the catalog under a specific [slug], forking the
  /// local plan if the slug differs from its current catalog slug.
  ///
  /// Behaviour depends on the program's current source:
  ///   - Source is local / imported: identical to [publishProgram] (first-time
  ///     publish at the requested slug).
  ///   - Source is catalog and [slug] equals the current slug: delegates to
  ///     [publishProgram] — pure update, no fork.
  ///   - Source is catalog and [slug] differs from the current slug: a local
  ///     fork is created (new [Program.uuid]) tracking the new slug, and the
  ///     fork is published. The original local plan is left untouched and
  ///     continues to track its existing slug.
  ///
  /// Returns the published [Program] (the fork, when a fork was created).
  ///
  /// Throws the same exceptions as [publishProgram].
  Future<({Program program, bool notModified})> publishProgramAs(
    String programUuid, {
    required String slug,
    required List<String> tags,
    required DrillClient client,
  }) async {
    final local = _repo.loadProgram(programUuid);
    if (local == null) {
      throw StateError('Program $programUuid not found');
    }
    final cleanSlug = sanitizeSlug(slug);
    if (cleanSlug.isEmpty) {
      throw ArgumentError('Slug cannot be empty after sanitization');
    }

    final currentSlug = local.source.whenOrNull(
      catalog: (existingSlug, latestEtag, installedAt) => existingSlug,
    );
    if (currentSlug == null || currentSlug == cleanSlug) {
      // First-time publish, or update in place under the same slug. No fork.
      return publishProgram(
        programUuid,
        slug: cleanSlug,
        tags: tags,
        client: client,
      );
    }

    // Fork: clone the plan locally with a fresh uuid and a local source,
    // then publish the fork at the new slug. The original keeps its
    // catalog(currentSlug) source.
    final now = DateTime.now();
    final fork = local.copyWith(
      uuid: nanoid(10),
      source: const ProgramSource.local(),
      metadata: local.metadata.copyWith(updated: now),
      contentHash: local.computeContentHash(),
    );
    await _repo.saveProgram(fork);
    _controller.add(ProgramEvent(ProgramEventType.programCreated, fork));

    return publishProgram(
      fork.uuid,
      slug: cleanSlug,
      tags: tags,
      client: client,
    );
  }

  List<Team> loadTeams() {
    if (activeProgramUuid == null) return const [];
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

  Program _programForExport({
    required String uuid,
    required String name,
    required List<String> selected,
  }) {
    final now = DateTime.now();
    final current = activeProgram;
    final exercises = loadExercises()
        .where((exercise) => selected.contains(exercise.uuid))
        .toList();
    return Program(
      uuid: uuid,
      name: name,
      description: current?.description ?? '',
      metadata:
          current?.metadata.copyWith(updated: now) ??
          ProgramMetadata(created: now, updated: now, version: '1.0'),
      source: current?.source ?? const ProgramSource.local(),
      teams: loadTeams(),
      sessions: current?.sessions ?? const [],
      exercises: exercises,
      rolePlays: loadRolePlays(),
      actors: loadActors(),
    );
  }

  /// Public entry point for the gated startup call in [MainScreen].
  ///
  /// Only runs when SharedPreferences already contains the active-program key
  /// (i.e., the user has previously created a program). On a fresh install,
  /// [MainScreen] skips this call so no auto-created "Default plan" appears.
  Future<void> ensureActiveProgram(AppLocalizations localizations) =>
      _ensureActiveProgram(localizations.defaultPlanName);

  Future<void> _ensureActiveProgram(String defaultPlanName) async {
    if (activeProgramUuid != null) return;
    final program = await createProgram(name: defaultPlanName);
    await _repo.setActiveProgramUuid(program.uuid);
  }

  Future<void> _overwriteCatalogProgram(
    Program local,
    Program remote,
    String slug,
    String latestEtag,
  ) async {
    final merged = remote.copyWith(
      uuid: local.uuid,
      name: remote.name,
      source: ProgramSource.catalog(
        slug: slug,
        latestEtag: latestEtag,
        installedAt: DateTime.now(),
      ),
      contentHash: remote.computeContentHash(),
    );
    await _repo.saveProgram(merged);
    _controller.add(ProgramEvent(ProgramEventType.programRefreshed, merged));
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
    bool calcFromTimes = true,
    List<Station> stations = const [],
  }) {
    assert(
      numberOfTeams <= numberOfStations,
      '<numberOfTeams> must be less or equal to <numberOfStations>',
    );
    final schedule = List<List<TimeOfDay>>.generate(numberOfRounds, (
      stationIndex,
    ) {
      TimeOfDay currentStartTime = _addMinutesToTime(
        startTime,
        stationIndex * (executionTime + evaluationTime + rotationTime),
      );

      return List.generate(3, (phaseIndex) {
        final phaseDuration = switch (phaseIndex) {
          0 => calcFromTimes ? 0 : executionTime,
          1 => calcFromTimes ? executionTime : evaluationTime,
          2 => calcFromTimes ? evaluationTime : rotationTime,
          _ => throw UnimplementedError(),
        };
        final phaseTime = _addMinutesToTime(currentStartTime, phaseDuration);

        currentStartTime = phaseTime;
        return phaseTime;
      });
    });

    final lastRound = schedule.last;
    final lastPhase = lastRound.last;
    final endTime = calcFromTimes
        ? TimeOfDay.fromDateTime(
            lastPhase.toDateTime().add(Duration(minutes: rotationTime)),
          )
        : lastPhase;

    return Exercise(
      name: name,
      uuid: uuid ?? nanoid(8),
      startTime: startTime.toSimple(),
      executionTime: executionTime,
      evaluationTime: evaluationTime,
      rotationTime: rotationTime,
      numberOfTeams: numberOfTeams,
      numberOfRounds: numberOfRounds,
      stations: ensureStations(localizations, numberOfStations, stations),
      schedule: List.unmodifiable(
        schedule.map((e) => e.map((e) => e.toSimple()).toList()),
      ),
      endTime: endTime.toSimple(),
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

  static TimeOfDay _addMinutesToTime(TimeOfDay time, int minutesToAdd) {
    final totalMinutes = time.hour * 60 + time.minute + minutesToAdd;
    final addedHours = totalMinutes ~/ 60;
    final addedMinutes = totalMinutes % 60;

    return TimeOfDay(hour: addedHours % 24, minute: addedMinutes);
  }
}
