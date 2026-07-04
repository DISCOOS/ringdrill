import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/drill_variable.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/views/station_form_screen.dart';

/// DESIGN-008 follow-up 07 — the section-navigated `StationFormScreen`
/// behind `RINGDRILL_PLAN_VARIABLES`: the override table
/// (`VariableOverridesSection`) at station scope, token-aware markdown
/// fields resolving through the full program→exercise→station cascade, and
/// save-time undeclared-token validation. `RINGDRILL_PLAN_VARIABLES` is a
/// compile-time `bool.fromEnvironment`, so every flag-on test pumps
/// `StationFormScreen` with `debugPlanVariablesOverride: true` (a
/// `@visibleForTesting`-only constructor param — see `ExerciseFormScreen`'s
/// identical pattern). No explicit surface size is set: the default
/// `flutter_test` surface (800x600) already lands in the wide/medium
/// window class, so these tests exercise the master/detail rail directly
/// (tapping a section label needs no switcher-sheet step first).

Station _station({
  String name = 'Post 1',
  String? situationMd,
  Map<String, String> variableOverrides = const {},
}) => Station(
  index: 0,
  name: name,
  position: const LatLng(58.99, 10.43),
  situationMd: situationMd,
  variableOverrides: variableOverrides,
);

Exercise _exercise({Map<String, String> variableOverrides = const {}}) =>
    Exercise(
      uuid: 'ex-1',
      name: 'Exercise',
      startTime: const SimpleTimeOfDay(hour: 8, minute: 0),
      endTime: const SimpleTimeOfDay(hour: 9, minute: 0),
      numberOfTeams: 1,
      numberOfRounds: 1,
      executionTime: 10,
      evaluationTime: 5,
      rotationTime: 5,
      stations: const [],
      schedule: const [],
      variableOverrides: variableOverrides,
    );

class _Captured {
  Station? value;
}

Future<void> _openForm(
  WidgetTester tester,
  Station station,
  Exercise parentExercise,
  List<DrillVariable> variables,
  _Captured captured,
) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (ctx) => TextButton(
          onPressed: () async {
            captured.value = await Navigator.push<Station>(
              ctx,
              MaterialPageRoute(
                builder: (_) => StationFormScreen(
                  station: station,
                  parentExercise: parentExercise,
                  variables: variables,
                  debugPlanVariablesOverride: true,
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

void main() {
  late AppLocalizations l;

  setUpAll(() async {
    l = await AppLocalizations.delegate.load(const Locale('en'));
  });

  testWidgets(
    'flag-off: the legacy single-scroll OptionalFieldSections form renders',
    (tester) async {
      final captured = _Captured();
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (ctx) => TextButton(
              onPressed: () async {
                captured.value = await Navigator.push<Station>(
                  ctx,
                  MaterialPageRoute(
                    builder: (_) => StationFormScreen(station: _station()),
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

      expect(
        find.widgetWithText(OutlinedButton, l.briefSectionStationSituation),
        findsOneWidget,
      );
      expect(find.text(l.variablesSectionTitle), findsNothing);
      expect(captured.value, isNull);
    },
  );

  testWidgets('the override table shows the inherited value at station scope '
      '(program overlaid by the enclosing exercise)', (tester) async {
    await _openForm(
      tester,
      _station(),
      _exercise(variableOverrides: const {'frekvens': 'Kanal 8'}),
      const [DrillVariable(name: 'frekvens', value: 'Kanal 6')],
      _Captured(),
    );

    await tester.tap(find.text(l.variablesSectionTitle));
    await tester.pumpAndSettle();

    expect(
      find.text(l.variableOverridesSectionInheritedValueLabel('Kanal 8')),
      findsOneWidget,
      reason:
          'inherited at station scope means program overlaid by the '
          'enclosing exercise, not the bare program default',
    );
  });

  testWidgets(
    'a local override value writes to station.variableOverrides on save',
    (tester) async {
      final captured = _Captured();
      await _openForm(tester, _station(), _exercise(), const [
        DrillVariable(name: 'frekvens', value: 'Kanal 6'),
      ], captured);

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
      expect(captured.value!.variableOverrides, {'frekvens': 'Kanal 9'});
    },
  );

  testWidgets('a token-aware station field resolves the full cascade: station '
      'override shadows exercise override shadows program default', (
    tester,
  ) async {
    await _openForm(
      tester,
      _station(
        situationMd: 'x',
        variableOverrides: const {'frekvens': 'Kanal 9'},
      ),
      _exercise(variableOverrides: const {'frekvens': 'Kanal 8'}),
      const [DrillVariable(name: 'frekvens', value: 'Kanal 6')],
      _Captured(),
    );

    await tester.tap(find.text(l.briefSectionStationSituation));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'x /');
    await tester.pump();
    await tester.pump();

    expect(find.text('frekvens'), findsOneWidget);
    expect(find.text('Kanal 9'), findsOneWidget);
    expect(find.text('Kanal 8'), findsNothing);
    expect(find.text('Kanal 6'), findsNothing);
  });

  testWidgets(
    'save is blocked on an undeclared token; removing it unblocks save',
    (tester) async {
      final captured = _Captured();
      await _openForm(
        tester,
        _station(situationMd: 'Bruk {{var.mangler}}'),
        _exercise(),
        const [],
        captured,
      );

      await tester.tap(find.text(l.save));
      await tester.pumpAndSettle();
      expect(captured.value, isNull);
      expect(
        find.text(
          l.programSaveBlockedUndeclaredVariable(
            l.briefSectionStationSituation,
          ),
        ),
        findsOneWidget,
      );

      await tester.tap(find.text(l.briefSectionStationSituation));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, l.briefSectionStationSituation),
        'Bruk radio',
      );

      await tester.tap(find.text(l.save));
      await tester.pumpAndSettle();
      expect(captured.value, isNotNull);
      expect(captured.value!.situationMd, 'Bruk radio');
    },
  );
}
