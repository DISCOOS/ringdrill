import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/drill_variable.dart';
import 'package:ringdrill/models/plan.dart';
import 'package:ringdrill/services/plan_service.dart';
import 'package:ringdrill/views/plan_view.dart';
import 'package:ringdrill/views/roleplay_list_view.dart';
import 'package:ringdrill/views/station_list_view.dart';
import 'package:ringdrill/views/teams_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The Plan view's collapsed overview card (`_PlanOverview`) is an
/// independent, ad-hoc preview of `briefIntroMd`/`commsMd`/`beforeRoundMd`
/// (a stripped first-paragraph extract) that does not go through
/// `BriefRenderer.render` — it bypasses the DESIGN-008 variable/cross-
/// reference resolution pipeline entirely, so a `{{var.frekvens}}` or
/// `{{plan.name}}` token used in one of those fields showed up literally
/// in this preview even after BriefRenderer itself resolved it correctly.

class _TestPlanController extends PlanPageControllerBase {
  _TestPlanController({
    required super.stationListController,
    required super.rolePlaysController,
    required super.teamsPageController,
  });
}

const _planUuid = 'overview-plan';

Plan _basePlan({
  String? briefIntroMd,
  List<DrillVariable> variables = const [],
}) {
  final now = DateTime.utc(2026, 1, 1);
  return Plan(
    uuid: _planUuid,
    name: 'Vinterøvelse Nordland',
    description: '',
    metadata: PlanMetadata(created: now, updated: now, version: '1.1'),
    teams: const [],
    sessions: const [],
    exercises: const [],
    rolePlays: const [],
    actors: const [],
    variables: variables,
    briefIntroMd: briefIntroMd,
  );
}

Widget _harness() {
  final stationList = StationListController();
  final rolePlays = RolePlaysController();
  final controller = _TestPlanController(
    stationListController: stationList,
    rolePlaysController: rolePlays,
    teamsPageController: const TeamsPageController(),
  );
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: PlanView(
        controller: controller,
        stationListController: stationList,
        rolePlaysController: rolePlays,
      ),
    ),
  );
}

void main() {
  // PlanService.init() is guarded by an internal "already ready" flag —
  // only the first call in this isolate actually loads from
  // SharedPreferences, so later scenarios go through replacePlan
  // instead of re-seeding prefs + calling init() again.
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({
      'app:activePlan:v1': _planUuid,
      'app:librarySchema:v1': '1',
    });
    await PlanService().init();
    await PlanService().replacePlan(_basePlan());
  });

  testWidgets('resolves a declared variable in the overview card preview', (
    tester,
  ) async {
    await PlanService().replacePlan(
      _basePlan(
        briefIntroMd: 'Samband på kanal {{var.frekvens}}.',
        variables: const [DrillVariable(name: 'frekvens', value: 'Kanal 6')],
      ),
    );

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    expect(find.textContaining('Samband på kanal Kanal 6.'), findsOneWidget);
    expect(find.textContaining('{{var.frekvens}}'), findsNothing);
  });

  testWidgets('resolves {{plan.name}} in the overview card preview', (
    tester,
  ) async {
    await PlanService().replacePlan(
      _basePlan(briefIntroMd: 'Velkommen til {{plan.name}}.'),
    );

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Velkommen til Vinterøvelse Nordland.'),
      findsOneWidget,
    );
    expect(find.textContaining('{{plan.name}}'), findsNothing);
  });

  testWidgets(
    'an undeclared variable still shows the localized placeholder, not the raw token',
    (tester) async {
      await PlanService().replacePlan(
        _basePlan(briefIntroMd: 'Kanal {{var.mangler}}.'),
      );

      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(
        find.textContaining(l10n.briefUnknownVariable('mangler')),
        findsOneWidget,
      );
      expect(find.textContaining('{{var.mangler}}'), findsNothing);
    },
  );
}
