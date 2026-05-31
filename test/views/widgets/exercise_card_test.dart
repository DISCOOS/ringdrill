import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/theme.dart';
import 'package:ringdrill/views/program_view.dart';
import 'package:ringdrill/views/widgets/expandable_tile.dart';

Exercise _exercise({
  String uuid = 'exercise-card-test',
  String name = 'Search exercise',
  List<Station> stations = const [],
}) => Exercise(
  uuid: uuid,
  name: name,
  startTime: const SimpleTimeOfDay(hour: 10, minute: 0),
  endTime: const SimpleTimeOfDay(hour: 11, minute: 0),
  numberOfTeams: 1,
  numberOfRounds: 1,
  executionTime: 45,
  evaluationTime: 10,
  rotationTime: 5,
  stations: stations,
  schedule: const [[]],
);

Widget _harness({
  VoidCallback? onOpen,
  VoidCallback? onLongPress,
  List<Station> stations = const [],
  ThemeData? theme,
  bool? expanded,
  VoidCallback? onToggle,
}) => MaterialApp(
  theme: theme,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: Builder(
      builder: (context) => ExerciseCard(
        exercise: _exercise(stations: stations),
        localizations: AppLocalizations.of(context)!,
        markers: const [],
        expanded: expanded,
        onOpen: onOpen,
        onLongPress: onLongPress,
        onToggle: onToggle,
      ),
    ),
  ),
);

Widget _mutexHarness() => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: Builder(
      builder: (context) {
        String? expandedUuid;
        return StatefulBuilder(
          builder: (context, setState) {
            Widget card(String uuid, String name, String stationName) {
              return ExerciseCard(
                exercise: _exercise(
                  uuid: uuid,
                  name: name,
                  stations: [Station(index: 0, name: stationName)],
                ),
                localizations: AppLocalizations.of(context)!,
                markers: const [],
                expanded: expandedUuid == uuid,
                onToggle: () {
                  setState(() {
                    expandedUuid = expandedUuid == uuid ? null : uuid;
                  });
                },
              );
            }

            return Column(
              children: [
                card('exercise-a', 'Exercise A', 'Station A'),
                card('exercise-b', 'Exercise B', 'Station B'),
              ],
            );
          },
        );
      },
    ),
  ),
);

void main() {
  testWidgets('long-pressing card fires onLongPress only', (tester) async {
    var openCount = 0;
    var longPressCount = 0;
    await tester.pumpWidget(
      _harness(onOpen: () => openCount++, onLongPress: () => longPressCount++),
    );

    await tester.longPress(find.text('Search exercise'));
    await tester.pump();

    expect(longPressCount, 1);
    expect(openCount, 0);
  });

  testWidgets('station list expands even when stations have no map position', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(stations: const [Station(index: 0, name: 'Station Alpha')]),
    );

    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();

    expect(find.byType(ExpandableTile), findsNWidgets(2));
    expect(find.text('Station Alpha'), findsOneWidget);

    // The station row mirrors the CoordinatorScreen / StationListView
    // convention: swipe-to-edit (Dismissible) plus tap-to-open and
    // long-press-to-edit gestures wired on the tile. The round-by-round
    // rotation strip ("Team | 1 2 ...") is intentionally absent here.
    expect(find.text('Team'), findsNothing);
    expect(find.byType(Dismissible), findsOneWidget);
    final tiles = tester.widgetList<ExpandableTile>(
      find.byType(ExpandableTile),
    );
    expect(tiles.last.onOpen, isNotNull);
    expect(tiles.last.onLongPress, isNotNull);
    expect(
      tiles.last.color,
      Theme.of(
        tester.element(find.text('Station Alpha')),
      ).colorScheme.surfaceContainerHigh,
    );
  });

  testWidgets('station list uses brand dark background in dark mode', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        theme: ringDrillDarkTheme,
        stations: const [Station(index: 0, name: 'Station Alpha')],
      ),
    );

    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();

    final tiles = tester.widgetList<ExpandableTile>(
      find.byType(ExpandableTile),
    );
    expect(tiles.last.color, RingDrillColors.brandDeep);
  });

  testWidgets('controlled cards collapse the previously expanded card', (
    tester,
  ) async {
    await tester.pumpWidget(_mutexHarness());

    await tester.tap(find.byType(IconButton).at(0));
    await tester.pumpAndSettle();
    expect(find.text('Station A'), findsOneWidget);
    expect(find.text('Station B'), findsNothing);

    await tester.tap(find.byType(IconButton).at(1));
    await tester.pumpAndSettle();
    expect(find.text('Station A'), findsNothing);
    expect(find.text('Station B'), findsOneWidget);
  });
}
