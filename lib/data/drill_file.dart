import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as path;
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/program.dart';
import 'package:ringdrill/models/team.dart';
import 'package:universal_io/io.dart';

const drillVersion1_0 = '1.0';
const drillMimeType = 'application/x-drill';

class DrillFile {
  DrillFile({
    required this.version,
    required this.fileName,
    required this.mimeType,
    required this.content,
  });
  final String version;
  final String mimeType;
  final String fileName;
  final List<int> content;

  Program program() {
    final teams = <Team>[];
    final sessions = <Session>[];
    final exercises = <Exercise>[];
    late final Program program;
    late final ProgramMetadata metadata;

    final archive = ZipDecoder().decodeBytes(content);

    for (final file in archive.files) {
      if (file.isFile) {
        final content = utf8.decode(file.content as List<int>);
        final json = jsonDecode(content);
        if (file.name == 'program.json') {
          program = Program.fromJson(json);
          continue;
        }
        if (file.name == 'metadata.json') {
          metadata = ProgramMetadata.fromJson(json);
          continue;
        }
        if (file.name.startsWith('teams')) {
          teams.add(Team.fromJson(json));
          continue;
        }
        if (file.name.startsWith('sessions')) {
          sessions.add(Session.fromJson(json));
          continue;
        }
        if (file.name.startsWith('exercises')) {
          exercises.add(Exercise.fromJson(json));
          continue;
        }
      }
    }

    return program.copyWith(
      teams: teams,
      sessions: sessions,
      metadata: metadata,
      exercises: exercises,
    );
  }

  static DrillFile fromFile(File file) {
    final content = file.readAsBytesSync();
    return DrillFile(
      content: content,
      fileName: path.basename(file.path),
      version: drillVersion1_0,
      mimeType: drillMimeType,
    );
  }

  static DrillFile fromProgram(Program program, String fileName) {
    final archive = Archive();
    final encoder = ZipEncoder();

    // Serialize Program's metadata
    final metadata = utf8.encode(jsonEncode(program.metadata.toJson()));
    archive.addFile(ArchiveFile('metadata.json', metadata.length, metadata));

    // Serialize exercises into folder 'exercises'
    for (var exercise in program.exercises) {
      final json = utf8.encode(jsonEncode(exercise.toJson()));
      archive.addFile(
        ArchiveFile(
          path.join('exercises', '${exercise.uuid}.json'),
          json.length,
          json,
        ),
      );
    }

    // Serialize teams into folder 'teams'
    for (var team in program.teams) {
      final json = utf8.encode(jsonEncode(team.toJson()));
      archive.addFile(
        ArchiveFile(path.join('teams', '${team.uuid}.json'), json.length, json),
      );
    }

    // Serialize sessions into folder 'sessions'
    for (var session in program.sessions) {
      final json = utf8.encode(jsonEncode(session.toJson()));
      archive.addFile(
        ArchiveFile(
          path.join('sessions', '${session.uuid}.json'),
          json.length,
          json,
        ),
      );
    }

    // Serialize Program itself (without nested objects)
    final json = utf8.encode(
      jsonEncode(
        program.copyWith(teams: [], sessions: [], exercises: []).toJson(),
      ),
    );
    archive.addFile(ArchiveFile('program.json', json.length, json));

    return DrillFile(
      mimeType: drillMimeType,
      version: drillVersion1_0,
      fileName: '$fileName.drill',
      content: encoder.encode(archive),
    );
  }
}
