import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_archive/flutter_archive.dart';
import 'package:legalize/legalize.dart';
import 'package:path/path.dart' as path;
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/program.dart';
import 'package:universal_io/io.dart';

class ProgramManager {
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

    return zipFile;
  }

  /// Imports a Program from a .drill file
  Future<Program?> importFromLocalFile(
    File file, {
    OnExtracting? onExtracting,
  }) async {
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

    return fullProgram;
  }
}
