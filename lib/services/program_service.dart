import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_archive/flutter_archive.dart';
import 'package:latlong2/latlong.dart';
import 'package:legalize/legalize.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:ringdrill/data/program_repository.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/program.dart';
import 'package:ringdrill/models/team.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_io/io.dart';

const drillMimeType = 'application/x-drill';

enum ProgramEventType {
  exerciseAdded,
  exerciseDeleted,
  programOpened,
  programImported,
  programExported,
}

class ProgramEvent {
  final File? file;
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

  factory ProgramEvent.opened(Program program, File file) =>
      ProgramEvent(ProgramEventType.programOpened, program, file: file);

  factory ProgramEvent.imported(Program program, File file) =>
      ProgramEvent(ProgramEventType.programImported, program, file: file);

  factory ProgramEvent.exported(Program program, File file) =>
      ProgramEvent(ProgramEventType.programExported, program, file: file);
}

typedef StationLocation = ((String, int), String, LatLng);

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
  }) {
    final now = DateTime.now();
    return Program(
      uuid: uuid,
      name: name,
      description: description,
      metadata: ProgramMetadata(created: now, updated: now, version: '1.0'),
      sessions: [],
      teams: _repo.loadTeams(),
      exercises: _repo.loadExercises(),
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
    final deleted = await _repo.deleteExercise(uuid);
    if (deleted != null) {
      _controller.add(
        // TODO: Make Program persistent
        ProgramEvent.deleted(createProgram(uuid: uuid, name: uuid), deleted),
      );
    }
  }

  /// Exports a Program instance into a .drill file
  Future<File> exportToLocalFile(
    String uuid,
    String fileName,
    Directory destinationDir,
  ) async {
    final program = createProgram(uuid: uuid, name: fileName);
    // Create a temp folder for export
    final String tempDirPath = path.join(
      (await getTemporaryDirectory()).path,
      'program_export',
    );
    final tempDir = Directory(tempDirPath);
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    tempDir.createSync(recursive: true);

    // Serialize Program's metadata
    File(
      path.join(tempDirPath, 'metadata.json'),
    ).writeAsStringSync(jsonEncode(program.metadata.toJson()));

    // Serialize Exercises
    final exercisesDir = Directory(path.join(tempDirPath, 'exercises'));
    exercisesDir.createSync();
    for (var exercise in program.exercises) {
      File(
        path.join(exercisesDir.path, '${exercise.uuid}.json'),
      ).writeAsStringSync(jsonEncode(exercise.toJson()));
    }

    // Serialize Teams
    final teamsDir = Directory(path.join(tempDirPath, 'teams'));
    teamsDir.createSync();
    for (var team in program.teams) {
      File(
        path.join(teamsDir.path, '${team.uuid}.json'),
      ).writeAsStringSync(jsonEncode(team.toJson()));
    }

    // Serialize Sessions
    final sessionsDir = Directory(path.join(tempDirPath, 'sessions'));
    sessionsDir.createSync();
    for (var session in program.sessions) {
      File(
        path.join(sessionsDir.path, '${session.uuid}.json'),
      ).writeAsStringSync(jsonEncode(session.toJson()));
    }

    // Serialize Program itself (without nested objects)
    File(path.join(tempDirPath, 'program.json')).writeAsStringSync(
      jsonEncode(
        program
            .copyWith(
              teams: [],
              sessions: [], // Exclude sessions: handled as separate files
              exercises: [], // Exclude exercises: handled as separate files
            )
            .toJson(),
      ),
    );

    // Zip the files into a .drill file
    final zipFile = File(
      path.join(destinationDir.path, '${legalizeFilename(program.name)}.drill'),
    );
    if (zipFile.existsSync()) {
      zipFile.deleteSync();
    }

    await ZipFile.createFromDirectory(
      sourceDir: tempDir,
      zipFile: zipFile,
      recurseSubDirs: true,
    );

    tempDir.deleteSync(recursive: true);

    _controller.add(ProgramEvent.exported(program, zipFile));

    return zipFile;
  }

  /// Clears current and open Program from a .drill file
  Future<Program> openFromLocalFile(
    File file, {
    OnExtracting? onExtracting,
  }) async {
    final deleted = await _repo.deleteAllExercises();
    try {
      final program = await _importFromLocalFile(file, onExtracting);

      _controller.add(ProgramEvent.opened(program, file));

      return program;
    } catch (e) {
      for (final it in deleted) {
        _repo.addExercise(it);
      }
      rethrow;
    }
  }

  /// Imports a Program from a .drill file
  Future<Program> importFromLocalFile(
    File file, {
    OnExtracting? onExtracting,
  }) async {
    final program = await _importFromLocalFile(file, onExtracting);

    _controller.add(ProgramEvent.imported(program, file));

    return program;
  }

  Future<Program> _importFromLocalFile(
    File file,
    OnExtracting? onExtracting,
  ) async {
    const numberOfDirsInDrillFileFormat = 3;
    final t = (await getTemporaryDirectory()).path;
    final String tempDirPath = path.join(t, 'program_import');
    final tempDir = Directory(tempDirPath);
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    tempDir.createSync(recursive: true);

    final unzippedDirs = <String>[];

    // Extract files from archive
    await ZipFile.extractToDirectory(
      zipFile: file,
      onExtracting: (zipEntry, progress) {
        // HACK: I do not know why, but when unzipping a shared file
        // the project file name (which is not part of the file url) is
        // created first before files are unzipped into i. When opening
        // a file from local storage this does not happen
        if (zipEntry.isDirectory) {
          unzippedDirs.add(zipEntry.name);
        }
        return onExtracting != null
            ? onExtracting(zipEntry, progress)
            : ZipFileOperation.includeItem;
      },
      destinationDir: tempDir,
    );

    for (final it in tempDir.listSync()) {
      debugPrint(it.toString());
    }

    if (unzippedDirs.isEmpty) {
      throw Exception('[IMPORT] ${file.path} contains no data');
    }

    // Assume the extra folder i the root folder of unzipped files
    final unzippedDirPath = unzippedDirs.length > numberOfDirsInDrillFileFormat
        ? path.join(tempDirPath, unzippedDirs.first)
        : tempDirPath;

    // Deserialize Program
    final programJson = jsonDecode(
      File(path.join(unzippedDirPath, 'program.json')).readAsStringSync(),
    );
    final program = Program.fromJson(programJson);

    // Populate Exercises
    final exercises = Directory(path.join(unzippedDirPath, 'exercises'))
        .listSync()
        .where((e) => e.path.endsWith('.json'))
        .map(
          (file) =>
              Exercise.fromJson(jsonDecode(File(file.path).readAsStringSync())),
        )
        .toList();

    // Populate Teams
    final teams = Directory(path.join(unzippedDirPath, 'teams'))
        .listSync()
        .where((e) => e.path.endsWith('.json'))
        .map(
          (file) =>
              Team.fromJson(jsonDecode(File(file.path).readAsStringSync())),
        )
        .toList();

    // Populate Sessions
    final sessions = Directory(path.join(unzippedDirPath, 'sessions'))
        .listSync()
        .where((e) => e.path.endsWith('.json'))
        .map(
          (file) =>
              Session.fromJson(jsonDecode(File(file.path).readAsStringSync())),
        )
        .toList();

    // Reconstruct the Program with nested objects
    final fullProgram = program.copyWith(
      teams: teams,
      sessions: sessions,
      exercises: exercises,
    );

    tempDir.deleteSync(recursive: true);

    for (final it in exercises) {
      _repo.saveExercise(it);
    }
    return fullProgram;
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
