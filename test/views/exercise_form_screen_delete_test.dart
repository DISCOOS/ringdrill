import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/views/exercise_form_screen.dart';

Exercise _exercise() => Exercise(
  uuid: 'ex-del-1',
  name: 'Slett øvelse',
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
);

void main() {
  testWidgets('a new draft (no exercise) shows no delete action', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ExerciseFormScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.delete), findsNothing);
  });

  testWidgets(
    'an existing exercise shows a delete action that pops ExerciseFormDelete '
    'after confirmation',
    (tester) async {
      ExerciseFormResult? result;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (ctx) => TextButton(
              onPressed: () async {
                result = await Navigator.push<ExerciseFormResult>(
                  ctx,
                  MaterialPageRoute(
                    builder: (_) => ExerciseFormScreen(exercise: _exercise()),
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

      // The AppBar delete action → confirm the destructive dialog.
      await tester.tap(find.byIcon(Icons.delete));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.delete));
      await tester.pumpAndSettle();

      expect(result, isA<ExerciseFormDelete>());
      expect((result as ExerciseFormDelete).exercise.uuid, 'ex-del-1');
    },
  );
}
