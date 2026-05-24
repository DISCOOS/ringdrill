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

void main() {
  test('round-trips program with rolePlays and actors, schema is 1.1', () {
    const rp1 = RolePlay(
      uuid: 'rp-1',
      index: 0,
      exerciseUuid: 'ex-1',
      name: 'Anna Hansen',
      age: 67,
      signalement: 'Blå jakke',
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

    final decodedRp2 = decoded.rolePlays.firstWhere((r) => r.uuid == 'rp-2');
    expect(decodedRp2.actorUuid, 'actor-1');

    expect(decoded.actors.length, 1);
    expect(decoded.actors.first.uuid, 'actor-1');
    expect(decoded.actors.first.realName, 'Kari Nordmann');

    expect(decoded.metadata.schema, '1.1');
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
    expect(decoded.metadata.schema, '1.1');
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
}
