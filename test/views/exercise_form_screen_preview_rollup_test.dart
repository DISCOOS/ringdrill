import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/drill_variable.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/views/exercise_form_screen.dart';
import 'package:ringdrill/views/widgets/brief_markdown.dart';

/// DESIGN-010 stage 2 — the per-section preview toggle (remembered per
/// section across a switch) and the default-section rollup (lists active
/// sections resolved, tap-to-edit), exercised end to end through the real
/// ExerciseFormScreen/SectionNavigatedForm rather than a bespoke harness.
Exercise _exerciseWithMethod() => Exercise(
  uuid: 'ex-preview-1',
  name: 'Exercise 1',
  startTime: const SimpleTimeOfDay(hour: 8, minute: 0),
  endTime: const SimpleTimeOfDay(hour: 9, minute: 0),
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
  // Contains a {{var.name}} reference so the preview/rollup can be checked
  // against a resolved value, not just literal text.
  methodMd: 'Method for {{var.name}}',
);

Future<AppLocalizations> _pumpWideEditor(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ExerciseFormScreen(
        exercise: _exerciseWithMethod(),
        variables: const [DrillVariable(name: 'name', value: 'World')],
      ),
    ),
  );
  await tester.pumpAndSettle();
  return AppLocalizations.delegate.load(const Locale('en'));
}

void main() {
  testWidgets(
    'the preview toggle switches a section to resolved markdown and back, '
    'remembered across a section switch',
    (tester) async {
      final l = await _pumpWideEditor(tester);

      // Switch to the "Method" section via the wide rail.
      await tester.tap(find.text(l.briefSectionExerciseMethod));
      await tester.pumpAndSettle();

      expect(find.byTooltip(l.formSectionPreviewAction), findsOneWidget);
      expect(find.byType(BriefMarkdown), findsNothing);

      await tester.tap(find.byTooltip(l.formSectionPreviewAction));
      await tester.pumpAndSettle();

      expect(find.byType(BriefMarkdown), findsOneWidget);
      expect(find.textContaining('Method for World'), findsOneWidget);
      expect(find.byTooltip(l.formSectionEditAction), findsOneWidget);

      // Switch away to the default section and back — the preview state is
      // remembered per section within the session (DESIGN-010).
      await tester.tap(find.text(l.exercise(1)));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.briefSectionExerciseMethod));
      await tester.pumpAndSettle();

      expect(find.byType(BriefMarkdown), findsOneWidget);
      expect(find.byTooltip(l.formSectionEditAction), findsOneWidget);

      // Toggling back to edit restores the editable chip field.
      await tester.tap(find.byTooltip(l.formSectionEditAction));
      await tester.pumpAndSettle();

      expect(find.byType(BriefMarkdown), findsNothing);
      expect(find.byTooltip(l.formSectionPreviewAction), findsOneWidget);
    },
  );

  testWidgets(
    'the default section eye swaps the whole section to the rollup preview '
    '(DESIGN-010, revised 2026-07-10)',
    (tester) async {
      final l = await _pumpWideEditor(tester);

      // The default section is now previewable: its eye is enabled and, when
      // tapped, replaces the structural fields with the rollup.
      expect(find.byTooltip(l.formSectionPreviewAction), findsOneWidget);
      expect(
        find.widgetWithText(TextFormField, l.exerciseName),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip(l.formSectionPreviewAction));
      await tester.pumpAndSettle();

      expect(find.textContaining('Method for World'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, l.exerciseName), findsNothing);
      expect(find.byTooltip(l.formSectionEditAction), findsOneWidget);
    },
  );

  testWidgets(
    'the default-section preview shows the rollup, and tapping a block '
    'navigates to that section (tap-to-edit)',
    (tester) async {
      final l = await _pumpWideEditor(tester);

      await tester.tap(find.byTooltip(l.formSectionPreviewAction));
      await tester.pumpAndSettle();

      // Whole-section swap: the rollup is shown, the structural name field
      // is not.
      expect(find.textContaining('Method for World'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, l.exerciseName), findsNothing);

      // Tapping the rendered block jumps to the Method section: its own body
      // shows and the rail highlights Method.
      await tester.tap(find.textContaining('Method for World'));
      await tester.pumpAndSettle();

      final methodTile = tester.widget<ListTile>(
        find.ancestor(
          of: find.text(l.briefSectionExerciseMethod),
          matching: find.byType(ListTile),
        ),
      );
      expect(methodTile.selected, isTrue);
    },
  );

  testWidgets('narrow swaps the default section to the rollup preview via the '
      'app-bar eye, with no layout exception', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ExerciseFormScreen(
          exercise: _exerciseWithMethod(),
          variables: const [DrillVariable(name: 'name', value: 'World')],
        ),
      ),
    );
    await tester.pumpAndSettle();
    final l = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.tap(find.byTooltip(l.formSectionPreviewAction));
    await tester.pumpAndSettle();

    // No rail on narrow; the whole section swaps to the rollup, so the
    // structural field is replaced by the resolved content.
    expect(find.byType(ListTile), findsNothing);
    expect(find.widgetWithText(TextFormField, l.exerciseName), findsNothing);
    expect(find.textContaining('Method for World'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the rollup leads with the round table, derived from the form', (
    tester,
  ) async {
    // ADR-0062, mockup panel 3. The author reads the timetable instead of working the
    // clock out, and reads it in the preview because that is where the brief's own
    // rendering of it lives. Derived from the values in the form, not from the last
    // save, so a mode or duration change shows up before committing.
    final l = await _pumpWideEditor(tester);

    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pumpAndSettle();

    // SectionHeader uppercases a rollup label, as it does for every section.
    expect(find.text(l.roundTable.toUpperCase()), findsOne);
    // One round of 15 + 10 + 5 from 08:00 — the fixture's own numbers, rendered as
    // the round table's hhmm cells.
    expect(find.textContaining('0800'), findsWidgets);
  });
}
