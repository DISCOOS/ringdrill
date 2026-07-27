import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/data/plan_repository.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/plan.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/plan_service.dart';
import 'package:ringdrill/views/drill_player/player_mode.dart';
import 'package:ringdrill/views/drill_player/player_target_picker.dart';
import 'package:ringdrill/views/widgets/context_sheet.dart';
import 'package:ringdrill/views/widgets/exercise_number_badge.dart';
import 'package:ringdrill/views/widgets/role_number_badge.dart';
import 'package:ringdrill/views/widgets/station_number_badge.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The mini bar's badge is a *within-mode* selector: its picker lists siblings
/// of the kind the player is currently showing (ADR-0056), never a mixed list.
///
/// Because X always closes the player rather than unwinding a history, the
/// station and roleplay pickers pin the parent exercise as their first row —
/// that pinned row is the only way back *up* a mode.
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
  numberOfTeams: 1,
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
    teams: const [],
    sessions: const [],
    exercises: const [],
    rolePlays: const [],
    actors: const [],
  );
}

Future<void> _seedAndInit() async {
  SharedPreferences.setMockInitialValues({});
  PlanService().reset();
  final prefs = await SharedPreferences.getInstance();
  final repo = PlanRepository(prefs);
  await repo.savePlanShell(_shell());
  await repo.setActivePlanUuid(_planUuid);
  await repo.saveExercise(_exercise());
  await repo.saveExercise(_otherExercise());
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
  await tester.pumpWidget(_Harness(mode: mode));
  await tester.tap(find.text('open picker'));
  await tester.pumpAndSettle();
  return tester.state<_HarnessState>(find.byType(_Harness));
}

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  setUp(_seedAndInit);

  group('station mode', () {
    testWidgets('lists this exercise\'s stations under a pinned parent row', (
      tester,
    ) async {
      await _openPicker(tester, const StationPlayerMode(0));

      expect(find.text(l10n.pickerSelectStationTitle), findsOneWidget);
      // Siblings, and only this exercise's.
      expect(find.text('Post 1'), findsOneWidget);
      expect(find.text('Post 2'), findsOneWidget);
      expect(find.text('Foreign post'), findsNothing);
      // The parent, pinned — one exercise badge among the station badges.
      expect(find.text('Picker Exercise'), findsOneWidget);
      expect(find.byType(ExerciseNumberBadge), findsOneWidget);
      expect(find.byType(StationNumberBadge), findsNWidgets(2));
      expect(find.byType(RoleNumberBadge), findsNothing);
    });

    testWidgets('the parent row comes first, and returns the exercise', (
      tester,
    ) async {
      final state = await _openPicker(tester, const StationPlayerMode(0));

      // Pinned means first: above the sibling list, reachable without
      // scrolling.
      final rows = tester.getTopLeft(find.text('Picker Exercise'));
      expect(rows.dy, lessThan(tester.getTopLeft(find.text('Post 1')).dy));

      await tester.tap(find.text('Picker Exercise'));
      await tester.pumpAndSettle();

      expect(state.picked, isA<ExerciseSheetTarget>());
      expect(
        (state.picked! as ExerciseSheetTarget).exerciseUuid,
        _exerciseUuid,
      );
    });

    testWidgets('picking a sibling returns that station', (tester) async {
      final state = await _openPicker(tester, const StationPlayerMode(0));

      await tester.tap(find.text('Post 2'));
      await tester.pumpAndSettle();

      expect(state.picked, isA<StationSheetTarget>());
      expect((state.picked! as StationSheetTarget).stationIndex, 1);
    });

    // Re-picking what is already showing is a no-op, so the host is never
    // asked to navigate to where it already is.
    testWidgets('the current station is marked and resolves null', (
      tester,
    ) async {
      final state = await _openPicker(tester, const StationPlayerMode(0));

      expect(find.byIcon(Icons.check), findsOneWidget);

      await tester.tap(find.text('Post 1'));
      await tester.pumpAndSettle();

      expect(state.resolved, isTrue);
      expect(state.picked, isNull);
    });
  });

  group('roleplay mode', () {
    testWidgets('lists this exercise\'s roleplays under a pinned parent row', (
      tester,
    ) async {
      await _openPicker(tester, const RolePlayerMode(_roleUuid));

      expect(find.text(l10n.pickerSelectRoleTitle), findsOneWidget);
      expect(find.text('Savnet person'), findsOneWidget);
      expect(find.text('Pårørende'), findsOneWidget);
      expect(
        find.text('Fremmed markør'),
        findsNothing,
        reason: 'roleplays of another exercise are not siblings',
      );
      expect(find.text('Picker Exercise'), findsOneWidget);
      expect(find.byType(RoleNumberBadge), findsNWidgets(2));
      expect(find.byType(ExerciseNumberBadge), findsOneWidget);
      expect(find.byType(StationNumberBadge), findsNothing);
    });

    testWidgets('each row names the post the markør is placed at', (
      tester,
    ) async {
      await _openPicker(tester, const RolePlayerMode(_roleUuid));

      // Subtitles, so a list of markør names stays navigable.
      expect(find.text('Post 1'), findsOneWidget);
      expect(find.text('Post 2'), findsOneWidget);
    });

    testWidgets('picking a sibling returns that roleplay', (tester) async {
      final state = await _openPicker(tester, const RolePlayerMode(_roleUuid));

      await tester.tap(find.text('Pårørende'));
      await tester.pumpAndSettle();

      expect(state.picked, isA<RoleSheetTarget>());
      expect((state.picked! as RoleSheetTarget).rolePlayUuid, _otherRoleUuid);
    });
  });

  group('exercise mode', () {
    // Nothing to pin: the exercise *is* the top of the hierarchy, and a row
    // for the current exercise already exists in the list itself.
    testWidgets('lists exercises with no parent row', (tester) async {
      await _openPicker(tester, const ExercisePlayerMode());

      expect(find.text(l10n.pickerSelectExerciseTitle), findsOneWidget);
      expect(find.text('Picker Exercise'), findsOneWidget);
      expect(find.text('Other Exercise'), findsOneWidget);
      expect(find.byType(ExerciseNumberBadge), findsNWidgets(2));
      expect(find.byType(StationNumberBadge), findsNothing);
      expect(find.byType(RoleNumberBadge), findsNothing);
    });

    testWidgets('picking another exercise returns it as a target', (
      tester,
    ) async {
      final state = await _openPicker(tester, const ExercisePlayerMode());

      await tester.tap(find.text('Other Exercise'));
      await tester.pumpAndSettle();

      expect(state.picked, isA<ExerciseSheetTarget>());
      expect(
        (state.picked! as ExerciseSheetTarget).exerciseUuid,
        _otherExerciseUuid,
      );
    });
  });
}
