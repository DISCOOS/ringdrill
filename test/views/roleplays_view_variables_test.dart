import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/drill_variable.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/views/roleplays_view.dart';
import 'package:ringdrill/views/widgets/plan_scope.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// DESIGN-008 follow-up 09 — variable resolution on the live-UI RolePlaysView
/// list: the role name (`RingDrillText`, needs an ambient `PlanScope`) and
/// the exercise/station subtitle (a direct `substitutePlanVariables` call,
/// resolved from `ProgramService().activeProgram` regardless of any
/// `PlanScope` ancestor).

const _programUuid = 'prog-rv-vars';
const _exerciseUuid = 'ex-rv-vars';
const _roleUuid = 'role-rv-vars';

final _declaredVariables = const [
  DrillVariable(name: 'frekvens', value: 'Kanal 6'),
];

Exercise _exercise() => Exercise(
  uuid: _exerciseUuid,
  name: 'Øvelse {{var.frekvens}}',
  startTime: const SimpleTimeOfDay(hour: 8, minute: 0),
  numberOfTeams: 1,
  numberOfRounds: 1,
  executionTime: 10,
  evaluationTime: 5,
  rotationTime: 2,
  stations: const [],
  schedule: const [
    [
      SimpleTimeOfDay(hour: 8, minute: 0),
      SimpleTimeOfDay(hour: 8, minute: 10),
      SimpleTimeOfDay(hour: 8, minute: 15),
    ],
  ],
  endTime: const SimpleTimeOfDay(hour: 8, minute: 17),
  // Station-less, unassigned role: the exercise-scope override is the
  // whole story for both the role name and the subtitle.
  variableOverrides: const {'frekvens': 'Kanal 8'},
);

RolePlay _role() => RolePlay(
  uuid: _roleUuid,
  index: 0,
  exerciseUuid: _exerciseUuid,
  name: 'Recon {{var.frekvens}}',
);

Map<String, Object> _buildPrefs() {
  final ex = _exercise();
  return {
    'app:activeProgram:v1': _programUuid,
    'app:librarySchema:v1': '1',
    'p:$_programUuid': jsonEncode({
      'uuid': _programUuid,
      'name': 'Test Program',
      'description': '',
      'metadata': {
        'created': '2024-01-01T00:00:00.000Z',
        'updated': '2024-01-01T00:00:00.000Z',
        'version': '1.1',
      },
      'exercises': [],
      'teams': [],
      'sessions': [],
      'rolePlays': [],
      'actors': [],
      'variables': _declaredVariables.map((v) => v.toJson()).toList(),
    }),
    'pe:$_programUuid:$_exerciseUuid': jsonEncode(ex.toJson()),
    'pr:$_programUuid:$_roleUuid': jsonEncode(_role().toJson()),
  };
}

Widget _buildView({required bool withPlanScope}) {
  final controller = RolePlaysController();
  final body = CustomScrollView(
    slivers: [RolePlaysView(controller: controller)],
  );
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: withPlanScope
          ? PlanScope(variables: _declaredVariables, child: body)
          : body,
    ),
  );
}

void main() {
  late AppLocalizations l;

  setUpAll(() async {
    l = await AppLocalizations.delegate.load(const Locale('en'));
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues(_buildPrefs());
    await ProgramService().init();
  });

  testWidgets(
    'a role name inside a PlanScope resolves; outside one it stays raw, no throw',
    (tester) async {
      await tester.pumpWidget(_buildView(withPlanScope: true));
      await tester.pumpAndSettle();

      // The role's own exercise override (Kanal 8) shadows the program
      // declared default (Kanal 6).
      expect(find.text('Recon Kanal 8'), findsOneWidget);
      expect(find.textContaining('{{var.frekvens}}'), findsNothing);
    },
  );

  testWidgets('outside a PlanScope ancestor the role name renders raw text', (
    tester,
  ) async {
    await tester.pumpWidget(_buildView(withPlanScope: false));
    await tester.pumpAndSettle();

    expect(find.text('Recon {{var.frekvens}}'), findsOneWidget);
    // No FlutterError surfaced by the test framework — pumpAndSettle
    // above would have rethrown one had RingDrillText thrown on the
    // missing PlanScope.
  });

  testWidgets(
    'the subtitle resolves the exercise name with its exercise-scope override',
    (tester) async {
      await tester.pumpWidget(_buildView(withPlanScope: false));
      await tester.pumpAndSettle();

      expect(
        find.text(l.roleSubtitleExercise('Øvelse Kanal 8')),
        findsOneWidget,
      );
      expect(
        find.text(l.roleSubtitleExercise('Øvelse Kanal 6')),
        findsNothing,
      );
    },
  );
}
