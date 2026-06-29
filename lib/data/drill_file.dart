import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as path;
import 'package:ringdrill/models/actor.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/program.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/team.dart';
import 'package:universal_io/io.dart';

/// Why a `.drill` archive could not be parsed.
///
/// Distinguishes user-input problems (wrong file dragged onto the open
/// sheet, half-downloaded blob, archive from a future RingDrill version)
/// from genuine bugs. The UI maps each reason to a localized message and
/// — critically — does NOT report these to Sentry, because they are not
/// our defects.
enum DrillFormatReason {
  /// File bytes are empty, or the file does not exist on disk by the time
  /// we try to read it.
  empty,

  /// Bytes are not a valid ZIP container at all (renamed `.pdf`, `.txt`,
  /// truncated download, etc.).
  notArchive,

  /// Valid ZIP, but `program.json` is missing. Either a manually crafted
  /// zip or a `.drill` produced by a very different tool.
  missingProgram,

  /// `program.json` (or `metadata.json`, or one of the entity manifests)
  /// is present but the JSON or the schema-shape is wrong.
  corruptManifest,

  /// The archive declares a schema version this build does not know how
  /// to read. Hint to the user: upgrade RingDrill.
  schemaUnsupported,
}

/// Thrown by [DrillFile.program] when the archive cannot be parsed for
/// reasons that are user-visible rather than a programming error.
///
/// Implements [FormatException] for backwards compatibility — any
/// existing `on FormatException` catch sites keep working — but adds a
/// typed [reason] so the import path can pick a useful message instead
/// of the generic "Open failed, try again." snackbar.
class DrillFormatException implements FormatException {
  DrillFormatException(this.reason, this.message, {this.cause});

  /// What category of format problem this is. Drives the user-visible
  /// message.
  final DrillFormatReason reason;

  /// Human-readable, English diagnostic. Used in logs and as a fallback;
  /// the UI maps [reason] to a localized message.
  @override
  final String message;

  /// Original exception that triggered this wrap (ZIP decode error, JSON
  /// parse error, …). Kept so debug logs still surface the underlying
  /// cause; never logged to Sentry.
  final Object? cause;

  @override
  dynamic get source => null;

  @override
  int get offset => -1;

  @override
  String toString() => cause == null
      ? 'DrillFormatException(${reason.name}): $message'
      : 'DrillFormatException(${reason.name}): $message (cause: $cause)';
}

class DrillFile {
  static const drillSchema1_0 = '1.0';
  static const drillSchema1_1 = '1.1';
  static const drillSchema1_2 = '1.2';
  static const drillSchemaCurrent = drillSchema1_2;
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
    // Exercise manifests keyed by uuid; markdown patches collected separately.
    final exerciseJsons = <String, Map<String, dynamic>>{};
    // exerciseMdFields[uuid][fieldName] = content
    final exerciseMdFields = <String, Map<String, String>>{};
    // stationMdFields[(exerciseUuid, index)][fieldName] = content
    final stationMdFields = <(String, int), Map<String, String>>{};
    // Intermediate storage keyed by uuid for the two-pass approach.
    final rolePlayJsons = <String, Map<String, dynamic>>{};
    final rolePlayMdFields = <String, Map<String, String>>{};
    final actorJsons = <String, Map<String, dynamic>>{};
    final actorNotesFields = <String, String>{};
    final actors = <Actor>[];
    // Program-level markdown fields (program/intro.md, program/comms.md,
    // program/before-round.md).
    String? programBriefIntroMd;
    String? programCommsMd;
    String? programBeforeRoundMd;
    // Nullable rather than `late final`: a `.drill` archive produced by
    // an older client, a manual zip, or a truncated download may be
    // missing one or both of these entries. With `late final` the
    // access at the bottom of this method blows up with the opaque
    // `LateInitializationError: Field '' has not been initialized.`
    // We want a clear FormatException with a name so the import path
    // can surface a useful message to the user instead.
    Program? program;
    ProgramMetadata? metadata;

    if (content.isEmpty) {
      throw DrillFormatException(
        DrillFormatReason.empty,
        'Invalid .drill archive: file is empty.',
      );
    }

    // ZipDecoder is unfortunately lenient: feed it ASCII garbage and it
    // happily returns an Archive with zero entries instead of throwing,
    // which would then look like "empty zip" to the user even though
    // they handed us a PDF. The fix is a cheap magic-byte sniff up
    // front: every ZIP starts with "PK" (0x50 0x4B). Anything that
    // doesn't is not a ZIP, full stop — surface that as `notArchive`
    // before ZipDecoder gets a chance to lie about it.
    if (content.length < 2 || content[0] != 0x50 || content[1] != 0x4B) {
      throw DrillFormatException(
        DrillFormatReason.notArchive,
        'Invalid .drill archive: bytes are not a ZIP container '
        '(missing PK signature).',
      );
    }

    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(content);
    } catch (e) {
      // Bytes had the PK signature but ZipDecoder still rejected them
      // (truncated central directory, etc.). Treat as not-a-(usable)-
      // archive so the user gets the same "wrong file" message instead
      // of a raw RangeError / ArchiveException reaching the snackbar.
      throw DrillFormatException(
        DrillFormatReason.notArchive,
        'Invalid .drill archive: bytes are not a valid ZIP container.',
        cause: e,
      );
    }

    if (archive.files.isEmpty) {
      throw DrillFormatException(
        DrillFormatReason.empty,
        'Invalid .drill archive: ZIP container has no entries.',
      );
    }

    // Pass 1: index all archive entries by name.
    final index = <String, List<int>>{};
    for (final file in archive.files) {
      if (file.isFile) {
        index[file.name] = file.content as List<int>;
      }
    }

    // Early fast-fail for the by-far most common breakage mode (the
    // Sentry ticket that triggered this hardening). Catching it before
    // we attempt to parse other entries means a `.drill` that ALSO has
    // a malformed team manifest still surfaces the real problem
    // ("program.json is missing") rather than a misleading "corrupt
    // manifest" from the unrelated team entry that the iteration would
    // otherwise hit first.
    if (!index.containsKey('program.json')) {
      throw DrillFormatException(
        DrillFormatReason.missingProgram,
        'Invalid .drill archive: missing required entry "program.json".',
      );
    }

    // Pass 2: classify and deserialize by exact path shape.
    for (final entry in index.entries) {
      final name = entry.key;
      final bytes = entry.value;

      if (name == 'program.json') {
        try {
          final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
          program = Program.fromJson(json);
        } catch (e) {
          throw DrillFormatException(
            DrillFormatReason.corruptManifest,
            'Invalid .drill archive: program.json could not be parsed.',
            cause: e,
          );
        }
        continue;
      }
      if (name == 'metadata.json') {
        try {
          final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
          metadata = ProgramMetadata.fromJson(json);
        } catch (e) {
          throw DrillFormatException(
            DrillFormatReason.corruptManifest,
            'Invalid .drill archive: metadata.json could not be parsed.',
            cause: e,
          );
        }
        continue;
      }
      if (name == 'program/intro.md') {
        programBriefIntroMd = utf8.decode(bytes);
        continue;
      }
      if (name == 'program/comms.md') {
        programCommsMd = utf8.decode(bytes);
        continue;
      }
      if (name == 'program/before-round.md') {
        programBeforeRoundMd = utf8.decode(bytes);
        continue;
      }

      final segments = name.split('/');

      if (segments.length == 2) {
        // <folder>/<uuid>.json — entity manifests.
        // Wrap per-entry so a single corrupt team/session/etc. surfaces
        // as a typed format error (corruptManifest) instead of a raw
        // TypeError/FormatException leaking through to the snackbar.
        final folder = segments[0];
        final file = segments[1];
        if (!file.endsWith('.json')) continue;
        try {
          final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;

          if (folder == 'teams') {
            teams.add(Team.fromJson(json));
          } else if (folder == 'sessions') {
            sessions.add(Session.fromJson(json));
          } else if (folder == 'exercises') {
            final uuid = file.substring(0, file.length - 5); // strip .json
            exerciseJsons[uuid] = json;
          } else if (folder == 'roleplays') {
            final uuid = file.substring(0, file.length - 5); // strip .json
            rolePlayJsons[uuid] = json;
          } else if (folder == 'actors') {
            final uuid = file.substring(0, file.length - 5);
            actorJsons[uuid] = json;
          }
        } catch (e) {
          throw DrillFormatException(
            DrillFormatReason.corruptManifest,
            'Invalid .drill archive: entry "$name" could not be parsed.',
            cause: e,
          );
        }
        continue;
      }

      if (segments.length == 3 && segments[2].endsWith('.md')) {
        // <folder>/<uuid>/<field>.md — markdown companion files
        final folder = segments[0];
        final uuid = segments[1];
        final field = segments[2];
        final mdContent = utf8.decode(bytes);

        if (folder == 'exercises') {
          exerciseMdFields.putIfAbsent(uuid, () => {})[field] = mdContent;
        } else if (folder == 'roleplays') {
          rolePlayMdFields.putIfAbsent(uuid, () => {})[field] = mdContent;
        } else if (folder == 'actors' && field == 'notes.md') {
          actorNotesFields[uuid] = mdContent;
        }
        continue;
      }

      if (segments.length == 5 &&
          segments[0] == 'exercises' &&
          segments[2] == 'stations' &&
          segments[4].endsWith('.md')) {
        // exercises/<uuid>/stations/<index>/<field>.md
        final exerciseUuid = segments[1];
        final stationIdx = int.tryParse(segments[3]);
        final field = segments[4];
        if (stationIdx != null) {
          final mdContent = utf8.decode(bytes);
          stationMdFields.putIfAbsent((
            exerciseUuid,
            stationIdx,
          ), () => {})[field] = mdContent;
        }
        continue;
      }
    }

    // Build Exercise entities, patching in markdown fields and station markdown.
    final exercises = <Exercise>[];
    for (final entry in exerciseJsons.entries) {
      final uuid = entry.key;
      final json = entry.value;
      late final Exercise base;
      try {
        base = Exercise.fromJson(json);
      } catch (e) {
        throw DrillFormatException(
          DrillFormatReason.corruptManifest,
          'Invalid .drill archive: entry "exercises/$uuid.json" '
          'could not be parsed.',
          cause: e,
        );
      }
      var exercise = base;

      final exMd = exerciseMdFields[uuid];
      if (exMd != null && exMd.isNotEmpty) {
        exercise = exercise.copyWith(
          methodMd: exMd['method.md'],
          learningGoalsMd: exMd['learning-goals.md'],
          trainingFocusMd: exMd['training-focus.md'],
          orderFormatMd: exMd['order-format.md'],
          executionTipsMd: exMd['execution-tips.md'],
          commsMd: exMd['comms.md'],
        );
      }

      // Patch station markdown into each station.
      final patchedStations = exercise.stations.map((station) {
        final key = (uuid, station.index);
        final sMd = stationMdFields[key];
        if (sMd == null || sMd.isEmpty) return station;
        return station.copyWith(
          equipmentMd: sMd['equipment.md'],
          situationMd: sMd['situation.md'],
          missionMd: sMd['mission.md'],
          logisticsMd: sMd['logistics.md'],
          criticalQuestionsMd: sMd['critical-questions.md'],
          leaderAnswersMd: sMd['leader-answers.md'],
          directorNotesMd: sMd['director-notes.md'],
        );
      }).toList();

      exercises.add(exercise.copyWith(stations: patchedStations));
    }

    // Build RolePlay entities with legacy-inline fallback + .md precedence.
    final rolePlays = <RolePlay>[];
    for (final entry in rolePlayJsons.entries) {
      final uuid = entry.key;
      final json = entry.value;

      // Capture legacy inline values before fromJson (which ignores them).
      final legacyBehavior = json['behavior'] as String?;
      final legacyBackground = json['background'] as String?;

      late final RolePlay rpBase;
      try {
        rpBase = RolePlay.fromJson(json);
      } catch (e) {
        throw DrillFormatException(
          DrillFormatReason.corruptManifest,
          'Invalid .drill archive: entry "roleplays/$uuid.json" '
          'could not be parsed.',
          cause: e,
        );
      }
      var rp = rpBase;

      final mdFields = rolePlayMdFields[uuid];
      final behavior = mdFields != null && mdFields.containsKey('behavior.md')
          ? mdFields['behavior.md']
          : legacyBehavior;
      final background =
          mdFields != null && mdFields.containsKey('background.md')
          ? mdFields['background.md']
          : legacyBackground;
      final propsMd = mdFields?['props.md'];

      if (behavior != null || background != null || propsMd != null) {
        rp = rp.copyWith(
          behavior: behavior,
          background: background,
          propsMd: propsMd,
        );
      }
      rolePlays.add(rp);
    }

    // Build Actor entities with legacy-inline fallback + .md precedence.
    for (final entry in actorJsons.entries) {
      final uuid = entry.key;
      final json = entry.value;

      final legacyNotes = json['notes'] as String?;

      late final Actor actorBase;
      try {
        actorBase = Actor.fromJson(json);
      } catch (e) {
        throw DrillFormatException(
          DrillFormatReason.corruptManifest,
          'Invalid .drill archive: entry "actors/$uuid.json" '
          'could not be parsed.',
          cause: e,
        );
      }
      var actor = actorBase;

      final notes = actorNotesFields.containsKey(uuid)
          ? actorNotesFields[uuid]
          : legacyNotes;

      if (notes != null) {
        actor = actor.copyWith(notes: notes);
      }
      actors.add(actor);
    }

    if (program == null) {
      throw DrillFormatException(
        DrillFormatReason.missingProgram,
        'Invalid .drill archive: missing required entry "program.json".',
      );
    }
    // metadata.json was not part of the very first schema (drillSchema1_0).
    // Fall back to the embedded metadata on the program shell so we can
    // still import those older archives instead of crashing.
    final effectiveMetadata = metadata ?? program.metadata;

    // Reject archives from a future schema version this build does not
    // know how to read. We only know about 1.0/1.1/1.2 today; anything
    // higher is most likely from a newer RingDrill. Accept the unknown-
    // but-non-numeric case (treat as legacy) so we don't accidentally
    // refuse archives produced by tooling that left schema blank.
    final schemaStr = effectiveMetadata.schema;
    if (schemaStr != null && schemaStr.isNotEmpty) {
      final parts = schemaStr.split('.');
      final major = parts.isNotEmpty ? int.tryParse(parts[0]) : null;
      final minor = parts.length > 1 ? int.tryParse(parts[1]) : null;
      final currentSplit = drillSchemaCurrent.split('.');
      final currentMajor = int.parse(currentSplit[0]);
      final currentMinor = int.parse(currentSplit[1]);
      if (major != null && minor != null) {
        final isFuture =
            major > currentMajor ||
            (major == currentMajor && minor > currentMinor);
        if (isFuture) {
          throw DrillFormatException(
            DrillFormatReason.schemaUnsupported,
            'Invalid .drill archive: schema "$schemaStr" is newer than '
            'supported ($drillSchemaCurrent). Update RingDrill.',
          );
        }
      }
    }

    var result = program.copyWith(
      teams: teams,
      sessions: sessions,
      metadata: effectiveMetadata,
      exercises: exercises,
      rolePlays: rolePlays,
      actors: actors,
    );

    if (programBriefIntroMd != null ||
        programCommsMd != null ||
        programBeforeRoundMd != null) {
      result = result.copyWith(
        briefIntroMd: programBriefIntroMd,
        commsMd: programCommsMd,
        beforeRoundMd: programBeforeRoundMd,
      );
    }

    return result;
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

    // Program-level markdown fields.
    _writeMd(archive, 'program/intro.md', program.briefIntroMd);
    _writeMd(archive, 'program/comms.md', program.commsMd);
    _writeMd(archive, 'program/before-round.md', program.beforeRoundMd);

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
      // Exercise-level markdown fields.
      final exBase = path.join('exercises', exercise.uuid);
      _writeMd(archive, path.join(exBase, 'method.md'), exercise.methodMd);
      _writeMd(
        archive,
        path.join(exBase, 'learning-goals.md'),
        exercise.learningGoalsMd,
      );
      _writeMd(
        archive,
        path.join(exBase, 'training-focus.md'),
        exercise.trainingFocusMd,
      );
      _writeMd(
        archive,
        path.join(exBase, 'order-format.md'),
        exercise.orderFormatMd,
      );
      _writeMd(
        archive,
        path.join(exBase, 'execution-tips.md'),
        exercise.executionTipsMd,
      );
      _writeMd(archive, path.join(exBase, 'comms.md'), exercise.commsMd);
      // Station-level markdown fields (keyed by station.index, not UUID).
      for (final station in exercise.stations) {
        final sBase = path.join(exBase, 'stations', '${station.index}');
        _writeMd(
          archive,
          path.join(sBase, 'equipment.md'),
          station.equipmentMd,
        );
        _writeMd(
          archive,
          path.join(sBase, 'situation.md'),
          station.situationMd,
        );
        _writeMd(archive, path.join(sBase, 'mission.md'), station.missionMd);
        _writeMd(
          archive,
          path.join(sBase, 'logistics.md'),
          station.logisticsMd,
        );
        _writeMd(
          archive,
          path.join(sBase, 'critical-questions.md'),
          station.criticalQuestionsMd,
        );
        _writeMd(
          archive,
          path.join(sBase, 'leader-answers.md'),
          station.leaderAnswersMd,
        );
        _writeMd(
          archive,
          path.join(sBase, 'director-notes.md'),
          station.directorNotesMd,
        );
      }
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
      final rpBase = path.join('roleplays', rolePlay.uuid);
      _writeMd(archive, path.join(rpBase, 'behavior.md'), rolePlay.behavior);
      _writeMd(
        archive,
        path.join(rpBase, 'background.md'),
        rolePlay.background,
      );
      _writeMd(archive, path.join(rpBase, 'props.md'), rolePlay.propsMd);
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
      _writeMd(
        archive,
        path.join('actors', actor.uuid, 'notes.md'),
        actor.notes,
      );
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

/// Writes a markdown companion file to [archive] at [filePath] iff [content]
/// is non-null. Empty string writes a zero-byte file; null writes no file.
void _writeMd(Archive archive, String filePath, String? content) {
  if (content == null) return;
  final bytes = utf8.encode(content);
  archive.addFile(ArchiveFile(filePath, bytes.length, bytes));
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
