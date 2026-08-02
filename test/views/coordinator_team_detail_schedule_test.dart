import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/plan_service.dart';
import 'package:ringdrill/views/coordinator_screen.dart';
import 'package:ringdrill/views/widgets/card_section_header.dart';
import 'package:ringdrill/views/widgets/expandable_tile.dart';
import 'package:ringdrill/views/widgets/position_empty_state.dart';
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
    // A description, so the expanded body has content whose left edge can be
    // compared with the header's.
    Station(index: 0, name: 'Post 1', description: 'Eidene. Finsøk rundt IPP.'),
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

  testWidgets('the team-detail schedule renders via the shared ScheduleCard, not '
      'PhaseHeaders + Card-wrapped ScheduleRows', (tester) async {
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

    // Reported from a phone: the expanded body stepped in past its own header.
    // `ExpandableTile` already insets the body to the same 16 its header uses, so
    // a wrapper `Padding` here put the card 8 further in than the team name above
    // it. Asserted against the header's own left edge rather than a number, so it
    // cannot drift back.
    // The header's own title, which is the first Text in the tile's tree — the
    // header is built before the body. Comparing against it rather than against a
    // number means the assertion survives a change to the tile's insets.
    final headerTitle = find
        .descendant(
          of: find.byType(ExpandableTile).first,
          matching: find.byType(Text),
        )
        .first;
    expect(
      tester.getTopLeft(scheduleCardFinder).dx,
      tester.getTopLeft(headerTitle).dx,
      reason:
          'the nested card starts where the team name does, not one wrapper '
          'further in',
    );
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
  });

  testWidgets('an expanded station body lines up with its own header too', (
    tester,
  ) async {
    // The other half of the report, and the worse half: this body had a wrapper
    // `Padding` *and* one per child, putting the description 32 in while the station
    // badge in the header stayed at 16.
    await tester.pumpWidget(
      _harness(const CoordinatorScreen(uuid: _exerciseUuid)),
    );
    await tester.pumpAndSettle();

    // Stations is the default segment, so only the row needs expanding.
    await tester.tap(find.byIcon(Icons.expand_more).first);
    await tester.pumpAndSettle();

    final tile = find.byType(ExpandableTile).first;
    // The station badge is the leftmost thing in the header, so its *box* is what the
    // body lines up with — not the text inside it, which the badge's own padding
    // indents a further 4.
    final leading = tester.widget<ExpandableTile>(tile).leading;
    expect(leading, isNotNull, reason: 'the station tile carries a badge');
    final description = find.textContaining('Finsøk rundt IPP');
    expect(description, findsOneWidget, reason: 'the body is expanded');

    expect(
      tester.getTopLeft(description).dx,
      tester.getTopLeft(find.byWidget(leading!)).dx,
      reason: 'the description starts where the header content does',
    );
  });

  group('a station with no position teaches, rather than just reporting', () {
    testWidgets('the expanded card shows the teaching state and its action', (
      tester,
    ) async {
      // Was the bare "Posisjon … Ikke satt" row: it says what is missing and leaves
      // the reader to work out the fix. A positioned station shows a mini-map in this
      // slot, so the empty case has to be the same card with teaching where the map
      // goes — not a different-looking one-liner.
      await tester.pumpWidget(
        _harness(const CoordinatorScreen(uuid: _exerciseUuid)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.expand_more).first);
      await tester.pumpAndSettle();

      expect(find.byType(PositionEmptyState), findsWidgets);
      expect(find.text(l10n.noPositionStationBody), findsOneWidget);
      expect(
        find.text(l10n.setPosition),
        findsOneWidget,
        reason: 'a director can fix it from here, so the action is offered',
      );
    });

    testWidgets('the all-stations map names the fix, not just the absence', (
      tester,
    ) async {
      // The map pane had an icon and the words "No location". Plural case, so no
      // action: with a dozen stations, picking one for the reader would be a guess.
      await tester.pumpWidget(
        _harness(const CoordinatorScreen(uuid: _exerciseUuid)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.mapTab));
      await tester.pumpAndSettle();

      expect(find.text(l10n.noPositionTitle), findsOneWidget);
      expect(find.text(l10n.noPositionExerciseBody), findsOneWidget);
      expect(
        find.text(l10n.setPosition),
        findsNothing,
        reason: 'the map cannot know which station to open',
      );
    });
  });
}
