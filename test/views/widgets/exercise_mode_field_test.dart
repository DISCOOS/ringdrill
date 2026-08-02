// ADR-0062's conduct field, and the reason it matters more than it looks: the
// exercise editor rebuilds its exercise from these inputs on every save, so a mode
// the form does not hold is a mode the first LAGRE throws away.
//
// The control itself is deliberately nothing new — a tappable `InputDecorator` opening
// `showRingdrillPicker`, the same shape the start-time field and the roleplay editor's
// station selector use — so what is worth testing is the wiring, not the widget.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/views/widgets/exercise_mode_field.dart';

Future<AppLocalizations> _pump(
  WidgetTester tester, {
  required ExerciseMode mode,
  required ValueChanged<ExerciseMode> onChanged,
}) async {
  tester.view.physicalSize = const Size(500, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ExerciseModeField(mode: mode, onChanged: onChanged),
      ),
    ),
  );
  return AppLocalizations.delegate.load(const Locale('en'));
}

void main() {
  testWidgets('shows the current mode, and every mode when opened', (
    tester,
  ) async {
    final l = await _pump(tester, mode: ExerciseMode.ring, onChanged: (_) {});

    expect(find.text(l.exerciseMode), findsOne);
    expect(find.text(l.exerciseModeRing), findsOne);

    await tester.tap(find.text(l.exerciseModeRing));
    await tester.pumpAndSettle();

    // Each option carries its sentence: the app has to teach the difference, and the
    // sentence is where that happens.
    expect(find.text(l.exerciseModeTogether), findsOne);
    expect(find.text(l.exerciseModeSplit), findsOne);
    expect(find.text(l.exerciseModeRingDescription), findsOne);
    expect(find.text(l.exerciseModeTogetherDescription), findsOne);
    expect(find.text(l.exerciseModeSplitDescription), findsOne);
  });

  testWidgets('the row is a framed field, not a bare list tile', (
    tester,
  ) async {
    // As a `ListTile` this had no frame and read as a caption floating between two rows
    // of real inputs. It is the form's own tappable-value idiom now — an `InkWell`
    // around an `InputDecorator`, like the start-time field — with the outlined border
    // rather than the siblings' underline, since it governs the whole exercise.
    await _pump(tester, mode: ExerciseMode.ring, onChanged: (_) {});

    expect(find.byType(ListTile), findsNothing);
    final decorator = tester.widget<InputDecorator>(
      find.byType(InputDecorator),
    );
    expect(decorator.decoration.border, isA<OutlineInputBorder>());
    expect(decorator.decoration.prefixIcon, isNotNull, reason: 'the mode icon');
    expect(decorator.decoration.suffixIcon, isNotNull, reason: 'it opens');
  });

  testWidgets('the three labels read as a set of one-word options', (
    tester,
  ) async {
    // The picker's job is three parallel choices, so "Ring" beside "Together" and
    // "Split" — not "Ring Route", which is what the brief calls the route in a
    // sentence with room for it. And not "Ring Drill", which names the whole domain
    // rather than one mode of one exercise.
    final l = await _pump(tester, mode: ExerciseMode.ring, onChanged: (_) {});
    expect(l.exerciseModeRing, 'Ring');
    expect(
      l.briefRingRoute,
      'Ring Route',
      reason: 'the brief keeps its own term',
    );
    expect(find.text(l.exerciseModeRing), findsOne);
  });

  testWidgets('choosing a different mode reports it', (tester) async {
    ExerciseMode? chosen;
    final l = await _pump(
      tester,
      mode: ExerciseMode.ring,
      onChanged: (mode) => chosen = mode,
    );

    await tester.tap(find.text(l.exerciseModeRing));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.exerciseModeTogether));
    await tester.pumpAndSettle();

    expect(chosen, ExerciseMode.together);
  });

  testWidgets('choosing the mode it already has reports nothing', (
    tester,
  ) async {
    // So a caller that has to confirm a destructive change is not asked to
    // re-check whether anything actually changed.
    var calls = 0;
    final l = await _pump(
      tester,
      mode: ExerciseMode.together,
      onChanged: (_) => calls++,
    );

    await tester.tap(find.text(l.exerciseModeTogether));
    await tester.pumpAndSettle();
    // Two now: the row's own value and the picker's row.
    await tester.tap(find.text(l.exerciseModeTogether).last);
    await tester.pumpAndSettle();

    expect(calls, 0);
  });

  testWidgets('dismissing the picker reports nothing', (tester) async {
    var calls = 0;
    final l = await _pump(
      tester,
      mode: ExerciseMode.ring,
      onChanged: (_) => calls++,
    );

    await tester.tap(find.text(l.exerciseModeRing));
    await tester.pumpAndSettle();
    // Escape is what the sheet and the dialog both honour.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(calls, 0);
  });
}
