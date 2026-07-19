import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/drill_variable.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/views/widgets/exercise_scope.dart';
import 'package:ringdrill/views/widgets/plan_scope.dart';
import 'package:ringdrill/views/widgets/ringdrill_text.dart';
import 'package:ringdrill/views/widgets/station_scope.dart';

/// DESIGN-010 stage 3 — RingDrillText now delegates to resolveScopedField
/// (ADR-0048), so it resolves the full `{{station.*}}`/`{{exercise.*}}`/
/// `{{program.*}}` cascade wherever those scopes are present, not just
/// `{{var.*}}`. Uses a real MaterialApp with localizationsDelegates (unlike
/// ringdrill_text_test.dart's bare harness) so the resolveScopedField branch
/// — not the l10n-absent plain fallback — is what's under test.
Exercise _exercise() => Exercise(
  uuid: 'ex-1',
  name: 'Exercise One',
  startTime: SimpleTimeOfDay(hour: 8, minute: 0),
  endTime: SimpleTimeOfDay(hour: 9, minute: 0),
  numberOfTeams: 2,
  numberOfRounds: 2,
  executionTime: 10,
  evaluationTime: 5,
  rotationTime: 5,
  stations: const [],
  schedule: const [],
);

Future<void> _pump(WidgetTester tester, Widget home) => tester.pumpWidget(
  MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: home),
  ),
);

void main() {
  testWidgets('under a station/exercise scope, resolves {{station.name}} and '
      '{{exercise.name}}, not just {{var.*}}', (tester) async {
    await _pump(
      tester,
      PlanScope(
        variables: const [],
        child: ExerciseScope(
          exercise: _exercise(),
          variableOverrides: const {},
          child: StationScope(
            locations: const [],
            persons: const [],
            name: 'Station A',
            child: const RingDrillText.plain('{{station.name}} / {{exercise.name}}'),
          ),
        ),
      ),
    );

    expect(find.text('Station A / Exercise One'), findsOneWidget);
  });

  testWidgets(
    'with only a PlanScope ancestor, resolves {{var.*}} and {{program.name}}',
    (tester) async {
      await _pump(
        tester,
        PlanScope(
          variables: const [DrillVariable(name: 'freq', value: 'Kanal 6')],
          programName: 'Program One',
          child: const RingDrillText.plain('{{var.freq}} @ {{program.name}}'),
        ),
      );

      expect(find.text('Kanal 6 @ Program One'), findsOneWidget);
    },
  );

  testWidgets(
    'with only a PlanScope ancestor, a station-scope reference is left '
    'literal (no ExerciseScope/StationScope), the same bounded limitation '
    'ADR-0048 documents for the brief itself',
    (tester) async {
      const content = '{{station.name}}';
      await _pump(
        tester,
        PlanScope(variables: const [], child: const RingDrillText.plain(content)),
      );

      expect(find.text(content), findsOneWidget);
    },
  );

  testWidgets('with no scope ancestor at all, degrades to the raw text', (
    tester,
  ) async {
    await _pump(tester, const RingDrillText.plain('{{station.name}} {{var.freq}}'));

    expect(find.text('{{station.name}} {{var.freq}}'), findsOneWidget);
  });
}
