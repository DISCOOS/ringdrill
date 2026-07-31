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

/// The Plan view's overview card (`_PlanOverview`) previews
/// `briefIntroMd`/`commsMd`/`beforeRoundMd` without going through
/// `BriefRenderer.render`, so it has its own resolution path — which is why a
/// `{{var.frekvens}}` or `{{plan.name}}` in one of those fields once showed up
/// literally here even after BriefRenderer resolved it correctly.
///
/// Collapsed it is still a plain-text teaser, measured with a `TextPainter` and
/// therefore necessarily plain. Expanded it is no longer "a stripped
/// first-paragraph extract": it renders the resolved markdown through
/// `BriefMarkdownBlock`, so tables, bold and copy chips read as they do in the
/// brief. Both states must resolve identically — that is what these tests pin.

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
    staff: const [],
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

  testWidgets('resolution holds through the expanded markdown rendering', (
    tester,
  ) async {
    // Collapsed and expanded take different paths — a plain teaser versus
    // `BriefMarkdownBlock` — so a token resolved in one could easily be literal in
    // the other. `findRichText` because the expanded state is a markdown span tree,
    // not a `Text`.
    await PlanService().replacePlan(
      _basePlan(
        briefIntroMd: 'Samband på kanal {{var.frekvens}}.\n\nAndre avsnitt.',
        variables: const [DrillVariable(name: 'frekvens', value: 'Kanal 6')],
      ),
    );

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    expect(find.textContaining('Samband på kanal Kanal 6.'), findsOneWidget);

    await tester.tap(find.text(l10n.showMore));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Samband på kanal Kanal 6.', findRichText: true),
      findsWidgets,
    );
    expect(
      find.textContaining('Andre avsnitt.', findRichText: true),
      findsWidgets,
      reason: 'expanded shows the whole field, not just its first paragraph',
    );
    expect(
      find.textContaining('{{var.frekvens}}', findRichText: true),
      findsNothing,
    );
  });
}
