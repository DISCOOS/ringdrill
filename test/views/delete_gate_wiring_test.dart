import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/data/plan_repository.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/staff.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/plan.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/app_user_role.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/services/plan_service.dart';
import 'package:ringdrill/utils/prefs.dart';
import 'package:ringdrill/views/coordinator_screen.dart';
import 'package:ringdrill/views/roleplay_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Deleting is gated separately from editing (ADR-0057).
///
/// The distinction these tests exist for: an actor authors a markør's script, so
/// the *pencil* stays — but the *bin* must not, and the two sit side by side in
/// the same AppBar. A gate that asked `canEdit` for both would look correct and
/// hand an actor the delete button.
///
/// Also covers the overflow menu the wide layout hides: gating only the visible
/// icons leaves the compact layout's `⋮` entries reachable, which is where this
/// hole was actually reported.
const _planUuid = 'plan-delete-gate';
const _exerciseUuid = 'exercise-delete-gate';
const _roleUuid = 'role-delete-gate';
const _actorUuid = 'actor-delete-gate';

Plan _shell() {
  final now = DateTime.utc(2026, 1, 1);
  return Plan(
    uuid: _planUuid,
    name: 'Delete Gate Plan',
    description: '',
    metadata: PlanMetadata(created: now, updated: now, version: '1.0'),
    teams: const [],
    sessions: const [],
    exercises: const [],
    staff: const [Staff(uuid: _actorUuid, realName: 'Nina Staff')],
  );
}

Exercise _exercise() => Exercise(
  uuid: _exerciseUuid,
  index: 0,
  name: 'Delete Gate Exercise',
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

RolePlay _rolePlay() => const RolePlay(
  uuid: _roleUuid,
  index: 0,
  exerciseUuid: _exerciseUuid,
  stationIndex: 0,
  name: 'Hilde',
  staffUuid: _actorUuid,
  position: LatLng(59.92, 10.76),
);

Future<void> _seed() async {
  SharedPreferences.setMockInitialValues({});
  PlanService().reset();
  Prefs.reset();
  final prefs = await SharedPreferences.getInstance();
  Prefs.bind(prefs);
  addTearDown(Prefs.reset);
  final repo = PlanRepository(prefs);
  await repo.savePlanShell(_shell());
  await repo.setActivePlanUuid(_planUuid);
  await repo.saveExercise(_exercise());
  await repo.saveStaff(const Staff(uuid: _actorUuid, realName: 'Nina Staff'));
  await repo.saveRolePlay(_rolePlay());
  await PlanService().init();
}

Future<void> _pump(WidgetTester tester, Widget home) async {
  // Compact, so the exercise viewer renders its overflow menu rather than the
  // standalone icons — the half that was left ungated.
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );
  await tester.pumpAndSettle();
}

/// The bin's [IconButton], whatever wraps it.
Finder get _bin => find.widgetWithIcon(IconButton, Icons.delete);
Finder get _pencil => find.widgetWithIcon(IconButton, Icons.edit);

bool _enabled(WidgetTester tester, Finder finder) =>
    tester.widget<IconButton>(finder).onPressed != null;

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  setUp(() async {
    await _seed();
    ExerciseService().stop();
    appUserRole.value = AppUserRole.director;
    addTearDown(() => appUserRole.value = AppUserRole.director);
  });

  group('the roleplay viewer', () {
    testWidgets('a director gets both the pencil and the bin', (tester) async {
      await _pump(tester, const RolePlayScreen(uuid: _roleUuid));

      expect(_pencil, findsOneWidget);
      expect(_bin, findsOneWidget);
    });

    // The whole reason canDelete exists as its own function.
    testWidgets('an actor keeps the pencil but loses the bin', (tester) async {
      appUserRole.value = AppUserRole.actor;
      await _pump(tester, const RolePlayScreen(uuid: _roleUuid));

      expect(
        _pencil,
        findsOneWidget,
        reason: 'a markør\'s script is the actor\'s to write',
      );
      expect(
        _bin,
        findsNothing,
        reason: 'authoring the script does not authorise deleting the markør',
      );
    });

    testWidgets('an instructor gets neither', (tester) async {
      appUserRole.value = AppUserRole.instructor;
      await _pump(tester, const RolePlayScreen(uuid: _roleUuid));

      expect(_pencil, findsNothing);
      expect(_bin, findsNothing);
    });

    // canEdit exempts roleplays from the live lock on purpose; canDelete does
    // not. Both halves asserted together, because the exemption is what makes
    // this pair easy to get wrong.
    testWidgets('while the exercise runs, the pencil works and the bin does '
        'not', (tester) async {
      await _pump(tester, const RolePlayScreen(uuid: _roleUuid));
      expect(_enabled(tester, _bin), isTrue);

      ExerciseService().start(_exercise());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        _enabled(tester, _pencil),
        isTrue,
        reason: 'adjusting a markør mid-scenario is the point',
      );
      expect(
        _enabled(tester, _bin),
        isFalse,
        reason: 'deleting one the running exercise references is data loss',
      );

      ExerciseService().stop();
      await tester.pump();
    });
  });

  // Reported against the compact overflow menu specifically: the wide layout's
  // icons and the compact menu are separate code paths, and only one of them
  // being gated is indistinguishable from neither at a glance.
  group('the exercise viewer overflow menu', () {
    testWidgets('a director can open it and reach both actions', (
      tester,
    ) async {
      await _pump(tester, CoordinatorScreen(uuid: _exerciseUuid));

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.text(l10n.editExercise), findsOneWidget);
      expect(find.text(l10n.deleteExercise), findsOneWidget);
    });

    testWidgets('an actor has no menu at all', (tester) async {
      appUserRole.value = AppUserRole.actor;
      await _pump(tester, CoordinatorScreen(uuid: _exerciseUuid));

      expect(
        find.byIcon(Icons.more_vert),
        findsNothing,
        reason: 'a menu whose every entry is denied is not worth opening',
      );
    });

    testWidgets('nor an instructor', (tester) async {
      appUserRole.value = AppUserRole.instructor;
      await _pump(tester, CoordinatorScreen(uuid: _exerciseUuid));

      expect(find.byIcon(Icons.more_vert), findsNothing);
    });
  });
}
