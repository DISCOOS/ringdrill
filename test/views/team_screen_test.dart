import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/plan_service.dart';
import 'package:ringdrill/views/phase_headers.dart';
import 'package:ringdrill/views/shell/master_detail_scope.dart';
import 'package:ringdrill/views/team_screen.dart';
import 'package:ringdrill/views/widgets/card_section_header.dart';
import 'package:ringdrill/views/widgets/context_sheet.dart';
import 'package:ringdrill/views/widgets/schedule_card.dart';
import 'package:ringdrill/views/widgets/schedule_table.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Fixtures — DESIGN-010 stage 3e: team_screen.dart's per-exercise schedule
// migrated from PhaseHeaders + Card-wrapped ScheduleRows onto the shared
// ScheduleCard.
// ---------------------------------------------------------------------------

const _planUuid = 'prog-team-screen';
const _exerciseUuid = 'ex-team-screen';

Exercise _exercise() => Exercise(
  uuid: _exerciseUuid,
  name: 'Team Screen Test Exercise',
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
  setUp(() async {
    await _seedAndInit();
  });

  testWidgets(
    'the per-exercise schedule renders via the shared ScheduleCard, not '
    'PhaseHeaders + Card-wrapped ScheduleRows',
    (tester) async {
      await tester.pumpWidget(_harness(const TeamScreen(teamIndex: 0)));
      await tester.pumpAndSettle();

      // Expand the exercise tile (chevron) — the schedule only renders once
      // expanded.
      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pumpAndSettle();

      expect(find.byType(ScheduleCard), findsOneWidget);
      expect(find.byType(CardSectionHeader), findsOneWidget);
      expect(find.byType(ScheduleTable), findsOneWidget);
      // No standalone PhaseHeaders left above the table.
      expect(find.byType(PhaseHeaders), findsOneWidget); // the table's own
      expect(
        find.descendant(
          of: find.byType(ScheduleTable),
          matching: find.byType(Card),
        ),
        findsNothing,
        reason: 'the old per-round Card-wrapped rows are gone',
      );

      expect(find.text('Post 1'), findsOneWidget);
      expect(find.text('Post 2'), findsOneWidget);
      expect(find.text('DRILL'), findsOneWidget);
      expect(find.text('EVAL'), findsOneWidget);
      expect(find.text('ROLL'), findsOneWidget);
    },
  );

  testWidgets(
    'shows the close-X with no MasterDetailScope in context (narrow)',
    (tester) async {
      await tester.pumpWidget(_harness(const TeamScreen(teamIndex: 0)));
      await tester.pumpAndSettle();

      // Fix B: team_screen.dart was missed in the leading migration and
      // hardcoded a plain close-X IconButton instead of MasterDetailLeading.
      // Outside a MasterDetailScope (narrow/full-screen sheet) that shared
      // widget also renders a close-X, so this alone doesn't prove the fix —
      // paired with the wide-layout case below, it does.
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.sidebar_left), findsNothing);
    },
  );

  testWidgets(
    'shows the sidebar toggle instead of the close-X under a '
    'MasterDetailScope with a collapse toggle (wide)',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MasterDetailScope(
            target: ValueNotifier<ContextSheetTarget?>(null),
            emptyPaneBuilder: (_) => const SizedBox.shrink(),
            onToggleMaster: () {},
            child: const TeamScreen(teamIndex: 0),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(CupertinoIcons.sidebar_left), findsOneWidget);
      expect(find.byIcon(Icons.close), findsNothing);
    },
  );
}
