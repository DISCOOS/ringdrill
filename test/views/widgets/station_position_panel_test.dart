import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/views/widgets/position_card.dart';
import 'package:ringdrill/views/widgets/station_position_panel.dart';

/// docs/prompts/position-panel-read-alignment.md — StationPositionPanel on
/// the shared PositionCardShell: a bordered card (mini-map + coordinate bar
/// + chevron) when the station has a position, and the plain `noLocation`
/// fallback (no card, no map) when it does not.
void main() {
  late AppLocalizations l;

  setUpAll(() async {
    l = await AppLocalizations.delegate.load(const Locale('en'));
  });

  Exercise exercise() => Exercise(
    uuid: 'ex-1',
    name: 'Exercise',
    startTime: const SimpleTimeOfDay(hour: 8, minute: 0),
    endTime: const SimpleTimeOfDay(hour: 9, minute: 0),
    numberOfTeams: 1,
    numberOfRounds: 1,
    executionTime: 10,
    evaluationTime: 5,
    rotationTime: 5,
    stations: const [],
    schedule: const [],
  );

  Future<void> pump(WidgetTester tester, Station station) => tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: StationPositionPanel(exercise: exercise(), station: station),
      ),
    ),
  );

  testWidgets(
    'a positioned station renders the shared card shell with a chevron and '
    'the UTM coordinate, and tapping it opens the interactive map sheet',
    (tester) async {
      final station = Station(
        index: 0,
        name: 'Post 1',
        position: const LatLng(58.99, 10.43),
      );
      await pump(tester, station);

      expect(find.byType(PositionCardShell), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      expect(find.text(l.noLocation), findsNothing);

      expect(find.byType(BottomSheet), findsNothing);
      await tester.tap(find.byType(PositionCardShell));
      await tester.pumpAndSettle();

      // openStationMapSheet opens the interactive map in a modal sheet.
      expect(find.byType(BottomSheet), findsOneWidget);
    },
  );

  testWidgets(
    'a station without a position shows the noLocation fallback and no card',
    (tester) async {
      final station = Station(index: 0, name: 'Post 1');
      await pump(tester, station);

      expect(find.text(l.noLocation), findsOneWidget);
      expect(find.byType(PositionCardShell), findsNothing);
      expect(find.byIcon(Icons.chevron_right), findsNothing);
    },
  );

  testWidgets(
    'asCard defaults to false (no nested Card when already inside one, e.g. '
    'an ExpandableTile body) and opts into its own Card when set',
    (tester) async {
      final station = Station(
        index: 0,
        name: 'Post 1',
        position: const LatLng(58.99, 10.43),
      );

      // Default (false): embedding inside an ambient Card must not add a
      // second, nested Card around the panel.
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Card(
              child: StationPositionPanel(
                exercise: exercise(),
                station: station,
              ),
            ),
          ),
        ),
      );
      expect(find.byType(Card), findsOneWidget);

      // asCard: true — a bare page with no ambient card, so the panel
      // must draw its own.
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: StationPositionPanel(
              exercise: exercise(),
              station: station,
              asCard: true,
            ),
          ),
        ),
      );
      expect(find.byType(Card), findsOneWidget);
    },
  );
}
