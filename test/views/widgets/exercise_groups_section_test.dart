// ADR-0062's parallel-group editor, mockup panels 7 and 7b.
//
// Two things are worth testing here and the widget tree is not one of them: that the
// author cannot easily make the collision the rules forbid, and that when a document
// already contains one the editor says so in the same terms `analyze` does.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/numbering.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/models/team.dart';
import 'package:ringdrill/views/widgets/border_shell.dart';
import 'package:ringdrill/views/widgets/card_section_header.dart';
import 'package:ringdrill/views/widgets/exercise_groups_section.dart';

const _stations = [
  Station(index: 0, name: 'Missing child'),
  Station(index: 1, name: 'Abandoned vehicle'),
  Station(index: 2, name: 'Shoreline sweep'),
];

const _teams = [
  Team(uuid: 't1', index: 0, name: 'Lag 2.1'),
  Team(uuid: 't2', index: 1, name: 'Lag 2.2'),
  Team(uuid: 't3', index: 2, name: 'Lag 2.3'),
  Team(uuid: 't4', index: 3, name: 'Lag 2.4'),
];

Future<AppLocalizations> _pump(
  WidgetTester tester, {
  required List<ExerciseGroup> groups,
  ValueChanged<List<ExerciseGroup>>? onChanged,
}) async {
  tester.view.physicalSize = const Size(600, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: ExerciseGroupsSection(
            groups: groups,
            stations: _stations,
            teams: _teams,
            numberOfTeams: 4,
            exerciseNumber: 7,
            stationNumberFormat: StationNumberFormat.alpha,
            onChanged: onChanged ?? (_) {},
          ),
        ),
      ),
    ),
  );
  return AppLocalizations.delegate.load(const Locale('en'));
}

/// The uneven split the mockup draws: four teams across three stations, 2 + 1 + 1.
const _uneven = [
  ExerciseGroup(
    stations: [
      GroupSlot(stationIndex: 0, teams: [0, 1]),
      GroupSlot(stationIndex: 1, teams: [2]),
      GroupSlot(stationIndex: 2, teams: [3]),
    ],
  ),
];

void main() {
  testWidgets('a group card lines up with the section header above it', (
    tester,
  ) async {
    // The cards used to carry an 8px side margin, which read as a stack of rounds
    // belonging to something narrower than its own header — the header's rule ran past
    // them on both sides.
    await _pump(tester, groups: _uneven);

    final header = tester.getRect(find.byType(CardSectionHeader));
    final card = tester.getRect(find.byType(BorderShell).first);

    expect(card.left, header.left);
    expect(card.right, header.right);
  });

  testWidgets('a group card is flat and bordered, like the editors\' others', (
    tester,
  ) async {
    // A raised `Card` among underlined fields reads as something that could be dragged.
    // The editors' treatment is [BorderShell] — flat, `outlineVariant` hairline — which
    // the station editor's placement card already uses; this asserts the group cards did
    // not quietly keep a Material `Card` of their own.
    await _pump(tester, groups: _uneven);

    expect(find.byType(BorderShell), findsOne);
    expect(find.byType(Card), findsNothing);
    // Opaque, so a swipe-to-delete reveal cannot show through the card body.
    final shell = tester.widget<BorderShell>(find.byType(BorderShell));
    expect(shell.color, isNotNull);
  });

  testWidgets('an empty section says what a group is', (tester) async {
    final l = await _pump(tester, groups: const []);
    expect(find.text(l.exerciseGroupsEmpty), findsOne);
    expect(find.text(l.exerciseGroupAdd), findsOne);
  });

  testWidgets('groups of unequal size are shown as authored', (tester) async {
    // 2 + 1 + 1. Nothing here assumes halves.
    final l = await _pump(tester, groups: _uneven);

    expect(find.text('${l.round(1)} 1'), findsOne);
    for (final station in _stations) {
      expect(find.text(station.name), findsOne);
    }
    for (final team in _teams) {
      expect(find.text(team.name), findsOne);
    }
    // Every team is placed, so neither rule is broken.
    expect(find.byIcon(Icons.error_outline), findsNothing);
    expect(find.byIcon(Icons.info_outline), findsNothing);
  });

  testWidgets('a team on two stations of one group is flagged as an error', (
    tester,
  ) async {
    // The stations run at once, so it cannot be at both.
    final l = await _pump(
      tester,
      groups: const [
        ExerciseGroup(
          stations: [
            GroupSlot(stationIndex: 0, teams: [0, 1]),
            GroupSlot(stationIndex: 1, teams: [1, 2]),
            GroupSlot(stationIndex: 2, teams: [3]),
          ],
        ),
      ],
    );

    expect(find.byIcon(Icons.error_outline), findsOne);
    expect(find.text(l.exerciseGroupTeamCollision('Lag 2.2')), findsOne);
    // Both chips carry the mark, because neither placement is more wrong than the
    // other and the author is who knows which to drop.
    expect(find.text('Lag 2.2'), findsNWidgets(2));
  });

  testWidgets('a team in no station of the group is a warning, not an error', (
    tester,
  ) async {
    // Holding a team back is legitimate; saying so is still worth it.
    final l = await _pump(
      tester,
      groups: const [
        ExerciseGroup(
          stations: [
            GroupSlot(stationIndex: 0, teams: [0, 1, 2]),
          ],
        ),
      ],
    );

    expect(find.byIcon(Icons.error_outline), findsNothing);
    expect(find.byIcon(Icons.info_outline), findsOne);
    expect(find.text(l.exerciseGroupTeamsUnplaced('Lag 2.4')), findsOne);
  });

  testWidgets('an empty group makes no unplaced-team noise', (tester) async {
    // A group with no stations yet is mid-edit, not wrong. Warning about all four
    // teams the moment "New parallel group" is tapped would be noise the author
    // caused by starting.
    await _pump(tester, groups: const [ExerciseGroup(stations: [])]);
    expect(find.byIcon(Icons.info_outline), findsNothing);
  });

  testWidgets('adding a team offers only the ones not yet in the group', (
    tester,
  ) async {
    // The collision is made hard to commit in the first place; the check stays
    // because a document can still be written by hand.
    List<ExerciseGroup>? saved;
    final l = await _pump(
      tester,
      groups: const [
        ExerciseGroup(
          stations: [
            GroupSlot(stationIndex: 0, teams: [0, 1]),
            GroupSlot(stationIndex: 1, teams: []),
          ],
        ),
      ],
      onChanged: (groups) => saved = groups,
    );

    await tester.tap(find.text(l.exerciseGroupAddTeam).last);
    await tester.pumpAndSettle();

    // 2.1 and 2.2 are taken; only 2.3 and 2.4 are on offer.
    expect(find.text('Lag 2.3'), findsOne);
    expect(find.text('Lag 2.4'), findsOne);

    await tester.tap(find.text('Lag 2.3'));
    await tester.pumpAndSettle();

    expect(saved!.single.stations.last.teams, [2]);
  });

  testWidgets('adding a station offers only the ones not already in it', (
    tester,
  ) async {
    // One station cannot run twice at the same time, so offering it again would be
    // offering a mistake.
    List<ExerciseGroup>? saved;
    final l = await _pump(
      tester,
      groups: const [
        ExerciseGroup(stations: [GroupSlot(stationIndex: 0)]),
      ],
      onChanged: (groups) => saved = groups,
    );

    await tester.tap(find.text(l.exerciseGroupAddStation));
    await tester.pumpAndSettle();

    expect(find.text('Abandoned vehicle'), findsOne);
    expect(find.text('Shoreline sweep'), findsOne);
    // Already in the group, so it is not offered again — the one occurrence left is
    // the row behind the picker.
    expect(find.text('Missing child'), findsOne);

    await tester.tap(find.text('Shoreline sweep'));
    await tester.pumpAndSettle();

    expect(saved!.single.stations.map((s) => s.stationIndex), [0, 2]);
  });

  testWidgets('removing a team chip drops just that team', (tester) async {
    List<ExerciseGroup>? saved;
    await _pump(tester, groups: _uneven, onChanged: (groups) => saved = groups);

    await tester.tap(
      find.descendant(
        of: find.widgetWithText(InputChip, 'Lag 2.1'),
        matching: find.byIcon(Icons.close),
      ),
    );
    await tester.pumpAndSettle();

    expect(saved!.single.stations.first.teams, [1]);
  });

  testWidgets('adding a group appends an empty one', (tester) async {
    List<ExerciseGroup>? saved;
    final l = await _pump(
      tester,
      groups: _uneven,
      onChanged: (groups) => saved = groups,
    );

    await tester.tap(find.text(l.exerciseGroupAdd));
    await tester.pumpAndSettle();

    expect(saved, hasLength(2));
    expect(saved!.last.stations, isEmpty);
  });
}
