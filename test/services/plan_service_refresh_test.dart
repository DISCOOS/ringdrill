import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ringdrill/data/drill_client.dart';
import 'package:ringdrill/data/drill_file.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/plan.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/plan_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Regression test for the bug where local-only edits to a catalog-sourced
/// plan were silently ignored on "update from catalog": the HEAD short-circuit
/// returned upToDate without ever consulting the local contentHash, so users
/// got no conflict dialog and no way to revert.
///
/// The fix in [PlanService.refreshCatalogItem] computes `hasLocalChanges`
/// before the 304 short-circuit, downloads the unchanged remote copy, and
/// passes the divergence through the conflict callback with
/// `remoteUnchanged: true`.
void main() {
  const slug = 'sample-plan';
  const installedEtag = 'etag-v1';

  Plan buildBaselinePlan(String planUuid) {
    final now = DateTime.utc(2026, 5, 28);
    final exercise = Exercise(
      uuid: 'exercise-1',
      name: 'Run',
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
    final baseline = Plan(
      uuid: planUuid,
      name: 'Sample Plan',
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
      rolePlays: const [],
      actors: const [],
    );
    return baseline.copyWith(contentHash: baseline.computeContentHash());
  }

  DrillClient buildMockClient(Plan remote) {
    final remoteBytes = DrillFile.fromPlan(remote, '$slug.drill').content;
    return DrillClient(
      baseUrl: 'https://example.test',
      httpClient: MockClient((request) async {
        if (request.method == 'HEAD') {
          // Server says: nothing has changed since you installed.
          return http.Response('', 304, headers: {'etag': installedEtag});
        }
        if (request.method == 'GET') {
          return http.Response.bytes(
            remoteBytes,
            200,
            headers: {
              'etag': installedEtag,
              'content-type': 'application/vnd.discoos.ringdrill',
            },
          );
        }
        return http.Response('unexpected', 500);
      }),
    );
  }

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await PlanService().init();
  });

  tearDown(() async {
    await PlanService().clearAllForTest();
  });

  test(
    'local-only edit triggers conflict callback with remoteUnchanged=true',
    () async {
      final service = PlanService();
      final baseline = buildBaselinePlan('plan-edit');

      // Pretend the user installed the plan from the catalog: baseline
      // contentHash matches what is on disk.
      await service.replacePlan(baseline);

      // Locally edit the exercise start time. replacePlan does NOT recompute
      // contentHash — that is precisely what marks the plan as having
      // unpublished edits.
      final editedExercise = baseline.exercises.single.copyWith(
        startTime: const SimpleTimeOfDay(hour: 9, minute: 30),
      );
      final edited = baseline.copyWith(exercises: [editedExercise]);
      await service.replacePlan(edited);

      // Sanity check: contentHash now diverges from the live content.
      final stored = service.loadPlan(baseline.uuid)!;
      expect(stored.contentHash, isNotNull);
      expect(stored.computeContentHash(), isNot(stored.contentHash));

      // The remote bytes mirror the originally installed plan (unchanged).
      final client = buildMockClient(baseline);

      bool conflictCallbackInvoked = false;
      bool seenRemoteUnchanged = false;
      PlanDiff? seenDiff;

      final outcome = await service.refreshCatalogItem(
        baseline.uuid,
        client,
        onConflict:
            (
              diff, {
              required ownedSlug,
              required remoteUnchanged,
              required localVersion,
              required catalogVersion,
            }) async {
              conflictCallbackInvoked = true;
              seenRemoteUnchanged = remoteUnchanged;
              seenDiff = diff;
              // Choose revert (overwriteLocal). This used to be silently
              // skipped because the dialog never opened in this branch.
              return CatalogConflictChoice.overwriteLocal;
            },
      );

      expect(
        conflictCallbackInvoked,
        isTrue,
        reason: 'Conflict dialog must open even when remote returns 304',
      );
      expect(
        seenRemoteUnchanged,
        isTrue,
        reason:
            'Service must signal remoteUnchanged so UI can pick the '
            'right wording (Revert vs. Update).',
      );
      expect(seenDiff, isNotNull);
      // Local edit showed up as a modified exercise in the diff.
      expect(seenDiff!.modifiedExercises.map((i) => i.name), contains('Run'));

      expect(outcome.kind, CatalogRefreshKind.updatedAfterPrompt);
      expect(outcome.remoteUnchanged, isTrue);

      // After overwriteLocal the local copy is back to baseline start time.
      final restored = service.loadPlan(baseline.uuid)!;
      expect(restored.exercises.single.startTime.hour, 8);
      expect(restored.exercises.single.startTime.minute, 0);
      // contentHash is re-synced to remote content, so a subsequent refresh
      // would short-circuit cleanly.
      expect(restored.contentHash, restored.computeContentHash());
    },
  );

  test('unchanged remote + clean local short-circuits to upToDate', () async {
    final service = PlanService();
    final baseline = buildBaselinePlan('plan-clean');
    await service.replacePlan(baseline);

    final client = buildMockClient(baseline);

    var conflictCalled = false;
    final outcome = await service.refreshCatalogItem(
      baseline.uuid,
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

    expect(conflictCalled, isFalse);
    expect(outcome.kind, CatalogRefreshKind.upToDate);
  });

  // Regression test: a plan whose catalog slug has been removed server-side
  // used to make refreshCatalogItem call download() anyway, which throws an
  // uncaught 404 DrillApiException. Every UI call site's generic catch-all
  // then showed "catalog service unavailable" — misleading, since the
  // service itself is fine and retrying can never help. HEAD's `exists`
  // flag is now checked before download() is ever called.
  test(
    'a 404 on HEAD (slug removed from the catalog) reports removedFromCatalog '
    'instead of throwing',
    () async {
      final service = PlanService();
      final baseline = buildBaselinePlan('plan-removed');
      await service.replacePlan(baseline);

      final client = DrillClient(
        baseUrl: 'https://example.test',
        httpClient: MockClient((request) async {
          return http.Response('', 404);
        }),
      );

      var conflictCalled = false;
      final outcome = await service.refreshCatalogItem(
        baseline.uuid,
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

      expect(conflictCalled, isFalse);
      expect(outcome.kind, CatalogRefreshKind.removedFromCatalog);
    },
  );
}
