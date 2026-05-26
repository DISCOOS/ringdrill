import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/data/drill_file.dart';
import 'package:ringdrill/models/actor.dart';
import 'package:ringdrill/models/program.dart';
import 'package:ringdrill/models/role_play.dart';

Program _emptyProgram() {
  final now = DateTime(2026);
  return Program(
    uuid: 'prog-1',
    name: 'Test',
    description: '',
    metadata: ProgramMetadata(created: now, updated: now, version: '1.0'),
    teams: const [],
    sessions: const [],
    exercises: const [],
    rolePlays: const [],
    actors: const [],
  );
}

/// Builds a synthetic 1.1-style archive with markdown fields inlined in JSON.
DrillFile _build1_1Archive({
  String? behavior,
  String? background,
  String? notes,
}) {
  final now = DateTime(2026);
  final archive = Archive();
  final encoder = ZipEncoder();

  // metadata.json stamped 1.1
  final metaJson = jsonEncode({
    'created': now.toIso8601String(),
    'updated': now.toIso8601String(),
    'version': '1.0',
    'schema': '1.1',
  });
  final metaBytes = utf8.encode(metaJson);
  archive.addFile(ArchiveFile('metadata.json', metaBytes.length, metaBytes));

  // program.json
  final progJson = jsonEncode({
    'uuid': 'prog-1',
    'name': 'Test',
    'description': '',
    'metadata': {
      'created': now.toIso8601String(),
      'updated': now.toIso8601String(),
      'version': '1.0',
      'schema': '1.1',
    },
    'teams': <dynamic>[],
    'sessions': <dynamic>[],
    'exercises': <dynamic>[],
  });
  final progBytes = utf8.encode(progJson);
  archive.addFile(ArchiveFile('program.json', progBytes.length, progBytes));

  // roleplays/rp-1.json with inline markdown
  final rpMap = <String, dynamic>{
    'uuid': 'rp-1',
    'index': 0,
    'exerciseUuid': 'ex-1',
    'name': 'Anna Hansen',
  };
  if (behavior != null) rpMap['behavior'] = behavior;
  if (background != null) rpMap['background'] = background;
  final rpBytes = utf8.encode(jsonEncode(rpMap));
  archive.addFile(ArchiveFile('roleplays/rp-1.json', rpBytes.length, rpBytes));

  // actors/actor-1.json with inline notes
  final actorMap = <String, dynamic>{
    'uuid': 'actor-1',
    'realName': 'Kari Nordmann',
  };
  if (notes != null) actorMap['notes'] = notes;
  final actorBytes = utf8.encode(jsonEncode(actorMap));
  archive.addFile(
    ArchiveFile('actors/actor-1.json', actorBytes.length, actorBytes),
  );

  return DrillFile(
    schema: DrillFile.drillSchema1_1,
    mimeType: DrillFile.drillMimeType,
    fileName: 'test.drill',
    content: encoder.encode(archive),
  );
}

void main() {
  test('round-trips program with rolePlays and actors, schema is 1.1', () {
    const rp1 = RolePlay(
      uuid: 'rp-1',
      index: 0,
      exerciseUuid: 'ex-1',
      name: 'Anna Hansen',
      age: 67,
      signalement: 'Blå jakke',
      behavior: 'Confused and scared',
      background: 'Fell down stairs',
    );
    const rp2 = RolePlay(
      uuid: 'rp-2',
      index: 1,
      exerciseUuid: 'ex-1',
      name: 'Ola Nordmann',
      actorUuid: 'actor-1',
    );
    const actor1 = Actor(
      uuid: 'actor-1',
      realName: 'Kari Nordmann',
      phone: '+4791234567',
      notes: 'Keep in character',
    );

    final program = _emptyProgram().copyWith(
      rolePlays: [rp1, rp2],
      actors: [actor1],
    );

    final drillFile = DrillFile.fromProgram(program, 'test');
    final decoded = drillFile.program();

    expect(decoded.rolePlays.length, 2);
    expect(decoded.rolePlays.any((r) => r.uuid == 'rp-1'), isTrue);
    expect(decoded.rolePlays.any((r) => r.uuid == 'rp-2'), isTrue);
    final decodedRp1 = decoded.rolePlays.firstWhere((r) => r.uuid == 'rp-1');
    expect(decodedRp1.name, 'Anna Hansen');
    expect(decodedRp1.age, 67);
    expect(decodedRp1.signalement, 'Blå jakke');
    expect(decodedRp1.behavior, 'Confused and scared');
    expect(decodedRp1.background, 'Fell down stairs');

    final decodedRp2 = decoded.rolePlays.firstWhere((r) => r.uuid == 'rp-2');
    expect(decodedRp2.actorUuid, 'actor-1');

    expect(decoded.actors.length, 1);
    expect(decoded.actors.first.uuid, 'actor-1');
    expect(decoded.actors.first.realName, 'Kari Nordmann');
    expect(decoded.actors.first.notes, 'Keep in character');

    expect(decoded.metadata.schema, '1.2');
  });

  test('round-trips empty program without creating spurious folders', () {
    final program = _emptyProgram();
    final drillFile = DrillFile.fromProgram(program, 'empty');
    final archive = ZipDecoder().decodeBytes(drillFile.content);

    final names = archive.files.where((f) => f.isFile).map((f) => f.name);
    expect(names.any((n) => n.startsWith('roleplays')), isFalse);
    expect(names.any((n) => n.startsWith('actors')), isFalse);

    final decoded = drillFile.program();
    expect(decoded.rolePlays, isEmpty);
    expect(decoded.actors, isEmpty);
    // schema is always stamped by fromProgram
    expect(decoded.metadata.schema, '1.2');
  });

  test('opens a synthetic 1.0 archive with no roleplays/actors/schema', () {
    // Build a minimal 1.0-style archive by hand (no roleplays/, actors/, schema)
    final now = DateTime(2026);
    final prog = Program(
      uuid: 'prog-old',
      name: 'Old',
      description: '',
      metadata: ProgramMetadata(created: now, updated: now, version: '1.0'),
      teams: const [],
      sessions: const [],
      exercises: const [],
      rolePlays: const [],
      actors: const [],
    );
    final archive = Archive();
    final encoder = ZipEncoder();

    // metadata.json without schema field
    final metaJson = jsonEncode({
      'created': now.toIso8601String(),
      'updated': now.toIso8601String(),
      'version': '1.0',
    });
    final metaBytes = utf8.encode(metaJson);
    archive.addFile(ArchiveFile('metadata.json', metaBytes.length, metaBytes));

    // program.json matching a real 1.0 archive (has metadata inline, no roleplays/actors)
    final progJson = jsonEncode({
      'uuid': prog.uuid,
      'name': prog.name,
      'description': prog.description,
      'metadata': {
        'created': now.toIso8601String(),
        'updated': now.toIso8601String(),
        'version': '1.0',
      },
      'teams': <dynamic>[],
      'sessions': <dynamic>[],
      'exercises': <dynamic>[],
    });
    final progBytes = utf8.encode(progJson);
    archive.addFile(ArchiveFile('program.json', progBytes.length, progBytes));

    final drillFile = DrillFile(
      schema: DrillFile.drillSchema1_0,
      mimeType: DrillFile.drillMimeType,
      fileName: 'legacy.drill',
      content: encoder.encode(archive),
    );

    final decoded = drillFile.program();
    expect(decoded.rolePlays, isEmpty);
    expect(decoded.actors, isEmpty);
    expect(decoded.metadata.schema, isNull);
  });

  test('writes markdown as .md files in archive', () {
    const rp = RolePlay(
      uuid: 'rp-1',
      index: 0,
      exerciseUuid: 'ex-1',
      name: 'Anna',
      behavior: 'Act confused',
      background: 'Previous injury',
    );
    const actor = Actor(
      uuid: 'actor-1',
      realName: 'Kari',
      notes: 'Stay in character',
    );
    final program = _emptyProgram().copyWith(
      rolePlays: [rp],
      actors: [actor],
    );

    final drillFile = DrillFile.fromProgram(program, 'test');
    final archive = ZipDecoder().decodeBytes(drillFile.content);

    final byName = {
      for (final f in archive.files.where((f) => f.isFile))
        f.name: utf8.decode(f.content as List<int>),
    };

    // .md files are present with correct content
    expect(byName['roleplays/rp-1/behavior.md'], 'Act confused');
    expect(byName['roleplays/rp-1/background.md'], 'Previous injury');
    expect(byName['actors/actor-1/notes.md'], 'Stay in character');

    // JSON manifests do not carry the markdown keys
    final rpJson =
        jsonDecode(byName['roleplays/rp-1.json']!) as Map<String, dynamic>;
    expect(rpJson.containsKey('behavior'), isFalse);
    expect(rpJson.containsKey('background'), isFalse);

    final actorJson =
        jsonDecode(byName['actors/actor-1.json']!) as Map<String, dynamic>;
    expect(actorJson.containsKey('notes'), isFalse);
  });

  test('reads back 1.1 archive with inline markdown fields', () {
    final drillFile = _build1_1Archive(
      behavior: 'Confused',
      background: 'Head trauma',
      notes: 'PII notes',
    );
    final decoded = drillFile.program();

    final rp = decoded.rolePlays.firstWhere((r) => r.uuid == 'rp-1');
    expect(rp.behavior, 'Confused');
    expect(rp.background, 'Head trauma');

    final actor = decoded.actors.firstWhere((a) => a.uuid == 'actor-1');
    expect(actor.notes, 'PII notes');
  });

  test('prefers .md file over legacy inline JSON when both present', () {
    final now = DateTime(2026);
    final archive = Archive();
    final encoder = ZipEncoder();

    final metaBytes = utf8.encode(
      jsonEncode({'created': now.toIso8601String(), 'updated': now.toIso8601String(), 'version': '1.0', 'schema': '1.1'}),
    );
    archive.addFile(ArchiveFile('metadata.json', metaBytes.length, metaBytes));

    final progBytes = utf8.encode(
      jsonEncode({'uuid': 'prog-1', 'name': 'T', 'description': '', 'metadata': {'created': now.toIso8601String(), 'updated': now.toIso8601String(), 'version': '1.0'}, 'teams': [], 'sessions': [], 'exercises': []}),
    );
    archive.addFile(ArchiveFile('program.json', progBytes.length, progBytes));

    // roleplay JSON with inline (legacy) value
    final rpBytes = utf8.encode(
      jsonEncode({'uuid': 'rp-1', 'index': 0, 'exerciseUuid': 'ex-1', 'name': 'Anna', 'behavior': 'legacy inline'}),
    );
    archive.addFile(ArchiveFile('roleplays/rp-1.json', rpBytes.length, rpBytes));

    // .md file with different content — should win
    final mdBytes = utf8.encode('md file content');
    archive.addFile(
      ArchiveFile('roleplays/rp-1/behavior.md', mdBytes.length, mdBytes),
    );

    final drillFile = DrillFile(
      schema: DrillFile.drillSchema1_1,
      mimeType: DrillFile.drillMimeType,
      fileName: 'test.drill',
      content: encoder.encode(archive),
    );

    final decoded = drillFile.program();
    final rp = decoded.rolePlays.firstWhere((r) => r.uuid == 'rp-1');
    expect(rp.behavior, 'md file content');
  });

  test('empty md file roundtrips as empty string, missing as null', () {
    const rp = RolePlay(
      uuid: 'rp-1',
      index: 0,
      exerciseUuid: 'ex-1',
      name: 'Anna',
      behavior: '', // empty string -> zero-byte file
      background: null, // null -> no file
    );
    final program = _emptyProgram().copyWith(rolePlays: [rp]);

    final drillFile = DrillFile.fromProgram(program, 'test');

    // Verify the archive: behavior.md present (zero bytes), background.md absent
    final archive = ZipDecoder().decodeBytes(drillFile.content);
    final names = archive.files.where((f) => f.isFile).map((f) => f.name).toSet();
    expect(names.contains('roleplays/rp-1/behavior.md'), isTrue);
    expect(names.contains('roleplays/rp-1/background.md'), isFalse);

    final decoded = drillFile.program();
    final decodedRp = decoded.rolePlays.firstWhere((r) => r.uuid == 'rp-1');
    expect(decodedRp.behavior, '');
    expect(decodedRp.background, isNull);
  });

  test('mutating behavior on a rolePlay changes the content hash', () {
    const rp = RolePlay(
      uuid: 'rp-1',
      index: 0,
      exerciseUuid: 'ex-1',
      name: 'Anna',
      behavior: 'Original behavior',
    );
    final program = _emptyProgram().copyWith(rolePlays: [rp]);
    final hash1 = program.computeContentHash();

    final modified = program.copyWith(
      rolePlays: [rp.copyWith(behavior: 'Changed behavior')],
    );
    final hash2 = modified.computeContentHash();

    expect(hash2, isNot(hash1));
  });

  test('identical content with different archive-entry order produces equal hashes', () {
    const rp1 = RolePlay(
      uuid: 'aaa-rp',
      index: 0,
      exerciseUuid: 'ex-1',
      name: 'First',
      behavior: 'Calm',
    );
    const rp2 = RolePlay(
      uuid: 'zzz-rp',
      index: 1,
      exerciseUuid: 'ex-1',
      name: 'Second',
      background: 'History',
    );

    final programA = _emptyProgram().copyWith(rolePlays: [rp1, rp2]);
    final programB = _emptyProgram().copyWith(rolePlays: [rp2, rp1]);

    expect(programA.computeContentHash(), programB.computeContentHash());
  });

  test('roundtrip preserves content hash', () {
    const rp = RolePlay(
      uuid: 'rp-1',
      index: 0,
      exerciseUuid: 'ex-1',
      name: 'Anna',
      behavior: 'Act confused',
      background: 'Previous injury',
    );
    const actor = Actor(
      uuid: 'actor-1',
      realName: 'Kari',
      notes: 'Stay in character',
    );
    final program = _emptyProgram().copyWith(
      rolePlays: [rp],
      actors: [actor],
    );

    final hashBefore = program.computeContentHash();
    final drillFile = DrillFile.fromProgram(program, 'test');
    final decoded = drillFile.program();
    final hashAfter = decoded.computeContentHash();

    expect(hashAfter, hashBefore);
  });
}
