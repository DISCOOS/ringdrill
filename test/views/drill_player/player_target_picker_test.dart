import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/data/plan_repository.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/plan.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/models/team.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/services/plan_service.dart';
import 'package:ringdrill/views/drill_player/player_mode.dart';
import 'package:ringdrill/views/drill_player/player_target_picker.dart';
import 'package:ringdrill/views/widgets/context_sheet.dart';
import 'package:ringdrill/views/widgets/exercise_number_badge.dart';
import 'package:ringdrill/views/widgets/role_number_badge.dart';
import 'package:ringdrill/views/widgets/station_number_badge.dart';
import 'package:ringdrill/views/widgets/team_number_badge.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The player's picker lists **every** target reachable from where it is, in one
/// grouped list (ADR-0056), whatever mode it is in.
///
/// It used to list siblings of the current kind only, with the parent exercise
/// pinned on top as the one way back up — so moving between kinds took two taps
/// and the pinned row existed only to enable that. These tests pin the grouped
/// contract instead: all exercises, plus the *current* exercise's posts, markers
/// and teams, under section headers.
const _planUuid = 'prog-target-picker';
const _exerciseUuid = 'ex-target-picker';
const _otherExerciseUuid = 'ex-target-picker-2';
const _roleUuid = 'role-target-picker';
const _otherRoleUuid = 'role-target-picker-2';
const _foreignRoleUuid = 'role-target-picker-foreign';

Exercise _exercise() => Exercise(
  uuid: _exerciseUuid,
  index: 0,
  name: 'Picker Exercise',
  startTime: const SimpleTimeOfDay(hour: 8, minute: 0),
  numberOfTeams: 2,
  numberOfRounds: 1,
  executionTime: 10,
  evaluationTime: 5,
  rotationTime: 2,
  stations: const [
    Station(index: 0, name: 'Post 1'),
    Station(index: 1, name: 'Post 2'),
  ],
  schedule: const [
    [
      SimpleTimeOfDay(hour: 8, minute: 0),
      SimpleTimeOfDay(hour: 8, minute: 10),
      SimpleTimeOfDay(hour: 8, minute: 15),
    ],
  ],
  endTime: const SimpleTimeOfDay(hour: 8, minute: 17),
);

Exercise _otherExercise() => _exercise().copyWith(
  uuid: _otherExerciseUuid,
  index: 1,
  name: 'Other Exercise',
  stations: const [Station(index: 0, name: 'Foreign post')],
);

Plan _shell() {
  final now = DateTime.utc(2026, 1, 1);
  return Plan(
    uuid: _planUuid,
    name: 'Test Plan',
    description: '',
    metadata: PlanMetadata(created: now, updated: now, version: '1.1'),
    teams: const [
      Team(uuid: 'team-a', index: 0, name: 'Alfa'),
      Team(uuid: 'team-b', index: 1, name: 'Bravo'),
      // In the roster but beyond this exercise's numberOfTeams.
      Team(uuid: 'team-c', index: 2, name: 'Charlie'),
    ],
    sessions: const [],
    exercises: const [],
    rolePlays: const [],
    actors: const [],
  );
}

Future<void> _seedAndInit() async {
  SharedPreferences.setMockInitialValues({});
  PlanService().reset();
  ExerciseService().stop();
  final prefs = await SharedPreferences.getInstance();
  final repo = PlanRepository(prefs);
  await repo.savePlanShell(_shell());
  await repo.setActivePlanUuid(_planUuid);
  await repo.saveExercise(_exercise());
  await repo.saveExercise(_otherExercise());
  // Teams live under their own keys, not inside the plan shell — savePlanShell
  // drops the `teams:` list on the way in.
  for (final team in _shell().teams) {
    await repo.saveTeam(team);
  }
  await repo.saveRolePlay(
    const RolePlay(
      uuid: _roleUuid,
      index: 0,
      exerciseUuid: _exerciseUuid,
      stationIndex: 0,
      name: 'Savnet person',
    ),
  );
  await repo.saveRolePlay(
    const RolePlay(
      uuid: _otherRoleUuid,
      index: 1,
      exerciseUuid: _exerciseUuid,
      stationIndex: 1,
      name: 'Pårørende',
    ),
  );
  // Belongs to a different exercise — must never show up in this exercise's
  // roleplay picker.
  await repo.saveRolePlay(
    const RolePlay(
      uuid: _foreignRoleUuid,
      index: 0,
      exerciseUuid: _otherExerciseUuid,
      stationIndex: 0,
      name: 'Fremmed markør',
    ),
  );
  await PlanService().init();
}

/// Opens the picker on demand and records what it resolved to.
class _Harness extends StatefulWidget {
  const _Harness({required this.mode});

  final PlayerMode mode;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  ContextSheetTarget? picked;
  bool resolved = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                final result = await showPlayerTargetPicker(
                  context,
                  mode: widget.mode,
                  exercise: PlanService().getExercise(_exerciseUuid)!,
                );
                setState(() {
                  picked = result;
                  resolved = true;
                });
              },
              child: const Text('open picker'),
            ),
          ),
        ),
      ),
    );
  }
}

Future<_HarnessState> _openPicker(WidgetTester tester, PlayerMode mode) async {
  // Tall enough for every group to be laid out: the picker's ListView builds
  // lazily, so rows below the fold do not exist for the finders at all — and
  // this list is deliberately long now that it spans all four kinds.
  tester.view.physicalSize = const Size(900, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(_Harness(mode: mode));
  await tester.tap(find.text('open picker'));
  await tester.pumpAndSettle();
  return tester.state<_HarnessState>(find.byType(_Harness));
}

/// Stops the session and settles a frame. Not cosmetic: the service holds a
/// periodic timer, and a `tearDown` callback runs after the tree is disposed —
/// too late, so the test fails on a pending timer.
Future<void> _stopLive(WidgetTester tester) async {
  ExerciseService().stop();
  await tester.pump();
}

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  setUp(_seedAndInit);

  /// Every group header, in list order.
  List<String> groups() => [
    l10n.exercise(2),
    l10n.stationsTab,
    l10n.scriptSegment,
    l10n.team(2),
  ];

  group('every mode lists every group', () {
    for (final (name, mode) in <(String, PlayerMode)>[
      ('exercise', ExercisePlayerMode()),
      ('station', StationPlayerMode(0)),
      ('roleplay', RolePlayerMode(_roleUuid)),
      ('team', TeamPlayerMode(0)),
    ]) {
      testWidgets('$name mode', (tester) async {
        await _openPicker(tester, mode);

        expect(find.text(l10n.pickerGoToTitle), findsOneWidget);
        for (final group in groups()) {
          expect(
            find.text(group),
            findsOneWidget,
            reason: '$name mode must still offer the "$group" group',
          );
        }
        // One badge kind per group, so each row reads as its own kind.
        expect(find.byType(ExerciseNumberBadge), findsNWidgets(2));
        expect(find.byType(StationNumberBadge), findsNWidgets(2));
        expect(find.byType(RoleNumberBadge), findsNWidgets(2));
        expect(find.byType(TeamNumberBadge), findsNWidgets(2));
      });
    }
  });

  group('scope', () {
    testWidgets('lists every exercise, but only this one\'s children', (
      tester,
    ) async {
      await _openPicker(tester, const StationPlayerMode(0));

      // Exercises: the whole plan, so the player can move between them.
      expect(find.widgetWithText(ListTile, 'Picker Exercise'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Other Exercise'), findsOneWidget);
      // Children: only the exercise the player is on. A post belongs to one
      // exercise, so listing every exercise's would bury the ones being run.
      // Post names appear twice over — as station rows and as the markør rows'
      // subtitles — so these are asserted by their unique badge labels.
      expect(find.text('1.1'), findsOneWidget);
      expect(find.text('1.2'), findsOneWidget);
      expect(find.text('Foreign post'), findsNothing);
      expect(find.text('Fremmed markør'), findsNothing);
    });
  });

  group('the current target', () {
    testWidgets('is the only row marked, in station mode', (tester) async {
      await _openPicker(tester, const StationPlayerMode(1));

      expect(find.byIcon(Icons.check), findsOneWidget);
      // The parent exercise is somewhere to go, not where you are.
      expect(
        find.descendant(
          of: find.widgetWithText(ListTile, 'Picker Exercise'),
          matching: find.byIcon(Icons.check),
        ),
        findsNothing,
      );
    });

    testWidgets('is the exercise row in exercise mode', (tester) async {
      await _openPicker(tester, const ExercisePlayerMode());

      expect(
        find.descendant(
          of: find.widgetWithText(ListTile, 'Picker Exercise'),
          matching: find.byIcon(Icons.check),
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('resolves null when re-picked', (tester) async {
      final state = await _openPicker(tester, const StationPlayerMode(0));

      // By badge, not name: a post's name also appears as a markør row's
      // subtitle, so the name alone would be ambiguous here.
      await tester.tap(find.text('1.1'));
      await tester.pumpAndSettle();

      expect(state.resolved, isTrue);
      expect(state.picked, isNull);
    });
  });

  // The point of the change: any kind is one tap away, from any mode.
  group('crossing kinds in one tap', () {
    testWidgets('station mode to a roleplay', (tester) async {
      final state = await _openPicker(tester, const StationPlayerMode(0));

      await tester.tap(find.text('Pårørende'));
      await tester.pumpAndSettle();

      expect(state.picked, isA<RoleSheetTarget>());
      expect((state.picked! as RoleSheetTarget).rolePlayUuid, _otherRoleUuid);
    });

    testWidgets('roleplay mode to a team', (tester) async {
      final state = await _openPicker(tester, const RolePlayerMode(_roleUuid));

      await tester.tap(find.text('Bravo'));
      await tester.pumpAndSettle();

      expect(state.picked, isA<TeamSheetTarget>());
      expect((state.picked! as TeamSheetTarget).teamIndex, 1);
    });

    testWidgets('team mode to a station', (tester) async {
      final state = await _openPicker(tester, const TeamPlayerMode(0));

      await tester.tap(find.text('1.2'));
      await tester.pumpAndSettle();

      expect(state.picked, isA<StationSheetTarget>());
      expect((state.picked! as StationSheetTarget).stationIndex, 1);
    });

    testWidgets('station mode to another exercise', (tester) async {
      final state = await _openPicker(tester, const StationPlayerMode(0));

      await tester.tap(find.text('Other Exercise'));
      await tester.pumpAndSettle();

      expect(state.picked, isA<ExerciseSheetTarget>());
      expect(
        (state.picked! as ExerciseSheetTarget).exerciseUuid,
        _otherExerciseUuid,
      );
    });
  });

  // The "cannot switch the live exercise" rule lives here now. The mini bar used
  // to enforce it by refusing to open at all in exercise mode, which also blocked
  // navigating *within* the running exercise — the reported bug.
  group('while an exercise is running', () {
    testWidgets('its own children stay pickable', (tester) async {
      ExerciseService().start(_exercise());
      final state = await _openPicker(tester, const ExercisePlayerMode());

      await tester.tap(find.text('1.2'));
      await tester.pumpAndSettle();

      expect(state.picked, isA<StationSheetTarget>());
      expect((state.picked! as StationSheetTarget).stationIndex, 1);

      await _stopLive(tester);
    });

    // Omitted rather than shown-but-disabled: it keeps the list short and every
    // row actionable, which matters most in the situation this picker is used in.
    testWidgets('the exercise group holds only the running exercise', (
      tester,
    ) async {
      ExerciseService().start(_exercise());
      await _openPicker(tester, const ExercisePlayerMode());

      expect(find.widgetWithText(ListTile, 'Picker Exercise'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Other Exercise'), findsNothing);
      expect(find.byType(ExerciseNumberBadge), findsOneWidget);
      // The group header stays, so the row still reads as an exercise.
      expect(find.text(l10n.exercise(2)), findsOneWidget);

      await _stopLive(tester);
    });

    testWidgets('with nothing running, every exercise is listed', (
      tester,
    ) async {
      await _openPicker(tester, const ExercisePlayerMode());

      expect(find.widgetWithText(ListTile, 'Picker Exercise'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Other Exercise'), findsOneWidget);
    });
  });

  // The grouping is applied to the *filtered* rows, so a search cannot strand a
  // header above a group whose rows all filtered out, nor hide the header of a
  // group that still matches. Faking headers inside itemBuilder gets this wrong.
  group('search', () {
    testWidgets('keeps only the groups that still match', (tester) async {
      await _openPicker(tester, const StationPlayerMode(0));
      // 8 entries here, so the search field is shown (searchThreshold).
      final field = find.byKey(const Key('ringdrill-picker-search'));
      expect(field, findsOneWidget);

      await tester.enterText(field, 'Bravo');
      await tester.pumpAndSettle();

      // Scoped to the row: the search field itself now also contains "Bravo".
      expect(find.widgetWithText(ListTile, 'Bravo'), findsOneWidget);
      expect(find.text(l10n.team(2)), findsOneWidget);
      // Every other group's header goes with its rows.
      expect(find.text(l10n.stationsTab), findsNothing);
      expect(find.text(l10n.scriptSegment), findsNothing);
      expect(find.text(l10n.exercise(2)), findsNothing);
    });

    // Operators know their posts and markers by number, and the number is what
    // the row shows — so it has to be searchable, not only the name.
    testWidgets('a formatted number reaches its row', (tester) async {
      await _openPicker(tester, const StationPlayerMode(0));
      final field = find.byKey(const Key('ringdrill-picker-search'));

      await tester.enterText(field, '1.2-1');
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ListTile, 'Pårørende'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Post 1'), findsNothing);

      await tester.enterText(field, '#2');
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ListTile, 'Other Exercise'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Picker Exercise'), findsNothing);
    });

    testWidgets('a station number matches the station, not its markør', (
      tester,
    ) async {
      await _openPicker(tester, const StationPlayerMode(0));

      await tester.enterText(
        find.byKey(const Key('ringdrill-picker-search')),
        '1.1',
      );
      await tester.pumpAndSettle();

      // "1.1" is a prefix of the markør label "1.1-1", so both legitimately
      // match — what matters is that the station itself is reachable this way.
      // Scoped to the badge: the search field now contains "1.1" as well.
      expect(
        find.descendant(
          of: find.byType(StationNumberBadge),
          matching: find.text('1.1'),
        ),
        findsOneWidget,
      );
      expect(find.text(l10n.stationsTab), findsOneWidget);
    });

    testWidgets('a team number reaches its team', (tester) async {
      await _openPicker(tester, const StationPlayerMode(0));

      await tester.enterText(
        find.byKey(const Key('ringdrill-picker-search')),
        '2',
      );
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ListTile, 'Bravo'), findsOneWidget);
      expect(find.text(l10n.team(2)), findsOneWidget);
    });

    testWidgets('a group name narrows to that kind', (tester) async {
      await _openPicker(tester, const StationPlayerMode(0));

      await tester.enterText(
        find.byKey(const Key('ringdrill-picker-search')),
        l10n.stationsTab,
      );
      await tester.pumpAndSettle();

      expect(find.text('1.1'), findsOneWidget);
      expect(find.text('1.2'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Bravo'), findsNothing);
    });
  });
}
