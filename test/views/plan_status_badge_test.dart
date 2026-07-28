import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/plan.dart';
import 'package:ringdrill/services/catalog_status_service.dart';
import 'package:ringdrill/services/plan_service.dart';
import 'package:ringdrill/views/plan_status_badge.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Step 2 (B): the AppBar badge surfaces an "Unpublished" state for a
/// catalog plan whose local edits diverge from the published snapshot, and
/// offers a one-tap publish. Divergence is detected by comparing the stored
/// `contentHash` (set at install/publish) against a freshly computed hash —
/// the same signal `refreshCatalogItem` uses.
///
/// The catalog status is pre-set to `online` so the badge's first-show probe
/// short-circuits and the test never touches the network.
void main() {
  Plan buildCatalogPlan(String uuid) {
    final now = DateTime.utc(2026, 6, 2);
    final base = Plan(
      uuid: uuid,
      name: 'Plan',
      description: '',
      metadata: PlanMetadata(created: now, updated: now, version: '1.0'),
      source: PlanSource.catalog(
        slug: 'plan-slug',
        latestEtag: 'etag-1',
        installedAt: now,
      ),
      teams: const [],
      sessions: const [],
      exercises: const [],
      rolePlays: const [],
      staff: const [],
    );
    return base.copyWith(contentHash: base.computeContentHash());
  }

  Widget harness() => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: const Scaffold(body: PlanStatusBadge()),
  );

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await PlanService().init();
  });

  setUp(() {
    // Suppress the badge's first-show catalog probe (no network in tests).
    CatalogStatusService().setStatus(CatalogServiceState.online);
  });

  tearDown(() async {
    await PlanService().clearAllForTest();
  });

  testWidgets('shows the unpublished badge when a catalog plan diverges', (
    tester,
  ) async {
    final service = PlanService();
    final base = buildCatalogPlan('prog-unpub');
    await service.replacePlan(base);
    // A local edit. replacePlan does not recompute contentHash, so the
    // stored hash now lags the live content — i.e. unpublished changes.
    await service.replacePlan(base.copyWith(name: 'Edited name'));
    await service.setActive('prog-unpub');

    await tester.pumpWidget(harness());
    await tester.pump();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.planStatusUnpublished), findsOneWidget);
    expect(find.byIcon(Icons.cloud_upload_outlined), findsOneWidget);
  });

  testWidgets('hides the unpublished badge when a catalog plan is in sync', (
    tester,
  ) async {
    final service = PlanService();
    final base = buildCatalogPlan('prog-sync');
    await service.replacePlan(base);
    await service.setActive('prog-sync');

    await tester.pumpWidget(harness());
    await tester.pump();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.planStatusUnpublished), findsNothing);
  });

  // Publishing uploads the whole plan, so on a slow connection the tap looked like
  // it did nothing until the result snackbar arrived. The outcome was never silent
  // — _runUpload reports success, 409/412 and a catch-all failure — but with no
  // in-flight feedback there is nothing to tell "working" from "the tap missed",
  // and the natural response to that is to tap again.
  //
  // Driven through the publish seam: the spinner exists only *during* the await,
  // and the real path resolves in microtasks under the stubbed HttpClient, so the
  // in-flight frame never renders. The Completer holds it open deliberately.
  group('while publishing', () {
    Future<void> seedDivergedPlan(String uuid) async {
      final service = PlanService();
      final base = buildCatalogPlan(uuid);
      await service.replacePlan(base);
      await service.replacePlan(base.copyWith(name: 'Edited name'));
      await service.setActive(uuid);
    }

    testWidgets('the badge spins and says so, then stops', (tester) async {
      await seedDivergedPlan('prog-publishing');
      final gate = Completer<void>();

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: PlanStatusBadge(publishOverride: (_) => gate.future),
          ),
        ),
      );
      await tester.pump();
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      expect(find.byType(CircularProgressIndicator), findsNothing);

      await tester.tap(find.text(l10n.planStatusUnpublished));
      await tester.pump();

      expect(
        find.byType(CircularProgressIndicator),
        findsOneWidget,
        reason: 'the tap must show it is working, not look ignored',
      );
      expect(find.text(l10n.planStatusPublishing), findsOneWidget);
      expect(
        find.byIcon(Icons.cloud_upload_outlined),
        findsNothing,
        reason: 'the spinner replaces the icon so the badge keeps its width',
      );

      gate.complete();
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    // A failed upload must clear the spinner too. The publish helper reports its
    // own failure; the badge's job is only to stop looking busy.
    testWidgets('a failure clears the spinner', (tester) async {
      await seedDivergedPlan('prog-publish-fail');
      final gate = Completer<void>();

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: PlanStatusBadge(publishOverride: (_) => gate.future),
          ),
        ),
      );
      await tester.pump();
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      await tester.tap(find.text(l10n.planStatusUnpublished));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      gate.completeError(Exception('upload failed'));
      await tester.pumpAndSettle();

      expect(
        find.byType(CircularProgressIndicator),
        findsNothing,
        reason: 'a throw must not leave the badge spinning forever',
      );
      // The error itself is deliberately not swallowed here: `_onPublishTap` uses
      // try/finally, not try/catch, so an unexpected throw still reaches the zone
      // handler and Sentry. Reaching this line proves the badge recovered; the
      // error's own fate is the publish helper's business.
    });

    // Tapping twice would race two uploads of the same plan, the second able to
    // land a 412 against the etag the first is about to move.
    testWidgets('a second tap while in flight is ignored', (tester) async {
      await seedDivergedPlan('prog-publish-twice');
      final gate = Completer<void>();
      var calls = 0;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: PlanStatusBadge(
              publishOverride: (_) {
                calls++;
                return gate.future;
              },
            ),
          ),
        ),
      );
      await tester.pump();
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      await tester.tap(find.text(l10n.planStatusUnpublished));
      await tester.pump();
      await tester.tap(find.text(l10n.planStatusPublishing));
      await tester.pump();

      expect(calls, 1);

      gate.complete();
      await tester.pumpAndSettle();
    });
  });
}
