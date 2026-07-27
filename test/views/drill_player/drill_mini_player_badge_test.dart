import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/data/plan_repository.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/plan.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/services/plan_service.dart';
import 'package:ringdrill/views/drill_player/drill_mini_player.dart';
import 'package:ringdrill/views/drill_player/mini_round_row.dart';
import 'package:ringdrill/views/drill_player/player_mode.dart';
import 'package:ringdrill/views/widgets/exercise_number_badge.dart';
import 'package:ringdrill/views/widgets/role_number_badge.dart';
import 'package:ringdrill/views/widgets/station_number_badge.dart';
import 'package:ringdrill/views/widgets/team_number_badge.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The mini bar's leading badge follows the player's [PlayerMode] (ADR-0056):
/// exercise `#n`, station `n.m`, markør `n.m-k`, team `n`.
///
/// Two invariants worth pinning:
/// - The label is computed in ONE place. It used to be derived separately in
///   the running and the idle branch — with three badge kinds that duplication
///   would drift, so both branches now share `_buildBadge`.
/// - Interactivity does *not* depend on an exercise running. The bar's picker
///   navigates to any target now, so making it inert while live blocked exactly
///   what the player is for — moving between the running exercise's posts,
///   markers and teams. "Cannot switch the live exercise" moved into the picker,
///   which disables the other exercises' rows (see player_target_picker_test).
const _planUuid = 'prog-badge';
const _exerciseUuid = 'ex-badge';
const _roleUuid = 'role-badge';

Exercise _exercise() => Exercise(
  uuid: _exerciseUuid,
  index: 0,
  name: 'Badge Exercise',
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
  ExerciseService().stop();
  final prefs = await SharedPreferences.getInstance();
  final repo = PlanRepository(prefs);
  await repo.savePlanShell(_shell());
  await repo.setActivePlanUuid(_planUuid);
  await repo.saveExercise(_exercise());
  await repo.saveRolePlay(
    const RolePlay(
      uuid: _roleUuid,
      index: 0,
      exerciseUuid: _exerciseUuid,
      stationIndex: 1,
      name: 'Savnet person',
    ),
  );
  await PlanService().init();
}

/// [onOpen] null mirrors the in-player hosts: there is nothing to open, so the
/// strip navigates instead. Pass a callback to mirror a docked bar.
Widget _harness(
  PlayerMode mode, {
  bool interactive = true,
  VoidCallback? onOpen,
}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: DrillMiniPlayer(
      exercise: _exercise(),
      mode: mode,
      onOpen: onOpen,
      onPickTarget: interactive ? (_) {} : null,
    ),
  ),
);

/// True when the badge carries its own tap target. Keyed rather than
/// tap-and-observe, because an inert badge must not merely ignore the tap — it
/// must present no affordance (ripple) at all. And keyed rather than
/// `find.ancestor(matching: InkWell)`, because the whole strip is an InkWell
/// (its `onOpen`), so every badge has one of those above it either way.
bool _badgeIsTappable(WidgetTester tester) =>
    tester.any(find.byKey(const Key('drill-mini-player-badge')));

/// Starts the exercise and settles one frame. Stopping again before the test
/// ends is not cosmetic: the service holds a periodic timer, and a pending
/// timer at teardown fails the test.
Future<void> _start(WidgetTester tester) async {
  ExerciseService().start(_exercise());
  await tester.pump();
}

Future<void> _stop(WidgetTester tester) async {
  ExerciseService().stop();
  await tester.pump();
}

late AppLocalizations _l10n;

void main() {
  setUpAll(() async {
    _l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  setUp(_seedAndInit);

  group('badge kind follows the mode', () {
    testWidgets('exercise mode renders the exercise badge', (tester) async {
      await tester.pumpWidget(_harness(const ExercisePlayerMode()));
      await tester.pump();

      expect(find.byType(ExerciseNumberBadge), findsOneWidget);
      expect(find.byType(StationNumberBadge), findsNothing);
      expect(find.byType(RoleNumberBadge), findsNothing);
      expect(find.text('#1'), findsOneWidget);
    });

    testWidgets('station mode renders the station badge', (tester) async {
      await tester.pumpWidget(_harness(const StationPlayerMode(1)));
      await tester.pump();

      expect(find.byType(StationNumberBadge), findsOneWidget);
      expect(find.byType(ExerciseNumberBadge), findsNothing);
      expect(find.text('1.2'), findsOneWidget);
    });

    testWidgets('roleplay mode renders the markør badge', (tester) async {
      await tester.pumpWidget(_harness(const RolePlayerMode(_roleUuid)));
      await tester.pump();

      expect(find.byType(RoleNumberBadge), findsOneWidget);
      expect(find.byType(ExerciseNumberBadge), findsNothing);
      // Station code plus the role's 1-based number at that post.
      expect(find.text('1.2-1'), findsOneWidget);
    });

    testWidgets('team mode renders the team badge', (tester) async {
      await tester.pumpWidget(_harness(const TeamPlayerMode(1)));
      await tester.pump();

      expect(find.byType(TeamNumberBadge), findsOneWidget);
      expect(find.byType(ExerciseNumberBadge), findsNothing);
      // A bare 1-based number — teams have no sub-division to encode, and the
      // team's *name* lives in the surface's title, not in a 36px badge.
      expect(find.text('2'), findsOneWidget);
    });

    // A roleplay deleted while the bar is up must not throw: the host screen's
    // own gone-state pane is what tells the user.
    testWidgets('an unknown roleplay degrades to a "?" label', (tester) async {
      await tester.pumpWidget(_harness(const RolePlayerMode('does-not-exist')));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('1.?'), findsOneWidget);
    });
  });

  group('interactivity', () {
    testWidgets('idle: the exercise badge is tappable', (tester) async {
      await tester.pumpWidget(_harness(const ExercisePlayerMode()));
      await tester.pump();

      expect(_badgeIsTappable(tester), isTrue);
    });

    testWidgets('no callback: the badge presents no affordance', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(const ExercisePlayerMode(), interactive: false),
      );
      await tester.pump();

      expect(_badgeIsTappable(tester), isFalse);
    });

    // Was the opposite assertion: the badge used to go inert here, which is the
    // reported bug — in play mode neither badge nor strip responded, so there was
    // no way to reach the running exercise's own posts, markers or teams.
    testWidgets('running: the exercise badge stays tappable', (tester) async {
      await tester.pumpWidget(_harness(const ExercisePlayerMode()));
      await _start(tester);

      expect(find.byType(ExerciseNumberBadge), findsOneWidget);
      expect(_badgeIsTappable(tester), isTrue);

      await _stop(tester);
    });

    testWidgets('running: the station badge stays tappable', (tester) async {
      await tester.pumpWidget(_harness(const StationPlayerMode(1)));
      await _start(tester);

      expect(find.byType(StationNumberBadge), findsOneWidget);
      expect(_badgeIsTappable(tester), isTrue);

      await _stop(tester);
    });

    testWidgets('running: the markør badge stays tappable', (tester) async {
      await tester.pumpWidget(_harness(const RolePlayerMode(_roleUuid)));
      await _start(tester);

      expect(find.byType(RoleNumberBadge), findsOneWidget);
      expect(_badgeIsTappable(tester), isTrue);

      await _stop(tester);
    });

    testWidgets('running: the team badge stays tappable', (tester) async {
      await tester.pumpWidget(_harness(const TeamPlayerMode(0)));
      await _start(tester);

      expect(find.byType(TeamNumberBadge), findsOneWidget);
      expect(_badgeIsTappable(tester), isTrue);

      await _stop(tester);
    });
  });

  // Tapping the bar anywhere — not just the 36px badge — opens the picker when
  // the bar is already inside the surface it describes. A docked bar keeps
  // opening the player instead.
  group('the strip as a tap target', () {
    testWidgets('with no onOpen, tapping the strip opens the picker', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(const StationPlayerMode(1)));
      await tester.pump();

      await tester.tap(find.byType(MiniRoundRow));
      await tester.pumpAndSettle();

      expect(find.text(_l10n.pickerGoToTitle), findsOneWidget);
    });

    testWidgets('with onOpen, tapping the strip opens that instead', (
      tester,
    ) async {
      var opened = 0;
      await tester.pumpWidget(
        _harness(const StationPlayerMode(1), onOpen: () => opened++),
      );
      await tester.pump();

      await tester.tap(find.byType(MiniRoundRow));
      await tester.pumpAndSettle();

      expect(opened, 1);
      expect(find.text(_l10n.pickerGoToTitle), findsNothing);
    });

    // Was asserting the opposite: the strip used to stay inert here, which is the
    // reported bug — in play mode neither strip nor badge responded at all.
    testWidgets('running in exercise mode, the strip opens the picker', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(const ExercisePlayerMode()));
      await _start(tester);

      await tester.tap(find.byType(MiniRoundRow));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text(_l10n.pickerGoToTitle), findsOneWidget);

      await _stop(tester);
    });

    testWidgets('running in station mode, the strip does open it', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(const StationPlayerMode(1)));
      await _start(tester);

      await tester.tap(find.byType(MiniRoundRow));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text(_l10n.pickerGoToTitle), findsOneWidget);

      await _stop(tester);
    });
  });

  // Anti-drift: the running and idle strips used to compute the label
  // independently. Same inputs must give the same badge either way.
  group('one label, both states', () {
    for (final (name, mode) in <(String, PlayerMode)>[
      ('exercise', ExercisePlayerMode()),
      ('station', StationPlayerMode(1)),
      ('roleplay', RolePlayerMode(_roleUuid)),
      ('team', TeamPlayerMode(1)),
    ]) {
      testWidgets('$name mode reads the same idle and running', (tester) async {
        await tester.pumpWidget(_harness(mode));
        await tester.pump();
        final idle = _badgeLabel(tester);

        await _start(tester);
        final running = _badgeLabel(tester);

        expect(running, idle);

        await _stop(tester);
      });
    }
  });
}

/// The text inside whichever badge the bar rendered.
String _badgeLabel(WidgetTester tester) {
  final badge = find.byWidgetPredicate(
    (w) =>
        w is ExerciseNumberBadge ||
        w is StationNumberBadge ||
        w is RoleNumberBadge ||
        w is TeamNumberBadge,
  );
  expect(badge, findsOneWidget);
  return tester
      .widget<Text>(find.descendant(of: badge, matching: find.byType(Text)))
      .data!;
}
