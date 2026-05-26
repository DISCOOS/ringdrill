import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as path;
import 'package:ringdrill/models/actor.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/program.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/team.dart';
import 'package:universal_io/io.dart';

class DrillFile {
  static const drillSchema1_0 = '1.0';
  static const drillSchema1_1 = '1.1';
  static const drillSchema1_2 = '1.2';
  static const drillSchemaCurrent = drillSchema1_1;
  // TODO: Change to iana format for custom mime type
  static const drillMimeType = 'application/vnd.ringdrill+zip';
  static const drillExtension = 'drill';

  DrillFile({
    required this.schema,
    required this.content,
    required this.fileName,
    required this.mimeType,
    this.version = 0,
  });

  final int version;
  final String schema;
  final String mimeType;
  final String fileName;
  final List<int> content;

  String get slug => path.basenameWithoutExtension(fileName);
  String get versionedSlug => sanitizeSlug('$slug@$version');

  Program program() {
    final teams = <Team>[];
    final sessions = <Session>[];
    final exercises = <Exercise>[];
    // Intermediate storage keyed by uuid for the two-pass approach.
    final rolePlayJsons = <String, Map<String, dynamic>>{};
    final rolePlayMdFields = <String, Map<String, String>>{};
    final actorJsons = <String, Map<String, dynamic>>{};
    final actorNotesFields = <String, String>{};
    final actors = <Actor>[];
    // Nullable rather than `late final`: a `.drill` archive produced by
    // an older client, a manual zip, or a truncated download may be
    // missing one or both of these entries. With `late final` the
    // access at the bottom of this method blows up with the opaque
    // `LateInitializationError: Field '' has not been initialized.`
    // We want a clear FormatException with a name so the import path
    // can surface a useful message to the user instead.
    Program? program;
    ProgramMetadata? metadata;

    final archive = ZipDecoder().decodeBytes(content);

    // Pass 1: index all archive entries by name.
    final index = <String, List<int>>{};
    for (final file in archive.files) {
      if (file.isFile) {
        index[file.name] = file.content as List<int>;
      }
    }

    // Pass 2: classify and deserialize by exact path shape.
    for (final entry in index.entries) {
      final name = entry.key;
      final bytes = entry.value;

      if (name == 'program.json') {
        final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
        program = Program.fromJson(json);
        continue;
      }
      if (name == 'metadata.json') {
        final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
        metadata = ProgramMetadata.fromJson(json);
        continue;
      }

      final segments = name.split('/');

      if (segments.length == 2) {
        // <folder>/<uuid>.json — entity manifests
        final folder = segments[0];
        final file = segments[1];
        if (!file.endsWith('.json')) continue;
        final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;

        if (folder == 'teams') {
          teams.add(Team.fromJson(json));
        } else if (folder == 'sessions') {
          sessions.add(Session.fromJson(json));
        } else if (folder == 'exercises') {
          exercises.add(Exercise.fromJson(json));
        } else if (folder == 'roleplays') {
          final uuid = file.substring(0, file.length - 5); // strip .json
          rolePlayJsons[uuid] = json;
        } else if (folder == 'actors') {
          final uuid = file.substring(0, file.length - 5);
          actorJsons[uuid] = json;
        }
        continue;
      }

      if (segments.length == 3 && segments[2].endsWith('.md')) {
        // <folder>/<uuid>/<field>.md — markdown companion files
        final folder = segments[0];
        final uuid = segments[1];
        final field = segments[2];
        final mdContent = utf8.decode(bytes);

        if (folder == 'roleplays') {
          rolePlayMdFields.putIfAbsent(uuid, () => {})[field] = mdContent;
        } else if (folder == 'actors' && field == 'notes.md') {
          actorNotesFields[uuid] = mdContent;
        }
        continue;
      }
    }

    // Build RolePlay entities with legacy-inline fallback + .md precedence.
    final rolePlays = <RolePlay>[];
    for (final entry in rolePlayJsons.entries) {
      final uuid = entry.key;
      final json = entry.value;

      // Capture legacy inline values before fromJson (which ignores them).
      final legacyBehavior = json['behavior'] as String?;
      final legacyBackground = json['background'] as String?;

      var rp = RolePlay.fromJson(json);

      final mdFields = rolePlayMdFields[uuid];
      final behavior = mdFields != null && mdFields.containsKey('behavior.md')
          ? mdFields['behavior.md']
          : legacyBehavior;
      final background =
          mdFields != null && mdFields.containsKey('background.md')
          ? mdFields['background.md']
          : legacyBackground;

      if (behavior != null || background != null) {
        rp = rp.copyWith(behavior: behavior, background: background);
      }
      rolePlays.add(rp);
    }

    // Build Actor entities with legacy-inline fallback + .md precedence.
    for (final entry in actorJsons.entries) {
      final uuid = entry.key;
      final json = entry.value;

      final legacyNotes = json['notes'] as String?;

      var actor = Actor.fromJson(json);

      final notes = actorNotesFields.containsKey(uuid)
          ? actorNotesFields[uuid]
          : legacyNotes;

      if (notes != null) {
        actor = actor.copyWith(notes: notes);
      }
      actors.add(actor);
    }

    if (program == null) {
      throw const FormatException(
        'Invalid .drill archive: missing required entry "program.json".',
      );
    }
    // metadata.json was not part of the very first schema (drillSchema1_0).
    // Fall back to the embedded metadata on the program shell so we can
    // still import those older archives instead of crashing.
    final effectiveMetadata = metadata ?? program.metadata;

    return program.copyWith(
      teams: teams,
      sessions: sessions,
      metadata: effectiveMetadata,
      exercises: exercises,
      rolePlays: rolePlays,
      actors: actors,
    );
  }

  static DrillFile fromFile(File file) {
    final content = file.readAsBytesSync();
    return DrillFile(
      content: content,
      fileName: path.basename(file.path),
      schema: drillSchema1_0,
      mimeType: drillMimeType,
    );
  }

  static DrillFile fromBytes(String fileName, List<int> content) {
    return DrillFile(
      content: content,
      fileName: fileName,
      schema: drillSchema1_0,
      mimeType: drillMimeType,
    );
  }

  static DrillFile fromProgram(Program program, String fileName) {
    final archive = Archive();
    final encoder = ZipEncoder();

    // Serialize Program's metadata, stamping the current schema version.
    final metadataWithSchema = program.metadata.copyWith(
      schema: drillSchemaCurrent,
    );
    final metadata = utf8.encode(jsonEncode(metadataWithSchema.toJson()));
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

    // Serialize roleplays into folder 'roleplays'
    for (var rolePlay in program.rolePlays) {
      final json = utf8.encode(jsonEncode(rolePlay.toJson()));
      archive.addFile(
        ArchiveFile(
          path.join('roleplays', '${rolePlay.uuid}.json'),
          json.length,
          json,
        ),
      );
      // Write .md companion files for markdown fields (null = no file,
      // empty string = zero-byte file).
      if (rolePlay.behavior != null) {
        final md = utf8.encode(rolePlay.behavior!);
        archive.addFile(
          ArchiveFile(
            path.join('roleplays', rolePlay.uuid, 'behavior.md'),
            md.length,
            md,
          ),
        );
      }
      if (rolePlay.background != null) {
        final md = utf8.encode(rolePlay.background!);
        archive.addFile(
          ArchiveFile(
            path.join('roleplays', rolePlay.uuid, 'background.md'),
            md.length,
            md,
          ),
        );
      }
    }

    // Serialize actors into folder 'actors'
    for (var actor in program.actors) {
      final json = utf8.encode(jsonEncode(actor.toJson()));
      archive.addFile(
        ArchiveFile(
          path.join('actors', '${actor.uuid}.json'),
          json.length,
          json,
        ),
      );
      if (actor.notes != null) {
        final md = utf8.encode(actor.notes!);
        archive.addFile(
          ArchiveFile(
            path.join('actors', actor.uuid, 'notes.md'),
            md.length,
            md,
          ),
        );
      }
    }

    // Serialize Program itself (without nested objects)
    final json = utf8.encode(
      jsonEncode(
        program
            .copyWith(
              teams: [],
              sessions: [],
              exercises: [],
              rolePlays: [],
              actors: [],
            )
            .toJson(),
      ),
    );
    archive.addFile(ArchiveFile('program.json', json.length, json));

    return DrillFile(
      schema: drillSchemaCurrent,
      mimeType: drillMimeType,
      fileName: '$fileName.drill',
      content: encoder.encode(archive),
    );
  }
}

String sanitizeSlug(String s) {
  return s
      .toLowerCase()
      .trim()
      .replaceAll(RegExp(r'\s+'), '-')
      .replaceAll(RegExp(r'[^a-z0-9\-]'), '-')
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
}
