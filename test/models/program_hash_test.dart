import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/models/actor.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/program.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/station.dart';

void main() {
  final _now = DateTime(2026);

  Program _base() => Program(
        uuid: 'prog-1',
        name: 'Test',
        description: '',
        metadata: ProgramMetadata(created: _now, updated: _now, version: '1.0'),
        teams: const [],
        sessions: const [],
        exercises: const [],
        rolePlays: const [],
        actors: const [],
      );

  const _rp1 = RolePlay(
    uuid: 'rp-1',
    index: 0,
    exerciseUuid: 'ex-1',
    name: 'Anna Hansen',
  );
  const _rp2 = RolePlay(
    uuid: 'rp-2',
    index: 1,
    exerciseUuid: 'ex-1',
    name: 'Ola Nordmann',
  );
  const _actor1 = Actor(uuid: 'actor-1', realName: 'Kari');

  test('content hash is stable across actor mutations', () {
    final base = _base().copyWith(rolePlays: [_rp1]);
    final withActor = base.copyWith(actors: [_actor1]);
    final differentActor = base.copyWith(
      actors: [_actor1.copyWith(phone: '+47999')],
    );
    expect(base.computeContentHash(), withActor.computeContentHash());
    expect(base.computeContentHash(), differentActor.computeContentHash());
  });

  test('content hash changes when rolePlays change', () {
    final base = _base();
    final withRole = base.copyWith(rolePlays: [_rp1]);
    final withTwoRoles = base.copyWith(rolePlays: [_rp1, _rp2]);
    final modifiedRole = base.copyWith(
      rolePlays: [_rp1.copyWith(name: 'Changed')],
    );

    expect(base.computeContentHash(), isNot(withRole.computeContentHash()));
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
    final local = _base().copyWith(rolePlays: [_rp1]);
    final remote = _base().copyWith(
      rolePlays: [
        _rp1.copyWith(name: 'Anna Renamed'),
        _rp2,
      ],
    );
    final diff = diffPrograms(local, remote);
    expect(diff.modifiedRolePlays, ['Anna Renamed']);
    expect(diff.addedRolePlays, ['Ola Nordmann']);
    expect(diff.removedRolePlays, isEmpty);
  });

  test('ProgramMetadata round-trips with and without schema', () {
    final withoutSchema = ProgramMetadata(
      created: _now,
      updated: _now,
      version: '1.0',
    );
    final decoded = ProgramMetadata.fromJson(withoutSchema.toJson());
    expect(decoded.schema, isNull);

    final withSchema = ProgramMetadata(
      created: _now,
      updated: _now,
      version: '1.0',
      schema: '1.1',
    );
    final decoded2 = ProgramMetadata.fromJson(withSchema.toJson());
    expect(decoded2.schema, '1.1');
  });
}
