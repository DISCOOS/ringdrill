// Adding a team to a parallel group must not move the form.
//
// Reported from real use: building Round 2 or 3 meant scrolling back down after every
// single team. Reproduced here against the composition the exercise editor actually
// uses — a text field above a long scroll view — because the cause is not in the
// section's own tree, which is plain enough to rule out.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/numbering.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/models/team.dart';
import 'package:ringdrill/views/widgets/exercise_groups_section.dart';

const _stations = [
  Station(index: 0, name: 'Angler'),
  Station(index: 1, name: 'Car camping'),
  Station(index: 2, name: 'Runner'),
  Station(index: 3, name: 'Suicide risk'),
];

const _teams = [
  Team(uuid: 't1', index: 0, name: 'Lag 1'),
  Team(uuid: 't2', index: 1, name: 'Lag 2'),
  Team(uuid: 't3', index: 2, name: 'Lag 3'),
  Team(uuid: 't4', index: 3, name: 'Lag 4'),
];

/// Three groups, so the last one is well below the fold — the state the report
/// describes.
const _threeGroups = [
  ExerciseGroup(
    stations: [
      GroupSlot(stationIndex: 0, teams: [0, 1]),
      GroupSlot(stationIndex: 2, teams: [2, 3]),
    ],
  ),
  ExerciseGroup(
    stations: [
      GroupSlot(stationIndex: 1, teams: [0, 1]),
      GroupSlot(stationIndex: 3, teams: [2, 3]),
    ],
  ),
  ExerciseGroup(stations: [GroupSlot(stationIndex: 0, teams: [0])]),
];

/// Mirrors the exercise editor's own composition: a token-aware text field at the top
/// of a `SingleChildScrollView`, the groups section far below it, and a `setState`
/// parent that owns the list.
class _Harness extends StatefulWidget {
  const _Harness();

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  List<ExerciseGroup> groups = _threeGroups;
  final controller = TextEditingController(text: 'Førsteinnsats søk');
  final focusNode = FocusNode();

  @override
  void dispose() {
    controller.dispose();
    focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: controller,
              focusNode: focusNode,
              decoration: const InputDecoration(labelText: 'Exercise Name'),
            ),
            const SizedBox(height: 600),
            ExerciseGroupsSection(
              groups: groups,
              stations: _stations,
              teams: _teams,
              numberOfTeams: 4,
              exerciseNumber: 1,
              stationNumberFormat: StationNumberFormat.alpha,
              onChanged: (next) => setState(() => groups = next),
            ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('adding a team leaves the scroll offset where it was', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const _Harness(),
      ),
    );
    final l = await AppLocalizations.delegate.load(const Locale('en'));

    // The author has been typing in the name field, as they would have been.
    await tester.tap(find.byType(TextFormField));
    await tester.pumpAndSettle();

    // Then scrolls down to the last group and adds a team to it.
    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text(l.exerciseGroupAddTeam).last,
      300,
      scrollable: scrollable,
    );
    await tester.pumpAndSettle();
    final before = tester.state<ScrollableState>(scrollable).position.pixels;
    expect(before, greaterThan(0), reason: 'the test must actually be scrolled');

    await tester.tap(find.text(l.exerciseGroupAddTeam).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lag 2').last);
    await tester.pumpAndSettle();

    expect(
      tester.state<ScrollableState>(scrollable).position.pixels,
      before,
      reason:
          'the form jumped after adding a team, so every team in a group below '
          'the fold costs the author a scroll',
    );
  });

  testWidgets('with nothing focused it never jumped — which names the cause', (
    tester,
  ) async {
    // The discriminator. 20px is where the name field sits, so the jump is not a lost
    // offset: it is `Scrollable.ensureVisible` restoring focus to the field the author
    // last typed in when the picker's route pops. No focus, nothing to scroll to.
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const _Harness(),
      ),
    );
    final l = await AppLocalizations.delegate.load(const Locale('en'));

    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text(l.exerciseGroupAddTeam).last,
      300,
      scrollable: scrollable,
    );
    await tester.pumpAndSettle();
    final before = tester.state<ScrollableState>(scrollable).position.pixels;

    await tester.tap(find.text(l.exerciseGroupAddTeam).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lag 2').last);
    await tester.pumpAndSettle();

    expect(tester.state<ScrollableState>(scrollable).position.pixels, before);
  });
}
