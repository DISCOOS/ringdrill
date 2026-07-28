import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/data/plan_repository.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/location.dart';
import 'package:ringdrill/models/plan.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/app_user_role.dart';
import 'package:ringdrill/services/plan_service.dart';
import 'package:ringdrill/utils/app_config.dart';
import 'package:ringdrill/utils/prefs.dart';
import 'package:ringdrill/views/map_view.dart';
import 'package:ringdrill/views/station_screen.dart';
import 'package:ringdrill/views/widgets/station_scenario_map.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// DESIGN-010 stage 3b commit 4 — the Post viewer's Postbeskrivelse rollup
/// card (resolved lead + labeled sections, role-gated director note) and
/// map card (scenario markers), driven by the settings role rather than an
/// in-view toggle.
///
/// Station.*Md fields are excluded from JSON (ADR-0022) — persisting them
/// so `PlanService.init()` picks them up (like the real app) needs
/// `PlanRepository.saveExercise`'s sidecar-key path, not a bare
/// SharedPreferences JSON blob (mirrors
/// test/data/plan_repository_brief_fields_test.dart's own setup).
const _planUuid = 'prog-post-rollup';
const _exerciseUuid = 'ex-post-rollup';

Plan _shell() {
  final now = DateTime.utc(2026, 1, 1);
  return Plan(
    uuid: _planUuid,
    name: 'Test Plan',
    description: '',
    metadata: PlanMetadata(created: now, updated: now, version: '1.0'),
    teams: const [],
    sessions: const [],
    exercises: const [],
  );
}

Exercise _exercise() => Exercise(
  uuid: _exerciseUuid,
  index: 0,
  name: 'Test Exercise',
  startTime: const SimpleTimeOfDay(hour: 8, minute: 0),
  numberOfTeams: 1,
  numberOfRounds: 1,
  executionTime: 10,
  evaluationTime: 5,
  rotationTime: 2,
  stations: [
    Station(
      index: 0,
      name: 'Post 1',
      description: 'Ingress for post 1.',
      situationMd: 'Situasjonsbeskrivelse.',
      directorNotesMd: 'Hemmelig notat til leder.',
      position: const LatLng(59.91, 10.75),
      locations: const [
        Location(
          slug: 'lkp',
          label: 'LKP',
          kind: LocationKind.lkp,
          position: LatLng(59.92, 10.76),
        ),
      ],
    ),
  ],
  schedule: const [
    [
      SimpleTimeOfDay(hour: 8, minute: 0),
      SimpleTimeOfDay(hour: 8, minute: 10),
      SimpleTimeOfDay(hour: 8, minute: 15),
    ],
  ],
  endTime: const SimpleTimeOfDay(hour: 8, minute: 17),
);

Future<void> _seedAndInit({String? role}) async {
  SharedPreferences.setMockInitialValues({AppConfig.keyAppUserRole: ?role});
  final prefs = await SharedPreferences.getInstance();
  // The role is read synchronously now (see Prefs), so a test that seeds one has
  // to bind the instance — unbound reads mean "nothing stored", which would leave
  // the director default in force and quietly pass the director-only assertion.
  Prefs.reset();
  Prefs.bind(prefs);
  addTearDown(Prefs.reset);
  // The notifier leads once seeded, so seeding it is what makes the stored role
  // actually take effect — binding alone is not enough.
  seedAppUserRoleFromStore();
  final repo = PlanRepository(prefs);
  await repo.savePlanShell(_shell());
  await repo.setActivePlanUuid(_planUuid);
  await repo.saveExercise(_exercise());
  await PlanService().init();
}

Widget _buildScreen() {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) =>
            const StationScreen(stationIndex: 0, uuid: _exerciseUuid),
      ),
    ],
  );
  return MaterialApp.router(
    routerConfig: router,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
  );
}

void main() {
  testWidgets('the rollup renders the resolved lead and its labeled sections', (
    tester,
  ) async {
    await _seedAndInit(role: 'director');
    await tester.pumpWidget(_buildScreen());
    await tester.pumpAndSettle();

    expect(
      find.text('Ingress for post 1.', findRichText: true),
      findsOneWidget,
    );
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    // SectionHeader renders every section label uppercased.
    expect(
      find.text(l10n.briefSectionStationSituation.toUpperCase()),
      findsOneWidget,
    );
    expect(
      find.text('Situasjonsbeskrivelse.', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets(
    'the director-only section is hidden for a non-director settings role',
    (tester) async {
      await _seedAndInit(role: 'instructor');
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.briefSectionStationDirectorNotes), findsNothing);
      expect(
        find.text('Hemmelig notat til leder.', findRichText: true),
        findsNothing,
      );
    },
  );

  testWidgets(
    'the director-only section is shown for the director settings role',
    (tester) async {
      await _seedAndInit(role: 'director');
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      // SectionHeader renders every section label uppercased.
      expect(
        find.text(l10n.briefSectionStationDirectorNotes.toUpperCase()),
        findsOneWidget,
      );
      expect(
        find.text('Hemmelig notat til leder.', findRichText: true),
        findsOneWidget,
      );
      expect(find.text(l10n.directorOnlyBadge), findsOneWidget);
    },
  );

  testWidgets(
    'the map card receives the station\'s scenario markers and legend',
    (tester) async {
      await _seedAndInit(role: 'director');
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      // Default test window (~800px) is medium: the map now lives behind the
      // "Map" segment of the Info/Map selector, so select it before reading
      // the map card.
      await tester.tap(find.byIcon(Icons.map));
      await tester.pumpAndSettle();

      // `find.byType(MapView)` implicitly means `MapView<dynamic>`, which
      // does not `==` the actual `MapView<int>` instance's runtime type
      // (generics make exact Type equality too strict here) — a predicate
      // `is` check handles the covariance correctly.
      final mapView =
          tester.widgetList(find.byWidgetPredicate((w) => w is MapView)).first
              as MapView;
      // Station's own position (id 0) + the one scenario location (id 1).
      expect(mapView.markers, hasLength(2));
      expect(find.byType(StationScenarioLegend), findsOneWidget);
    },
  );
}
