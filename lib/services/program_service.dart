import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_archive/flutter_archive.dart';
import 'package:legalize/legalize.dart';
import 'package:path/path.dart' as path;
import 'package:ringdrill/data/exercise_repository.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/program.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_io/io.dart';

const drillMimeType = 'application/x-drill';

enum ProgramEventType { opened, imported, exported }

class ProgramEvent {
  final File? file;
  final Program program;
  final ProgramEventType type;

  ProgramEvent(this.type, this.program, this.file);

  factory ProgramEvent.opened(Program program, File file) =>
      ProgramEvent(ProgramEventType.opened, program, file);

  factory ProgramEvent.imported(Program program, File file) =>
      ProgramEvent(ProgramEventType.imported, program, file);

  factory ProgramEvent.exported(Program program, File file) =>
      ProgramEvent(ProgramEventType.exported, program, file);
}

class ProgramService {
  static final ProgramService _instance = ProgramService._internal();

  factory ProgramService() => _instance;

  ProgramService._internal();

  final StreamController<ProgramEvent> _controller =
      StreamController.broadcast();

  bool _isReady = false;
  late final ExerciseRepository repo;
  late final SharedPreferences _prefs;

  Stream<ProgramEvent> get events => _controller.stream;

  Program create({
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
      exercises: repo.loadExercises(),
      sessions: [],
    );
  }

  Future<List<Exercise>> init() async {
    if (!_isReady) {
      _prefs = await SharedPreferences.getInstance();
      repo = ExerciseRepository(_prefs);
      _isReady = true;
    }
    return repo.loadExercises();
  }

  /// Exports a Program instance into a .drill file
  Future<File> exportToLocalFile(
    Program program,
    Directory destinationDir,
  ) async {
    // Create a temp folder for export
    final String tempDirPath = path.join(
      Directory.systemTemp.path,
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
              exercises: [], // Exclude exercises: handled as separate files
              sessions: [], // Exclude sessions: handled as separate files
            )
            .toJson(),
      ),
    );

    // Zip the files into a .drill file
    final zipFile = File(
      path.join(destinationDir.path, '${legalizeFilename(program.name)}.drill'),
    );

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
    final deleted = await repo.deleteAllExercises();
    try {
      final program = await _importFromLocalFile(file, onExtracting);

      _controller.add(ProgramEvent.opened(program, file));

      return program;
    } catch (e) {
      for (final it in deleted) {
        repo.addExercise(it);
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
    final String tempDirPath = path.join(
      Directory.systemTemp.path,
      'program_import',
    );
    final tempDir = Directory(tempDirPath);
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    tempDir.createSync(recursive: true);

    // Extract files from archive
    await ZipFile.extractToDirectory(
      zipFile: file,
      onExtracting: (zipEntry, progress) {
        return onExtracting != null
            ? onExtracting(zipEntry, progress)
            : ZipFileOperation.includeItem;
      },
      destinationDir: tempDir,
    );

    for (final it in tempDir.listSync()) {
      debugPrint(it.toString());
    }

    // Deserialize Program
    final programJson = jsonDecode(
      File(path.join(tempDirPath, 'program.json')).readAsStringSync(),
    );
    final program = Program.fromJson(programJson);

    // Populate Exercises
    final exercises = Directory(path.join(tempDirPath, 'exercises'))
        .listSync()
        .where((e) => e.path.endsWith('.json'))
        .map(
          (file) =>
              Exercise.fromJson(jsonDecode(File(file.path).readAsStringSync())),
        )
        .toList();

    // Populate Sessions
    final sessions = Directory(path.join(tempDirPath, 'sessions'))
        .listSync()
        .where((e) => e.path.endsWith('.json'))
        .map(
          (file) =>
              Session.fromJson(jsonDecode(File(file.path).readAsStringSync())),
        )
        .toList();

    // Reconstruct the Program with nested objects
    final fullProgram = program.copyWith(
      exercises: exercises,
      sessions: sessions,
    );

    tempDir.deleteSync(recursive: true);

    for (final it in exercises) {
      repo.saveExercise(it);
    }
    return fullProgram;
  }
}
