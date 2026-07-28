import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/plan_service.dart';
import 'package:ringdrill/views/plan_view.dart';
import 'package:ringdrill/views/shell/app_router.dart';
import 'package:ringdrill/views/widgets/context_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A "selection" means "this is what the master/detail pane is showing", so it
/// only exists in a layout that *has* one.
///
/// `MainScreen`'s selection-memory listeners run off `ValueNotifier`s, outside
/// any `LayoutBuilder`, and used to stand in `ContextSheetController.isModal`
/// for "am I narrow?". That is a different question, and it answers "no" in the
/// compact layout whenever no modal happens to be up — so a Plan-segment switch
/// adopted a selection into nothing, leaving the controller "open" on a target
/// no surface was rendering. Two consequences: `showOrReplace` short-circuited
/// to `replace` and wrote later opens into the void (so an item could be opened
/// once and then never again), and the wide sync branch could `router.go` the
/// compact layout to a segment the user never asked for.
const _planUuid = 'plan-detail-selection-scope';
const _exerciseAUuid = 'exercise-detail-selection-a';
const _exerciseBUuid = 'exercise-detail-selection-b';

Exercise _exercise({
  required String uuid,
  required String name,
  required String stationName,
  required int hour,
}) => Exercise(
  uuid: uuid,
  name: name,
  startTime: SimpleTimeOfDay(hour: hour, minute: 0),
  numberOfTeams: 1,
  numberOfRounds: 1,
  executionTime: 10,
  evaluationTime: 5,
  rotationTime: 2,
  stations: [Station(index: 0, name: stationName)],
  schedule: [
    [
      SimpleTimeOfDay(hour: hour, minute: 0),
      SimpleTimeOfDay(hour: hour, minute: 10),
      SimpleTimeOfDay(hour: hour, minute: 15),
    ],
  ],
  endTime: SimpleTimeOfDay(hour: hour, minute: 17),
);

Map<String, Object> _prefs() {
  final a = _exercise(
    uuid: _exerciseAUuid,
    name: 'Exercise A',
    stationName: 'Station A1',
    hour: 8,
  );
  final b = _exercise(
    uuid: _exerciseBUuid,
    name: 'Exercise B',
    stationName: 'Station B1',
    hour: 9,
  );
  return {
    'app:activePlan:v1': _planUuid,
    'app:librarySchema:v1': '1',
    'p:$_planUuid': jsonEncode({
      'uuid': _planUuid,
      'name': 'Detail Selection Plan',
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
    'pe:$_planUuid:$_exerciseAUuid': jsonEncode(a.toJson()),
    'pe:$_planUuid:$_exerciseBUuid': jsonEncode(b.toJson()),
  };
}

Future<void> _pumpApp(WidgetTester tester, {required Size size}) async {
  tester.view.physicalSize = size;
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

/// The shell's own controller, read through any widget inside it.
ContextSheetController _controller(WidgetTester tester) =>
    ContextSheet.maybeOf(tester.element(find.byType(PlanView).first))!;

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

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues(_prefs());
    await PlanService().init();
  });

  testWidgets('compact: opening an item, closing it and switching segments '
      'leaves no selection behind', (tester) async {
    await _pumpApp(tester, size: const Size(400, 800));

    // Nothing is auto-selected in compact — there is no pane to fill.
    expect(_controller(tester).isOpen, isFalse);
    expect(_controller(tester).target.value, isNull);

    // Open an exercise from the list, then close it.
    await tester.tap(find.text('Exercise B').first);
    await tester.pumpAndSettle();
    expect(_controller(tester).isModal, isTrue);
    _controller(tester).close();
    await tester.pumpAndSettle();
    expect(_controller(tester).isOpen, isFalse);

    // The segment-memory restore fires here. In compact it must not adopt the
    // remembered pick: nothing would be rendering it.
    await _tapSegment(tester, l10n.stationsTab);
    await _tapSegment(tester, l10n.exercise(2));

    expect(
      _controller(tester).isOpen,
      isFalse,
      reason: 'a compact layout has no detail pane to hold a selection',
    );
    expect(_controller(tester).target.value, isNull);
  });

  // The reported bug, end to end: it survived a close and a segment switch only
  // because showOrReplace saw a bogus "open" controller and replaced into it.
  testWidgets('compact: an item can be reopened after closing it', (
    tester,
  ) async {
    await _pumpApp(tester, size: const Size(400, 800));

    await tester.tap(find.text('Exercise B').first);
    await tester.pumpAndSettle();
    expect(find.text('Station B1'), findsOneWidget);

    _controller(tester).close();
    await tester.pumpAndSettle();
    expect(find.text('Station B1'), findsNothing);

    await _tapSegment(tester, l10n.stationsTab);
    await _tapSegment(tester, l10n.exercise(2));

    await tester.tap(find.text('Exercise B').first);
    await tester.pumpAndSettle();

    expect(find.text('Station B1'), findsOneWidget);
  });

  // Reported as intermittent: reloading the browser on a segment auto-selected
  // fine, but switching segments *rapidly* left the list unselected. The
  // restore used to write null and leave `build`'s auto-select-first to refill
  // on a later frame — a two-step transition whose empty middle a fast switch
  // lands in, with no further frame scheduled to finish the job. Switching
  // twice without pumping in between is that race, made deterministic.
  testWidgets('wide: rapid segment switching never leaves the pane empty', (
    tester,
  ) async {
    await _pumpApp(tester, size: const Size(1200, 800));
    expect(_controller(tester).isOpen, isTrue);

    final segments = find.byType(SegmentedButton<PlanSegment>);
    // No pumpAndSettle between the taps: the second switch arrives before the
    // frame that would have refilled the pane after the first.
    await tester.tap(
      find.descendant(of: segments, matching: find.text(l10n.stationsTab)),
    );
    await tester.tap(
      find.descendant(of: segments, matching: find.text(l10n.exercise(2))),
    );
    await tester.pumpAndSettle();

    expect(
      _controller(tester).target.value,
      isNotNull,
      reason: 'the detail pane must never be left with nothing selected',
    );
    expect(_controller(tester).isOpen, isTrue);
  });

  // The other half of the invariant: the wide layout must still adopt, or the
  // detail pane would sit empty and its leading chevron would make no sense.
  testWidgets(
    'wide: a selection is adopted and survives a segment round trip',
    (tester) async {
      await _pumpApp(tester, size: const Size(1200, 800));

      // Auto-select-first fills the pane without a tap.
      expect(_controller(tester).isOpen, isTrue);
      expect(find.text('Station A1'), findsOneWidget);

      await tester.tap(find.text('Exercise B').first);
      await tester.pumpAndSettle();
      expect(find.text('Station B1'), findsOneWidget);

      await _tapSegment(tester, l10n.stationsTab);
      await _tapSegment(tester, l10n.exercise(2));

      expect(_controller(tester).isOpen, isTrue);
      expect(
        find.text('Station B1'),
        findsOneWidget,
        reason: 'the remembered pick is restored, not discarded',
      );
    },
  );
}
