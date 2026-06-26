import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ringdrill/data/drill_client.dart';
import 'package:ringdrill/data/drill_file.dart';
import 'package:ringdrill/models/actor.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/program.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Regression test for the bug where a catalog refresh silently destroyed the
/// local cast roster. Actors are local PII and stripped from the catalog
/// archive server-side (ADR-0018), so the downloaded remote always has an
/// empty actor list. `_overwriteCatalogProgram` used to save that empty list
/// over the local copy, wiping the user's actors and breaking every
/// role↔actor assignment — the "marker list had a name yesterday, it's empty
/// today" report.
///
/// The fix merges locally-stored actors back in when overwriting from the
/// catalog (and on reinstall via [ProgramService.installFromFile]).
void main() {
  const slug = 'cast-plan';
  const installedEtag = 'etag-v1';

  Program buildProgram(
    String programUuid, {
    required List<Actor> actors,
    required List<RolePlay> rolePlays,
  }) {
    final now = DateTime.utc(2026, 6, 2);
    final exercise = Exercise(
      uuid: 'exercise-1',
      name: 'Patrol',
      startTime: const SimpleTimeOfDay(hour: 8, minute: 0),
      numberOfTeams: 1,
      numberOfRounds: 1,
      executionTime: 10,
      evaluationTime: 5,
      rotationTime: 2,
      stations: const [Station(index: 0, name: 'Station 1')],
      schedule: const [
        [
          SimpleTimeOfDay(hour: 8, minute: 0),
          SimpleTimeOfDay(hour: 8, minute: 10),
          SimpleTimeOfDay(hour: 8, minute: 15),
        ],
      ],
      endTime: const SimpleTimeOfDay(hour: 8, minute: 17),
    );
    final base = Program(
      uuid: programUuid,
      name: 'Cast Plan',
      description: '',
      metadata: ProgramMetadata(created: now, updated: now, version: '1.0'),
      source: ProgramSource.catalog(
        slug: slug,
        latestEtag: installedEtag,
        installedAt: now,
      ),
      teams: const [],
      sessions: const [],
      exercises: [exercise],
      rolePlays: rolePlays,
      actors: actors,
    );
    return base.copyWith(contentHash: base.computeContentHash());
  }

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await ProgramService().init();
  });

  tearDown(() async {
    await ProgramService().clearAllForTest();
  });

  test('silent catalog refresh preserves locally-stored actors', () async {
    final service = ProgramService();
    const programUuid = 'program-cast';
    const actor = Actor(
      uuid: 'actor-1',
      realName: 'Kari Nordmann',
      phone: '12345678',
    );
    const rolePlay = RolePlay(
      uuid: 'role-1',
      index: 0,
      exerciseUuid: 'exercise-1',
      name: 'Turgaaer',
      stationIndex: 0,
      actorUuid: 'actor-1',
    );

    final local = buildProgram(
      programUuid,
      actors: const [actor],
      rolePlays: const [rolePlay],
    );
    await service.replaceProgram(local);

    // Sanity: the actor and its cast assignment are stored locally, and the
    // local copy has no divergence from the installed snapshot (so the
    // refresh takes the silent path, not the conflict dialog).
    final stored = service.loadProgram(programUuid)!;
    expect(stored.actors.map((a) => a.uuid), contains('actor-1'));
    expect(stored.rolePlays.single.actorUuid, 'actor-1');
    expect(stored.computeContentHash(), stored.contentHash);

    // Remote mirrors the same plan but with actors stripped server-side. The
    // roleplay still references actor-1.
    final remote = buildProgram(
      programUuid,
      actors: const [],
      rolePlays: const [rolePlay],
    );
    final remoteBytes = DrillFile.fromProgram(remote, '$slug.drill').content;

    final client = DrillClient(
      baseUrl: 'https://example.test',
      httpClient: MockClient((request) async {
        if (request.method == 'HEAD') {
          // Server has a newer version than the one we installed.
          return http.Response('', 200, headers: {'etag': 'etag-v2'});
        }
        if (request.method == 'GET') {
          return http.Response.bytes(
            remoteBytes,
            200,
            headers: {
              'etag': 'etag-v2',
              'content-type': 'application/vnd.discoos.ringdrill',
            },
          );
        }
        return http.Response('unexpected', 500);
      }),
    );

    var conflictCalled = false;
    final outcome = await service.refreshCatalogItem(
      programUuid,
      client,
      onConflict: (diff, {required ownedSlug, required remoteUnchanged}) async {
        conflictCalled = true;
        return CatalogConflictChoice.cancel;
      },
    );

    expect(
      conflictCalled,
      isFalse,
      reason: 'no local divergence → silent update, no dialog',
    );
    expect(outcome.kind, CatalogRefreshKind.updatedSilently);

    final refreshed = service.loadProgram(programUuid)!;
    expect(
      refreshed.actors.map((a) => a.uuid),
      contains('actor-1'),
      reason: 'local cast roster must survive a catalog refresh',
    );
    expect(refreshed.actors.single.realName, 'Kari Nordmann');
    expect(
      refreshed.rolePlays.single.actorUuid,
      'actor-1',
      reason: 'cast assignment must still resolve after refresh',
    );
  });
}
