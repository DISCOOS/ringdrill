// A station can own any of the three phase times (ADR-0062, extended): a long post, a
// long debrief, and a long walk off it are all things a real plan states about a post.
//
// The editor's job is to make "inherit" and "override" legible per phase and to save
// exactly what was typed — an override the form drops is a schedule the author cannot
// explain, since the round times come from these three.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/views/station_form_screen.dart';

final _exercise = Exercise(
  uuid: 'ex',
  name: 'E',
  startTime: const SimpleTimeOfDay(hour: 10, minute: 0),
  endTime: const SimpleTimeOfDay(hour: 12, minute: 0),
  numberOfTeams: 4,
  numberOfRounds: 4,
  executionTime: 15,
  evaluationTime: 10,
  rotationTime: 5,
  stations: const [Station(index: 0, name: 'Post 1')],
  schedule: const [],
);

Future<AppLocalizations> _pump(WidgetTester tester, Station station) async {
  tester.view.physicalSize = const Size(900, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: StationFormScreen(station: station, parentExercise: _exercise),
    ),
  );
  await tester.pumpAndSettle();
  return AppLocalizations.delegate.load(const Locale('en'));
}

Finder _field(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(TextFormField));

void main() {
  testWidgets('all three phases are offered, and inherit by default', (
    tester,
  ) async {
    final l = await _pump(tester, const Station(index: 0, name: 'Post 1'));

    for (final label in [l.executionTime, l.evaluationTime, l.rotationTime]) {
      expect(_field(label), findsOneWidget, reason: label);
    }
    expect(find.text(l.stationTimingInherits), findsOneWidget);

    // The exercise's own values show as hints, so "inherit" says what it inherits
    // rather than leaving three blanks.
    for (final inherited in ['15', '10', '5']) {
      expect(find.text(inherited), findsOneWidget, reason: inherited);
    }
  });

  testWidgets('an override on one phase leaves the other two inheriting', (
    tester,
  ) async {
    final l = await _pump(
      tester,
      const Station(index: 0, name: 'Post 1', rotationTime: 25),
    );

    // 15 + 10 + 25. The note is about this station's timing as a whole, which is why
    // there is one of it rather than one per field.
    expect(find.text(l.stationTimingOverridden(50)), findsOneWidget);
    expect(find.text(l.stationTimingInherits), findsNothing);
  });

  testWidgets('the note follows the fields as they are edited', (tester) async {
    final l = await _pump(tester, const Station(index: 0, name: 'Post 1'));

    await tester.enterText(_field(l.executionTime), '100');
    await tester.pumpAndSettle();
    expect(find.text(l.stationTimingOverridden(115)), findsOneWidget);

    await tester.enterText(_field(l.evaluationTime), '25');
    await tester.pumpAndSettle();
    expect(find.text(l.stationTimingOverridden(130)), findsOneWidget);

    // Cleared is inherit again, not zero.
    await tester.enterText(_field(l.executionTime), '');
    await tester.enterText(_field(l.evaluationTime), '');
    await tester.pumpAndSettle();
    expect(find.text(l.stationTimingInherits), findsOneWidget);
  });

  testWidgets('each label floats, so an empty field still reads as its phase', (
    tester,
  ) async {
    // Unfloated, an empty field's label sits where the value goes at full size —
    // truncating to "Evaluation T…" in a three-column row and hiding the hint that
    // shows what is inherited.
    final l = await _pump(tester, const Station(index: 0, name: 'Post 1'));

    for (final label in [l.executionTime, l.evaluationTime, l.rotationTime]) {
      final field = tester.widget<TextField>(
        find.descendant(of: _field(label), matching: find.byType(TextField)),
      );
      expect(
        field.decoration?.floatingLabelBehavior,
        FloatingLabelBehavior.always,
        reason: label,
      );
    }
  });

  testWidgets('zero is an override, not an absence', (tester) async {
    // A post with no debrief, or one whose successor is at the same spot, are both
    // real — and the exercise's own three already accept zero, so a stricter rule on
    // the override would only surprise. Typing 0 used to mean "inherit", which saved
    // the exercise's value and gave the author no way to say "none".
    final l = await _pump(tester, const Station(index: 0, name: 'Post 1'));

    await tester.enterText(_field(l.evaluationTime), '0');
    await tester.enterText(_field(l.rotationTime), '0');
    await tester.pumpAndSettle();

    // 15 + 0 + 0, so the note has to change — if 0 read as inherit it would still be
    // saying 30, and still be saying "inherited".
    expect(find.text(l.stationTimingOverridden(15)), findsOneWidget);
    expect(find.text(l.stationTimingInherits), findsNothing);
    expect(
      find.text(l.pleaseEnterAValidNumber),
      findsNothing,
      reason: 'zero is valid',
    );
  });

  testWidgets('a negative time is still rejected', (tester) async {
    final l = await _pump(tester, const Station(index: 0, name: 'Post 1'));

    await tester.enterText(_field(l.rotationTime), '-5');
    await tester.pumpAndSettle();
    // The validator runs on save; force it the way the form does.
    tester.state<FormState>(find.byType(Form).first).validate();
    await tester.pumpAndSettle();

    expect(find.text(l.pleaseEnterAValidNumber), findsWidgets);
  });
}
