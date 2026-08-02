import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/plan_service.dart';
import 'package:ringdrill/views/coordinator_screen.dart';
import 'package:ringdrill/views/widgets/card_section_header.dart';
import 'package:ringdrill/views/widgets/schedule_card.dart';
import 'package:ringdrill/views/widgets/schedule_table.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Fixtures — DESIGN-010 stage 3f: coordinator_screen.dart's team-detail
// schedule migrated from PhaseHeaders + Card-wrapped ScheduleRows onto the
// shared ScheduleCard (last such occurrence in the codebase). Mirrors the
// fixture already used for the 3e team_screen_test.dart migration.
//
// The DESIGN-010 coordinator-play-and-status-polish follow-up (B1) also put
// the coordinator's own top-of-body round table onto a ScheduleCard, so a
// running coordinator now shows two ScheduleCards at once: the always-
// visible one above the segmented selector, and (once a team row is
// expanded) this test's team-detail one. Assertions below scope to the
// *second* ScheduleCard (index 1) to stay unambiguous.
// ---------------------------------------------------------------------------

const _planUuid = 'prog-coordinator-team-detail';
const _exerciseUuid = 'ex-coordinator-team-detail';

Exercise _exercise() => Exercise(
  uuid: _exerciseUuid,
  name: 'Coordinator Team Detail Test Exercise',
  startTime: const SimpleTimeOfDay(hour: 8, minute: 0),
  numberOfTeams: 1,
  numberOfRounds: 2,
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
    [
      SimpleTimeOfDay(hour: 8, minute: 20),
      SimpleTimeOfDay(hour: 8, minute: 30),
      SimpleTimeOfDay(hour: 8, minute: 35),
    ],
  ],
  endTime: const SimpleTimeOfDay(hour: 9, minute: 0),
);

Map<String, Object> _basePrefs() {
  final ex = _exercise();
  return {
    'app:activePlan:v1': _planUuid,
    'app:librarySchema:v1': '1',
    'p:$_planUuid': jsonEncode({
      'uuid': _planUuid,
      'name': 'Test Plan',
      'description': '',
      'metadata': {
        'created': '2024-01-01T00:00:00.000Z',
        'updated': '2024-01-01T00:00:00.000Z',
        'version': '1.1',
      },
      'exercises': [],
      'teams': [],
      'sessions': [],
      'rolePlays': [],
      'actors': [],
    }),
    'pe:$_planUuid:$_exerciseUuid': jsonEncode(ex.toJson()),
  };
}

Future<void> _seedAndInit() async {
  SharedPreferences.setMockInitialValues(_basePrefs());
  await PlanService().init();
}

Widget _harness(Widget widget) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: widget,
);

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  setUp(() async {
    await _seedAndInit();
  });

  testWidgets(
    'the team-detail schedule renders via the shared ScheduleCard, not '
    'PhaseHeaders + Card-wrapped ScheduleRows',
    (tester) async {
      await tester.pumpWidget(
        _harness(const CoordinatorScreen(uuid: _exerciseUuid)),
      );
      await tester.pumpAndSettle();

      // Switch from the default "Stations" segment to "Teams". By label, not by
      // icon: a four-segment selector carries no icons — four labels plus four
      // icons overflow a phone (`view_segments.dart`).
      final l = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.tap(find.text(l.team(1)).first);
      await tester.pumpAndSettle();

      // Expand the (only) team row. The rotation timetable is no longer
      // pinned above the selector — it moved into the Info segment — so on
      // the Teams segment the team tile's own chevron is the only one.
      await tester.tap(find.byIcon(Icons.expand_more).last);
      await tester.pumpAndSettle();

      // Renders through the shared ScheduleCard (CardSectionHeader + bordered
      // ScheduleTable) — same as the Post/Spill viewers and the other team
      // surfaces — not the old bare per-round Card-wrapped rows. The rotation
      // timetable used to be a second ScheduleCard pinned above the selector;
      // it now lives in the Info segment, so the team-detail card is the only
      // one on this segment.
      final scheduleCardFinders = find.byType(ScheduleCard);
      expect(scheduleCardFinders, findsOneWidget);
      final scheduleCardFinder = scheduleCardFinders.first;
      expect(
        find.descendant(
          of: scheduleCardFinder,
          matching: find.byType(CardSectionHeader),
        ),
        findsOneWidget,
      );
      expect(
        find.text(l10n.stationTimingCardTitle.toUpperCase()),
        findsOneWidget,
        reason: 'the ScheduleCard section header carries the shared title',
      );

      final tableWithinCard = find.descendant(
        of: scheduleCardFinder,
        matching: find.byType(ScheduleTable),
      );
      expect(tableWithinCard, findsOneWidget);
      expect(
        find.descendant(of: tableWithinCard, matching: find.byType(Card)),
        findsNothing,
        reason: 'the old per-round Card-wrapped rows are gone',
      );

      // Both stations' rounds are listed, in order (now prefixed with the
      // formatted post number, e.g. "1.1 Post 1").
      expect(find.textContaining('Post 1'), findsOneWidget);
      expect(find.textContaining('Post 2'), findsOneWidget);

      // The team-detail table's own header row, still scoped to the card.
      expect(
        find.descendant(
          of: tableWithinCard,
          matching: find.text(l10n.drill.toUpperCase()),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: tableWithinCard,
          matching: find.text(l10n.eval.toUpperCase()),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: tableWithinCard,
          matching: find.text(l10n.roll.toUpperCase()),
        ),
        findsOneWidget,
      );
    },
  );
}
