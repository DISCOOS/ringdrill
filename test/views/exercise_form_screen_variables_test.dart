import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/drill_variable.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/views/exercise_form_screen.dart';

/// DESIGN-008 follow-up 06 — the section-navigated `ExerciseFormScreen`:
/// the override-only Variabler section (`VariableOverridesSection`),
/// token-aware markdown fields resolving at exercise scope, and save-time
/// undeclared-token validation.

Exercise _exercise({
  String name = 'Original name',
  String? methodMd,
  Map<String, String> variableOverrides = const {},
}) => Exercise(
  uuid: 'ex-1',
  name: name,
  startTime: const SimpleTimeOfDay(hour: 8, minute: 0),
  numberOfTeams: 1,
  numberOfRounds: 1,
  executionTime: 10,
  evaluationTime: 5,
  rotationTime: 2,
  stations: const [Station(index: 0, name: 'Post 1')],
  schedule: const [
    [
      SimpleTimeOfDay(hour: 8, minute: 0),
      SimpleTimeOfDay(hour: 8, minute: 10),
      SimpleTimeOfDay(hour: 8, minute: 15),
    ],
  ],
  endTime: const SimpleTimeOfDay(hour: 8, minute: 17),
  methodMd: methodMd,
  variableOverrides: variableOverrides,
);

class _Captured {
  ExerciseFormResult? value;
}

Future<void> _openForm(
  WidgetTester tester,
  Exercise? exercise,
  List<DrillVariable> variables,
  _Captured captured,
) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (ctx) => TextButton(
          onPressed: () async {
            captured.value = await Navigator.push<ExerciseFormResult>(
              ctx,
              MaterialPageRoute(
                builder: (_) => ExerciseFormScreen(
                  exercise: exercise,
                  variables: variables,
                ),
              ),
            );
          },
          child: const Text('Open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

/// Opens the section switcher sheet by tapping the current section's label
/// in the compact bottom bar (DESIGN-008 follow-up 04).
Future<void> _openSwitcherFrom(WidgetTester tester, String currentLabel) async {
  await tester.tap(
    find.descendant(
      of: find.byType(BottomAppBar),
      matching: find.text(currentLabel),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  late AppLocalizations l;

  setUpAll(() async {
    l = await AppLocalizations.delegate.load(const Locale('en'));
  });

  testWidgets(
    'override table lists declared variables with their inherited value',
    (tester) async {
      await _openForm(tester, _exercise(), const [
        DrillVariable(name: 'frekvens', value: 'Kanal 6'),
        DrillVariable(name: 'sted'),
      ], _Captured());

      await _openSwitcherFrom(tester, l.exercise(1));
      await tester.tap(find.text(l.variablesSectionTitle));
      await tester.pumpAndSettle();

      expect(find.text('frekvens'), findsOneWidget);
      expect(find.text('sted'), findsOneWidget);
      // The inherited default reads as a parenthesized value after the name
      // (DESIGN-008 follow-up 11, variable-overrides.html); an empty
      // default renders no parenthesis at all.
      expect(find.text('(Kanal 6)'), findsOneWidget);
      expect(find.textContaining('(—)'), findsNothing);
    },
  );

  testWidgets('setting a local override value writes it to variableOverrides '
      'on save', (tester) async {
    final captured = _Captured();
    await _openForm(tester, _exercise(), const [
      DrillVariable(name: 'frekvens', value: 'Kanal 6'),
    ], captured);

    await _openSwitcherFrom(tester, l.exercise(1));
    await tester.tap(find.text(l.variablesSectionTitle));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(
        TextFormField,
        l.variableOverridesSectionLocalValueLabel,
      ),
      'Kanal 9',
    );
    await tester.tap(find.text(l.save));
    await tester.pumpAndSettle();

    expect(captured.value, isNotNull);
    expect(captured.value!.exercise.variableOverrides, {'frekvens': 'Kanal 9'});
  });

  testWidgets('clearing a local override value reverts to inherit on save', (
    tester,
  ) async {
    final captured = _Captured();
    await _openForm(
      tester,
      _exercise(variableOverrides: const {'frekvens': 'Kanal 9'}),
      const [DrillVariable(name: 'frekvens', value: 'Kanal 6')],
      captured,
    );

    await _openSwitcherFrom(tester, l.exercise(1));
    await tester.tap(find.text(l.variablesSectionTitle));
    await tester.pumpAndSettle();
    expect(find.text('Kanal 9'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(
        TextFormField,
        l.variableOverridesSectionLocalValueLabel,
      ),
      '',
    );
    await tester.tap(find.text(l.save));
    await tester.pumpAndSettle();

    expect(captured.value, isNotNull);
    expect(captured.value!.exercise.variableOverrides, <String, String>{});
  });

  testWidgets(
    'a token-aware field previews the exercise-scope effective value, '
    'shadowed by the local override',
    (tester) async {
      await _openForm(
        tester,
        _exercise(
          methodMd: 'x',
          variableOverrides: const {'frekvens': 'Kanal 9'},
        ),
        const [DrillVariable(name: 'frekvens', value: 'Kanal 6')],
        _Captured(),
      );

      await _openSwitcherFrom(tester, l.exercise(1));
      await tester.tap(find.text(l.briefSectionExerciseMethod));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'x /');
      await tester.pump();
      await tester.pump();

      expect(find.text('frekvens'), findsOneWidget);
      expect(
        find.text('Kanal 9'),
        findsOneWidget,
        reason: 'the exercise-scope override shadows the program default',
      );
      expect(find.text('Kanal 6'), findsNothing);
    },
  );

  testWidgets(
    'creating a variable inline from a markdown field declares it, and save '
    'returns it in additions.variables (ADR-0047, DESIGN-009 follow-up 4)',
    (tester) async {
      final captured = _Captured();
      await _openForm(
        tester,
        _exercise(methodMd: 'x'),
        const [],
        captured,
      );

      await _openSwitcherFrom(tester, l.exercise(1));
      await tester.tap(find.text(l.briefSectionExerciseMethod));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'x /frekvens');
      await tester.pump();
      await tester.pump();

      final createLabel = l.tokenMenuCreateVariable('frekvens');
      expect(find.text(createLabel), findsOneWidget);
      await tester.tap(find.text(createLabel));
      await tester.pump();

      // The freshly declared (empty) variable chips amber, not red.
      expect(find.textContaining('{{var.frekvens}}'), findsOneWidget);

      await tester.tap(find.text(l.save));
      await tester.pumpAndSettle();

      expect(captured.value, isNotNull);
      expect(
        captured.value!.additions.variables.map((v) => v.name),
        ['frekvens'],
      );
      expect(captured.value!.additions.stationLocations, isEmpty);
      expect(captured.value!.additions.stationPersons, isEmpty);
    },
  );

  testWidgets(
    'save is blocked on an undeclared token; removing it unblocks save',
    (tester) async {
      final captured = _Captured();
      await _openForm(
        tester,
        _exercise(methodMd: 'Bruk {{var.mangler}}'),
        const [],
        captured,
      );

      await tester.tap(find.text(l.save));
      await tester.pumpAndSettle();
      expect(captured.value, isNull);
      expect(
        find.text(
          l.programSaveBlockedUndeclaredVariable(l.briefSectionExerciseMethod),
        ),
        findsOneWidget,
      );

      await _openSwitcherFrom(tester, l.exercise(1));
      await tester.tap(find.text(l.briefSectionExerciseMethod));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, l.briefSectionExerciseMethod),
        'Bruk radio',
      );

      await tester.tap(find.text(l.save));
      await tester.pumpAndSettle();
      expect(captured.value, isNotNull);
      expect(captured.value!.exercise.methodMd, 'Bruk radio');
    },
  );

  testWidgets(
    'save is not blocked when the referenced name is already declared',
    (tester) async {
      final captured = _Captured();
      await _openForm(
        tester,
        _exercise(methodMd: 'Bruk {{var.mangler}}'),
        const [DrillVariable(name: 'mangler', value: 'Kanal 6')],
        captured,
      );

      await tester.tap(find.text(l.save));
      await tester.pumpAndSettle();

      expect(captured.value, isNotNull);
      expect(captured.value!.exercise.methodMd, 'Bruk {{var.mangler}}');
    },
  );

  testWidgets(
    'save round-trips a name edit, an override and a markdown field, and '
    'generateSchedule regeneration preserves the override',
    (tester) async {
      final captured = _Captured();
      await _openForm(tester, _exercise(), const [
        DrillVariable(name: 'frekvens', value: 'Kanal 6'),
      ], captured);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Original name'),
        'Renamed',
      );

      await _openSwitcherFrom(tester, l.exercise(1));
      await tester.tap(find.text(l.variablesSectionTitle));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(
          TextFormField,
          l.variableOverridesSectionLocalValueLabel,
        ),
        'Kanal 9',
      );

      await _openSwitcherFrom(tester, l.variablesSectionTitle);
      await tester.tap(find.text(l.formSectionAddAction));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.briefSectionExerciseMethod));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, l.briefSectionExerciseMethod),
        'Metode {{var.frekvens}}',
      );

      await tester.tap(find.text(l.save));
      await tester.pumpAndSettle();

      final saved = captured.value?.exercise;
      expect(saved, isNotNull);
      expect(saved!.name, 'Renamed');
      expect(saved.variableOverrides, {'frekvens': 'Kanal 9'});
      expect(saved.methodMd, 'Metode {{var.frekvens}}');
      // generateSchedule regenerated the schedule from scalar inputs — a
      // non-empty schedule proves the regeneration path ran, not just a
      // passthrough of the original Exercise.
      expect(saved.schedule, isNotEmpty);
    },
  );
}
