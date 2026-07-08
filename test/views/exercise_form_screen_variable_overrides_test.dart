import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/views/exercise_form_screen.dart';

/// DESIGN-008 Stage 1: ExerciseFormScreen rebuilds the Exercise via
/// ProgramService.generateSchedule on save, which does not itself know
/// about variableOverrides — the screen must pass the existing exercise's
/// overrides through explicitly (see exercise_form_screen.dart's call to
/// generateSchedule). This is the widget-level counterpart to the
/// generateSchedule-level coverage in test/models/program_variables_test.dart.
Exercise _exerciseWithOverrides() => Exercise(
  uuid: 'ex-vars-1',
  name: 'Original name',
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
  variableOverrides: const {'frekvens': 'Kanal 8'},
);

void main() {
  testWidgets('saving an edited exercise preserves its variableOverrides', (
    tester,
  ) async {
    ExerciseFormResult? captured;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (ctx) => TextButton(
            onPressed: () async {
              captured = await Navigator.push<ExerciseFormResult>(
                ctx,
                MaterialPageRoute(
                  builder: (_) =>
                      ExerciseFormScreen(exercise: _exerciseWithOverrides()),
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // Change an unrelated field so the save path actually rebuilds the
    // exercise via generateSchedule, then save.
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Original name'),
      'Renamed',
    );
    await tester.tap(find.text(l10n.save));
    await tester.pumpAndSettle();

    expect(captured, isNotNull);
    expect(captured!.exercise.name, 'Renamed');
    expect(captured!.exercise.variableOverrides, {'frekvens': 'Kanal 8'});
  });
}
