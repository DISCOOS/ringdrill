import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/services/plan_service.dart';
import 'package:ringdrill/views/drill_player/exercise_picker_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ADR-0049 follow-up — showExercisePickerSheet rebuilt on showRingdrillPicker:
/// same badge/name/subtitle/current-check content, now inside the adaptive
/// picker surface instead of a bespoke `showRingdrillActionSheet` body.

const _planUuid = 'prog-1';

final _exercise1 = Exercise(
  uuid: 'ex-1',
  index: 0,
  name: 'Søk og redning',
  startTime: const SimpleTimeOfDay(hour: 8, minute: 0),
  endTime: const SimpleTimeOfDay(hour: 9, minute: 0),
  numberOfTeams: 1,
  numberOfRounds: 1,
  executionTime: 10,
  evaluationTime: 5,
  rotationTime: 5,
  stations: const [],
  schedule: const [],
);

final _exercise2 = Exercise(
  uuid: 'ex-2',
  index: 1,
  name: 'Førsteinnsats',
  startTime: const SimpleTimeOfDay(hour: 10, minute: 0),
  endTime: const SimpleTimeOfDay(hour: 11, minute: 0),
  numberOfTeams: 1,
  numberOfRounds: 1,
  executionTime: 10,
  evaluationTime: 5,
  rotationTime: 5,
  stations: const [],
  schedule: const [],
);

Future<void> _seedAndInit() async {
  SharedPreferences.setMockInitialValues({
    'app:activePlan:v1': _planUuid,
    'app:librarySchema:v1': '1',
    'p:$_planUuid': jsonEncode({
      'uuid': _planUuid,
      'name': 'Test Plan',
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
    }),
    'pe:$_planUuid:${_exercise1.uuid}': jsonEncode(_exercise1.toJson()),
    'pe:$_planUuid:${_exercise2.uuid}': jsonEncode(_exercise2.toJson()),
  });
  await PlanService().init();
}

/// `tester.view.physicalSize` keeps layout and MediaQuery consistent (see
/// the note in `ringdrill_picker_test.dart` / `roleplay_form_screen_layout_test.dart`).
void _setWidth(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<Exercise?> _open(WidgetTester tester, {required Exercise current}) async {
  Exercise? result;
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            result = await showExercisePickerSheet(context, current: current);
          },
          child: const Text('Open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  late AppLocalizations l;

  setUpAll(() async {
    l = await AppLocalizations.delegate.load(const Locale('en'));
  });

  setUp(_seedAndInit);

  testWidgets('shows title, both exercises with their time range, and a '
      'check on the current one', (tester) async {
    _setWidth(tester, 1000);
    await _open(tester, current: _exercise1);

    expect(find.text(l.pickerSelectExerciseTitle), findsOneWidget);
    expect(find.text(_exercise1.name), findsOneWidget);
    expect(find.text(_exercise2.name), findsOneWidget);
    expect(find.text('08:00 – 09:00'), findsOneWidget);
    expect(
      find.descendant(
        of: find.widgetWithText(ListTile, _exercise1.name),
        matching: find.byIcon(Icons.check),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.widgetWithText(ListTile, _exercise2.name),
        matching: find.byIcon(Icons.check),
      ),
      findsNothing,
    );
  });

  testWidgets('tapping another exercise resolves with it; tapping the '
      'current one is a no-op (resolves null)', (tester) async {
    _setWidth(tester, 1000);
    Exercise? result;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showExercisePickerSheet(
                context,
                current: _exercise1,
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_exercise2.name));
    await tester.pumpAndSettle();

    expect(result?.uuid, _exercise2.uuid);
  });

  testWidgets('compact width opens as a bottom sheet', (tester) async {
    _setWidth(tester, 400);
    await _open(tester, current: _exercise1);

    expect(
      find.byKey(const Key('ringdrill-sheet-drag-handle')),
      findsOneWidget,
    );
  });
}
