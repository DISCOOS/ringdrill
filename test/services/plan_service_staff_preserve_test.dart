import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ringdrill/data/drill_client.dart';
import 'package:ringdrill/data/drill_file.dart';
import 'package:ringdrill/models/staff.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/plan.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/plan_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Regression test for the bug where a catalog refresh silently destroyed the
/// local cast roster. Actors are local PII and stripped from the catalog
/// archive server-side (ADR-0018), so the downloaded remote always has an
/// empty actor list. `_overwriteCatalogPlan` used to save that empty list
/// over the local copy, wiping the user's actors and breaking every
/// role↔actor assignment — the "marker list had a name yesterday, it's empty
/// today" report.
///
/// The fix merges locally-stored actors back in when overwriting from the
/// catalog (and on reinstall via [PlanService.installFromFile]).
void main() {
  const slug = 'cast-plan';
  const installedEtag = 'etag-v1';

  Plan buildPlan(
    String planUuid, {
    required List<Staff> staff,
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
    final base = Plan(
      uuid: planUuid,
      name: 'Cast Plan',
      description: '',
      metadata: PlanMetadata(created: now, updated: now, version: '1.0'),
      source: PlanSource.catalog(
        slug: slug,
        latestEtag: installedEtag,
        installedAt: now,
      ),
      teams: const [],
      sessions: const [],
      exercises: [exercise],
      rolePlays: rolePlays,
      staff: staff,
    );
    return base.copyWith(contentHash: base.computeContentHash());
  }

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await PlanService().init();
  });

  tearDown(() async {
    await PlanService().clearAllForTest();
  });

  test('silent catalog refresh preserves locally-stored actors', () async {
    final service = PlanService();
    const planUuid = 'plan-cast';
    const actor = Staff(
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
      staffUuid: 'actor-1',
    );

    final local = buildPlan(
      planUuid,
      staff: const [actor],
      rolePlays: const [rolePlay],
    );
    await service.replacePlan(local);

    // Sanity: the actor and its cast assignment are stored locally, and the
    // local copy has no divergence from the installed snapshot (so the
    // refresh takes the silent path, not the conflict dialog).
    final stored = service.loadPlan(planUuid)!;
    expect(stored.staff.map((a) => a.uuid), contains('actor-1'));
    expect(stored.rolePlays.single.staffUuid, 'actor-1');
    expect(stored.computeContentHash(), stored.contentHash);

    // Remote mirrors the same plan but with actors stripped server-side. The
    // roleplay still references actor-1.
    final remote = buildPlan(
      planUuid,
      staff: const [],
      rolePlays: const [rolePlay],
    );
    final remoteBytes = DrillFile.fromPlan(remote, '$slug.drill').content;

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
      planUuid,
      client,
      onConflict:
          (
            diff, {
            required ownedSlug,
            required remoteUnchanged,
            required localVersion,
            required catalogVersion,
          }) async {
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

    final refreshed = service.loadPlan(planUuid)!;
    expect(
      refreshed.staff.map((a) => a.uuid),
      contains('actor-1'),
      reason: 'local cast roster must survive a catalog refresh',
    );
    expect(refreshed.staff.single.realName, 'Kari Nordmann');
    expect(
      refreshed.rolePlays.single.staffUuid,
      'actor-1',
      reason: 'cast assignment must still resolve after refresh',
    );
  });
}
