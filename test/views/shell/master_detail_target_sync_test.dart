import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/plan_service.dart';
import 'package:ringdrill/views/plan_view.dart';
import 'package:ringdrill/views/roleplay_list_view.dart';
import 'package:ringdrill/views/roleplay_screen.dart';
import 'package:ringdrill/views/shell/app_router.dart';
import 'package:ringdrill/views/station_screen.dart';
import 'package:ringdrill/views/widgets/context_sheet.dart';
import 'package:ringdrill/views/widgets/expandable_tile.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Covers docs/prompts/design-shell-master-detail-target-sync.md: a redirect
/// that changes the ContextSheetTarget's owning entity kind (e.g. the Spill
/// viewer's post-context card opening its Post) must drag the wide master
/// pane's segment and selection along with it, instead of leaving the master
/// on the segment/row it was on before the redirect fired.
const _planUuid = 'plan-master-detail-sync';
const _exerciseAUuid = 'exercise-sync-a';
const _exerciseBUuid = 'exercise-sync-b';
const _roleUuid = 'role-sync';

final _exerciseA = Exercise(
  uuid: _exerciseAUuid,
  name: 'Exercise A',
  startTime: const SimpleTimeOfDay(hour: 8, minute: 0),
  numberOfTeams: 1,
  numberOfRounds: 1,
  executionTime: 10,
  evaluationTime: 5,
  rotationTime: 2,
  stations: const [Station(index: 0, name: 'Station A1')],
  schedule: const [
    [
      SimpleTimeOfDay(hour: 8, minute: 0),
      SimpleTimeOfDay(hour: 8, minute: 10),
      SimpleTimeOfDay(hour: 8, minute: 15),
    ],
  ],
  endTime: const SimpleTimeOfDay(hour: 8, minute: 17),
);

final _exerciseB = Exercise(
  uuid: _exerciseBUuid,
  name: 'Exercise B',
  startTime: const SimpleTimeOfDay(hour: 9, minute: 0),
  numberOfTeams: 1,
  numberOfRounds: 1,
  executionTime: 10,
  evaluationTime: 5,
  rotationTime: 2,
  stations: const [Station(index: 0, name: 'Station B1')],
  schedule: const [
    [
      SimpleTimeOfDay(hour: 9, minute: 0),
      SimpleTimeOfDay(hour: 9, minute: 10),
      SimpleTimeOfDay(hour: 9, minute: 15),
    ],
  ],
  endTime: const SimpleTimeOfDay(hour: 9, minute: 17),
);

const _rolePlay = RolePlay(
  uuid: _roleUuid,
  index: 0,
  exerciseUuid: _exerciseAUuid,
  stationIndex: 0,
  name: 'Turgåer',
);

Map<String, Object> _prefs() {
  return {
    'app:activePlan:v1': _planUuid,
    'app:librarySchema:v1': '1',
    'p:$_planUuid': jsonEncode({
      'uuid': _planUuid,
      'name': 'Master/Detail Sync Plan',
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
    'pe:$_planUuid:$_exerciseAUuid': jsonEncode(_exerciseA.toJson()),
    'pe:$_planUuid:$_exerciseBUuid': jsonEncode(_exerciseB.toJson()),
    'pr:$_planUuid:$_roleUuid': jsonEncode(_rolePlay.toJson()),
  };
}

Future<void> _pumpApp(WidgetTester tester, {required bool wide}) async {
  tester.view.physicalSize = wide
      ? const Size(1200, 800)
      : const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await PlanService().setActive(_planUuid);
  final router = buildRouter(false, true);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapSegment(WidgetTester tester, String label) async {
  await tester.tap(
    find
        .descendant(
          of: find.byType(SegmentedButton<PlanSegment>),
          matching: find.text(label),
        )
        .hitTestable(),
  );
  await tester.pumpAndSettle();
}

Set<PlanSegment> _selectedSegment(WidgetTester tester) {
  return tester
      .widget<SegmentedButton<PlanSegment>>(
        find.byType(SegmentedButton<PlanSegment>),
      )
      .selected;
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(_prefs());
    await PlanService().init();
  });

  group('segmentForTarget', () {
    test('maps every target kind to its owning segment', () {
      expect(
        segmentForTarget(const ExerciseSheetTarget(exerciseUuid: 'e')),
        PlanSegment.exercises,
      );
      expect(
        segmentForTarget(
          const StationSheetTarget(exerciseUuid: 'e', stationIndex: 0),
        ),
        PlanSegment.stations,
      );
      expect(
        segmentForTarget(const RoleSheetTarget(rolePlayUuid: 'r')),
        PlanSegment.script,
      );
      expect(
        segmentForTarget(
          const TeamSheetTarget(exerciseUuid: 'e', teamIndex: 0),
        ),
        PlanSegment.teams,
      );
      expect(
        segmentForTarget(const TeamOverviewSheetTarget(teamIndex: 0)),
        PlanSegment.teams,
      );
    });

    test('BriefSheetTarget has no owning segment', () {
      expect(
        segmentForTarget(const BriefSheetTarget(planUuid: 'p')),
        isNull,
      );
    });
  });

  testWidgets(
    'a redirect from a purely auto-selected (never explicitly tapped) '
    'detail pane works, instead of asserting on a not-open sheet',
    (tester) async {
      // Regression test for the ContextSheetController._isOpen gap: the
      // wide layout's auto-select-first and per-segment memory-restore used
      // to write the shared target notifier directly instead of going
      // through `show()`, leaving `_isOpen` false. Tapping a context-sheet
      // card's `.replace(...)` from such an auto-selected (never explicitly
      // opened) detail then hit `ContextSheetController`'s "requires an open
      // sheet" assert. `adoptWideSelection` fixes this by marking the
      // controller open the way `show()` would.
      await _pumpApp(tester, wide: true);
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      // Switch to the Spill (script) segment: its only roleplay auto-selects
      // — no explicit master-list tap — opening RolePlayScreen with the
      // station-context card for its linked post (Station A1).
      await _tapSegment(tester, l10n.scriptSegment);
      expect(
        tester.widget<RolePlayScreen>(find.byType(RolePlayScreen)).rolePlayUuid,
        _roleUuid,
      );
      expect(_selectedSegment(tester), {PlanSegment.script});

      // Tapping the post-context card must not throw the "requires an open
      // sheet" assert, and must still redirect correctly.
      await tester.tap(find.text('1.1 Station A1'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(_selectedSegment(tester), {PlanSegment.stations});
      expect(
        tester
            .widget<StationScreen>(find.byType(StationScreen))
            .uuid,
        _exerciseAUuid,
      );
    },
  );

  testWidgets(
    'a cross-segment redirect (Spill post-context card) switches the wide '
    'master to Poster with that station selected, and it sticks',
    (tester) async {
      await _pumpApp(tester, wide: true);
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      // Switch to the Spill (script) segment and explicitly open its only
      // roleplay — an explicit master-list pick, rather than relying on
      // auto-select-first — landing on RolePlayScreen with the
      // station-context card for its linked post (Station A1).
      await _tapSegment(tester, l10n.scriptSegment);
      await tester.tap(
        find.descendant(
          of: find.byType(RolePlayListView),
          matching: find.text('Turgåer'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<RolePlayScreen>(find.byType(RolePlayScreen)).rolePlayUuid,
        _roleUuid,
      );
      expect(_selectedSegment(tester), {PlanSegment.script});

      // The post-context card is the only "Station A1" text on screen at
      // this point (the master list is still showing roleplays).
      await tester.tap(find.text('1.1 Station A1'));
      await tester.pumpAndSettle();

      // The redirect (ContextSheet.replace(StationSheetTarget(...))) must
      // drag the master along: segment switches to Poster...
      expect(_selectedSegment(tester), {PlanSegment.stations});
      // ...and the detail pane shows the Post viewer for that station.
      final detail = tester.widget<StationScreen>(
        find.byType(StationScreen),
      );
      expect(detail.uuid, _exerciseAUuid);
      expect(detail.stationIndex, 0);
      // ...and the master list highlights the same row (Poster now also
      // lists Exercise B's unrelated station, so scope to the tile that
      // actually wraps "Station A1").
      expect(
        tester
            .widget<ExpandableTile>(
              find.ancestor(
                of: find.text('Station A1'),
                matching: find.byType(ExpandableTile),
              ),
            )
            .selected,
        isTrue,
      );

      // Not reverted by a later rebuild (the per-segment selection memory
      // must not race the redirect and clobber it back to null/first).
      await tester.pump();
      await tester.pump();
      expect(find.byType(StationScreen), findsOneWidget);
      expect(find.byType(RolePlayScreen), findsNothing);
    },
  );

  testWidgets('an explicit in-segment pick after a redirect still works and is '
      'remembered per segment', (tester) async {
    await _pumpApp(tester, wide: true);
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    // Land on Poster/Station A1 via the cross-segment redirect.
    await _tapSegment(tester, l10n.scriptSegment);
    await tester.tap(
      find.descendant(
        of: find.byType(RolePlayListView),
        matching: find.text('Turgåer'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('1.1 Station A1'));
    await tester.pumpAndSettle();
    expect(_selectedSegment(tester), {PlanSegment.stations});

    // Explicit in-segment pick: Station B1 (no redirect involved, plain
    // master-list tap) — the existing per-segment memory must still work.
    await tester.tap(find.text('Station B1').first);
    await tester.pumpAndSettle();
    var detail = tester.widget<StationScreen>(
      find.byType(StationScreen),
    );
    expect(detail.uuid, _exerciseBUuid);

    // Switching away and back to Poster restores the explicit pick
    // (Station B1), not the earlier redirect target (Station A1) and not
    // the segment's first item.
    await _tapSegment(tester, l10n.scriptSegment);
    await _tapSegment(tester, l10n.stationsTab);
    detail = tester.widget<StationScreen>(
      find.byType(StationScreen),
    );
    expect(detail.uuid, _exerciseBUuid);
  });

  testWidgets(
    'switching to a segment whose remembered target is cross-segment does not '
    'crash when the switch runs during build (deferred router.go)',
    (tester) async {
      // Regression for the "setState() called during build" crash: an external
      // rebuild drives MainScreen.didUpdateWidget → `_initTab` (during build),
      // whose segment-memory restore reached `router.go`, marking the Router
      // dirty mid-build. The fix defers that `go` to a post-frame callback.
      //
      // A segment only remembers a *cross-segment* target via the narrow modal
      // branch of `_onDetailTargetChangedForSelectionMemory`. Plant it under
      // `script` there, then switch away to `stations` before going wide so
      // wide's auto-select-first does not clobber `script`'s memory. Tapping
      // back to `script` then runs `_initTab` during the router's build and
      // restores that cross-segment target — the crash path.
      await _pumpApp(tester, wide: false);
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      await _tapSegment(tester, l10n.scriptSegment);
      await tester.tap(find.text('Turgåer').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('1.1 Station A1'));
      await tester.pumpAndSettle();
      expect(find.byType(StationScreen), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // Leave script (so its cross-segment memory survives wide entry).
      await _tapSegment(tester, l10n.stationsTab);
      await tester.pumpAndSettle();

      tester.view.physicalSize = const Size(1200, 800);
      await tester.pumpAndSettle();

      // Back to script → `_initTab` restores script's cross-segment Station
      // target during build → deferred router.go. Must not throw.
      await _tapSegment(tester, l10n.scriptSegment);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // The deferred go lands on Poster with that station shown.
      expect(_selectedSegment(tester), {PlanSegment.stations});
      expect(find.byType(StationScreen), findsOneWidget);
    },
  );

  testWidgets(
    'narrow layout is unaffected: a redirect inside the modal sheet does not '
    'touch the underlying segment',
    (tester) async {
      await _pumpApp(tester, wide: false);
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      // No auto-select in narrow: switching segment alone opens nothing.
      await _tapSegment(tester, l10n.scriptSegment);
      expect(find.byType(RolePlayScreen), findsNothing);

      // Explicitly open the roleplay as a full-screen modal sheet.
      await tester.tap(find.text('Turgåer').first);
      await tester.pumpAndSettle();
      expect(find.byType(RolePlayScreen), findsOneWidget);

      // The post-context card still redirects the modal's own content...
      await tester.tap(find.text('1.1 Station A1'));
      await tester.pumpAndSettle();
      expect(find.byType(StationScreen), findsOneWidget);

      // ...but closing it lands back on the Spill segment underneath, not
      // Poster: the narrow layout has no master pane, so the redirect must
      // not have switched `activeSegment`.
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(_selectedSegment(tester), {PlanSegment.script});
      expect(find.text('Turgåer'), findsOneWidget);
    },
  );
}
