import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/models/actor.dart';
import 'package:ringdrill/models/program.dart';
import 'package:ringdrill/models/role_play.dart';

void main() {
  final now = DateTime(2026);

  Program base() => Program(
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

  const rp1 = RolePlay(
    uuid: 'rp-1',
    index: 0,
    exerciseUuid: 'ex-1',
    name: 'Anna Hansen',
  );
  const rp2 = RolePlay(
    uuid: 'rp-2',
    index: 1,
    exerciseUuid: 'ex-1',
    name: 'Ola Nordmann',
  );
  const actor1 = Actor(uuid: 'actor-1', realName: 'Kari');

  test('content hash is stable across actor mutations', () {
    final prog = base().copyWith(rolePlays: [rp1]);
    final withActor = prog.copyWith(actors: [actor1]);
    final differentActor = prog.copyWith(
      actors: [actor1.copyWith(phone: '+47999')],
    );
    expect(prog.computeContentHash(), withActor.computeContentHash());
    expect(prog.computeContentHash(), differentActor.computeContentHash());
  });

  test('content hash changes when rolePlays change', () {
    final prog = base();
    final withRole = prog.copyWith(rolePlays: [rp1]);
    final withTwoRoles = prog.copyWith(rolePlays: [rp1, rp2]);
    final modifiedRole = prog.copyWith(
      rolePlays: [rp1.copyWith(name: 'Changed')],
    );

    expect(prog.computeContentHash(), isNot(withRole.computeContentHash()));
    expect(
      withRole.computeContentHash(),
      isNot(withTwoRoles.computeContentHash()),
    );
    expect(
      withRole.computeContentHash(),
      isNot(modifiedRole.computeContentHash()),
    );
  });

  test('diffPrograms detects added/removed/modified rolePlays', () {
    final local = base().copyWith(rolePlays: [rp1]);
    final remote = base().copyWith(
      rolePlays: [
        rp1.copyWith(name: 'Anna Renamed'),
        rp2,
      ],
    );
    final diff = diffPrograms(local, remote);
    expect(diff.modifiedRolePlays, ['Anna Renamed']);
    expect(diff.addedRolePlays, ['Ola Nordmann']);
    expect(diff.removedRolePlays, isEmpty);
  });

  test('content hash changes when tags change', () {
    final prog = base();
    final withTags = prog.copyWith(tags: ['sar', 'urban']);
    final differentTags = prog.copyWith(tags: ['sar']);
    expect(prog.computeContentHash(), isNot(withTags.computeContentHash()));
    expect(withTags.computeContentHash(), isNot(differentTags.computeContentHash()));
    // Order-insensitive: same tags in different order must still differ from
    // empty (they serialise as an ordered list, so ordering IS significant in
    // the current hash — this test just confirms tags are included at all).
    expect(prog.computeContentHash(), isNot(differentTags.computeContentHash()));
  });

  test('diffPrograms detects tag changes', () {
    final a = base().copyWith(tags: ['sar', 'urban']);
    final b = base().copyWith(tags: ['sar']);
    final diff = diffPrograms(a, b);
    expect(diff.tagsLocal, isNotNull);
    expect(diff.tagsRemote, isNotNull);
    expect(diff.tagsLocal, contains('urban'));
  });

  test('diffPrograms: no tag diff when tags are identical', () {
    final a = base().copyWith(tags: ['sar']);
    final b = base().copyWith(tags: ['sar']);
    final diff = diffPrograms(a, b);
    expect(diff.tagsLocal, isNull);
    expect(diff.tagsRemote, isNull);
  });

  test('ProgramMetadata round-trips with and without schema', () {
    final withoutSchema = ProgramMetadata(
      created: now,
      updated: now,
      version: '1.0',
    );
    final decoded = ProgramMetadata.fromJson(withoutSchema.toJson());
    expect(decoded.schema, isNull);

    final withSchema = ProgramMetadata(
      created: now,
      updated: now,
      version: '1.0',
      schema: '1.1',
    );
    final decoded2 = ProgramMetadata.fromJson(withSchema.toJson());
    expect(decoded2.schema, '1.1');
  });
}
