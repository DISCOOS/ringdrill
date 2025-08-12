import 'dart:async';

import 'package:latlong2/latlong.dart';
import 'package:ringdrill/data/drill_file.dart';
import 'package:ringdrill/data/program_repository.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/program.dart';
import 'package:ringdrill/models/team.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef OnSelectExercises =
    Future<Iterable<Exercise>?> Function(Iterable<Exercise> items);

enum ProgramEventType {
  exerciseAdded,
  exerciseDeleted,
  programOpened,
  programImported,
  programExported,
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
  late final SharedPreferences _prefs;

  Stream<ProgramEvent> get events => _controller.stream;

  Future<List<Exercise>> init() async {
    if (!_isReady) {
      _prefs = await SharedPreferences.getInstance();
      _repo = ProgramRepository(_prefs);
      _isReady = true;
    }
    return _repo.loadExercises();
  }

  Program createProgram({
    required String uuid,
    required String name,
    String description = '',
    List<String> exercises = const [],
  }) {
    final now = DateTime.now();
    final all = _repo.loadExercises();
    return Program(
      uuid: uuid,
      name: name,
      description: description,
      metadata: ProgramMetadata(created: now, updated: now, version: '1.0'),
      sessions: const [],
      teams: _repo.loadTeams(),
      exercises: exercises.isEmpty
          ? all
          : all.where((e) => exercises.contains(e.uuid)).toList(),
    );
  }

  Exercise? getExercise(String uuid) => _repo.getExercise(uuid);

  List<Exercise> loadExercises() => _repo.loadExercises();

  List<StationLocation> getLocations() {
    final markers = <((String, int), String, LatLng)>[];
    for (final e in loadExercises()) {
      markers.addAll(e.getLocations());
    }
    return markers;
  }

  Future<void> saveExercise(
    AppLocalizations localizations,
    Exercise exercise,
  ) async {
    await ensureTeams(localizations, exercise.numberOfTeams);
    await _repo.saveExercise(exercise);
    _controller.add(
      ProgramEvent.added(
        // TODO: Make Program persistent
        createProgram(uuid: exercise.uuid, name: exercise.uuid),
        exercise,
      ),
    );
  }

  Future<void> deleteExercise(String uuid, [bool replace = false]) async {
    final program = createProgram(uuid: uuid, name: uuid);
    final deleted = await _repo.deleteExercise(uuid);
    if (deleted != null) {
      _controller.add(
        // TODO: Make Program persistent
        ProgramEvent.deleted(program, deleted),
      );
    }
  }

  /// Exports a Program instance into a .drill file
  Future<DrillFile> exportProgram(
    String uuid,
    String fileName,
    List<String> selected,
  ) async {
    final program = createProgram(uuid: uuid, name: fileName);

    final drillFile = DrillFile.fromProgram(program, fileName);

    _controller.add(ProgramEvent.exported(program, drillFile));

    return drillFile;
  }

  /// Clears current and open Program from a .drill file
  Future<Program?> openProgram(
    DrillFile file, {
    OnSelectExercises? onSelect,
  }) async {
    final deleted = await _repo.deleteAllExercises();
    try {
      final program = await _importProgram(file, onSelect);
      if (program != null) {
        ExerciseService().stop();
        _controller.add(ProgramEvent.opened(program, file));
      }

      return program;
    } catch (e) {
      for (final it in deleted) {
        _repo.addExercise(it);
      }
      rethrow;
    }
  }

  /// Imports a Program from a .drill file
  Future<Program?> importProgram(
    DrillFile file, {
    OnSelectExercises? onSelect,
  }) async {
    final program = await _importProgram(file, onSelect);
    if (program != null) {
      ExerciseService().stop();
      _controller.add(ProgramEvent.imported(program, file));
    }

    return program;
  }

  Future<Program?> _importProgram(
    DrillFile file,
    OnSelectExercises? onSelect,
  ) async {
    final program = file.program();

    final selected = onSelect == null
        ? program.exercises
        : await onSelect.call(program.exercises);

    // User canceled
    if (selected == null) return null;

    for (final it in selected) {
      _repo.saveExercise(it);
    }

    // Reconstruct the Program with nested objects
    return program.copyWith(exercises: selected.toList());
  }

  List<Team> loadTeams() {
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
    final teams = ProgramX.ensureTeams(
      localizations,
      numberOfTeams,
      loadTeams(),
    );
    for (final it in teams.where((e) => !_repo.containsTeam(e.uuid))) {
      await _repo.addTeam(it);
    }
    return teams;
  }
}
