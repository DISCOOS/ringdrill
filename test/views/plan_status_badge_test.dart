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
      actors: const [],
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
}
