import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/views/exercise_form_screen.dart';

void main() {
  testWidgets('loads oversized legacy counters without clamping them', (
    tester,
  ) async {
    final exercise = _oversizedExercise();

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ExerciseFormScreen(exercise: exercise),
      ),
    );

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.legacyOversizedExerciseNotice), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is EditableText && widget.controller.text == '14',
      ),
      findsNWidgets(3),
    );

    await tester.tap(find.text(l10n.save));
    await tester.pump();

    expect(
      find.text(l10n.mustBeEqualToOrLessThanNumberOf('12')),
      findsNWidgets(3),
    );
  });
}

Exercise _oversizedExercise() {
  final schedule = List<List<SimpleTimeOfDay>>.generate(
    14,
    (index) => [
      SimpleTimeOfDay.fromMinutes(8 * 60 + index * 20),
      SimpleTimeOfDay.fromMinutes(8 * 60 + index * 20 + 10),
      SimpleTimeOfDay.fromMinutes(8 * 60 + index * 20 + 15),
    ],
  );
  return Exercise(
    uuid: 'legacy-oversized',
    name: 'Legacy oversized',
    startTime: const SimpleTimeOfDay(hour: 8, minute: 0),
    numberOfTeams: 14,
    numberOfRounds: 14,
    executionTime: 10,
    evaluationTime: 5,
    rotationTime: 5,
    stations: List<Station>.generate(
      14,
      (index) => Station(index: index, name: 'Station ${index + 1}'),
    ),
    schedule: schedule,
    endTime: const SimpleTimeOfDay(hour: 12, minute: 40),
  );
}
