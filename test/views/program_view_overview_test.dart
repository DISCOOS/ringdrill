import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/drill_variable.dart';
import 'package:ringdrill/models/program.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/views/program_view.dart';
import 'package:ringdrill/views/roleplay_list_view.dart';
import 'package:ringdrill/views/station_list_view.dart';
import 'package:ringdrill/views/teams_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The Program view's collapsed overview card (`_ProgramOverview`) is an
/// independent, ad-hoc preview of `briefIntroMd`/`commsMd`/`beforeRoundMd`
/// (a stripped first-paragraph extract) that does not go through
/// `BriefRenderer.render` — it bypasses the DESIGN-008 variable/cross-
/// reference resolution pipeline entirely, so a `{{var.frekvens}}` or
/// `{{program.name}}` token used in one of those fields showed up literally
/// in this preview even after BriefRenderer itself resolved it correctly.

class _TestProgramController extends ProgramPageControllerBase {
  _TestProgramController({
    required super.stationListController,
    required super.rolePlaysController,
    required super.teamsPageController,
  });
}

const _programUuid = 'overview-program';

Program _baseProgram({
  String? briefIntroMd,
  List<DrillVariable> variables = const [],
}) {
  final now = DateTime.utc(2026, 1, 1);
  return Program(
    uuid: _programUuid,
    name: 'Vinterøvelse Nordland',
    description: '',
    metadata: ProgramMetadata(created: now, updated: now, version: '1.1'),
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
  final controller = _TestProgramController(
    stationListController: stationList,
    rolePlaysController: rolePlays,
    teamsPageController: const TeamsPageController(),
  );
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: ProgramView(
        controller: controller,
        stationListController: stationList,
        rolePlaysController: rolePlays,
      ),
    ),
  );
}

void main() {
  // ProgramService.init() is guarded by an internal "already ready" flag —
  // only the first call in this isolate actually loads from
  // SharedPreferences, so later scenarios go through replaceProgram
  // instead of re-seeding prefs + calling init() again.
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({
      'app:activeProgram:v1': _programUuid,
      'app:librarySchema:v1': '1',
    });
    await ProgramService().init();
    await ProgramService().replaceProgram(_baseProgram());
  });

  testWidgets('resolves a declared variable in the overview card preview', (
    tester,
  ) async {
    await ProgramService().replaceProgram(
      _baseProgram(
        briefIntroMd: 'Samband på kanal {{var.frekvens}}.',
        variables: const [DrillVariable(name: 'frekvens', value: 'Kanal 6')],
      ),
    );

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    expect(find.textContaining('Samband på kanal Kanal 6.'), findsOneWidget);
    expect(find.textContaining('{{var.frekvens}}'), findsNothing);
  });

  testWidgets('resolves {{program.name}} in the overview card preview', (
    tester,
  ) async {
    await ProgramService().replaceProgram(
      _baseProgram(briefIntroMd: 'Velkommen til {{program.name}}.'),
    );

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Velkommen til Vinterøvelse Nordland.'),
      findsOneWidget,
    );
    expect(find.textContaining('{{program.name}}'), findsNothing);
  });

  testWidgets(
    'an undeclared variable still shows the localized placeholder, not the raw token',
    (tester) async {
      await ProgramService().replaceProgram(
        _baseProgram(briefIntroMd: 'Kanal {{var.mangler}}.'),
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
