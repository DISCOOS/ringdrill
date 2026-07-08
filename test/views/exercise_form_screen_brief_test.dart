import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/views/exercise_form_screen.dart';

Exercise _exerciseWithMethod() => Exercise(
  uuid: 'ex-brief-1',
  name: 'Brief øvelse',
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
  methodMd: 'Gruppevis øving utendørs',
);

void main() {
  testWidgets('seeded brief section survives a save round-trip', (
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
                      ExerciseFormScreen(exercise: _exerciseWithMethod()),
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

    // The Method section is seeded as active; switch to it via the rail
    // (default 800x600 surface lands in the wide/medium window class).
    await tester.tap(find.text(l10n.briefSectionExerciseMethod));
    await tester.pumpAndSettle();
    expect(find.text('Gruppevis øving utendørs'), findsOneWidget);

    // Replace the method content and save.
    await tester.enterText(
      find.widgetWithText(TextFormField, l10n.briefSectionExerciseMethod),
      'Skogsøving',
    );
    await tester.tap(find.text(l10n.save));
    await tester.pumpAndSettle();

    expect(captured, isNotNull);
    expect(captured!.exercise.methodMd, 'Skogsøving');
    // Other brief fields stay null because we never added their sections.
    expect(captured!.exercise.learningGoalsMd, isNull);
    expect(captured!.exercise.commsMd, isNull);
  });

  testWidgets('removing a seeded brief section clears its value on save', (
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
                      ExerciseFormScreen(exercise: _exerciseWithMethod()),
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

    // Switch to the seeded Method section, then remove it via its overflow
    // menu's "Remove section" action.
    await tester.tap(find.text(l10n.briefSectionExerciseMethod));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.formSectionRemoveAction));
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10n.save));
    await tester.pumpAndSettle();

    expect(captured, isNotNull);
    expect(captured!.exercise.methodMd, isNull);
  });

  testWidgets(
    'hides the divider below the optional fields once all are added',
    (tester) async {
      final exercise = _exerciseWithMethod().copyWith(
        learningGoalsMd: 'mål',
        trainingFocusMd: 'fokus',
        orderFormatMd: 'ordreform',
        executionTipsMd: 'tips',
        commsMd: 'kom',
      );
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (ctx) => TextButton(
              onPressed: () => Navigator.push<ExerciseFormResult>(
                ctx,
                MaterialPageRoute(
                  builder: (_) => ExerciseFormScreen(exercise: exercise),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // No add-buttons left, so the divider above the (now absent)
      // add-buttons row is hidden.
      expect(find.byType(Divider), findsNothing);
    },
  );
}
