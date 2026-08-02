// The round count is an input in one mode and a consequence in the other two
// (ADR-0062), and the editor used to blur the difference: a disabled `Antall runder`
// field sat in the counter row showing a number nothing kept true.
//
// Two things are asserted here. That the field is present exactly where it is an input,
// which is the reported UI complaint. And that the number stated outside ring is
// *derived* rather than remembered — the reason the old field was not merely ugly.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/views/exercise_form_screen.dart';
import 'package:ringdrill/views/widgets/exercise_mode_field.dart';

/// Four stations and a saved `numberOfRounds: 4`, so a mode that derives fewer rounds
/// than that disagrees with the stored value — which is the case that used to show.
Exercise _exercise({
  ExerciseMode mode = ExerciseMode.ring,
  List<ExerciseGroup> groups = const [],
  List<Station>? stations,
}) => Exercise(
  uuid: 'ex-rounds',
  name: 'Exercise 1',
  startTime: const SimpleTimeOfDay(hour: 8, minute: 0),
  endTime: const SimpleTimeOfDay(hour: 10, minute: 0),
  numberOfTeams: 4,
  numberOfRounds: 4,
  executionTime: 15,
  evaluationTime: 10,
  rotationTime: 5,
  mode: mode,
  groups: groups,
  stations:
      stations ??
      const [
        Station(index: 0, name: 'Post 1'),
        Station(index: 1, name: 'Post 2'),
        Station(index: 2, name: 'Post 3'),
        Station(index: 3, name: 'Post 4'),
      ],
  schedule: const [],
);

Future<AppLocalizations> _pump(WidgetTester tester, Exercise exercise) async {
  tester.view.physicalSize = const Size(1200, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ExerciseFormScreen(exercise: exercise),
    ),
  );
  await tester.pumpAndSettle();
  return AppLocalizations.delegate.load(const Locale('en'));
}

Finder _roundsField(AppLocalizations l) => find.ancestor(
  of: find.text(l.numberOfRounds),
  matching: find.byType(TextFormField),
);

void main() {
  testWidgets('ring: the round count is an editable field', (tester) async {
    final l = await _pump(tester, _exercise());

    expect(_roundsField(l), findsOneWidget);
    final field = tester.widget<TextFormField>(_roundsField(l));
    expect(
      field.enabled,
      isTrue,
      reason: 'a ring route is where the author sets this',
    );
  });

  testWidgets('together: no field at all, and the derived count is stated', (
    tester,
  ) async {
    // Not a disabled field. That is the whole complaint: greyed-out text with a greyed
    // label in a row of live inputs reads as something the app has broken.
    final l = await _pump(tester, _exercise(mode: ExerciseMode.together));

    expect(_roundsField(l), findsNothing);
    expect(
      find.text(l.exerciseRoundsDerivedPerStation(4)),
      findsOneWidget,
      reason: 'four stations, so four rounds',
    );
  });

  testWidgets('split: the count follows the groups, not the saved value', (
    tester,
  ) async {
    // The bug the old field hid. Saved `numberOfRounds` is 4 and there are four
    // stations, but three parallel groups derive three rounds — and the field showed 4
    // under the label "= number of stations", which is not even the rule for split.
    final l = await _pump(
      tester,
      _exercise(
        mode: ExerciseMode.split,
        groups: const [
          ExerciseGroup(
            stations: [
              GroupSlot(stationIndex: 0, teams: [0, 1]),
              GroupSlot(stationIndex: 1, teams: [2, 3]),
            ],
          ),
          ExerciseGroup(
            stations: [
              GroupSlot(stationIndex: 2, teams: [0, 1]),
              GroupSlot(stationIndex: 3, teams: [2, 3]),
            ],
          ),
          ExerciseGroup(
            stations: [
              GroupSlot(stationIndex: 0, teams: [0]),
            ],
          ),
        ],
      ),
    );

    expect(_roundsField(l), findsNothing);
    expect(find.text(l.exerciseRoundsDerivedPerGroup(3)), findsOneWidget);
    expect(
      find.text(l.exerciseRoundsDerivedPerGroup(4)),
      findsNothing,
      reason: 'four was the stored value, and stating it was the bug',
    );
  });

  testWidgets('split with no groups yet says nothing about rounds', (
    tester,
  ) async {
    // `roundsForMode` falls back to the station count here. True, but not a rule worth
    // teaching — the groups section below is already asking for the first group, and a
    // note claiming "4 rounds — one per parallel group" with no groups is a lie.
    final l = await _pump(tester, _exercise(mode: ExerciseMode.split));

    expect(_roundsField(l), findsNothing);
    expect(
      find.textContaining(l.exerciseRoundsDerivedPerGroup(4)),
      findsNothing,
    );
    expect(
      find.textContaining(l.exerciseRoundsDerivedPerStation(4)),
      findsNothing,
    );
  });

  testWidgets('switching mode swaps the field for the note, and back', (
    tester,
  ) async {
    final l = await _pump(tester, _exercise());
    expect(_roundsField(l), findsOneWidget);

    await tester.tap(find.byType(ExerciseModeField));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.exerciseModeTogether).last);
    await tester.pumpAndSettle();

    expect(_roundsField(l), findsNothing);
    expect(find.text(l.exerciseRoundsDerivedPerStation(4)), findsOneWidget);

    await tester.tap(find.byType(ExerciseModeField));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.exerciseModeRing).last);
    await tester.pumpAndSettle();

    expect(_roundsField(l), findsOneWidget, reason: 'an input again');
    expect(find.text(l.exerciseRoundsDerivedPerStation(4)), findsNothing);
  });

  group('stations overriding the exercise phases', () {
    /// Two of three stations override, on different phases: 100-minute execution and a
    /// 25-minute walk on one, a 25-minute debrief on another.
    const overriding = [
      Station(index: 0, name: 'Post 1', executionTime: 100, rotationTime: 25),
      Station(index: 1, name: 'Post 2'),
      Station(index: 2, name: 'Post 3', evaluationTime: 25),
    ];

    testWidgets('ring: one length, from each phase maxed on its own', (
      tester,
    ) async {
      // Without this the exercise's three fields quietly stop describing the exercise:
      // an author reads "15 | 10 | 5" and 150-minute rounds in the table below with
      // nothing connecting them.
      //
      // 150 is 100 + 25 + 25 — execution from the first station, debrief from the
      // third, walk from the first. Taking the longest station's whole triple would
      // say 135, which is why the derivation maxes each phase separately.
      final l = await _pump(tester, _exercise(stations: overriding));

      expect(
        find.text(l.exerciseStationsOverrideUniform(2, 150)),
        findsOneWidget,
      );
    });

    testWidgets('together: a range, because the rounds really do differ', (
      tester,
    ) async {
      // A round is a station here, so each is that station's own total: 135, 30, 45.
      final l = await _pump(
        tester,
        _exercise(mode: ExerciseMode.together, stations: overriding),
      );

      expect(
        find.text(l.exerciseStationsOverrideRange(2, 30, 135)),
        findsOneWidget,
      );
    });

    testWidgets('nothing overridden, nothing said', (tester) async {
      // Almost every exercise. A note on all of them would be noise that teaches the
      // author to stop reading these.
      final l = await _pump(tester, _exercise());

      expect(find.text(l.exerciseStationsOverrideUniform(0, 30)), findsNothing);
      expect(
        find.textContaining('override'),
        findsNothing,
        reason: 'no station has taken these over',
      );
    });

    testWidgets('the count is stations, not overrides', (tester) async {
      // The first station overrides two phases. It is still one station.
      final l = await _pump(
        tester,
        _exercise(
          stations: const [
            Station(
              index: 0,
              name: 'Post 1',
              executionTime: 100,
              evaluationTime: 25,
              rotationTime: 25,
            ),
            Station(index: 1, name: 'Post 2'),
          ],
        ),
      );

      expect(
        find.text(l.exerciseStationsOverrideUniform(1, 150)),
        findsOneWidget,
      );
    });
  });

  testWidgets('ring keeps its revisit note, which the other modes must not show', (
    tester,
  ) async {
    // Revisits compare a rotation's length against the stations it rotates through.
    // Outside ring there is no rotation to be short of, so the wording would be
    // meaningless — and it was reachable, since the note read the same stale controller.
    final l = await _pump(tester, _exercise());

    await tester.enterText(_roundsField(l), '6');
    await tester.pumpAndSettle();
    expect(find.text(l.stationsRevisitNote(6, 4)), findsOneWidget);

    await tester.tap(find.byType(ExerciseModeField));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.exerciseModeTogether).last);
    await tester.pumpAndSettle();

    expect(find.text(l.stationsRevisitNote(6, 4)), findsNothing);
    expect(find.text(l.exerciseRoundsDerivedPerStation(4)), findsOneWidget);
  });
}
