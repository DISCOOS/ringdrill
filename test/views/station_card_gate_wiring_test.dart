// The station viewer's *cards* consult the gate, not just its AppBar pencil.
//
// Same failure mode as `edit_gate_wiring_test`: `canEdit`/`canCreate` were correct and
// the pencil asked them, while the Personer and Lokasjoner cards below reached the same
// editors by another door — ungated by role, and still live during a running drill. This
// asserts every affordance in those cards asks, with the two questions kept apart the
// way ADR-0057 states them: the role *hides*, the run *disables*.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/location.dart';
import 'package:ringdrill/models/person.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/staff.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/app_user_role.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/services/plan_service.dart';
import 'package:ringdrill/views/station_screen.dart';
import 'package:ringdrill/views/widgets/cast_pill.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _planUuid = 'plan-card-gate';
const _exerciseUuid = 'ex-card-gate';

/// Two persons on purpose: one with a marker (so its row opens the *spill* editor —
/// a roleplay edit) and one without (so its row opens the *person* editor — station
/// work). The row's permission depends on which, which is the subtlety worth pinning.
const _hilde = Person(slug: 'hilde', name: 'Hilde');
const _kari = Person(slug: 'kari', name: 'Kari Fiskeløs');
const _lkp = Location(slug: 'lkp', label: 'LKP', kind: LocationKind.lkp);

const _actor = Staff(uuid: 'actor-1', realName: 'Ola Nordmann');
const _roleForHilde = RolePlay(
  uuid: 'role-hilde',
  index: 0,
  exerciseUuid: _exerciseUuid,
  stationIndex: 0,
  name: 'Hilde',
  personRef: 'hilde',
  staffUuid: 'actor-1',
);

Exercise _exercise() => Exercise(
  uuid: _exerciseUuid,
  name: 'Gate Exercise',
  startTime: const SimpleTimeOfDay(hour: 8, minute: 0),
  numberOfTeams: 1,
  numberOfRounds: 1,
  executionTime: 10,
  evaluationTime: 5,
  rotationTime: 2,
  stations: const [
    Station(
      index: 0,
      name: 'Post 1',
      persons: [_hilde, _kari],
      locations: [_lkp],
    ),
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

Map<String, Object> _prefs() => {
  'app:activePlan:v1': _planUuid,
  'app:librarySchema:v1': '1',
  'p:$_planUuid': jsonEncode({
    'uuid': _planUuid,
    'name': 'Card Gate Plan',
    'description': '',
    'metadata': {
      'created': '2026-01-01T00:00:00.000Z',
      'updated': '2026-01-01T00:00:00.000Z',
      'version': '1.1',
    },
    'exercises': [],
    'teams': [],
    'sessions': [],
    'rolePlays': [],
    'actors': [],
  }),
  'pe:$_planUuid:$_exerciseUuid': jsonEncode(_exercise().toJson()),
  'pr:$_planUuid:${_roleForHilde.uuid}': jsonEncode(_roleForHilde.toJson()),
  'pa:$_planUuid:${_actor.uuid}': jsonEncode(_actor.toJson()),
};

/// Pumps the viewer. The run is started *before* pumping when [running], because
/// `_isStarted` is read as the screen loads — which is the state the report describes:
/// opening a post while the drill is already going.
Future<AppLocalizations> _pump(
  WidgetTester tester, {
  bool running = false,
}) async {
  tester.view.physicalSize = const Size(420, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  if (running) ExerciseService().start(_exercise());

  await tester.pumpWidget(
    MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) =>
                const StationScreen(stationIndex: 0, uuid: _exerciseUuid),
          ),
        ],
      ),
    ),
  );
  await _settle(tester, running: running);

  // The two cards live on the Script segment; the viewer opens on Info. This is the
  // state the report was taken in.
  final l10n = await AppLocalizations.delegate.load(const Locale('en'));
  await tester.tap(find.text(l10n.scriptTab));
  await _settle(tester, running: running);
  return l10n;
}

/// A running drill ticks once a second, so its tree never goes quiet and
/// `pumpAndSettle` times out. Pump a fixed handful of frames instead — enough for the
/// segment switch and the card build, which is all these tests look at.
Future<void> _settle(WidgetTester tester, {required bool running}) async {
  if (!running) {
    await tester.pumpAndSettle();
    return;
  }
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Pumps the viewer with the drill going, runs [body], then stops the clock *inside*
/// the test body.
///
/// The stop cannot be left to `tearDown`: the binding asserts no timer is pending as
/// soon as the body returns, which fails the test even when every assertion passed.
Future<void> _whileRunning(
  WidgetTester tester,
  Future<void> Function(AppLocalizations l) body,
) async {
  final l = await _pump(tester, running: true);
  try {
    await body(l);
  } finally {
    ExerciseService().stop();
    await tester.pump();
  }
}

/// The innermost `InkWell` wrapping [inner] — the affordance that owns it.
InkWell _tapTarget(WidgetTester tester, Finder inner) => tester.widget<InkWell>(
  find.ancestor(of: inner, matching: find.byType(InkWell)).first,
);

bool _enabled(WidgetTester tester, Finder inner) =>
    _tapTarget(tester, inner).onTap != null;

CastPill _pillOn(WidgetTester tester, String label) =>
    tester.widget<CastPill>(_pillFinder(label));

Finder _pillFinder(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(CastPill));

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(_prefs());
    await PlanService().init();
    ExerciseService().stop();
    appUserRole.value = StaffRole.director;
    addTearDown(() {
      ExerciseService().stop();
      appUserRole.value = StaffRole.director;
    });
  });

  group('a director, nothing running', () {
    testWidgets('both cards offer their add action, live', (tester) async {
      final l = await _pump(tester);

      expect(find.text(l.personsSectionAddAction), findsOneWidget);
      expect(find.text(l.locationsSectionAddAction), findsOneWidget);
      expect(_enabled(tester, find.text(l.personsSectionAddAction)), isTrue);
      expect(_enabled(tester, find.text(l.locationsSectionAddAction)), isTrue);
    });

    testWidgets('and the rows open their editors', (tester) async {
      await _pump(tester);

      expect(_enabled(tester, find.text('Kari Fiskeløs')), isTrue);
      expect(_enabled(tester, find.text('LKP')), isTrue);
    });
  });

  group('a director, while this exercise runs', () {
    // The reported bug. The pencil was already dead here; these were not.
    testWidgets('the add actions stay visible but go inert', (tester) async {
      await _whileRunning(tester, (l) async {
        expect(
          find.text(l.personsSectionAddAction),
          findsOneWidget,
          reason: 'a temporary freeze explains itself rather than vanishing',
        );
        expect(_enabled(tester, find.text(l.personsSectionAddAction)), isFalse);
        expect(
          _enabled(tester, find.text(l.locationsSectionAddAction)),
          isFalse,
        );
      });
    });

    testWidgets('and say why, naming the exercise to stop', (tester) async {
      await _whileRunning(tester, (l) async {
        expect(
          find.byTooltip(l.stopExerciseFirst('Gate Exercise')),
          findsNWidgets(3),
          reason:
              'one per card, plus the AppBar pencil that has always said this — '
              'they explain the same freeze, so they say the same sentence',
        );
      });
    });

    testWidgets('a person row no longer opens the person editor', (
      tester,
    ) async {
      await _whileRunning(tester, (l) async {
        expect(_enabled(tester, find.text('Kari Fiskeløs')), isFalse);
        expect(_enabled(tester, find.text('LKP')), isFalse);
        // The rows themselves stay: they are the scenario a marker reads off the
        // screen during the drill, not affordances.
        expect(find.text('Kari Fiskeløs'), findsOneWidget);
        expect(find.text('LKP'), findsOneWidget);
      });
    });

    testWidgets('but a marker can still be recast, and its spill opened', (
      tester,
    ) async {
      // ADR-0057's one live exemption, and the reason it exists: adjusting a markør
      // mid-scenario is the point. Editing a roleplay survives the lock; *creating*
      // one does not, which is why the two pills differ.
      await _whileRunning(tester, (l) async {
        expect(_pillOn(tester, _actor.realName).onTap, isNotNull);
        expect(_enabled(tester, find.text('Hilde')), isTrue);
      });
    });

    testWidgets('while adding a marker is frozen like any other structure', (
      tester,
    ) async {
      await _whileRunning(tester, (l) async {
        expect(
          _pillOn(tester, l.personsSectionAddMarkerAction).onTap,
          isNull,
          reason: 'canCreate has no roleplay exemption',
        );
      });
    });
  });

  group('a role that never gets these actions', () {
    testWidgets('an actor sees no add action at all', (tester) async {
      // Hidden, not disabled: an action this role will never have is noise.
      appUserRole.value = StaffRole.actor;
      final l = await _pump(tester);

      expect(find.text(l.personsSectionAddAction), findsNothing);
      expect(find.text(l.locationsSectionAddAction), findsNothing);
      // And the content is untouched.
      expect(find.text('Kari Fiskeløs'), findsOneWidget);
      expect(find.text('LKP'), findsOneWidget);
    });

    testWidgets('nor an instructor', (tester) async {
      appUserRole.value = StaffRole.instructor;
      final l = await _pump(tester);

      expect(find.text(l.personsSectionAddAction), findsNothing);
      expect(find.text(l.locationsSectionAddAction), findsNothing);
    });

    testWidgets('an actor cannot open a person or a location editor', (
      tester,
    ) async {
      // Persons and locations answer as `station`, which is director-only. An actor
      // *overrides* them through the roleplay rather than editing them here.
      appUserRole.value = StaffRole.actor;
      await _pump(tester);

      expect(_enabled(tester, find.text('Kari Fiskeløs')), isFalse);
      expect(_enabled(tester, find.text('LKP')), isFalse);
    });

    testWidgets('but an actor can open a spill and recast it', (tester) async {
      // The delegation that makes the actor role worth having.
      appUserRole.value = StaffRole.actor;
      await _pump(tester);

      expect(_enabled(tester, find.text('Hilde')), isTrue);
      expect(_pillOn(tester, _actor.realName).onTap, isNotNull);
    });
  });
}
